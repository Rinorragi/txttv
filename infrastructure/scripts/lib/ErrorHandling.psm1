<#
.SYNOPSIS
    Error handling and logging utilities for deployment scripts.

.DESCRIPTION
    Provides structured logging, error formatting, and validation helpers
    for deployment and testing scripts.
#>

function Write-DeploymentLog {
    <#
    .SYNOPSIS
        Writes a formatted log message with timestamp and severity.
    
    .PARAMETER Message
        The log message to write.
    
    .PARAMETER Level
        Log level: Info, Warning, Error, Success, Debug.
    
    .PARAMETER NoTimestamp
        Skip timestamp prefix.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Debug')]
        [string]$Level = 'Info',

        [Parameter(Mandatory = $false)]
        [switch]$NoTimestamp
    )

    process {
        $timestamp = if (-not $NoTimestamp) {
            "[{0:yyyy-MM-dd HH:mm:ss}] " -f (Get-Date)
        } else {
            ""
        }

        $prefix = switch ($Level) {
            'Info'    { "" }
            'Warning' { "⚠ WARNING: " }
            'Error'   { "❌ ERROR: " }
            'Success' { "✓ " }
            'Debug'   { "🔍 DEBUG: " }
        }

        $color = switch ($Level) {
            'Info'    { 'White' }
            'Warning' { 'Yellow' }
            'Error'   { 'Red' }
            'Success' { 'Green' }
            'Debug'   { 'Gray' }
        }

        $formattedMessage = "$timestamp$prefix$Message"

        Write-Host $formattedMessage -ForegroundColor $color

        # Also write to verbose/warning/error streams for proper logging
        switch ($Level) {
            'Debug'   { Write-Verbose $Message }
            'Warning' { Write-Warning $Message }
            'Error'   { Write-Error $Message -ErrorAction Continue }
        }
    }
}

function Format-ErrorMessage {
    <#
    .SYNOPSIS
        Formats an error record into a readable message.
    
    .PARAMETER ErrorRecord
        The error record to format.
    
    .PARAMETER IncludeStackTrace
        Include the stack trace in the output.
    
    .RETURNS
        Formatted error string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeStackTrace
    )

    $errorMessage = @()
    $errorMessage += "Error: $($ErrorRecord.Exception.Message)"
    
    if ($ErrorRecord.CategoryInfo) {
        $errorMessage += "Category: $($ErrorRecord.CategoryInfo.Category)"
    }

    if ($ErrorRecord.TargetObject) {
        $errorMessage += "Target: $($ErrorRecord.TargetObject)"
    }

    if ($ErrorRecord.InvocationInfo.ScriptName) {
        $errorMessage += "Script: $($ErrorRecord.InvocationInfo.ScriptName):$($ErrorRecord.InvocationInfo.ScriptLineNumber)"
    }

    if ($IncludeStackTrace -and $ErrorRecord.ScriptStackTrace) {
        $errorMessage += "Stack Trace:"
        $errorMessage += $ErrorRecord.ScriptStackTrace
    }

    return $errorMessage -join "`n"
}

function Test-RequiredParameter {
    <#
    .SYNOPSIS
        Validates that a required parameter has a value.
    
    .PARAMETER ParameterName
        The name of the parameter being validated.
    
    .PARAMETER ParameterValue
        The value to validate.
    
    .PARAMETER AllowEmptyString
        Allow empty strings (but not null).
    
    .RETURNS
        $true if valid, throws error if invalid.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ParameterName,

        [Parameter(Mandatory = $false)]
        [object]$ParameterValue,

        [Parameter(Mandatory = $false)]
        [switch]$AllowEmptyString
    )

    if ($null -eq $ParameterValue) {
        throw "Required parameter '$ParameterName' is null or not provided."
    }

    if (-not $AllowEmptyString -and $ParameterValue -is [string] -and [string]::IsNullOrWhiteSpace($ParameterValue)) {
        throw "Required parameter '$ParameterName' is empty or whitespace."
    }

    return $true
}

function Test-FilePath {
    <#
    .SYNOPSIS
        Validates that a file path exists and is accessible.
    
    .PARAMETER Path
        The file path to validate.
    
    .PARAMETER ParameterName
        Optional parameter name for error messages.
    
    .PARAMETER Extension
        Optional required file extension (e.g., ".bicep", ".json").
    
    .RETURNS
        $true if valid, throws error if invalid.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$ParameterName = "Path",

        [Parameter(Mandatory = $false)]
        [string]$Extension
    )

    if (-not (Test-Path $Path -PathType Leaf)) {
        throw "File not found for parameter '$ParameterName': $Path"
    }

    if ($Extension) {
        $actualExtension = [System.IO.Path]::GetExtension($Path)
        if ($actualExtension -ne $Extension) {
            throw "Invalid file extension for parameter '$ParameterName'. Expected '$Extension', got '$actualExtension'."
        }
    }

    return $true
}

function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Executes a script block with retry logic.
    
    .PARAMETER ScriptBlock
        The script block to execute.
    
    .PARAMETER MaxRetries
        Maximum number of retry attempts (default: 3).
    
    .PARAMETER RetryDelaySeconds
        Delay between retries in seconds (default: 5).
    
    .PARAMETER RetryMessage
        Optional message to display during retries.
    
    .RETURNS
        Result of the script block execution.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$RetryDelaySeconds = 5,

        [Parameter(Mandatory = $false)]
        [string]$RetryMessage = "Operation failed, retrying..."
    )

    $attempt = 0
    $success = $false
    $result = $null

    while (-not $success -and $attempt -lt $MaxRetries) {
        $attempt++
        try {
            Write-Verbose "Attempt $attempt of $MaxRetries..."
            $result = & $ScriptBlock
            $success = $true
        }
        catch {
            if ($attempt -lt $MaxRetries) {
                Write-DeploymentLog -Message "$RetryMessage (Attempt $attempt/$MaxRetries)" -Level Warning
                Write-Verbose "Error: $($_.Exception.Message)"
                Start-Sleep -Seconds $RetryDelaySeconds
            } else {
                Write-DeploymentLog -Message "Operation failed after $MaxRetries attempts." -Level Error
                throw
            }
        }
    }

    return $result
}

function New-DeploymentResult {
    <#
    .SYNOPSIS
        Creates a standardized deployment result object.
    
    .PARAMETER Success
        Whether the deployment succeeded.
    
    .PARAMETER Message
        Result message.
    
    .PARAMETER Data
        Optional additional data to include.
    
    .RETURNS
        PSCustomObject with Success, Message, Timestamp, and Data properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Success,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [hashtable]$Data = @{}
    )

    return [PSCustomObject]@{
        Success = $Success
        Message = $Message
        Timestamp = Get-Date -Format "o"
        Data = $Data
    }
}

Export-ModuleMember -Function Write-DeploymentLog, Format-ErrorMessage, Test-RequiredParameter, Test-FilePath, Invoke-WithRetry, New-DeploymentResult
