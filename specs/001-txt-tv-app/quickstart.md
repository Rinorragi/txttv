# Quickstart: TXT TV Application Development

**Feature**: 001-txt-tv-app  
**Date**: 2026-01-31  
**Audience**: Developers setting up local development environment

## Prerequisites

### Required Tools

- **Azure CLI**: v2.50+ ([Install](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- **Bicep CLI**: v0.20+ (installed with Azure CLI)
- **.NET SDK**: 10.0+ ([Install](https://dotnet.microsoft.com/download))
- **PowerShell**: 7.3+ ([Install](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell))
- **Git**: 2.40+ ([Install](https://git-scm.com/downloads))
- **Visual Studio Code**: Latest ([Install](https://code.visualstudio.com/))

### Recommended VS Code Extensions

```bash
code --install-extension ms-dotnettools.csharp
code --install-extension ms-azuretools.vscode-bicep
code --install-extension ionide.ionide-fsharp
code --install-extension ms-vscode.powershell
```

### Azure Subscription

- Active Azure subscription with permissions to create:
  - Resource Groups
  - Application Gateway
  - API Management (Consumption tier minimum)
  - Azure Functions
  - Storage Accounts
  - Virtual Networks

## Quick Start (5 Minutes)

### 1. Clone Repository

```powershell
git clone https://github.com/your-org/txttv.git
cd txttv
git checkout 001-txt-tv-app
```

### 2. Login to Azure

```powershell
az login
az account set --subscription "<your-subscription-id>"
```

### 3. Set Environment Variables

```powershell
# Set deployment parameters
$env:LOCATION = "eastus"
$env:RESOURCE_GROUP = "rg-txttv-dev"
$env:APIM_NAME = "apim-txttv-dev"
$env:FUNCTION_APP_NAME = "func-txttv-dev"
```

### 4. Deploy Infrastructure (Dev Environment)

```powershell
# Create resource group
az group create --name $env:RESOURCE_GROUP --location $env:LOCATION

# Deploy Bicep templates
az deployment group create `
    --resource-group $env:RESOURCE_GROUP `
    --template-file infrastructure/environments/dev/main.bicep `
    --parameters infrastructure/environments/dev/parameters.json
```

**Note**: Deployment takes approximately 15-20 minutes due to Application Gateway and APIM provisioning.

### 5. Convert Content to Policy Fragments

```powershell
# Convert text files to APIM policy fragments
.\infrastructure\scripts\convert-txt-to-fragment.ps1 `
    -SourceDir "content/pages" `
    -OutputDir "infrastructure/modules/apim/fragments"
```

### 6. Deploy Policy Fragments

```powershell
# Deploy updated policy fragments to APIM
az deployment group create `
    --resource-group $env:RESOURCE_GROUP `
    --template-file infrastructure/modules/apim/main.bicep
```

### 7. Test the Application

```powershell
# Get Application Gateway public IP
$appGwIp = az network public-ip show `
    --resource-group $env:RESOURCE_GROUP `
    --name pip-appgw-txttv-dev `
    --query ipAddress -o tsv

# Open in browser
Start-Process "http://$appGwIp/page/100"
```

## Development Workflow

### Adding New Pages

1. **Create content file**:
```powershell
New-Item -Path "content/pages/page-110.txt" -ItemType File
```

2. **Add news content**:
```
WEATHER UPDATE - Page 110

Sunny skies expected throughout the week.
Temperatures ranging 20-25°C.

More details on page 111.
```

3. **Convert to policy fragment**:
```powershell
.\infrastructure\scripts\convert-txt-to-fragment.ps1
```

4. **Deploy changes**:
```powershell
az deployment group create `
    --resource-group $env:RESOURCE_GROUP `
    --template-file infrastructure/modules/apim/main.bicep
```

5. **Test new page**:
```powershell
Start-Process "http://$appGwIp/page/110"
```

### Modifying APIM Policies

1. **Edit policy file**:
```powershell
code infrastructure/modules/apim/policies/page-routing-policy.xml
```

2. **Validate XML**:
```powershell
# Use Bicep validation which includes policy validation
az bicep build --file infrastructure/modules/apim/main.bicep
```

3. **Deploy policy changes**:
```powershell
az deployment group create `
    --resource-group $env:RESOURCE_GROUP `
    --template-file infrastructure/modules/apim/main.bicep
```

4. **Test policy behavior**:
```powershell
# Test with various page numbers
Invoke-WebRequest -Uri "http://$appGwIp/page/100" -UseBasicParsing
Invoke-WebRequest -Uri "http://$appGwIp/page/999" -UseBasicParsing # Should show error
```

### Testing WAF Rules

```powershell
# Test SQL injection (should be blocked)
Invoke-WebRequest -Uri "http://$appGwIp/page/100?id=1' OR '1'='1" -UseBasicParsing

# Test XSS (should be blocked)
Invoke-WebRequest -Uri "http://$appGwIp/page/<script>alert('xss')</script>" -UseBasicParsing

# Check WAF logs
az monitor log-analytics query `
    --workspace <workspace-id> `
    --analytics-query "AzureDiagnostics | where Category == 'ApplicationGatewayFirewallLog'" `
    --timespan P1D
```

### Developing F# Backend

1. **Navigate to function project**:
```powershell
cd src/backend/TxtTv.Functions
```

2. **Restore dependencies**:
```powershell
dotnet restore
```

3. **Run locally**:
```powershell
func start
```

4. **Test locally**:
```powershell
Invoke-WebRequest -Uri "http://localhost:7071/api/backend-test" -UseBasicParsing
# Expected: "you found through the maze"
```

5. **Deploy to Azure**:
```powershell
func azure functionapp publish $env:FUNCTION_APP_NAME
```

## Testing

### Run All Tests

```powershell
# Infrastructure validation
Invoke-Pester tests/infrastructure/

# Policy validation
Invoke-Pester tests/policies/

# Security tests (WAF)
Invoke-Pester tests/security/

# Integration tests
Invoke-Pester tests/integration/
```

### Run Specific Test Suite

```powershell
# Test only APIM policies
Invoke-Pester tests/policies/policy-validation.tests.ps1

# Test only WAF rules
Invoke-Pester tests/security/waf-sql-injection.tests.ps1
```

## Monitoring and Debugging

### View APIM Logs

```powershell
# Stream APIM logs
az monitor app-insights query `
    --app <app-insights-name> `
    --analytics-query "traces | where message contains 'apim-policy'" `
    --timespan P1H
```

### View Application Gateway Logs

```powershell
# Stream AppGW access logs
az monitor log-analytics query `
    --workspace <workspace-id> `
    --analytics-query "AzureDiagnostics | where Category == 'ApplicationGatewayAccessLog'" `
    --timespan P1H
```

### View Function Logs

```powershell
# Stream function logs
func azure functionapp logstream $env:FUNCTION_APP_NAME
```

### Test APIM Policy Tracing

1. Enable tracing in Azure Portal:
   - Navigate to APIM instance
   - API Settings → Enable tracing

2. Send request with trace header:
```powershell
$headers = @{
    "Ocp-Apim-Trace" = "true"
    "Ocp-Apim-Subscription-Key" = "<your-subscription-key>"
}
Invoke-WebRequest -Uri "http://$appGwIp/page/100" -Headers $headers
```

3. View trace in response header `Ocp-Apim-Trace-Location`

## Common Issues

### Issue: Deployment takes too long

**Solution**: Application Gateway can take 15-20 minutes. Monitor progress:
```powershell
az deployment group show `
    --resource-group $env:RESOURCE_GROUP `
    --name <deployment-name> `
    --query properties.provisioningState
```

### Issue: Page shows 404

**Possible causes**:
1. Policy fragment not deployed
2. Page number not in routing policy
3. WAF blocking request

**Debug**:
```powershell
# Check if fragment exists in APIM
az apim api policy list --resource-group $env:RESOURCE_GROUP --service-name $env:APIM_NAME

# Check WAF logs for blocks
az monitor log-analytics query `
    --workspace <workspace-id> `
    --analytics-query "AzureDiagnostics | where Category == 'ApplicationGatewayFirewallLog' and action_s == 'Blocked'"
```

### Issue: Backend test returns 503

**Possible causes**:
1. Function app not deployed
2. APIM backend configuration incorrect
3. Network connectivity issue

**Debug**:
```powershell
# Test function directly
Invoke-WebRequest -Uri "https://$env:FUNCTION_APP_NAME.azurewebsites.net/api/backend-test" -UseBasicParsing

# Check APIM backend health
az apim api operation show `
    --resource-group $env:RESOURCE_GROUP `
    --service-name $env:APIM_NAME `
    --api-id txttv-api `
    --operation-id GetBackendTest
```

### Issue: Changes not reflecting

**Solution**: Clear APIM cache and browser cache:
```powershell
# Clear browser cache (Ctrl+Shift+R in most browsers)

# Restart APIM (in portal or via CLI)
az apim update --resource-group $env:RESOURCE_GROUP --name $env:APIM_NAME
```

## Clean Up

### Delete All Resources

```powershell
# Delete resource group (removes all resources)
az group delete --name $env:RESOURCE_GROUP --yes --no-wait
```

### Delete Specific Resources

```powershell
# Delete only Application Gateway (keeps APIM, Functions)
az network application-gateway delete `
    --resource-group $env:RESOURCE_GROUP `
    --name appgw-txttv-dev
```

## Next Steps

After completing the quickstart:

1. **Review Architecture**: Read [data-model.md](data-model.md) to understand the data flow
2. **Review API Contracts**: Read [contracts/api-operations.md](contracts/api-operations.md) for endpoint details
3. **Add More Pages**: Create pages 100-120 with diverse content
4. **Configure WAF**: Customize WAF rules in `infrastructure/modules/waf/`
5. **Set Up CI/CD**: Review `.github/workflows/deploy.yml` and configure secrets
6. **Monitor Performance**: Set up Azure Monitor dashboards
7. **Implement Tasks**: See [tasks.md](tasks.md) for implementation checklist

## Resources

- [APIM Policy Reference](https://docs.microsoft.com/en-us/azure/api-management/api-management-policies)
- [Application Gateway WAF](https://docs.microsoft.com/en-us/azure/web-application-firewall/ag/ag-overview)
- [Azure Functions F# Guide](https://docs.microsoft.com/en-us/azure/azure-functions/functions-reference-fsharp)
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [HTMX Documentation](https://htmx.org/docs/)

## Support

For issues or questions:
1. Check [Common Issues](#common-issues) section above
2. Review logs in Application Insights
3. Consult project documentation in `specs/001-txt-tv-app/`
4. Create GitHub issue with logs and correlation ID
