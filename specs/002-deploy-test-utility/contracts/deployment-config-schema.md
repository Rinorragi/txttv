# Deployment Configuration Schema Contract

**Feature**: 002-deploy-test-utility  
**Date**: February 7, 2026  
**Plan**: [../plan.md](../plan.md)

## Overview

This document defines the configuration schema for deployment scripts and the format of environment-specific parameter files. These configurations control how Azure infrastructure is deployed.

## Deployment Script Parameters

### Command-Line Interface

```powershell
Deploy-Infrastructure.ps1
    -Environment <string>           # Required: dev, staging, or prod
    -SubscriptionId <guid>          # Optional: Override default subscription
    -ResourceGroupName <string>     # Optional: Override default resource group name
    -Location <string>              # Optional: Override default location
    -WhatIf                         # Optional: Dry-run mode (validate without deploying)
    -Verbose                        # Optional: Enable verbose output
    -Confirm:$false                 # Optional: Skip confirmation prompt
    -TimeoutMinutes <int>           # Optional: Maximum deployment duration (default: 60)
    [-Tag <hashtable>]              # Optional: Additional Azure tags
```

### Parameter Descriptions

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `Environment` | String | Yes | - | Target environment (dev, staging, prod) |
| `SubscriptionId` | GUID | No | From Az context | Azure subscription to deploy to |
| `ResourceGroupName` | String | No | `txttv-{env}-rg` | Resource group name |
| `Location` | String | No | From parameters file | Azure region |
| `WhatIf` | Switch | No | False | Validate without deploying |
| `Verbose` | Switch | No | False | Enable detailed logging |
| `Confirm` | Boolean | No | True | Prompt before deployment |
| `TimeoutMinutes` | Integer | No | 60 | Maximum deployment duration |
| `Tag` | Hashtable | No | {} | Additional resource tags |

### Usage Examples

```powershell
# Deploy to dev environment with defaults
.\Deploy-Infrastructure.ps1 -Environment dev

# Deploy to dev with custom resource group
.\Deploy-Infrastructure.ps1 -Environment dev -ResourceGroupName "my-txttv-rg"

# Validate deployment without executing (dry-run)
.\Deploy-Infrastructure.ps1 -Environment dev -WhatIf

# Deploy with verbose logging and no confirmation
.\Deploy-Infrastructure.ps1 -Environment dev -Verbose -Confirm:$false

# Deploy with additional tags
.\Deploy-Infrastructure.ps1 -Environment dev -Tag @{CostCenter="Engineering"; Owner="DevTeam"}

# Deploy to specific subscription
.\Deploy-Infrastructure.ps1 -Environment dev -SubscriptionId "12345678-1234-1234-1234-123456789abc"
```

## Environment Parameters File Schema

### File Location Pattern
```
infrastructure/environments/{environment}/parameters.json
```

### JSON Schema

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environmentName": {
      "value": "dev"
    },
    "location": {
      "value": "eastus"
    },
    "baseName": {
      "value": "txttv"
    },
    "apimPublisherEmail": {
      "value": "admin@example.com"
    },
    "apimPublisherName": {
      "value": "TXT TV Development"
    }
  }
}
```

### Parameter Definitions

| Parameter | Type | Required | Description | Constraints |
|-----------|------|----------|-------------|-------------|
| `environmentName` | String | Yes | Environment identifier | dev, staging, prod |
| `location` | String | Yes | Azure region | Valid Azure region name |
| `baseName` | String | Yes | Resource name prefix | 3-10 chars, alphanumeric, lowercase |
| `apimPublisherEmail` | String | Yes | APIM publisher email | Valid email format |
| `apimPublisherName` | String | Yes | APIM publisher name | 1-100 chars |

### Example Files

#### Dev Environment
**File**: `infrastructure/environments/dev/parameters.json`

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environmentName": {
      "value": "dev"
    },
    "location": {
      "value": "eastus"
    },
    "baseName": {
      "value": "txttv"
    },
    "apimPublisherEmail": {
      "value": "dev@example.com"
    },
    "apimPublisherName": {
      "value": "TXT TV Development"
    }
  }
}
```

#### Staging Environment
**File**: `infrastructure/environments/staging/parameters.json`

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environmentName": {
      "value": "staging"
    },
    "location": {
      "value": "westeurope"
    },
    "baseName": {
      "value": "txttv"
    },
    "apimPublisherEmail": {
      "value": "staging@example.com"
    },
    "apimPublisherName": {
      "value": "TXT TV Staging"
    }
  }
}
```

## Deployment Script Output Format

### Success Output

```json
{
  "status": "Completed",
  "deploymentName": "txttv-dev-20260207-143022",
  "resourceGroup": "txttv-dev-rg",
  "subscription": "12345678-1234-1234-1234-123456789abc",
  "startTime": "2026-02-07T14:30:22Z",
  "endTime": "2026-02-07T14:33:45Z",
  "duration": "00:03:23",
  "resourcesCreated": [
    {
      "name": "txttv-dev-apim",
      "type": "Microsoft.ApiManagement/service",
      "provisioningState": "Succeeded"
    },
    {
      "name": "txttv-dev-appgw",
      "type": "Microsoft.Network/applicationGateways",
      "provisioningState": "Succeeded"
    },
    {
      "name": "txttv-dev-func",
      "type": "Microsoft.Web/sites",
      "provisioningState": "Succeeded"
    }
  ],
  "outputs": {
    "apimEndpoint": "https://txttv-dev-apim.azure-api.net",
    "appGatewayPublicIp": "20.123.45.67",
    "functionAppUrl": "https://txttv-dev-func.azurewebsites.net"
  },
  "correlationId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```

### Failure Output

```json
{
  "status": "Failed",
  "deploymentName": "txttv-dev-20260207-143022",
  "resourceGroup": "txttv-dev-rg",
  "subscription": "12345678-1234-1234-1234-123456789abc",
  "startTime": "2026-02-07T14:30:22Z",
  "endTime": "2026-02-07T14:32:10Z",
  "duration": "00:01:48",
  "errors": [
    {
      "code": "ResourceQuotaExceeded",
      "message": "Operation could not be completed as it results in exceeding approved quota for APIM units",
      "target": "Microsoft.ApiManagement/service/txttv-dev-apim",
      "details": []
    }
  ],
  "resourcesCreated": [
    {
      "name": "txttv-dev-st",
      "type": "Microsoft.Storage/storageAccounts",
      "provisioningState": "Succeeded"
    }
  ],
  "resourcesFailed": [
    {
      "name": "txttv-dev-apim",
      "type": "Microsoft.ApiManagement/service",
      "provisioningState": "Failed"
    }
  ],
  "correlationId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "recommendedAction": "Check Azure quota limits for APIM in this subscription and region"
}
```

## Resource Naming Convention

### Pattern
```
{baseName}-{environment}-{resourceType}
```

### Resource Type Abbreviations

| Azure Resource | Abbreviation | Example |
|----------------|--------------|---------|
| Resource Group | rg | txttv-dev-rg |
| Storage Account | st (no hyphens) | txttv |devst |
| Function App | func | txttv-dev-func |
| API Management | apim | txttv-dev-apim |
| Application Gateway | appgw | txttv-dev-appgw |
| WAF Policy | waf | txttv-dev-waf |
| Virtual Network | vnet | txttv-dev-vnet |
| Log Analytics Workspace | law | txttv-dev-law |
| Application Insights | ai | txttv-dev-ai |

### Naming Rules
- Lowercase only
- Alphanumeric and hyphens (except storage accounts: no hyphens)
- 3-24 characters for storage accounts
- 1-64 characters for most other resources
- Globally unique where required (storage, APIM, function apps)

## Environment-Specific Configurations

### Dev Environment
- **SKU**: Developer tier (APIM), Basic (App Gateway)
- **Scale**: Single instance
- **Retention**: 7 days (logs)
- **Tags**: `Environment=dev`, `AutoShutdown=enabled`

### Staging Environment
- **SKU**: Standard tier (APIM), Standard_v2 (App Gateway)
- **Scale**: 1-3 instances
- **Retention**: 30 days (logs)
- **Tags**: `Environment=staging`, `AutoShutdown=disabled`

### Prod Environment
- **SKU**: Premium tier (APIM), WAF_v2 (App Gateway)
- **Scale**: 2-5 instances
- **Retention**: 90 days (logs)
- **Tags**: `Environment=prod`, `AutoShutdown=disabled`, `CriticalWorkload=true`

## Validation Rules

### Pre-Deployment Validation
1. **Azure Context Check**:
   - Verify Azure CLI/PowerShell authenticated
   - Confirm subscription access
   - Validate subscription quota availability

2. **Bicep Template Validation**:
   - Run `bicep build` on template
   - Check for syntax errors
   - Validate parameter references

3. **Parameter File Validation**:
   - Verify JSON structure
   - Check required parameters present
   - Validate parameter value constraints

4. **Resource Group Check**:
   - If resource group exists, check for conflicts
   - If creating new, verify name availability

### Post-Deployment Validation
1. **Resource Provisioning**:
   - All resources show `provisioningState: Succeeded`
   - No resources in Failed state

2. **Endpoint Availability**:
   - APIM endpoint responds to HTTP requests
   - Application Gateway public IP accessible
   - Function app responds to test requests

3. **Monitoring Configuration**:
   - Application Insights connected
   - Log Analytics workspace receiving logs
   - Diagnostic settings enabled

## Error Handling Contract

### Error Categories

| Category | Status Code | Description | Recovery Action |
|----------|-------------|-------------|-----------------|
| ValidationError | 1 | Invalid parameters or template | Fix parameters and retry |
| AuthenticationError | 2 | Azure credentials not configured | Run `az login` or `Connect-AzAccount` |
| QuotaExceeded | 3 | Insufficient Azure quota | Request quota increase or use different region |
| DeploymentFailed | 4 | Azure deployment error | Check error details, resolve issue, retry |
| TimeoutError | 5 | Deployment exceeded timeout | Increase timeout or check Azure status |
| PartialSuccess | 6 | Some resources failed | Review failed resources, cleanup and retry |

### Error Message Format

```
[ERROR] {Category}: {Message}

Details:
{DetailedDescription}

Suggested Action:
{RecoverySteps}

Correlation ID: {AzureCorrelationId}
```

### Example Error Messages

```
[ERROR] QuotaExceeded: APIM deployment failed due to quota limits

Details:
Attempted to deploy API Management instance in region 'eastus' but subscription
quota for Standard tier APIM instances is exceeded (1/1 used).

Suggested Action:
1. Request quota increase via Azure Portal (Support > New support request)
2. Delete an existing APIM instance in this region
3. Deploy to a different region with available quota

Correlation ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

## Cleanup Script Contract

### Command-Line Interface

```powershell
Remove-Infrastructure.ps1
    -Environment <string>           # Required: dev, staging, or prod
    -ResourceGroupName <string>     # Optional: Override default resource group name
    -Force                          # Optional: Skip confirmation prompt
    -DeleteResourceGroup            # Optional: Delete entire resource group
    -PreserveData                   # Optional: Keep storage accounts and data
```

### Cleanup Behavior

| Flag | Behavior |
|------|----------|
| None (default) | Prompts for confirmation, deletes all resources |
| `-Force` | No confirmation, deletes all resources |
| `-DeleteResourceGroup` | Deletes entire resource group (faster) |
| `-PreserveData` | Keeps storage accounts and their contents |

### Cleanup Output

```json
{
  "status": "Completed",
  "resourceGroup": "txttv-dev-rg",
  "deletedResources": 8,
  "preservedResources": 0,
  "duration": "00:02:15",
  "warnings": []
}
```

## Related Documents

- [Example Request Format](example-request-format.md) - Test request file schema
- [Data Model](../data-model.md) - Entity definitions
- [Quickstart Guide](../quickstart.md) - Deployment walkthrough
