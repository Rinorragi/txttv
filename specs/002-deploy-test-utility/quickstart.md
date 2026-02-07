# Quickstart Guide: Simple Deployment & WAF Testing Utility

**Feature**: 002-deploy-test-utility  
**Date**: February 7, 2026  
**Plan**: [plan.md](plan.md)

## Overview

This guide provides step-by-step instructions for deploying the TxtTV infrastructure to Azure and testing it using the HTTP testing utility. Complete these steps to have a working environment in under 10 minutes.

## Prerequisites

### Software Requirements
- **PowerShell 7.0+** - [Install PowerShell](https://aka.ms/powershell-release)
- **.NET SDK 10.0+** - [Install .NET](https://dotnet.microsoft.com/download/dotnet/10.0)
- **Azure CLI** or **Azure PowerShell Az module** - [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) | [Az Module](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps)
- **Git** - For cloning repository

### Azure Requirements
- Active Azure subscription
- Permissions to create resources (Contributor role on subscription or resource group)
- Sufficient quota for:
  - API Management (1 instance)
  - Application Gateway (1 instance)
  - Azure Functions (1 app)
  - Storage Account (1 account)

### Verify Prerequisites

```powershell
# Check PowerShell version (should be 7.0 or higher)
$PSVersionTable.PSVersion

# Check .NET SDK version (should be 10.0 or higher)
dotnet --version

# Check Azure CLI authentication
az account show

# OR check Azure PowerShell authentication
Get-AzContext
```

## Step 1: Clone Repository

```powershell
# Clone the repository
git clone https://github.com/your-org/txttv.git
cd txttv

# Switch to the feature branch
git checkout 002-deploy-test-utility
```

## Step 2: Configure Azure Authentication

### Option A: Azure CLI (Recommended)

```powershell
# Login to Azure
az login

# Set default subscription (if you have multiple)
az account set --subscription "Your Subscription Name or ID"

# Verify current subscription
az account show
```

### Option B: Azure PowerShell

```powershell
# Login to Azure
Connect-AzAccount

# Set default subscription (if you have multiple)
Set-AzContext -SubscriptionId "12345678-1234-1234-1234-123456789abc"

# Verify current context
Get-AzContext
```

## Step 3: Configure Deployment Parameters

Edit the environment-specific parameters file:

```powershell
# Open dev environment parameters
code infrastructure/environments/dev/parameters.json
```

Update the values:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environmentName": {
      "value": "dev"
    },
    "location": {
      "value": "eastus"  // Change to your preferred region
    },
    "baseName": {
      "value": "txttv"   // Change if you want different naming
    },
    "apimPublisherEmail": {
      "value": "your-email@example.com"  // Change to your email
    },
    "apimPublisherName": {
      "value": "Your Name"  // Change to your name
    }
  }
}
```

## Step 4: Deploy Infrastructure

Run the deployment script:

```powershell
# Navigate to infrastructure scripts directory
cd infrastructure/scripts

# Deploy to dev environment
.\Deploy-Infrastructure.ps1 -Environment dev

# The script will:
# 1. Validate Bicep templates
# 2. Check Azure authentication
# 3. Prompt for confirmation
# 4. Deploy resources (3-5 minutes)
# 5. Display deployment results
```

### Expected Output

```
[INFO] Starting deployment to environment: dev
[INFO] Validating Bicep templates...
[OK] Template validation successful
[INFO] Checking Azure authentication...
[OK] Authenticated as: user@example.com
[INFO] Target subscription: Your Subscription (12345678-1234-1234-1234-123456789abc)
[INFO] Resource group: txttv-dev-rg

Deploy to this subscription? [Y/n]: y

[INFO] Creating resource group: txttv-dev-rg
[INFO] Deploying Bicep templates...
[INFO] Deployment progress: 25% (1/4 modules)
[INFO] Deployment progress: 50% (2/4 modules)
[INFO] Deployment progress: 75% (3/4 modules)
[INFO] Deployment progress: 100% (4/4 modules)

[SUCCESS] Deployment completed in 3m 45s

Deployment Results:
--------------------
Status: Completed
Resources Created: 12
Resources Updated: 0
Resources Failed: 0

Endpoints:
- APIM Gateway: https://txttv-dev-apim.azure-api.net
- App Gateway: https://20.123.45.67
- Function App: https://txttv-dev-func.azurewebsites.net

Deployment Name: txttv-dev-20260207-143022
Correlation ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

### Troubleshooting Deployment

**Error: "Quota exceeded"**
```powershell
# Check quota usage
az vm list-usage --location eastus --output table

# Solution: Try different region or request quota increase
.\Deploy-Infrastructure.ps1 -Environment dev -Location westeurope
```

**Error: "Resource group already exists"**
```powershell
# Solution: Use existing resource group or delete it first
az group delete --name txttv-dev-rg --yes
```

## Step 5: Build the Test Utility

```powershell
# Navigate to utility directory
cd tools/TxtTv.TestUtility

# Restore dependencies and build
dotnet build

# Verify build succeeded
dotnet run -- --help
```

Expected help output:

```
TxtTV Test Utility v1.0.0

USAGE:
  TxtTv.TestUtility [command] [options]

COMMANDS:
  send      Send a single HTTP request
  load      Load and execute request from file
  list      List available example requests
  help      Display help information

Run 'TxtTv.TestUtility [command] --help' for more information on a command.
```

## Step 6: Configure the Utility

Set up the base URL and signing key:

```powershell
# Set environment variables (recommended)
$env:TXTTV_BASE_URL = "https://txttv-dev-apim.azure-api.net"
$env:TXTTV_SIGNING_KEY = "your-secret-key-here"

# OR use command-line arguments (shown in examples below)
```

## Step 7: Send Your First Test Request

### Example 1: Simple GET Request

```powershell
# Send GET request to fetch page 100
dotnet run -- send `
  --url "https://txttv-dev-apim.azure-api.net/api/pages/100" `
  --method GET `
  --key "my-secret-key"
```

Expected output:

```
[✓] GET /api/pages/100
    Status: 200 OK
    Duration: 145ms
    Signature: HMAC-SHA256 abc123...

Response Headers:
  Content-Type: application/json
  X-Powered-By: APIM

Response Body:
{
  "pageNumber": 100,
  "content": "Welcome to TXT TV..."
}
```

### Example 2: POST with JSON Payload

```powershell
dotnet run -- send `
  --url "https://txttv-dev-apim.azure-api.net/api/content" `
  --method POST `
  --header "Content-Type: application/json" `
  --body '{"title": "Test", "content": "Hello World"}' `
  --key "my-secret-key"
```

## Step 8: Run Example Requests

The repository includes pre-defined example requests:

```powershell
# List available examples
dotnet run -- list --directory ../../examples/requests

# Output:
# Available Examples:
#
# Legitimate Requests (3):
#   - get-page-100.json
#   - post-json-content.json
#   - post-xml-content.json
#
# WAF Test Requests (4):
#   - sql-injection-basic.json
#   - sql-injection-union.json
#   - xss-script-tag.json
#   - xss-event-handler.json
```

### Run a Legitimate Request Example

```powershell
dotnet run -- load `
  --file "../../examples/requests/legitimate/get-page-100.json" `
  --key "my-secret-key"
```

Expected output:

```
[✓] Get Page 100
    Description: Fetches TXT TV page 100 (index page) content
    Status: 200 OK (expected 200)
    Behavior: allowed (expected allowed)
    Duration: 132ms
    ✓ Test PASSED
```

### Run a WAF Test Example (SQL Injection)

```powershell
dotnet run -- load `
  --file "../../examples/requests/waf-tests/sql-injection-basic.json" `
  --key "my-secret-key"
```

Expected output (WAF blocking):

```
[✓] SQL Injection - Basic OR
    Description: Tests WAF blocking of basic SQL injection
    Status: 403 Forbidden (expected 403)
    Behavior: blocked (expected blocked)
    Duration: 89ms
    ✓ Test PASSED

Response Body:
{
  "error": "Request blocked by Web Application Firewall",
  "ruleId": "942100",
  "ruleMessage": "SQL Injection Attack Detected"
}
```

Expected output (if WAF NOT blocking - test failure):

```
[✗] SQL Injection - Basic OR
    Description: Tests WAF blocking of basic SQL injection
    Status: 200 OK (expected 403)
    Behavior: allowed (expected blocked)
    Duration: 145ms
    ❌ Test FAILED: Request was not blocked by WAF

⚠️  WARNING: WAF may not be configured correctly!
```

## Step 9: Run All Example Tests

Run all examples and generate a summary:

```powershell
# Run all legitimate tests
Get-ChildItem "../../examples/requests/legitimate/*.json" | ForEach-Object {
    Write-Host "`n--- Testing: $($_.Name) ---"
    dotnet run -- load --file $_.FullName --key "my-secret-key"
}

# Run all WAF tests
Get-ChildItem "../../examples/requests/waf-tests/*.json" | ForEach-Object {
    Write-Host "`n--- Testing: $($_.Name) ---"
    dotnet run -- load --file $_.FullName --key "my-secret-key"
}
```

## Step 10: View Deployment Resources

Check deployed resources in Azure Portal:

```powershell
# Open resource group in portal
az group show --name txttv-dev-rg --query id --output tsv | `
    ForEach-Object { Start-Process "https://portal.azure.com/#@/resource$_" }

# OR list resources via CLI
az resource list --resource-group txttv-dev-rg --output table
```

## Common Tasks

### Update Infrastructure

If you make changes to Bicep templates:

```powershell
cd infrastructure/scripts
.\Deploy-Infrastructure.ps1 -Environment dev -Confirm:$false
```

### Check Deployment Status

```powershell
# Get latest deployment
az deployment group list `
  --resource-group txttv-dev-rg `
  --query "[0].{Name:name, State:properties.provisioningState, Timestamp:properties.timestamp}" `
  --output table
```

### View Deployment Logs

```powershell
# Get deployment operations
az deployment operation group list `
  --resource-group txttv-dev-rg `
  --name "txttv-dev-20260207-143022" `
  --output table
```

### Add Custom Test Request

Create a new request file:

```powershell
# Create new test file
$newTest = @{
    name = "My Custom Test"
    description = "Tests my specific scenario"
    expectedBehavior = "allowed"
    expectedStatusCode = 200
    wafPattern = "none"
    tags = @("custom", "testing")
    request = @{
        method = "GET"
        path = "/api/pages/101"
        headers = @{
            "Accept" = "application/json"
        }
    }
} | ConvertTo-Json -Depth 10

$newTest | Out-File "../../examples/requests/legitimate/my-custom-test.json"

# Run your custom test
dotnet run -- load `
  --file "../../examples/requests/legitimate/my-custom-test.json" `
  --key "my-secret-key"
```

## Cleanup

### Remove All Resources

```powershell
cd infrastructure/scripts
.\Remove-Infrastructure.ps1 -Environment dev

# Confirm deletion when prompted, or use -Force to skip
.\Remove-Infrastructure.ps1 -Environment dev -Force
```

### Preserve Storage Data

If you want to keep storage accounts and data:

```powershell
.\Remove-Infrastructure.ps1 -Environment dev -PreserveData
```

## Next Steps

After completing this quickstart:

1. **Explore WAF Behavior**: Try different attack patterns from `examples/requests/waf-tests/`
2. **Customize Requests**: Create your own test scenarios
3. **Monitor Logs**: Check Application Insights for request telemetry
4. **Review Infrastructure**: Examine Bicep templates in `infrastructure/modules/`
5. **Run Tests**: Execute PowerShell tests in `tests/deployment/`

## Troubleshooting

### Utility Cannot Connect to Service

```powershell
# Verify APIM endpoint is accessible
curl https://txttv-dev-apim.azure-api.net/api/pages/100

# Check APIM status in portal
az apim show --name txttv-dev-apim --resource-group txttv-dev-rg --query provisioningState
```

### Signature Validation Errors

Remember: Server does NOT validate signatures (demonstration only). If you see signature-related errors, check:

1. Signing key is provided via `--key` argument or environment variable
2. Timestamp is within valid range (±5 minutes)
3. Request body matches what was signed

### WAF Not Blocking Malicious Requests

```powershell
# Check WAF policy status
az network application-gateway waf-policy show `
  --name txttv-dev-waf `
  --resource-group txttv-dev-rg `
  --query "managedRules.managedRuleSets"

# Verify WAF mode is "Prevention" not "Detection"
az network application-gateway waf-policy show `
  --name txttv-dev-waf `
  --resource-group txttv-dev-rg `
  --query "policySettings.mode"
```

## Reference

- [Deployment Config Schema](contracts/deployment-config-schema.md)
- [Example Request Format](contracts/example-request-format.md)
- [Data Model](data-model.md)
- [Implementation Plan](plan.md)
- [Feature Specification](spec.md)

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review Azure deployment logs
3. Check Application Insights for errors
4. Consult feature specification for requirements
