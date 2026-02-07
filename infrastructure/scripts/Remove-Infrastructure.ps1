<#
.SYNOPSIS
    Removes TxtTV Azure infrastructure.

.DESCRIPTION
    Cleanup script to delete Azure resources deployed for TxtTV.
    Can delete individual resources or the entire resource group.

.PARAMETER Environment
    Target environment: dev, staging, or prod.

.PARAMETER ResourceGroupName
    Optional resource group name. If not provided, uses rg-txttv-<environment>.

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER DeleteResourceGroup
    Delete the entire resource group (default behavior).
    If not specified, deletes individual resources within the group.

.PARAMETER PreserveData
    Skip deletion of storage accounts to preserve data.

.EXAMPLE
    .\Remove-Infrastructure.ps1 -Environment dev

.EXAMPLE
    .\Remove-Infrastructure.ps1 -Environment prod -Force -PreserveData
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$DeleteResourceGroup = $true,

    [Parameter(Mandatory = $false)]
    [switch]$PreserveData
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Get script directory to locate helper modules
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LibDir = Join-Path $ScriptDir 'lib'

# Import helper modules
Import-Module (Join-Path $LibDir 'AzureAuth.psm1') -Force
Import-Module (Join-Path $LibDir 'ErrorHandling.psm1') -Force

Write-DeploymentLog -Message "=== TxtTV Infrastructure Cleanup ===" -Level Warning
Write-DeploymentLog -Message "Environment: $Environment" -Level Info

# ==============================================================================
# AUTHENTICATION CHECK (T019)
# ==============================================================================

Write-DeploymentLog -Message "Checking Azure authentication..." -Level Info

$authStatus = Test-AzureAuthentication

if (-not $authStatus.IsAuthenticated) {
    Write-DeploymentLog -Message "Not authenticated with Azure CLI." -Level Warning
    $loginResult = Invoke-AzureLogin
    
    if (-not $loginResult.Success) {
        throw "Azure authentication failed. Please run 'az login' manually."
    }
    
    $authStatus = Test-AzureAuthentication
}

Write-DeploymentLog -Message "✓ Authenticated as: $($authStatus.Account)" -Level Success
Write-DeploymentLog -Message "  Subscription: $($authStatus.SubscriptionName)" -Level Info

# Set resource group name
if (-not $ResourceGroupName) {
    $ResourceGroupName = "rg-txttv-$Environment"
    Write-DeploymentLog -Message "Using default resource group name: $ResourceGroupName" -Level Info
}

# Check if resource group exists
Write-DeploymentLog -Message "Checking resource group..." -Level Info
$rgCheck = Test-AzureResourceGroup -ResourceGroupName $ResourceGroupName

if (-not $rgCheck.Exists) {
    Write-DeploymentLog -Message "Resource group does not exist: $ResourceGroupName" -Level Warning
    Write-DeploymentLog -Message "Nothing to delete." -Level Info
    exit 0
}

Write-DeploymentLog -Message "✓ Resource group found: $ResourceGroupName [$($rgCheck.Location)]" -Level Success

# ==============================================================================
# RESOURCE DELETION LOGIC (T020)
# ==============================================================================

# List resources to be deleted
Write-DeploymentLog -Message "Fetching resources in resource group..." -Level Info

$resourcesJson = az resource list --resource-group $ResourceGroupName --query "[].{Type:type, Name:name, Id:id}" 2>&1

if ($LASTEXITCODE -ne 0) {
    throw "Failed to list resources in resource group: $ResourceGroupName"
}

$resources = $resourcesJson | ConvertFrom-Json

if ($resources.Count -eq 0) {
    Write-DeploymentLog -Message "No resources found in resource group." -Level Info
    
    if ($DeleteResourceGroup) {
        Write-DeploymentLog -Message "Resource group is empty. Deleting resource group..." -Level Warning
    } else {
        Write-DeploymentLog -Message "Nothing to delete." -Level Info
        exit 0
    }
}

# Filter out storage accounts if PreserveData is set
$resourcesToDelete = $resources
if ($PreserveData) {
    $storageAccounts = $resources | Where-Object { $_.Type -like '*/storageAccounts' }
    $resourcesToDelete = $resources | Where-Object { $_.Type -notlike '*/storageAccounts' }
    
    if ($storageAccounts.Count -gt 0) {
        Write-DeploymentLog -Message "Preserving $($storageAccounts.Count) storage account(s):" -Level Warning
        $storageAccounts | ForEach-Object {
            Write-DeploymentLog -Message "  - $($_.Name)" -Level Info -NoTimestamp
        }
    }
}

# Display resources to be deleted
Write-Host ""
Write-Host "=== Resources to be Deleted ===" -ForegroundColor Red
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Location:       $($rgCheck.Location)" -ForegroundColor Yellow
Write-Host "Subscription:   $($authStatus.SubscriptionName)" -ForegroundColor Yellow
Write-Host ""

if ($DeleteResourceGroup) {
    Write-Host "ACTION: Delete entire resource group and all resources" -ForegroundColor Red
    Write-Host ""
    Write-Host "Resources (will all be deleted with resource group):" -ForegroundColor White
    $resources | ForEach-Object {
        $icon = if ($PreserveData -and $_.Type -like '*/storageAccounts') { "⚠" } else { "❌" }
        Write-Host "  $icon $($_.Type.PadRight(40)) $($_.Name)" -ForegroundColor White
    }
} else {
    Write-Host "ACTION: Delete individual resources (keep resource group)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Resources to delete:" -ForegroundColor White
    $resourcesToDelete | ForEach-Object {
        Write-Host "  ❌ $($_.Type.PadRight(40)) $($_.Name)" -ForegroundColor White
    }
    
    if ($PreserveData -and ($resources.Count -ne $resourcesToDelete.Count)) {
        Write-Host ""
        Write-Host "Resources to preserve:" -ForegroundColor Green
        $resources | Where-Object { $_.Id -notin $resourcesToDelete.Id } | ForEach-Object {
            Write-Host "  ✓ $($_.Type.PadRight(40)) $($_.Name)" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "Total resources: $($resources.Count)" -ForegroundColor Gray
if ($PreserveData) {
    Write-Host "To be deleted:   $($resourcesToDelete.Count)" -ForegroundColor Gray
}
Write-Host ""

# Confirmation prompt unless -Force
if (-not $Force) {
    Write-Host "⚠ WARNING: This action cannot be undone!" -ForegroundColor Red
    Write-Host ""
    
    if ($DeleteResourceGroup) {
        $confirmation = Read-Host "Type 'DELETE' to confirm resource group deletion"
        if ($confirmation -ne 'DELETE') {
            Write-DeploymentLog -Message "Deletion cancelled by user." -Level Warning
            exit 0
        }
    } else {
        $confirmation = Read-Host "Proceed with resource deletion? (y/N)"
        if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
            Write-DeploymentLog -Message "Deletion cancelled by user." -Level Warning
            exit 0
        }
    }
}

# Execute deletion
try {
    if ($DeleteResourceGroup) {
        # Delete entire resource group
        Write-DeploymentLog -Message "Deleting resource group: $ResourceGroupName" -Level Warning
        Write-Progress -Activity "Deleting Resource Group" -Status "Removing all resources..." -PercentComplete 0
        
        if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Delete resource group")) {
            az group delete --name $ResourceGroupName --yes --no-wait 2>&1 | Out-Null
            
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to initiate resource group deletion"
            }
            
            Write-DeploymentLog -Message "✓ Resource group deletion initiated" -Level Success
            Write-DeploymentLog -Message "Deletion is running in the background. This may take several minutes." -Level Info
            
            # Monitor deletion progress
            Write-DeploymentLog -Message "Monitoring deletion progress..." -Level Info
            $maxWaitMinutes = 10
            $startTime = Get-Date
            $deleted = $false
            
            while (((Get-Date) - $startTime).TotalMinutes -lt $maxWaitMinutes) {
                $percentComplete = [Math]::Min(90, (((Get-Date) - $startTime).TotalMinutes / $maxWaitMinutes) * 100)
                Write-Progress -Activity "Deleting Resource Group" `
                              -Status "Waiting for deletion to complete..." `
                              -PercentComplete $percentComplete
                
                $rgCheck = Test-AzureResourceGroup -ResourceGroupName $ResourceGroupName
                if (-not $rgCheck.Exists) {
                    $deleted = $true
                    break
                }
                
                Start-Sleep -Seconds 10
            }
            
            Write-Progress -Activity "Deleting Resource Group" -Completed
            
            if ($deleted) {
                Write-DeploymentLog -Message "✓ Resource group deleted successfully" -Level Success
            } else {
                Write-DeploymentLog -Message "Deletion is still in progress. Check Azure Portal for status." -Level Warning
            }
        }
    } else {
        # Delete individual resources
        Write-DeploymentLog -Message "Deleting resources..." -Level Warning
        
        $successCount = 0
        $failCount = 0
        $totalResources = $resourcesToDelete.Count
        
        foreach ($i in 0..($totalResources - 1)) {
            $resource = $resourcesToDelete[$i]
            $percentComplete = ($i / $totalResources) * 100
            
            Write-Progress -Activity "Deleting Resources" `
                          -Status "Deleting $($resource.Name) ($($i + 1)/$totalResources)" `
                          -PercentComplete $percentComplete
            
            try {
                Write-Verbose "Deleting resource: $($resource.Name) [$($resource.Type)]"
                
                if ($PSCmdlet.ShouldProcess($resource.Name, "Delete resource")) {
                    az resource delete --ids $resource.Id 2>&1 | Out-Null
                    
                    if ($LASTEXITCODE -eq 0) {
                        $successCount++
                        Write-DeploymentLog -Message "✓ Deleted: $($resource.Name)" -Level Success
                    } else {
                        $failCount++
                        Write-DeploymentLog -Message "✗ Failed to delete: $($resource.Name)" -Level Error
                    }
                }
            }
            catch {
                $failCount++
                Write-DeploymentLog -Message "✗ Error deleting $($resource.Name): $($_.Exception.Message)" -Level Error
            }
        }
        
        Write-Progress -Activity "Deleting Resources" -Completed
        
        Write-Host ""
        Write-Host "=== Deletion Summary ===" -ForegroundColor Cyan
        Write-Host "Successfully deleted: $successCount" -ForegroundColor Green
        if ($failCount -gt 0) {
            Write-Host "Failed to delete:     $failCount" -ForegroundColor Red
        }
        
        if ($failCount -eq 0) {
            Write-DeploymentLog -Message "✓ All resources deleted successfully" -Level Success
        } else {
            Write-DeploymentLog -Message "Some resources failed to delete. Check error messages above." -Level Warning
        }
        
        # Optionally delete the now-empty resource group
        if ($successCount -eq $totalResources -and -not $PreserveData) {
            Write-Host ""
            $deleteEmptyRg = Read-Host "Resource group is now empty. Delete the resource group? (y/N)"
            if ($deleteEmptyRg -eq 'y' -or $deleteEmptyRg -eq 'Y') {
                az group delete --name $ResourceGroupName --yes 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-DeploymentLog -Message "✓ Empty resource group deleted" -Level Success
                }
            }
        }
    }
    
    Write-DeploymentLog -Message "=== Cleanup Complete ===" -Level Success
}
catch {
    Write-DeploymentLog -Message "Deletion failed!" -Level Error
    Write-DeploymentLog -Message "Error: $($_.Exception.Message)" -Level Error
    
    $errorMessage = Format-ErrorMessage -ErrorRecord $_
    Write-Host $errorMessage -ForegroundColor Red
    
    exit 1
}
