# API Contracts: WAF Logging to Log Analytics

**Feature**: 003-waf-logging  
**Phase**: 1 (Design & Contracts)  
**Date**: February 7, 2026

## Overview

This feature does not introduce HTTP API endpoints or external API contracts. The "contracts" are infrastructure contracts - Bicep module parameter interfaces and expected infrastructure state.

---

## Bicep Module Contract

### Application Gateway Module

**Module Path**: `infrastructure/modules/app-gateway/main.bicep`

#### Input Contract (Parameters)

**New Parameter**:

```bicep
@description('Log Analytics workspace resource ID for diagnostic settings')
param logAnalyticsWorkspaceId string = ''
```

**Parameter Contract**:
- **Name**: `logAnalyticsWorkspaceId`
- **Type**: `string`
- **Required**: No (default: empty string)
- **Format**: Azure resource ID - `/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.OperationalInsights/workspaces/{workspaceName}`
- **Validation**: None (Azure validates format at deployment)
- **Behavior**:
  - If empty string: Diagnostic settings not created (backward compatible)
  - If valid workspace ID: Diagnostic settings created and logs flow
  - If invalid workspace ID: Deployment fails with Azure error

**Existing Parameters** (unchanged):
- `appGatewayName`: string (required)
- `location`: string (optional, default: resourceGroup().location)
- `tags`: object (optional, default: {})
- `skuTier`: 'Standard_v2' | 'WAF_v2' (optional, default: 'WAF_v2')
- `capacity`: int (optional, default: 1)
- `apimGatewayUrl`: string (required)
- `wafPolicyId`: string (optional, default: '')
- `vnetName`: string (required)
- `subnetName`: string (optional, default: 'appgw-subnet')
- `vnetAddressPrefix`: string (optional, default: '10.0.0.0/16')
- `subnetAddressPrefix`: string (optional, default: '10.0.1.0/24')

#### Output Contract (no changes)

**Existing Outputs** (unchanged):
- `applicationGatewayId`: Application Gateway resource ID
- `publicIpAddress`: Application Gateway public IP address
- `publicFqdn`: Application Gateway public FQDN

**No new outputs added**: Diagnostic settings resource ID not exposed (internal implementation detail)

---

## Environment Main.bicep Contract

### Updated Module Invocation

**File**: `infrastructure/environments/{dev|staging|prod}/main.bicep`

**Before** (existing):
```bicep
module appGateway '../modules/app-gateway/main.bicep' = {
  name: 'appgw-deployment'
  params: {
    appGatewayName: appGatewayName
    location: location
    tags: tags
    apimGatewayUrl: apim.outputs.gatewayUrl
    wafPolicyId: waf.outputs.wafPolicyId
    vnetName: vnetName
  }
}
```

**After** (with diagnostic settings):
```bicep
module appGateway '../modules/app-gateway/main.bicep' = {
  name: 'appgw-deployment'
  params: {
    appGatewayName: appGatewayName
    location: location
    tags: tags
    apimGatewayUrl: apim.outputs.gatewayUrl
    wafPolicyId: waf.outputs.wafPolicyId
    vnetName: vnetName
    logAnalyticsWorkspaceId: logAnalytics.id  // NEW
  }
}
```

**Contract Change**:
- **Field**: `logAnalyticsWorkspaceId`
- **Value**: Reference to `logAnalytics.id` from workspace resource
- **Precondition**: `logAnalytics` resource must be deployed before `appGateway` module (already satisfied - workspace deployed earlier in file)
- **Breaking**: No - parameter has default value, existing deployments work without change

---

## Azure Resource Contract

### Diagnostic Settings Resource

**Expected Resource State** (post-deployment):

```json
{
  "type": "Microsoft.Insights/diagnosticSettings",
  "apiVersion": "2021-05-01-preview",
  "name": "txttv-{environment}-appgw-diagnostics",
  "scope": "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/applicationGateways/txttv-{environment}-appgw",
  "properties": {
    "workspaceId": "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.OperationalInsights/workspaces/txttv-{environment}-law",
    "logs": [
      {
        "category": "ApplicationGatewayFirewallLog",
        "enabled": true,
        "retentionPolicy": {
          "enabled": false,
          "days": 0
        }
      }
    ],
    "metrics": []
  }
}
```

**Contract Guarantees**:
1. **Exactly one** diagnostic setting per Application Gateway
2. **Exactly one** log category enabled: `ApplicationGatewayFirewallLog`
3. **Retention policy disabled** (managed at workspace level)
4. **No metrics** enabled (not required for MVP)
5. **Workspace ID matches** Log Analytics workspace in same environment

---

## Log Analytics Query Contract

### Log Entry Structure

**Table**: `AzureDiagnostics`

**Query Pattern**:
```kql
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where <filter conditions>
```

**Guaranteed Fields** (always present):
- `TimeGenerated`: datetime (UTC)
- `ResourceId`: string (Application Gateway resource ID)
- `Category`: string (always "ApplicationGatewayFirewallLog")
- `ResourceType`: string (always "APPLICATIONGATEWAYS")

**WAF Event Fields** (present when WAF evaluates request):
- `clientIp_s`: string (source IP)
- `requestUri_s`: string (requested URI)
- `action_s`: string (Blocked | Allowed | Matched)
- `ruleId_s`: string (matched rule ID)
- `message_s`: string (rule description)
- `severity_s`: string (Critical | High | Medium | Low)

**Contract**:
- Fields suffixed with `_s` are strings (Log Analytics convention for dynamic fields)
- Fields suffixed with `_g` are GUIDs
- Fields without suffix are typed (datetime, int, etc.)
- Missing fields indicate log entry for non-WAF event (should not occur with FirewallLog category)

---

## Testing Contract

### Infrastructure Test Requirements

**Test**: Diagnostic settings existence
```powershell
Get-AzDiagnosticSetting -ResourceId $appGatewayResourceId
```

**Expected Result**:
- Returns 1 diagnostic setting
- `Name`: "txttv-{env}-appgw-diagnostics"
- `WorkspaceId`: Matches expected Log Analytics workspace ID
- `Logs[0].Category`: "ApplicationGatewayFirewallLog"
- `Logs[0].Enabled`: $true

### Integration Test Requirements

**Test**: Log entry existence after WAF block
1. Send malicious request to Application Gateway endpoint
2. Wait up to 5 minutes
3. Query Log Analytics for entry matching request

**Expected Result**:
```kql
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where requestUri_s contains "{test-marker}"
| where action_s == "Blocked"
| project TimeGenerated, clientIp_s, ruleId_s, message_s
```

Returns exactly 1 row with:
- `TimeGenerated`: Within last 5 minutes
- `clientIp_s`: Test client IP
- `ruleId_s`: Expected WAF rule ID (e.g., 942100 for SQL injection)
- `action_s`: "Blocked"

---

## Breaking Changes

**None** - This feature is additive only:
- New optional parameter (backward compatible with default value)
- New resource created (doesn't affect existing resources)
- No modifications to existing parameters, outputs, or resources

**Compatibility**: Existing infrastructure deployments continue working without any changes.
