# TxtTV Quick Start Guide

Get up and running with TxtTV deployment and testing in 5 minutes.

## Prerequisites

Before you begin, ensure you have:

- ✅ **PowerShell 7+** installed ([Download](https://aka.ms/powershell))
- ✅ **.NET 10 SDK** installed ([Download](https://dot.net))
- ✅ **Azure CLI** installed and authenticated (`az login`)
- ✅ **Bicep CLI** (or use `az bicep` as fallback)

Check prerequisites:

```powershell
# Check PowerShell version
$PSVersionTable.PSVersion

# Check .NET version
dotnet --version

# Check Azure CLI
az --version

# Login to Azure
az login
```

## Step 1: Deploy Infrastructure (2 minutes)

Deploy the TxtTV infrastructure to Azure:

```powershell
# Navigate to repository root (if not already there)
# cd <path-to-your-txttv-repo>

# Deploy to dev environment
.\infrastructure\scripts\Deploy-Infrastructure.ps1 -Environment dev
```

**What this does:**
- Validates Bicep templates
- Creates resource group (`rg-txttv-dev`)
- Deploys API Management, Azure Functions, Storage, Application Gateway
- Configures WAF rules
- Returns deployment outputs with endpoints

**Expected output:**
```
=== Deployment Complete ===
Deployment Name:    txttv-dev-20260207-120000
Resource Group:     rg-txttv-dev
Provisioning State: Succeeded
Correlation ID:     xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Deployment Outputs:
  apimEndpoint: https://your-apim.azure-api.net
  functionAppUrl: https://your-func.azurewebsites.net

Resources: 15 created
Duration: 4m 32s
```

## Step 2: Build Test Utility (1 minute)

Build the F# HTTP testing utility:

```powershell
# Navigate to test utility
cd tools\TxtTv.TestUtility

# Build the project
dotnet build
```

**Expected output:**
```
Build succeeded in 2.2s
→ bin\Debug\net10.0\TxtTv.TestUtility.dll
```

## Step 3: Send Your First Request (30 seconds)

Test the deployed API with a simple GET request:

```powershell
# Replace with your actual APIM endpoint from Step 1
$endpoint = "https://your-apim.azure-api.net"

# Send GET request to fetch page 100
dotnet run -- send -u "$endpoint/pages/100" -m GET -v
```

**Expected output:**
```
=== HTTP Response ===

Status: 200 OK
Time: 234ms

Headers:
  Content-Type: application/json
  X-Powered-By: Azure Functions

Body:
  {
    "pageNumber": 100,
    "content": "Welcome to TxtTV..."
  }

═══════════════════
```

## Step 4: Test with Signature (30 seconds)

Send a signed request with HMAC-SHA256:

```powershell
# Set your secret key (use the one configured in Azure Functions)
$secretKey = "your-secret-key-here"

# Send POST with signature
dotnet run -- send `
  -u "$endpoint/backend-test" `
  -m POST `
  -b '{"message":"Hello TxtTV","timestamp":"2026-02-07T12:00:00Z"}' `
  -k $secretKey `
  -v
```

**What this does:**
- Generates HMAC-SHA256 signature
- Adds `X-TxtTV-Signature` header
- Adds `X-TxtTV-Timestamp` header
- Sends signed POST request

## Step 5: Load Example Requests (1 minute)

Execute pre-built example requests:

```powershell
# List available examples
dotnet run -- list -d "..\..\examples\requests" -r

# Execute a single example
dotnet run -- load `
  -f "..\..\examples\requests\legitimate\get-page-100.json" `
  -k $secretKey `
  -v

# Run all legitimate examples
dotnet run -- load `
  -f "..\..\examples\requests\legitimate" `
  -k $secretKey `
  -c
```

## Step 6: Test WAF Protection (Optional)

Test Web Application Firewall rules:

```powershell
# Run all WAF tests
cd ..\..\  # Back to root
dotnet run --project tools\TxtTv.TestUtility -- load `
  -f "examples\requests\waf-tests" `
  -k $secretKey `
  -c `
  -v
```

**Expected results:**
- ✅ **SQL Injection** → 403 Forbidden (blocked)
- ✅ **XSS Attack** → 403 Forbidden (blocked)
- ✅ **Path Traversal** → 403 Forbidden (blocked)
- ✅ **Command Injection** → 403 Forbidden (blocked)

If requests are NOT blocked (200 OK), your WAF needs configuration!

## Step 7: Clean Up (30 seconds)

When done testing, remove all Azure resources:

```powershell
# Navigate back to repository root (if not already there)
# cd <path-to-your-txttv-repo>

# Remove all resources (prompts for confirmation)
.\infrastructure\scripts\Remove-Infrastructure.ps1 -Environment dev

# Or force delete without confirmation
.\infrastructure\scripts\Remove-Infrastructure.ps1 -Environment dev -Force
```

---

## Quick Reference Commands

### Deploy Infrastructure
```powershell
.\infrastructure\scripts\Deploy-Infrastructure.ps1 -Environment <dev|staging|prod>
```

### Send HTTP Request
```powershell
dotnet run --project tools\TxtTv.TestUtility -- send -u <url> -m <method> [-k <key>] [-v]
```

### Load Request File
```powershell
dotnet run --project tools\TxtTv.TestUtility -- load -f <file> [-k <key>] [-v] [-c]
```

### List Examples
```powershell
dotnet run --project tools\TxtTv.TestUtility -- list [-d <directory>] [-r]
```

### Remove Infrastructure
```powershell
.\infrastructure\scripts\Remove-Infrastructure.ps1 -Environment <env> [-Force]
```

---

## Troubleshooting

### "Azure CLI not authenticated"
```powershell
az login
az account show
```

### "Bicep validation failed"
Check template syntax:
```powershell
bicep build infrastructure\environments\dev\main.bicep
```

### "Deployment timeout"
Increase timeout:
```powershell
.\infrastructure\scripts\Deploy-Infrastructure.ps1 -Environment dev -TimeoutMinutes 60
```

### ".NET build errors"
Restore packages:
```powershell
cd tools\TxtTv.TestUtility
dotnet restore
dotnet clean
dotnet build
```

### "Connection refused"
- Verify APIM endpoint URL
- Check Azure Portal for resource status
- Wait for deployment to complete (5-10 minutes)

---

## Next Steps

- 📖 Read [infrastructure/README.md](infrastructure/README.md) for deployment details
- 📖 Read [tools/TxtTv.TestUtility/README.md](tools/TxtTv.TestUtility/README.md) for CLI reference
- 🧪 Explore example requests in `examples/requests/`
- 🛡️ Review WAF rules in `infrastructure/modules/waf/rules/`
- 🧾 Check deployment tests in `tests/deployment/`

## Support

For issues:
1. Check logs in Azure Portal
2. Review deployment correlation ID
3. Run with `-Verbose` flag for detailed output
4. Check [troubleshooting section](infrastructure/README.md#troubleshooting)

---

**Congratulations!** 🎉 You've deployed TxtTV infrastructure and sent your first test requests.
