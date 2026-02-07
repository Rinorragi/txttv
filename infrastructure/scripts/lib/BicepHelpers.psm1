<#
.SYNOPSIS
    Helper functions for Bicep template operations.

.DESCRIPTION
    Provides validation and build functions for Azure Bicep templates.
    Requires Azure CLI or Bicep CLI to be installed.
#>

function Test-BicepTemplate {
    <#
    .SYNOPSIS
        Validates a Bicep template file.
    
    .PARAMETER TemplatePath
        Path to the Bicep template file to validate.
    
    .RETURNS
        PSCustomObject with IsValid (bool) and Errors (array) properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$TemplatePath
    )

    $result = @{
        IsValid = $false
        Errors = @()
        TemplatePath = $TemplatePath
    }

    try {
        # Check if bicep CLI is available
        $bicepCommand = Get-Command bicep -ErrorAction SilentlyContinue
        if (-not $bicepCommand) {
            # Try az bicep as fallback
            $azCommand = Get-Command az -ErrorAction SilentlyContinue
            if (-not $azCommand) {
                throw "Neither 'bicep' nor 'az' CLI found. Please install Azure Bicep CLI or Azure CLI."
            }
            $useBicepCli = $false
        } else {
            $useBicepCli = $true
        }

        Write-Verbose "Validating Bicep template: $TemplatePath"
        
        if ($useBicepCli) {
            # Use bicep CLI directly
            $output = bicep build $TemplatePath --stdout 2>&1
            $exitCode = $LASTEXITCODE
        } else {
            # Use az bicep build
            $tempFile = [System.IO.Path]::GetTempFileName()
            $output = az bicep build --file $TemplatePath --outfile $tempFile 2>&1
            $exitCode = $LASTEXITCODE
            if (Test-Path $tempFile) {
                Remove-Item $tempFile -Force
            }
        }

        if ($exitCode -eq 0) {
            $result.IsValid = $true
            Write-Verbose "Bicep template is valid."
        } else {
            $result.Errors = @($output | Where-Object { $_ -match 'Error|Warning' })
            Write-Verbose "Bicep template validation failed with $($result.Errors.Count) errors."
        }
    }
    catch {
        $result.Errors += $_.Exception.Message
        Write-Error "Failed to validate Bicep template: $_"
    }

    return [PSCustomObject]$result
}

function Invoke-BicepBuild {
    <#
    .SYNOPSIS
        Builds a Bicep template to ARM JSON.
    
    .PARAMETER TemplatePath
        Path to the Bicep template file to build.
    
    .PARAMETER OutputPath
        Optional output path for the ARM template. If not specified, outputs to stdout.
    
    .RETURNS
        PSCustomObject with Success (bool), OutputPath (string), and Errors (array) properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$TemplatePath,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    $result = @{
        Success = $false
        OutputPath = $OutputPath
        Errors = @()
    }

    try {
        # Check if bicep CLI is available
        $bicepCommand = Get-Command bicep -ErrorAction SilentlyContinue
        if (-not $bicepCommand) {
            # Try az bicep as fallback
            $azCommand = Get-Command az -ErrorAction SilentlyContinue
            if (-not $azCommand) {
                throw "Neither 'bicep' nor 'az' CLI found. Please install Azure Bicep CLI or Azure CLI."
            }
            $useBicepCli = $false
        } else {
            $useBicepCli = $true
        }

        Write-Verbose "Building Bicep template: $TemplatePath"
        
        if ($OutputPath) {
            # Ensure output directory exists
            $outputDir = Split-Path $OutputPath -Parent
            if ($outputDir -and -not (Test-Path $outputDir)) {
                New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
            }

            if ($useBicepCli) {
                bicep build $TemplatePath --outfile $OutputPath 2>&1 | Out-Null
                $exitCode = $LASTEXITCODE
            } else {
                az bicep build --file $TemplatePath --outfile $OutputPath 2>&1 | Out-Null
                $exitCode = $LASTEXITCODE
            }
        } else {
            if ($useBicepCli) {
                bicep build $TemplatePath --stdout 2>&1 | Out-Null
                $exitCode = $LASTEXITCODE
            } else {
                $tempFile = [System.IO.Path]::GetTempFileName()
                az bicep build --file $TemplatePath --outfile $tempFile 2>&1 | Out-Null
                $exitCode = $LASTEXITCODE
                if (Test-Path $tempFile) {
                    Remove-Item $tempFile -Force
                }
            }
        }

        if ($exitCode -eq 0) {
            $result.Success = $true
            Write-Verbose "Bicep template built successfully."
        } else {
            throw "Bicep build failed with exit code $exitCode"
        }
    }
    catch {
        $result.Errors += $_.Exception.Message
        Write-Error "Failed to build Bicep template: $_"
    }

    return [PSCustomObject]$result
}

Export-ModuleMember -Function Test-BicepTemplate, Invoke-BicepBuild
