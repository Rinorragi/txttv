# TxtTV Infrastructure Deployment

Deploy TxtTV infrastructure using Azure Deployment Stacks for managed resource lifecycle.

## Prerequisites

- **Azure CLI 2.50+** (with deployment stacks support)
- **Bicep CLI** (included with Azure CLI 2.20+)
- **Azure Subscription** with permissions to create resources

## Quick Start

### 1. Login to Azure

```bash
az login
az account set --subscription "your-subscription-id"
```

### 2. Create Resource Group

```bash
# For dev environment
az group create --name txttv-dev-rg --location westeurope

# For staging environment
az group create --name txttv-staging-rg --location westeurope

# For production environment
az group create --name txttv-prod-rg --location westeurope
```

### 3. Deploy Infrastructure Stack

Deployment stacks provide managed lifecycle, prevent accidental deletion, and enable deny assignments.

```bash
# Deploy to dev
az stack group create \
  --name txttv-dev-stack \
  --resource-group txttv-dev-rg \
  --template-file infrastructure/environments/dev/main.bicep \
  --parameters infrastructure/environments/dev/parameters.json \
  --deny-settings-mode none \
  --action-on-unmanage deleteResources

# Deploy to staging
az stack group create \
  --name txttv-staging-stack \
  --resource-group txttv-staging-rg \
  --template-file infrastructure/environments/staging/main.bicep \
  --parameters infrastructure/environments/staging/parameters.json \
  --deny-settings-mode none \
  --action-on-unmanage deleteResources

# Deploy to production (with deny assignments for safety)
az stack group create \
  --name txttv-prod-stack \
  --resource-group txttv-prod-rg \
  --template-file infrastructure/environments/prod/main.bicep \
  --parameters infrastructure/environments/prod/parameters.json \
  --deny-settings-mode denyDelete \
  --action-on-unmanage detachAll
```

### 4. Get Deployment Outputs

```bash
# Get stack outputs
az stack group show \
  --name txttv-dev-stack \
  --resource-group txttv-dev-rg \
  --query 'outputs'

# Get specific output values
az stack group show \
  --name txttv-dev-stack \
  --resource-group txttv-dev-rg \
  --query 'outputs.appGatewayFqdn.value' -o tsv
```

### 5. Update Existing Stack

```bash
# Update stack (same command as create)
az stack group create \
  --name txttv-dev-stack \
  --resource-group txttv-dev-rg \
  --template-file infrastructure/environments/dev/main.bicep \
  --parameters infrastructure/environments/dev/parameters.json \
  --deny-settings-mode none \
  --action-on-unmanage deleteResources
```

### 6. Clean Up Resources

```bash
# Delete stack (automatically removes managed resources)
az stack group delete \
  --name txttv-dev-stack \
  --resource-group txttv-dev-rg \
  --action-on-unmanage deleteAll \
  --yes

# Or delete entire resource group
az group delete --name txttv-dev-rg --yes
```

## Deployment Stack Options

### Deny Settings

Control what operations are denied on stack-managed resources:

- **none**: No deny assignments (default for dev/staging)
- **denyDelete**: Prevent deletion of resources (recommended for production)
- **denyWriteAndDelete**: Prevent modification and deletion (maximum protection)

### Action on Unmanage

Define what happens to resources removed from template:

- **deleteResources**: Delete resources no longer in template (dev/staging)
- **deleteAll**: Delete resources and resource groups
- **detachAll**: Leave resources but remove from stack management (production safety)

## Deployment Options

### Validate Before Deploy

```bash
az stack group validate \
  --name txttv-dev-stack \
  --resource-group txttv-dev-rg \
  --template-file infrastructure/environments/dev/main.bicep \
  --parameters infrastructure/environments/dev/parameters.json
```

### What-If Analysis

```bash
# See what changes will be made
az deployment group what-if \
  --resource-group txttv-dev-rg \
  --template-file infrastructure/environments/dev/main.bicep \
  --parameters infrastructure/environments/dev/parameters.json
```

### Deploy with Custom Parameters

```bash
az stack group create \
  --name txttv-dev-stack \
  --resource-group txttv-dev-rg \
  --template-file infrastructure/environments/dev/main.bicep \
  --parameters apimPublisherEmail="your-email@example.com" \
  --deny-settings-mode none
```

### List All Stacks

```bash
# List stacks in resource group
az stack group list --resource-group txttv-dev-rg --output table

# Show stack details
az stack group show \
  --name txttv-dev-stack \
  --resource-group txttv-dev-rg
```

## Project Structure

```
infrastructure/
├── environments/
│   ├── dev/
│   │   ├── main.bicep              # Dev environment template
│   │   └── parameters.json         # Dev environment parameters
│   ├── staging/
│   │   ├── main.bicep
│   │   └── parameters.json
│   └── prod/
│       ├── main.bicep
│       └── parameters.json
└── modules/                         # Reusable Bicep modules
    ├── apim/
    ├── app-gateway/
    ├── backend/
    ├── storage/
    └── waf/
```

## Environment Configuration

All environments deploy to a **single resource group**:
- Dev: `txttv-dev-rg`
- Staging: `txttv-staging-rg`  
- Production: `txttv-prod-rg`

Each environment includes:
- Azure API Management (APIM)
- Application Gateway with WAF
- Azure Functions Backend
- Storage Account
- Log Analytics Workspace
- Application Insights

## Troubleshooting

### Deployment Fails

**Check stack status:**
```bash
az stack group list --resource-group txttv-dev-rg --output table

# Show detailed stack information
az stack group show \
  --name txttv-dev-stack \
  --resource-group txttv-dev-rg
```

**View deployment errors:**
```bash
# Get provisioning state
az stack group show \
  --name txttv-dev-stack \
  --resource-group txttv-dev-rg \
  --query 'provisioningState'

# Check deployment operations (if needed)
az deployment operation group list \
  --resource-group txttv-dev-rg \
  --name txttv-dev-stack \
  --query "[?properties.provisioningState=='Failed']"
```

**Validate Bicep template:**
```bash
az bicep build --file infrastructure/environments/dev/main.bicep
```

### Stack Already Exists

If a stack already exists, the `create` command will update it. To start fresh:

```bash
# Delete existing stack first
az stack group delete \
  --name txttv-dev-stack \
  --resource-group txttv-dev-rg \
  --action-on-unmanage deleteAll \
  --yes

# Then create new stack
az stack group create \
  --name txttv-dev-stack \
  --resource-group txttv-dev-rg \
  --template-file infrastructure/environments/dev/main.bicep \
  --parameters infrastructure/environments/dev/parameters.json
```

### Deny Settings Conflicts

If you get deny assignment errors:

```bash
# Deploy with no deny settings initially
az stack group create \
  --name txttv-dev-stack \
  --resource-group txttv-dev-rg \
  --template-file infrastructure/environments/dev/main.bicep \
  --parameters infrastructure/environments/dev/parameters.json \
  --deny-settings-mode none

# Later, update with deny settings if needed
az stack group create \
  --name txttv-dev-stack \
  --resource-group txttv-dev-rg \
  --template-file infrastructure/environments/dev/main.bicep \
  --parameters infrastructure/environments/dev/parameters.json \
  --deny-settings-mode denyDelete
```

### Resource Naming Conflicts

Storage accounts must be globally unique. Update `baseName` parameter in `parameters.json`:

```json
{
  "baseName": {
    "value": "txttvunique123"
  }
}
```

## WAF Logging & Monitoring

All WAF events (blocked and allowed requests) are automatically logged to Log Analytics workspace.

### Query WAF Logs in Log Analytics

**Access Log Analytics:**
1. Navigate to Azure Portal → Log Analytics workspace (e.g., `txttv-dev-law`)
2. Click **Logs** in the left menu
3. Run KQL queries to analyze WAF activity

**All WAF events in last hour:**
```kql
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where TimeGenerated > ago(1h)
| project TimeGenerated, clientIp_s, requestUri_s, action_s, ruleId_s, message_s
| order by TimeGenerated desc
```

**Only blocked requests:**
```kql
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| where TimeGenerated > ago(1h)
| project TimeGenerated, clientIp_s, requestUri_s, ruleId_s, message_s
| order by TimeGenerated desc
```

**Blocked requests by source IP:**
```kql
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| where TimeGenerated > ago(24h)
| summarize BlockCount = count() by clientIp_s
| order by BlockCount desc
```

**Most triggered WAF rules:**
```kql
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where TimeGenerated > ago(24h)
| summarize TriggerCount = count() by ruleId_s, message_s
| order by TriggerCount desc
| take 10
```

### Troubleshooting WAF Blocks

When users report blocked requests:

1. **Find the blocked request:**
   ```kql
   AzureDiagnostics
   | where ResourceType == "APPLICATIONGATEWAYS"
   | where Category == "ApplicationGatewayFirewallLog"
   | where clientIp_s == "user-ip-address"
   | where TimeGenerated > ago(1h)
   | project TimeGenerated, requestUri_s, action_s, ruleId_s, message_s, details_message_s
   ```

2. **Analyze the matched rule:**
   - Check `ruleId_s` - Specific OWASP rule that triggered
   - Check `message_s` - Human-readable rule description
   - Check `details_message_s` - Exact pattern that matched

3. **Determine if false positive:**
   - Legitimate business use case → Consider WAF rule tuning
   - Attack attempt → Keep block in place
   - Edge case → Educate user or adjust application

### Verify Diagnostic Settings

**Check if logging is configured:**
```bash
# Get Application Gateway resource ID
AG_ID=$(az network application-gateway show \
  --name txttv-dev-appgw \
  --resource-group txttv-dev-rg \
  --query id -o tsv)

# Check diagnostic settings
az monitor diagnostic-settings list --resource $AG_ID
```

**Expected output:**
```json
{
  "name": "txttv-dev-appgw-diagnostics",
  "workspaceId": "/subscriptions/.../txttv-dev-law",
  "logs": [
    {
      "category": "ApplicationGatewayFirewallLog",
      "enabled": true
    }
  ]
}
```

### No Logs Appearing?

**Diagnosis steps:**
1. Verify diagnostic settings exist (command above)
2. Check WAF is enabled: SKU should be "WAF_v2"
3. Generate test traffic (malicious request to trigger WAF)
4. Wait 5-10 minutes for initial log ingestion
5. Query Log Analytics

**Common issues:**
- **Diagnostic settings missing**: Redeploy infrastructure
- **WAF not enabled**: Cannot log WAF events without WAF_v2 SKU
- **Wrong workspace**: Check that WorkspaceId matches your Log Analytics workspace

## Security Notes

⚠️ **Important Security Considerations:**

1. **Secret Keys**: Never commit signature keys to source control
2. **Parameters Files**: Use Azure Key Vault references for secrets in `parameters.json`
3. **Logging**: Be careful with verbose logging in production

## Support

For issues or questions:
- Check existing issues in the repository
- Review Azure CLI and Bicep documentation
- Verify Azure subscription permissions and quotas
