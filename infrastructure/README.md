# TxtTV Deployment & Testing Utility

Simple deployment scripts and HTTP testing utility for the TxtTV Azure infrastructure.

## Features

### 🚀 Simple Deployment Scripts
- **One-command deployment**: Deploy entire Azure infrastructure with a single PowerShell script
- **Environment support**: Separate configurations for dev, staging, and prod
- **Automatic validation**: Bicep template validation before deployment
- **Progress monitoring**: Real-time deployment status and resource tracking
- **Easy cleanup**: Simple script to remove all resources

### 🧪 HTTP Testing Utility
- **Send HTTP requests**: GET, POST, PUT, PATCH with JSON/XML support
- **HMAC signatures**: Automatic request signing with HMAC-SHA256
- **Load from files**: Execute batches of requests from JSON definitions
- **WAF testing**: Pre-built examples to test Web Application Firewall rules
- **Pretty output**: Color-coded responses with formatted JSON/XML

## Quick Start

### Prerequisites
- **PowerShell 7+** (for deployment scripts)
- **.NET 10 SDK** (for test utility)
- **Azure CLI** (authenticated with `az login`)
- **Bicep CLI** (or use `az bicep`)

### 1. Deploy Infrastructure

```powershell
# Deploy to dev environment
.\infrastructure\scripts\Deploy-Infrastructure.ps1 -Environment dev

# Deploy to production with confirmation
.\infrastructure\scripts\Deploy-Infrastructure.ps1 -Environment prod

# Dry-run (what-if mode)
.\infrastructure\scripts\Deploy-Infrastructure.ps1 -Environment dev -WhatIf
```

### 2. Send Test Requests

```powershell
cd tools\TxtTv.TestUtility

# Simple GET request
dotnet run -- send -u "https://your-apim.azure-api.net/pages/100" -m GET -v

# POST with JSON body and signature
dotnet run -- send `
  -u "https://your-apim.azure-api.net/backend-test" `
  -m POST `
  -b '{"message":"Hello TxtTV"}' `
  -k "your-secret-key" `
  -v

# Load and execute request from file
dotnet run -- load -f "..\..\examples\requests\legitimate\get-page-100.json" -k "your-key"

# Execute all WAF tests
dotnet run -- load -f "..\..\examples\requests\waf-tests" -k "your-key" -c
```

### 3. Clean Up Resources

```powershell
# Remove all resources (prompts for confirmation)
.\infrastructure\scripts\Remove-Infrastructure.ps1 -Environment dev

# Force delete without confirmation
.\infrastructure\scripts\Remove-Infrastructure.ps1 -Environment dev -Force

# Delete resources but preserve storage accounts
.\infrastructure\scripts\Remove-Infrastructure.ps1 -Environment dev -PreserveData
```

## Project Structure

```
txttv/
├── infrastructure/
│   ├── scripts/
│   │   ├── Deploy-Infrastructure.ps1    # Main deployment script
│   │   ├── Remove-Infrastructure.ps1    # Cleanup script
│   │   └── lib/                         # PowerShell modules
│   │       ├── BicepHelpers.psm1
│   │       ├── AzureAuth.psm1
│   │       └── ErrorHandling.psm1
│   ├── environments/
│   │   ├── dev/
│   │   │   ├── main.bicep
│   │   │   └── parameters.json
│   │   ├── staging/
│   │   └── prod/
│   └── modules/                         # Bicep infrastructure modules
├── tools/
│   └── TxtTv.TestUtility/              # F# HTTP test utility
│       ├── CliArguments.fs
│       ├── SignatureGenerator.fs
│       ├── RequestLoader.fs
│       ├── HttpClient.fs
│       ├── ResponseFormatter.fs
│       └── Program.fs
├── examples/
│   └── requests/
│       ├── legitimate/                  # Valid test requests
│       └── waf-tests/                   # WAF attack simulations
└── tests/
    ├── deployment/                      # PowerShell Pester tests
    └── utility/                         # F# xUnit tests
```

## Deployment Script Options

### Deploy-Infrastructure.ps1

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-Environment` | Target environment (dev/staging/prod) | **Required** |
| `-SubscriptionId` | Azure subscription ID | Current subscription |
| `-ResourceGroupName` | Resource group name | `rg-txttv-<env>` |
| `-Location` | Azure region | `westeurope` |
| `-TimeoutMinutes` | Deployment timeout | `30` |
| `-WhatIf` | Dry-run mode | `false` |
| `-Force` | Skip confirmations | `false` |
| `-Json` | JSON output | `false` |

### Remove-Infrastructure.ps1

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-Environment` | Target environment | **Required** |
| `-ResourceGroupName` | Resource group name | `rg-txttv-<env>` |
| `-DeleteResourceGroup` | Delete entire resource group | `true` |
| `-PreserveData` | Skip storage accounts | `false` |
| `-Force` | Skip confirmations | `false` |

## Test Utility Commands

### send - Send a single HTTP request

```powershell
dotnet run -- send [options]

Options:
  -u, --url <URL>              Target URL (required)
  -m, --method <METHOD>        HTTP method (GET/POST/PUT/PATCH) [default: GET]
  -b, --body <BODY>            Request body for POST/PUT
  -h, --header <HEADER>        Custom header (Name: Value) [repeatable]
  -k, --signature-key <KEY>    Secret key for HMAC signature
  -s, --signature-header <HDR> Signature header name [default: X-TxtTV-Signature]
  -v, --verbose                Verbose output
```

### load - Execute requests from JSON files

```powershell
dotnet run -- load [options]

Options:
  -f, --file <PATH>            JSON file or directory (required)
  -k, --signature-key <KEY>    Secret key for HMAC signature
  -s, --signature-header <HDR> Signature header name [default: X-TxtTV-Signature]
  -c, --continue-on-error      Continue after failures
  -v, --verbose                Verbose output
```

### list - List available request files

```powershell
dotnet run -- list [options]

Options:
  -d, --directory <PATH>       Directory to search [default: examples/requests]
  -p, --pattern <PATTERN>      File pattern [default: *.json]
  -r, --recursive              Search recursively
```

## Request File Format

Example request definition (`request.json`):

```json
{
  "name": "Get Page 100",
  "description": "Fetch TxtTV home page",
  "method": "GET",
  "url": "https://your-apim.azure-api.net/pages/100",
  "headers": {
    "Accept": "application/json"
  },
  "body": null
}
```

For WAF tests, add:

```json
{
  "expectedBlocked": true,
  "wafRule": "SQL Injection Protection"
}
```

## WAF Testing

The utility includes pre-built WAF test examples:

- **SQL Injection**: Tests query parameter and body injection
- **XSS Protection**: Tests cross-site scripting patterns
- **Path Traversal**: Tests directory traversal attempts
- **Command Injection**: Tests command injection in headers
- **Rate Limiting**: Tests request throttling

Run all WAF tests:

```powershell
cd tools\TxtTv.TestUtility
dotnet run -- load -f "..\..\examples\requests\waf-tests" -k "your-key" -c -v
```

Expected behavior:
- ✅ **Blocked requests** (403/429 status) indicate WAF is working
- ⚠️ **Successful requests** with malicious payloads indicate potential security issues

## Troubleshooting

### Deployment Issues

**Authentication error:**
```powershell
az login
az account set --subscription "your-subscription-id"
```

**Bicep validation fails:**
```powershell
bicep build infrastructure\environments\dev\main.bicep
```

**Resource naming conflicts:**
- Storage accounts must be globally unique
- Modify `parameters.json` to use unique names

### Test Utility Issues

**Build errors:**
```powershell
cd tools\TxtTv.TestUtility
dotnet restore
dotnet build
```

**Connection timeout:**
- Check APIM endpoint URL
- Verify network connectivity
- Increase timeout: modify `sendGetRequest` timeout parameter

**Signature mismatch:**
- Verify the secret key matches backend configuration
- Check timestamp synchronization
- Ensure request body matches signed content

## Testing

### Run PowerShell Tests

```powershell
cd tests\deployment
Invoke-Pester
```

### Test Diagnostic Settings (WAF Logging)

```powershell
# Set environment variables
$env:ENVIRONMENT_NAME = "dev"
$env:RESOURCE_GROUP_NAME = "txttv-dev-rg"
$env:AZURE_SUBSCRIPTION_ID = "your-subscription-id"

# Run diagnostic settings tests
Invoke-Pester tests\infrastructure\diagnostic-settings.tests.ps1
```

### Run F# Tests

```powershell
cd tests\utility
dotnet test
```

## WAF Logging & Monitoring

### Query WAF Logs in Log Analytics

All WAF events (blocked and allowed requests) are automatically logged to Log Analytics workspace.

**Access Log Analytics:**
1. Navigate to Azure Portal → Log Analytics workspace (e.g., `txttv-dev-law`)
2. Click **Logs** in the left menu
3. Run KQL queries to analyze WAF activity

**Common Queries:**

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
```powershell
$appGwId = (Get-AzApplicationGateway -Name "txttv-dev-appgw" -ResourceGroupName "txttv-dev-rg").Id
Get-AzDiagnosticSetting -ResourceId $appGwId
```

**Expected output:**
```
Name                 : txttv-dev-appgw-diagnostics
WorkspaceId          : /subscriptions/.../txttv-dev-law
Logs[0].Category     : ApplicationGatewayFirewallLog
Logs[0].Enabled      : True
```

### No Logs Appearing?

**Diagnosis steps:**
1. Verify diagnostic settings exist (command above)
2. Check WAF is enabled: `Get-AzApplicationGateway` → Sku.Tier should be "WAF_v2"
3. Generate test traffic (malicious request to trigger WAF)
4. Wait 5-10 minutes for initial log ingestion
5. Query Log Analytics

**Common issues:**
- **Diagnostic settings missing**: Redeploy infrastructure with `logAnalyticsWorkspaceId` parameter
- **WAF not enabled**: Cannot log WAF events without WAF_v2 SKU
- **Wrong workspace**: Check that WorkspaceId matches your environment's Log Analytics workspace

## Development

### Build Test Utility

```powershell
cd tools\TxtTv.TestUtility
dotnet build --configuration Release
```

### Install Globally (Optional)

```powershell
dotnet pack
dotnet tool install --global --add-source ./nupkg TxtTv.TestUtility
txttv-test send -u "https://example.com" -m GET
```

## Security Notes

⚠️ **Important Security Considerations:**

1. **Secret Keys**: Never commit signature keys to source control
2. **Parameters Files**: Use Azure Key Vault references for secrets in `parameters.json`
3. **WAF Tests**: Only run malicious requests against your own test environments
4. **Rate Limiting**: Be respectful when testing rate limits
5. **Logging**: Signature keys are logged in verbose mode - use with caution

## Contributing

See the main repository README for contribution guidelines.

## License

See LICENSE file in the root directory.

## Support

For issues or questions:
- Check existing issues in the repository
- Review Azure CLI and Bicep documentation
- Verify Azure subscription permissions and quotas
