# Quickstart: WAF Logging to Log Analytics

**Feature**: 003-waf-logging  
**Estimated Time**: 15 minutes  
**Prerequisites**: Azure subscription, existing TXT TV infrastructure deployed

## What You'll Learn

- How to query WAF logs in Log Analytics
- How to identify blocked requests and security threats
- How to troubleshoot WAF false positives
- How to verify diagnostic settings are working

---

## Prerequisites

1. **Existing TXT TV infrastructure deployed**:
   - Application Gateway with WAF enabled
   - Log Analytics workspace
   - At least one environment (dev, staging, or prod)

2. **Azure CLI installed**: Version 2.50+ ([Install guide](https://docs.microsoft.com/cli/azure/install-azure-cli))

3. **Azure PowerShell installed** (for testing): Version 9.0+ ([Install guide](https://docs.microsoft.com/powershell/azure/install-az-ps))

4. **Access permissions**:
   - Contributor role on resource group (to deploy infrastructure)
   - Log Analytics Reader role on workspace (to query logs)

---

## Step 1: Deploy Updated Infrastructure (5 minutes)

The infrastructure changes are already committed to the repository. Deploy them to your environment:

```powershell
# Navigate to repository root
cd D:\ohjelmointi\txttv

# Set your environment
$environment = "dev"  # or "staging", "prod"

# Deploy infrastructure
.\infrastructure\scripts\Deploy-Infrastructure.ps1 `
    -Environment $environment `
    -SubscriptionId "<your-subscription-id>" `
    -Location "westeurope"
```

**What happens**:
- Application Gateway diagnostic settings are created
- Settings configured to send WAF logs to Log Analytics workspace
- Logs begin flowing within 5 minutes

**Verify deployment**:
```powershell
# Get Application Gateway resource ID
$appGwId = (Get-AzApplicationGateway -Name "txttv-$environment-appgw" -ResourceGroupName "txttv-$environment-rg").Id

# Check diagnostic settings
Get-AzDiagnosticSetting -ResourceId $appGwId
```

**Expected output**:
```
Name                              : txttv-dev-appgw-diagnostics
WorkspaceId                       : /subscriptions/.../txttv-dev-law
Logs[0].Category                  : ApplicationGatewayFirewallLog
Logs[0].Enabled                   : True
```

---

## Step 2: Generate Test Traffic (2 minutes)

Trigger some WAF events to verify logging is working:

```powershell
# Get Application Gateway public FQDN
$appGw = Get-AzApplicationGateway -Name "txttv-$environment-appgw" -ResourceGroupName "txttv-$environment-rg"
$publicIp = Get-AzPublicIpAddress -ResourceId $appGw.FrontendIPConfigurations[0].PublicIPAddress.Id
$endpoint = "http://$($publicIp.DnsSettings.Fqdn)"

Write-Host "Endpoint: $endpoint"

# Test 1: Legitimate request (should be allowed)
Invoke-WebRequest -Uri "$endpoint/page?id=100" -UseBasicParsing

# Test 2: SQL injection attempt (should be blocked)
try {
    Invoke-WebRequest -Uri "$endpoint/page?id=100' OR '1'='1" -UseBasicParsing
} catch {
    Write-Host "Request blocked by WAF (expected)" -ForegroundColor Green
}

# Test 3: XSS attempt (should be blocked)
try {
    Invoke-WebRequest -Uri "$endpoint/page?id=<script>alert('xss')</script>" -UseBasicParsing
} catch {
    Write-Host "Request blocked by WAF (expected)" -ForegroundColor Green
}
```

---

## Step 3: Query WAF Logs (5 minutes)

### Using Azure Portal

1. Navigate to **Log Analytics workspace** in Azure Portal
2. Select **Logs** from left menu
3. Run queries below in the query window

### Using Azure CLI

```bash
# Get workspace ID
az monitor log-analytics workspace show \
    --resource-group "txttv-dev-rg" \
    --workspace-name "txttv-dev-law" \
    --query customerId -o tsv

# Query logs (requires workspace ID from above)
az monitor log-analytics query \
    --workspace "<workspace-id>" \
    --analytics-query "<KQL query from below>"
```

### Sample Queries

**Query 1: All WAF events in last hour**
```kql
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where TimeGenerated > ago(1h)
| project TimeGenerated, clientIp_s, requestUri_s, action_s, ruleId_s, message_s
| order by TimeGenerated desc
```

**Expected Result**: See both allowed and blocked requests from Step 2

**Query 2: Only blocked requests**
```kql
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| where TimeGenerated > ago(1h)
| project TimeGenerated, clientIp_s, requestUri_s, ruleId_s, message_s
| order by TimeGenerated desc
```

**Expected Result**: See SQL injection and XSS attempts from Step 2

**Query 3: Blocked requests by source IP**
```kql
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| where TimeGenerated > ago(24h)
| summarize BlockCount = count() by clientIp_s
| order by BlockCount desc
```

**Expected Result**: Your test client IP with BlockCount = 2

**Query 4: Most triggered WAF rules**
```kql
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where TimeGenerated > ago(24h)
| summarize TriggerCount = count() by ruleId_s, message_s
| order by TriggerCount desc
| take 10
```

**Expected Result**: SQL injection and XSS rules at the top

---

## Step 4: Troubleshoot False Positive (3 minutes)

Scenario: Legitimate user reports they can't access `/page?id=100'test`

**Find the blocked request**:
```kql
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where requestUri_s contains "100'test"
| project TimeGenerated, clientIp_s, requestUri_s, action_s, ruleId_s, message_s, details_message_s
```

**Result shows**:
- `ruleId_s`: 942100
- `message_s`: SQL Injection Attack Detected via libinjection
- `details_message_s`: Matched Data: 'test found within ARGS:id

**Analysis**: Single quote in `id` parameter triggers SQL injection rule

**Resolution options**:
1. Educate user: Don't use single quotes in page IDs
2. URL encode: User should send `id=100%27test`
3. Tune WAF rule: Exclude this specific parameter (requires WAF policy change, out of scope)

---

## Step 5: Verify Log Retention (2 minutes)

Check that logs are retained for 30 days as required by compliance:

```kql
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| summarize OldestLog = min(TimeGenerated), NewestLog = max(TimeGenerated), TotalEvents = count()
```

**Check Log Analytics workspace retention**:
```powershell
$workspace = Get-AzOperationalInsightsWorkspace -Name "txttv-$environment-law" -ResourceGroupName "txttv-$environment-rg"
$workspace.retentionInDays
```

**Expected Output**: 30

---

## Common Issues and Solutions

### Issue: No logs appearing after 5+ minutes

**Diagnosis**:
```powershell
# Verify diagnostic settings exist
$diagnostics = Get-AzDiagnosticSetting -ResourceId $appGwId
if ($diagnostics) {
    Write-Host "✅ Diagnostic settings configured"
} else {
    Write-Host "❌ Diagnostic settings missing"
}

# Verify WAF is enabled
$appGw = Get-AzApplicationGateway -Name "txttv-$environment-appgw" -ResourceGroupName "txttv-$environment-rg"
if ($appGw.Sku.Tier -eq "WAF_v2") {
    Write-Host "✅ WAF enabled"
} else {
    Write-Host "❌ WAF not enabled (SKU: $($appGw.Sku.Tier))"
}
```

**Solutions**:
- If diagnostic settings missing: Redeploy infrastructure with `logAnalyticsWorkspaceId` parameter
- If WAF not enabled: Cannot proceed - WAF logs require WAF_v2 SKU
- If both OK: Wait up to 10 minutes for initial log ingestion

### Issue: Logs appear but missing expected fields

**Diagnosis**:
```kql
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| take 1
| project *
```

**Solutions**:
- Fields with `_s` suffix are dynamic strings (normal)
- Missing `action_s` or `ruleId_s`: Log entry may be for non-WAF event (shouldn't happen with FirewallLog category)
- Empty values: Request may not have triggered any WAF rules (legitimate traffic)

### Issue: Too many logs, high cost

**Diagnosis**:
```kql
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where TimeGenerated > ago(1d)
| summarize EventCount = count(), DataMB = sum(estimate_data_size(*)) / 1024 / 1024
```

**Solutions**:
- Expected: 100-1000 events/day for low traffic site
- If >10k events/day: May indicate ongoing attack or excessive logging
- Mitigation: WAF in Prevention mode (blocks attacks earlier, fewer log entries)
- Cost reduction: Reduce retention from 30 days (requires constitution variance)

---

## Next Steps

1. **Create dashboard**: Visualize WAF blocks by IP, rule, time
2. **Set up alerts**: Notify security team when block rate exceeds threshold
3. **Integrate with SIEM**: Forward logs to external security system
4. **Tune WAF rules**: Adjust rules based on false positive analysis

---

## Clean Up (Optional)

To disable logging (not recommended for production):

```bicep
// In infrastructure/environments/{env}/main.bicep
module appGateway '../modules/app-gateway/main.bicep' = {
  params: {
    // ... other params ...
    logAnalyticsWorkspaceId: ''  // Empty string disables logging
  }
}
```

Redeploy infrastructure - diagnostic settings will be removed.

---

## Reference

**Official Documentation**:
- [Application Gateway diagnostics](https://learn.microsoft.com/azure/application-gateway/application-gateway-diagnostics)
- [WAF log schema](https://learn.microsoft.com/azure/web-application-firewall/ag/application-gateway-waf-metrics)
- [Log Analytics query language](https://learn.microsoft.com/azure/data-explorer/kusto/query/)

**Internal Documentation**:
- [spec.md](../spec.md) - Feature requirements
- [data-model.md](../data-model.md) - Log schema details
- [contracts/bicep-module-contract.md](../contracts/bicep-module-contract.md) - Infrastructure contracts
