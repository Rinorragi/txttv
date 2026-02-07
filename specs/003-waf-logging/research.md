# Research: WAF Logging to Log Analytics

**Feature**: 003-waf-logging  
**Phase**: 0 (Outline & Research)  
**Date**: February 7, 2026

## Research Tasks

### 1. Azure Application Gateway Diagnostic Settings

**Question**: What diagnostic log categories are available for Application Gateway, and which one captures WAF events?

**Findings**:
- **ApplicationGatewayFirewallLog**: Captures all WAF rule matches, blocks, and decisions
- **ApplicationGatewayAccessLog**: HTTP access logs (optional, not required for WAF monitoring)
- **ApplicationGatewayPerformanceLog**: Performance metrics (optional)
- **Diagnostic settings support multiple destinations**: Log Analytics workspace, Storage Account, Event Hub

**Decision**: Use `ApplicationGatewayFirewallLog` category exclusively for this feature
**Rationale**: This category contains all WAF security events (block/allow decisions, rule matches, request details). Access and performance logs are not required for security monitoring MVP.

**Alternatives considered**:
- Enable all log categories: Rejected - unnecessary storage costs and log volume for initial implementation
- Use Storage Account instead of Log Analytics: Rejected - Log Analytics provides better querying and integration with Azure Monitor

---

### 2. Bicep Diagnostic Settings Resource Type

**Question**: What is the correct Bicep resource type and API version for configuring Application Gateway diagnostic settings?

**Findings**:
- **Resource type**: `Microsoft.Insights/diagnosticSettings`
- **Recommended API version**: `2021-05-01-preview` (stable and widely used)
- **Parent resource**: Must reference Application Gateway resource ID using `scope` property
- **Required properties**: `workspaceId`, `logs` array with `category` and `enabled`

**Example Bicep syntax**:
```bicep
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${appGatewayName}-diagnostics'
  scope: appGateway
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'ApplicationGatewayFirewallLog'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}
```

**Decision**: Use `Microsoft.Insights/diagnosticSettings@2021-05-01-preview` with `scope` property targeting Application Gateway
**Rationale**: This is the standard Azure pattern for diagnostic settings. Retention is handled at the Log Analytics workspace level (already configured to 30 days), so diagnostic settings retention policy should be disabled (days: 0).

**Alternatives considered**:
- Newer API version `2023-01-01-preview`: Available but not necessary - no new features needed for this use case
- Child resource syntax: Deprecated pattern, scope property is preferred

---

### 3. Log Analytics Workspace Integration

**Question**: How does the Application Gateway module receive the Log Analytics workspace ID from the environment deployment?

**Findings**:
- Log Analytics workspace already exists in each environment (dev/staging/prod)
- Environment main.bicep files create workspace: `resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01'`
- Workspace ID is available via `logAnalytics.id` property
- Application Gateway module must accept workspace ID as a parameter

**Required changes**:
1. Add parameter to `infrastructure/modules/app-gateway/main.bicep`:
   ```bicep
   @description('Log Analytics workspace resource ID for diagnostic settings')
   param logAnalyticsWorkspaceId string = ''
   ```

2. Update environment main.bicep files to pass workspace ID:
   ```bicep
   module appGateway '../modules/app-gateway/main.bicep' = {
     name: 'appgw-deployment'
     params: {
       // ... existing params ...
       logAnalyticsWorkspaceId: logAnalytics.id
     }
   }
   ```

**Decision**: Add optional parameter with empty string default to maintain backward compatibility
**Rationale**: Empty string default allows module to be deployed without diagnostic settings (for testing), but production deployments will always pass workspace ID.

**Alternatives considered**:
- Make parameter required: Rejected - breaks existing deployments and testing scenarios
- Pass workspace name instead of ID: Rejected - resource ID is the standard Azure pattern

---

### 4. Log Data Schema and Query Patterns

**Question**: What fields are available in ApplicationGatewayFirewallLog, and what queries will users run?

**Findings**:
- **Key fields in WAF logs**:
  - `TimeGenerated`: Event timestamp
  - `clientIp`: Source IP address
  - `requestUri`: Requested URI
  - `action`: WAF action taken (Blocked, Allowed, Matched)
  - `ruleSetType`: Rule set (OWASP, custom)
  - `ruleSetVersion`: Version (e.g., 3.2)
  - `ruleId`: Specific rule that matched
  - `message`: Rule description
  - `severity`: Rule severity level

- **Common query patterns for users**:
  ```kql
  // All blocked requests in last 24 hours
  AzureDiagnostics
  | where ResourceType == "APPLICATIONGATEWAYS"
  | where Category == "ApplicationGatewayFirewallLog"
  | where action_s == "Blocked"
  | where TimeGenerated > ago(24h)
  | project TimeGenerated, clientIp_s, requestUri_s, ruleId_s, message_s
  
  // Blocked requests by source IP
  AzureDiagnostics
  | where ResourceType == "APPLICATIONGATEWAYS"  
  | where Category == "ApplicationGatewayFirewallLog"
  | where action_s == "Blocked"
  | summarize BlockCount = count() by clientIp_s
  | order by BlockCount desc
  
  // Specific WAF rule triggers
  AzureDiagnostics
  | where ResourceType == "APPLICATIONGATEWAYS"
  | where Category == "ApplicationGatewayFirewallLog"
  | where ruleId_s == "942100" // SQL injection example
  | project TimeGenerated, clientIp_s, requestUri_s, details_message_s
  ```

**Decision**: Document sample queries in quickstart.md for immediate user value
**Rationale**: Users need to know how to query logs once enabled. Providing query templates accelerates adoption and demonstrates feature value.

**Alternatives considered**:
- Create pre-built Azure dashboard: Future enhancement - out of scope for MVP
- Create alerting rules: Future enhancement - monitoring alerts not required initially

---

### 5. Testing Strategy

**Question**: How can we automatically verify that diagnostic settings are correctly configured and logs are flowing?

**Findings**:
- **Bicep validation**: `az bicep build` catches syntax errors
- **PowerShell tests**: Can verify diagnostic settings exist using Azure PowerShell cmdlets
- **Integration tests**: Send test request, verify log entry appears in Log Analytics

**Test scenarios**:
1. **Infrastructure test** (Pester): 
   ```powershell
   Describe "Application Gateway Diagnostic Settings" {
     It "Should have diagnostic settings configured" {
       $diagnostics = Get-AzDiagnosticSetting -ResourceId $appGatewayId
       $diagnostics | Should -Not -BeNullOrEmpty
       $diagnostics.Logs.Category | Should -Contain "ApplicationGatewayFirewallLog"
     }
     
     It "Should send logs to correct Log Analytics workspace" {
       $diagnostics = Get-AzDiagnosticSetting -ResourceId $appGatewayId
       $diagnostics.WorkspaceId | Should -Be $expectedWorkspaceId
     }
   }
   ```

2. **Integration test** (Pester + Wait):
   - Deploy infrastructure
   - Send WAF-triggering request (SQL injection test)
   - Wait 5 minutes for log ingestion
   - Query Log Analytics for the specific request
   - Verify log entry exists with correct action (Blocked)

**Decision**: Implement both infrastructure tests (immediate) and integration tests (5-minute wait)
**Rationale**: Infrastructure tests provide fast feedback during deployment. Integration tests validate end-to-end functionality but require wait time for log ingestion.

**Alternatives considered**:
- Skip integration tests: Rejected - need to verify logs actually flow, not just configuration exists
- Use mock/stub for integration tests: Not applicable - testing real Azure service behavior

---

## Summary of Decisions

| Decision | Choice | Key Rationale |
|----------|--------|---------------|
| Log category | ApplicationGatewayFirewallLog only | Contains all WAF security events; other categories unnecessary for MVP |
| Resource type | Microsoft.Insights/diagnosticSettings@2021-05-01-preview | Stable API, standard pattern with scope property |
| Workspace integration | Pass logAnalytics.id as module parameter | Follows Azure resource reference best practices |
| Retention policy | Disabled in diagnostic settings (0 days) | Retention managed at workspace level (30 days configured) |
| Testing approach | Pester tests for config + integration test for log flow | Fast feedback + end-to-end validation |
| Documentation | Include KQL query samples in quickstart | Immediate user value, demonstrates feature capabilities |

All NEEDS CLARIFICATION items from Technical Context have been resolved.
