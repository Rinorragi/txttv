<#
.SYNOPSIS
    Deploys TxtTV Azure infrastructure using Bicep templates.

.DESCRIPTION
    Simplified deployment script that replaces the Azure DevOps pipeline.
    Validates Bicep templates, creates resource groups, and deploys infrastructure
    for the specified environment (dev, staging, or prod).

.PARAMETER Environment
    Target environment: dev, staging, or prod.

.PARAMETER SubscriptionId
    Optional Azure subscription ID. If not provided, uses the current subscription.

.PARAMETER ResourceGroupName
    Optional resource group name. If not provided, uses the default naming pattern:
    rg-txttv-<environment>

.PARAMETER Location
    Azure region for resource group creation. Default: westeurope

.PARAMETER WhatIf
    Performs a dry-run without actually deploying resources.

.PARAMETER TimeoutMinutes
    Deployment timeout in minutes. Default: 30

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER Json
    Output results in JSON format.

.EXAMPLE
    .\Deploy-Infrastructure.ps1 -Environment dev

.EXAMPLE
    .\Deploy-Infrastructure.ps1 -Environment prod -SubscriptionId "12345678-1234-1234-1234-123456789012" -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$Location = 'westeurope',

    [Parameter(Mandatory = $false)]
    [int]$TimeoutMinutes = 30,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Get script directory to locate helper modules
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LibDir = Join-Path $ScriptDir 'lib'

# Import helper modules
Import-Module (Join-Path $LibDir 'BicepHelpers.psm1') -Force
Import-Module (Join-Path $LibDir 'AzureAuth.psm1') -Force
Import-Module (Join-Path $LibDir 'ErrorHandling.psm1') -Force

Write-DeploymentLog -Message "=== TxtTV Infrastructure Deployment ===" -Level Info
Write-DeploymentLog -Message "Environment: $Environment" -Level Info
Write-DeploymentLog -Message "Location: $Location" -Level Info

# ==============================================================================
# PARAMETER VALIDATION (T011)
# ==============================================================================

Write-DeploymentLog -Message "Validating parameters..." -Level Info

# Validate environment (already validated by ValidateSet, but explicit message)
if ($Environment -notin @('dev', 'staging', 'prod')) {
    throw "Invalid environment '$Environment'. Must be: dev, staging, or prod"
}

# Validate SubscriptionId format if provided
if ($SubscriptionId) {
    $guidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    if ($SubscriptionId -notmatch $guidPattern) {
        throw "Invalid SubscriptionId format. Expected GUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    }
}

# Validate ResourceGroupName format
if (-not $ResourceGroupName) {
    $ResourceGroupName = "rg-txttv-$Environment"
    Write-DeploymentLog -Message "Using default resource group name: $ResourceGroupName" -Level Info
}

# Validate resource group name format (Azure naming rules)
if ($ResourceGroupName -notmatch '^[a-zA-Z0-9._\-()]+$') {
    throw "Invalid ResourceGroupName format. Must contain only alphanumerics, underscores, hyphens, periods, and parentheses."
}

if ($ResourceGroupName.Length -gt 90) {
    throw "ResourceGroupName too long. Maximum 90 characters allowed."
}

# Locate parameters file
$InfraDir = Split-Path -Parent $ScriptDir
$EnvDir = Join-Path $InfraDir "environments\$Environment"
$ParametersFile = Join-Path $EnvDir 'parameters.json'

if (-not (Test-Path $ParametersFile)) {
    throw "Parameters file not found: $ParametersFile"
}

Write-DeploymentLog -Message "Parameters file: $ParametersFile" -Level Info
Write-DeploymentLog -Message "✓ Parameter validation complete" -Level Success

# ==============================================================================
# AZURE AUTHENTICATION CHECK (T012)
# ==============================================================================

Write-DeploymentLog -Message "Checking Azure authentication..." -Level Info

$authStatus = Test-AzureAuthentication

if (-not $authStatus.IsAuthenticated) {
    Write-DeploymentLog -Message "Not authenticated with Azure CLI." -Level Warning
    $loginResult = Invoke-AzureLogin
    
    if (-not $loginResult.Success) {
        throw "Azure authentication failed. Please run 'az login' manually."
    }
    
    # Re-check authentication
    $authStatus = Test-AzureAuthentication
}

Write-DeploymentLog -Message "✓ Authenticated as: $($authStatus.Account)" -Level Success
Write-DeploymentLog -Message "  Current subscription: $($authStatus.SubscriptionName) ($($authStatus.SubscriptionId))" -Level Info

# Set subscription if specified
if ($SubscriptionId -and $SubscriptionId -ne $authStatus.SubscriptionId) {
    Write-DeploymentLog -Message "Switching to subscription: $SubscriptionId" -Level Info
    
    $subCheck = Test-AzureSubscription -SubscriptionId $SubscriptionId
    if (-not $subCheck.HasAccess) {
        throw "Cannot access subscription: $SubscriptionId"
    }
    
    Write-DeploymentLog -Message "✓ Subscription set: $($subCheck.SubscriptionName)" -Level Success
} else {
    $SubscriptionId = $authStatus.SubscriptionId
}

# Confirmation prompt unless -Force
if (-not $Force -and -not $WhatIfPreference) {
    Write-Host ""
    Write-Host "Deployment Details:" -ForegroundColor Cyan
    Write-Host "  Environment:      $Environment" -ForegroundColor White
    Write-Host "  Resource Group:   $ResourceGroupName" -ForegroundColor White
    Write-Host "  Location:         $Location" -ForegroundColor White
    Write-Host "  Subscription:     $($authStatus.SubscriptionName)" -ForegroundColor White
    Write-Host "  Subscription ID:  $SubscriptionId" -ForegroundColor White
    Write-Host ""
    
    $confirmation = Read-Host "Proceed with deployment? (y/N)"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-DeploymentLog -Message "Deployment cancelled by user." -Level Warning
        exit 0
    }
}

# ==============================================================================
# BICEP TEMPLATE VALIDATION (T013)
# ==============================================================================

Write-DeploymentLog -Message "Validating Bicep templates..." -Level Info

# Locate environment-specific main.bicep
$BicepTemplate = Join-Path $EnvDir 'main.bicep'

if (-not (Test-Path $BicepTemplate)) {
    throw "Bicep template not found: $BicepTemplate"
}

Write-DeploymentLog -Message "Template: $BicepTemplate" -Level Info

# Validate Bicep syntax
$validationResult = Test-BicepTemplate -TemplatePath $BicepTemplate

if (-not $validationResult.IsValid) {
    Write-DeploymentLog -Message "Bicep template validation failed:" -Level Error
    $validationResult.Errors | ForEach-Object {
        Write-DeploymentLog -Message "  $_" -Level Error
    }
    throw "Bicep validation failed. Please fix the errors and try again."
}

Write-DeploymentLog -Message "✓ Bicep template is valid" -Level Success

# Build template to ARM JSON (optional, for validation)
Write-DeploymentLog -Message "Building Bicep to ARM template..." -Level Info
$buildResult = Invoke-BicepBuild -TemplatePath $BicepTemplate

if (-not $buildResult.Success) {
    Write-DeploymentLog -Message "Bicep build failed:" -Level Error
    $buildResult.Errors | ForEach-Object {
        Write-DeploymentLog -Message "  $_" -Level Error
    }
    throw "Bicep build failed."
}

Write-DeploymentLog -Message "✓ Bicep template built successfully" -Level Success

# ==============================================================================
# RESOURCE GROUP CREATION/VERIFICATION (T014)
# ==============================================================================

Write-DeploymentLog -Message "Checking resource group..." -Level Info

$rgCheck = Test-AzureResourceGroup -ResourceGroupName $ResourceGroupName

if ($rgCheck.Exists) {
    Write-DeploymentLog -Message "✓ Resource group exists: $ResourceGroupName [$($rgCheck.Location)]" -Level Success
    
    # Verify location matches if resource group already exists
    if ($rgCheck.Location -ne $Location) {
        Write-DeploymentLog -Message "Warning: Resource group location ($($rgCheck.Location)) differs from specified location ($Location). Using existing location." -Level Warning
        $Location = $rgCheck.Location
    }
} else {
    Write-DeploymentLog -Message "Resource group does not exist. Creating..." -Level Info
    
    if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Create resource group in $Location")) {
        try {
            az group create --name $ResourceGroupName --location $Location --tags "Environment=$Environment" "ManagedBy=Deploy-Infrastructure.ps1" 2>&1 | Out-Null
            
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create resource group"
            }
            
            Write-DeploymentLog -Message "✓ Resource group created: $ResourceGroupName" -Level Success
        }
        catch {
            throw "Failed to create resource group '$ResourceGroupName': $_"
        }
    }
}

Write-DeploymentLog -Message "✓ Resource group ready: $ResourceGroupName" -Level Success
Write-DeploymentLog -Message "" -Level Info

# ==============================================================================
# BICEP DEPLOYMENT EXECUTION (T015)
# ==============================================================================

Write-DeploymentLog -Message "=== Starting deployment ===" -Level Info

# Generate unique deployment name with timestamp
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$deploymentName = "txttv-$Environment-$timestamp"

Write-DeploymentLog -Message "Deployment name: $deploymentName" -Level Info
Write-DeploymentLog -Message "Timeout: $TimeoutMinutes minutes" -Level Info

if ($WhatIfPreference) {
    Write-DeploymentLog -Message "Running in WhatIf mode (dry-run)..." -Level Warning
}

try {
    # Build az deployment command
    $deployCmd = "az deployment group create " +
                 "--name `"$deploymentName`" " +
                 "--resource-group `"$ResourceGroupName`" " +
                 "--template-file `"$BicepTemplate`" " +
                 "--parameters `"$ParametersFile`" " +
                 "--mode Incremental"
    
    if ($WhatIfPreference) {
        $deployCmd += " --what-if"
    }
    
    Write-DeploymentLog -Message "Executing deployment..." -Level Info
    
    # ==============================================================================
    # DEPLOYMENT PROGRESS MONITORING (T016)
    # ==============================================================================
    
    $deploymentStartTime = Get-Date
    $timeoutTime = $deploymentStartTime.AddMinutes($TimeoutMinutes)
    
    if ($WhatIfPreference) {
        # Execute what-if
        $whatIfOutput = Invoke-Expression $deployCmd 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-DeploymentLog -Message "✓ What-If validation complete" -Level Success
            Write-Host ""
            Write-Host "What-If Results:" -ForegroundColor Cyan
            $whatIfOutput | ForEach-Object { Write-Host $_ }
        } else {
            throw "What-If validation failed with exit code $exitCode"
        }
    } else {
        # Execute actual deployment with progress monitoring
        Write-Progress -Activity "Deploying Infrastructure" -Status "Starting deployment..." -PercentComplete 0
        
        # Start deployment in background
        $deployJob = Start-Job -ScriptBlock {
            param($cmd)
            $output = Invoke-Expression $cmd 2>&1
            return @{
                ExitCode = $LASTEXITCODE
                Output = $output
            }
        } -ArgumentList $deployCmd
        
        # Monitor deployment progress
        $percentComplete = 10
        while ($deployJob.State -eq 'Running') {
            # Check timeout
            if ((Get-Date) -gt $timeoutTime) {
                Stop-Job $deployJob
                Remove-Job $deployJob
                throw "Deployment timed out after $TimeoutMinutes minutes"
            }
            
            # Update progress
            $elapsed = (Get-Date) - $deploymentStartTime
            $percentComplete = [Math]::Min(90, 10 + ($elapsed.TotalMinutes / $TimeoutMinutes * 80))
            
            Write-Progress -Activity "Deploying Infrastructure" `
                          -Status "Provisioning resources... ($([Math]::Floor($elapsed.TotalMinutes))m $($elapsed.Seconds)s elapsed)" `
                          -PercentComplete $percentComplete
            
            Start-Sleep -Seconds 5
        }
        
        # Get job results
        $jobResult = Receive-Job $deployJob
        Remove-Job $deployJob
        
        Write-Progress -Activity "Deploying Infrastructure" -Completed
        
        if ($jobResult.ExitCode -ne 0) {
            throw "Deployment failed with exit code $($jobResult.ExitCode)"
        }
        
        # ==============================================================================
        # DEPLOYMENT RESULT OUTPUT (T017)
        # ==============================================================================
        
        Write-DeploymentLog -Message "✓ Deployment completed successfully" -Level Success
        
        $deploymentDuration = (Get-Date) - $deploymentStartTime
        Write-DeploymentLog -Message "Duration: $([Math]::Floor($deploymentDuration.TotalMinutes))m $($deploymentDuration.Seconds)s" -Level Info
        
        # Get deployment details
        Write-DeploymentLog -Message "Fetching deployment outputs..." -Level Info
        
        $deploymentJson = az deployment group show `
            --name $deploymentName `
            --resource-group $ResourceGroupName `
            --query "{correlationId: properties.correlationId, provisioningState: properties.provisioningState, outputs: properties.outputs}" `
            2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $deployment = $deploymentJson | ConvertFrom-Json
            
            Write-Host ""
            Write-Host "=== Deployment Summary ===" -ForegroundColor Green
            Write-Host "Deployment Name:    $deploymentName" -ForegroundColor White
            Write-Host "Resource Group:     $ResourceGroupName" -ForegroundColor White
            Write-Host "Provisioning State: $($deployment.provisioningState)" -ForegroundColor White
            Write-Host "Correlation ID:     $($deployment.correlationId)" -ForegroundColor Gray
            
            # Display outputs if available
            if ($deployment.outputs) {
                Write-Host ""
                Write-Host "Deployment Outputs:" -ForegroundColor Cyan
                $deployment.outputs.PSObject.Properties | ForEach-Object {
                    Write-Host "  $($_.Name): $($_.Value.value)" -ForegroundColor White
                }
            }
            
            # List created/updated resources
            Write-Host ""
            Write-Host "Resources in Resource Group:" -ForegroundColor Cyan
            $resourcesJson = az resource list --resource-group $ResourceGroupName --query "[].{Type:type, Name:name}" 2>&1
            if ($LASTEXITCODE -eq 0) {
                $resources = $resourcesJson | ConvertFrom-Json
                $resources | ForEach-Object {
                    Write-Host "  $($_.Type.PadRight(40)) $($_.Name)" -ForegroundColor White
                }
                Write-Host ""
                Write-Host "Total resources: $($resources.Count)" -ForegroundColor Gray
            }
            
            # JSON output if requested
            if ($Json) {
                $result = @{
                    Success = $true
                    DeploymentName = $deploymentName
                    ResourceGroup = $ResourceGroupName
                    Environment = $Environment
                    CorrelationId = $deployment.correlationId
                    ProvisioningState = $deployment.provisioningState
                    Duration = $deploymentDuration.TotalSeconds
                    Outputs = $deployment.outputs
                    ResourceCount = $resources.Count
                } | ConvertTo-Json -Depth 10
                
                Write-Output $result
            }
        }
    }
    
    Write-DeploymentLog -Message "=== Deployment Complete ===" -Level Success
}
catch {
    # ==============================================================================
    # ERROR HANDLING FOR DEPLOYMENT FAILURES (T018)
    # ==============================================================================
    
    Write-DeploymentLog -Message "Deployment failed!" -Level Error
    Write-DeploymentLog -Message "Error: $($_.Exception.Message)" -Level Error
    
    # Extract detailed error messages
    Write-Host ""
    Write-Host "=== Deployment Error Details ===" -ForegroundColor Red
    
    $errorMessage = Format-ErrorMessage -ErrorRecord $_ -IncludeStackTrace:$false
    Write-Host $errorMessage -ForegroundColor Red
    
    # Try to get deployment error details from Azure
    try {
        Write-Host ""
        Write-Host "Fetching deployment error details..." -ForegroundColor Yellow
        
        $errorJson = az deployment group show `
            --name $deploymentName `
            --resource-group $ResourceGroupName `
            --query "{correlationId: properties.correlationId, error: properties.error}" `
            2>&1
        
        if ($LASTEXITCODE -eq 0 -and $errorJson) {
            $deploymentError = $errorJson | ConvertFrom-Json
            
            Write-Host ""
            Write-Host "Azure Deployment Error:" -ForegroundColor Red
            Write-Host "  Code:    $($deploymentError.error.code)" -ForegroundColor White
            Write-Host "  Message: $($deploymentError.error.message)" -ForegroundColor White
            
            if ($deploymentError.error.details) {
                Write-Host ""
                Write-Host "Error Details:" -ForegroundColor Red
                $deploymentError.error.details | ForEach-Object {
                    Write-Host "  - $($_.code): $($_.message)" -ForegroundColor White
                }
            }
            
            Write-Host ""
            Write-Host "Correlation ID: $($deploymentError.correlationId)" -ForegroundColor Gray
            Write-Host "Use this ID to search Azure Activity Log for detailed diagnostics." -ForegroundColor Gray
        }
    }
    catch {
        Write-Verbose "Could not fetch deployment error details: $_"
    }
    
    # Suggest corrective actions based on common error patterns
    Write-Host ""
    Write-Host "Troubleshooting Suggestions:" -ForegroundColor Yellow
    
    $errorText = $_.Exception.Message
    if ($errorText -match 'Timeout|timed out') {
        Write-Host "  - Deployment timed out. Try increasing -TimeoutMinutes parameter." -ForegroundColor White
        Write-Host "  - Check if there are Azure service issues in your region." -ForegroundColor White
    }
    elseif ($errorText -match 'Conflict|exists') {
        Write-Host "  - Resource name conflict. Some resources may already exist." -ForegroundColor White
        Write-Host "  - Try using a different resource group or cleaning up existing resources." -ForegroundColor White
    }
    elseif ($errorText -match 'quota|limit') {
        Write-Host "  - Azure subscription quota limit reached." -ForegroundColor White
        Write-Host "  - Request quota increase or clean up unused resources." -ForegroundColor White
    }
    elseif ($errorText -match 'permission|authorization|forbidden') {
        Write-Host "  - Insufficient permissions to create resources." -ForegroundColor White
        Write-Host "  - Verify you have Contributor or Owner role on the subscription." -ForegroundColor White
    }
    else {
        Write-Host "  - Review the Bicep template: $BicepTemplate" -ForegroundColor White
        Write-Host "  - Check parameters file: $ParametersFile" -ForegroundColor White
        Write-Host "  - Verify all required services are available in region: $Location" -ForegroundColor White
    }
    
    Write-Host ""
    
    # JSON error output if requested
    if ($Json) {
        $errorResult = @{
            Success = $false
            Error = $_.Exception.Message
            DeploymentName = $deploymentName
            ResourceGroup = $ResourceGroupName
            Environment = $Environment
        } | ConvertTo-Json
        
        Write-Output $errorResult
    }
    
    exit 1
}
