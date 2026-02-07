<#
.SYNOPSIS
    Helper functions for Azure authentication checks.

.DESCRIPTION
    Provides functions to verify Azure CLI authentication status,
    subscription access, and resource group permissions.
#>

function Test-AzureAuthentication {
    <#
    .SYNOPSIS
        Checks if the user is authenticated with Azure CLI.
    
    .RETURNS
        PSCustomObject with IsAuthenticated (bool), Account (string), and TenantId (string).
    #>
    [CmdletBinding()]
    param()

    $result = @{
        IsAuthenticated = $false
        Account = $null
        TenantId = $null
        SubscriptionId = $null
        SubscriptionName = $null
    }

    try {
        # Check if az CLI is available
        $azCommand = Get-Command az -ErrorAction SilentlyContinue
        if (-not $azCommand) {
            Write-Error "Azure CLI (az) not found. Please install Azure CLI from https://aka.ms/installazurecli"
            return [PSCustomObject]$result
        }

        Write-Verbose "Checking Azure authentication status..."
        
        # Get account information
        $accountJson = az account show 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Verbose "Not authenticated with Azure CLI."
            return [PSCustomObject]$result
        }

        $account = $accountJson | ConvertFrom-Json
        $result.IsAuthenticated = $true
        $result.Account = $account.user.name
        $result.TenantId = $account.tenantId
        $result.SubscriptionId = $account.id
        $result.SubscriptionName = $account.name

        Write-Verbose "Authenticated as: $($result.Account)"
        Write-Verbose "Subscription: $($result.SubscriptionName) ($($result.SubscriptionId))"
    }
    catch {
        Write-Error "Failed to check Azure authentication: $_"
    }

    return [PSCustomObject]$result
}

function Test-AzureSubscription {
    <#
    .SYNOPSIS
        Verifies access to a specific Azure subscription.
    
    .PARAMETER SubscriptionId
        The subscription ID to verify access to.
    
    .RETURNS
        PSCustomObject with HasAccess (bool), SubscriptionName (string), and State (string).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId
    )

    $result = @{
        HasAccess = $false
        SubscriptionId = $SubscriptionId
        SubscriptionName = $null
        State = $null
    }

    try {
        Write-Verbose "Checking access to subscription: $SubscriptionId"
        
        # Try to set the subscription
        $subJson = az account set --subscription $SubscriptionId 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Verbose "Cannot access subscription: $SubscriptionId"
            return [PSCustomObject]$result
        }

        # Get subscription details
        $subJson = az account show --subscription $SubscriptionId 2>&1
        if ($LASTEXITCODE -eq 0) {
            $subscription = $subJson | ConvertFrom-Json
            $result.HasAccess = $true
            $result.SubscriptionName = $subscription.name
            $result.State = $subscription.state

            Write-Verbose "Subscription access confirmed: $($result.SubscriptionName) [$($result.State)]"
        }
    }
    catch {
        Write-Error "Failed to verify subscription access: $_"
    }

    return [PSCustomObject]$result
}

function Test-AzureResourceGroup {
    <#
    .SYNOPSIS
        Checks if a resource group exists and is accessible.
    
    .PARAMETER ResourceGroupName
        The name of the resource group to check.
    
    .PARAMETER Location
        Optional location to create the resource group if it doesn't exist.
    
    .RETURNS
        PSCustomObject with Exists (bool), Location (string), and ProvisioningState (string).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $false)]
        [string]$Location
    )

    $result = @{
        Exists = $false
        ResourceGroupName = $ResourceGroupName
        Location = $null
        ProvisioningState = $null
    }

    try {
        Write-Verbose "Checking resource group: $ResourceGroupName"
        
        # Check if resource group exists
        $rgJson = az group show --name $ResourceGroupName 2>&1
        if ($LASTEXITCODE -eq 0) {
            $rg = $rgJson | ConvertFrom-Json
            $result.Exists = $true
            $result.Location = $rg.location
            $result.ProvisioningState = $rg.properties.provisioningState

            Write-Verbose "Resource group exists: $ResourceGroupName [$($result.Location)]"
        } else {
            Write-Verbose "Resource group does not exist: $ResourceGroupName"
        }
    }
    catch {
        Write-Error "Failed to check resource group: $_"
    }

    return [PSCustomObject]$result
}

function Invoke-AzureLogin {
    <#
    .SYNOPSIS
        Initiates Azure CLI login if not already authenticated.
    
    .PARAMETER UseDeviceCode
        Use device code flow for authentication (useful for remote sessions).
    
    .RETURNS
        PSCustomObject with Success (bool) and Account (string).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$UseDeviceCode
    )

    $result = @{
        Success = $false
        Account = $null
    }

    try {
        # Check current authentication
        $authStatus = Test-AzureAuthentication
        if ($authStatus.IsAuthenticated) {
            Write-Verbose "Already authenticated as: $($authStatus.Account)"
            $result.Success = $true
            $result.Account = $authStatus.Account
            return [PSCustomObject]$result
        }

        Write-Host "Initiating Azure login..." -ForegroundColor Cyan
        
        if ($UseDeviceCode) {
            az login --use-device-code
        } else {
            az login
        }

        if ($LASTEXITCODE -eq 0) {
            $authStatus = Test-AzureAuthentication
            $result.Success = $authStatus.IsAuthenticated
            $result.Account = $authStatus.Account
            Write-Host "Successfully authenticated as: $($result.Account)" -ForegroundColor Green
        } else {
            Write-Error "Azure login failed."
        }
    }
    catch {
        Write-Error "Failed to login to Azure: $_"
    }

    return [PSCustomObject]$result
}

Export-ModuleMember -Function Test-AzureAuthentication, Test-AzureSubscription, Test-AzureResourceGroup, Invoke-AzureLogin
