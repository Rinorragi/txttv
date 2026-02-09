<#
.SYNOPSIS
    Validation functions for APIM policy fragment generation.

.DESCRIPTION
    Provides 4-layer validation for generated policy fragments:
    - Layer 1: XML Well-Formedness
    - Layer 2: APIM Schema Compliance
    - Layer 3: Security Scanning (XSS patterns, size limits)
    - Layer 4: Integration Validation (fragment loading)

.NOTES
    Version: 1.0.0
    Used by: convert-web-to-apim.ps1
    Requirements: PowerShell 7+
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# === Layer 1: XML Well-Formedness ===

<#
.SYNOPSIS
    Validates XML structure and encoding.
    
.PARAMETER XmlContent
    XML string to validate
    
.RETURNS
    PSCustomObject with IsValid, ErrorMessage
#>
function Test-XmlWellFormedness {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$XmlContent
    )
    
    try {
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.LoadXml($XmlContent)
        
        return [PSCustomObject]@{
            IsValid = $true
            ErrorMessage = $null
        }
    }
    catch {
        return [PSCustomObject]@{
            IsValid = $false
            ErrorMessage = "XML parsing failed: $($_.Exception.Message)"
        }
    }
}

# === Layer 2: APIM Schema Compliance ===

<#
.SYNOPSIS
    Validates policy fragment structure against APIM requirements.
    
.PARAMETER FragmentPath
    Path to the policy fragment XML file
    
.RETURNS
    PSCustomObject with IsValid, Warnings[], Errors[]
#>
function Test-ApimSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FragmentPath
    )
    
    $warnings = @()
    $errors = @()
    
    if (-not (Test-Path $FragmentPath)) {
        return [PSCustomObject]@{
            IsValid = $false
            Warnings = @()
            Errors = @("File not found: $FragmentPath")
        }
    }
    
    $content = Get-Content $FragmentPath -Raw
    
    # Check root element
    if ($content -notmatch '(?s)<fragment>.*</fragment>') {
        $errors += "Missing or invalid <fragment> root element"
    }
    
    # Check for set-body element
    if ($content -notmatch '(?s)<set-body>.*</set-body>') {
        $errors += "Missing <set-body> element"
    }
    
    # Check for CDATA section
    if ($content -notmatch '(?s)<!\[CDATA\[.*\]\]>') {
        $warnings += "No CDATA section found - HTML content should be wrapped in CDATA"
    }
    
    # Check for HTML5 DOCTYPE
    if ($content -notmatch '<!DOCTYPE html>') {
        $warnings += "No HTML5 DOCTYPE declaration found"
    }
    
    return [PSCustomObject]@{
        IsValid = ($errors.Count -eq 0)
        Warnings = $warnings
        Errors = $errors
    }
}

# === Layer 3: Security Scanning ===

<#
.SYNOPSIS
    Scans content for XSS patterns and validates size limits.
    
.PARAMETER FragmentPath
    Path to the policy fragment XML file
    
.PARAMETER MaxSizeKB
    Maximum allowed file size in KB (default: 256)
    
.RETURNS
    PSCustomObject with IsValid, SecurityIssues[], SizeBytes
#>
function Test-SecurityCompliance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FragmentPath,
        
        [Parameter()]
        [int]$MaxSizeKB = 256
    )
    
    $securityIssues = @()
    
    if (-not (Test-Path $FragmentPath)) {
        return [PSCustomObject]@{
            IsValid = $false
            SecurityIssues = @("File not found: $FragmentPath")
            SizeBytes = 0
        }
    }
    
    $content = Get-Content $FragmentPath -Raw
    $sizeBytes = [System.Text.Encoding]::UTF8.GetByteCount($content)
    $maxSizeBytes = $MaxSizeKB * 1024
    
    # Size check
    if ($sizeBytes -gt $maxSizeBytes) {
        $securityIssues += "File size ($sizeBytes bytes) exceeds limit ($maxSizeBytes bytes)"
    }
    
    # XSS pattern detection (outside CDATA sections)
    $xssPatterns = @(
        '(?s)<script[^>]*>(?!.*CDATA).*?</script>',  # Unprotected script tags
        'on\w+\s*=\s*["''].*?["'']',             # Event handlers (onclick, onerror, etc.)
        'javascript:',                            # javascript: protocol
        '<iframe[^>]*>',                         # Iframes
        'eval\s*\(',                             # eval() calls
        'document\.write',                       # document.write
        'innerHTML\s*=',                         # innerHTML assignment
        '<embed[^>]*>',                          # embed tags
        '<object[^>]*>'                          # object tags
    )
    
    # Extract content outside CDATA sections
    $contentOutsideCdata = $content -replace '(?s)<!\[CDATA\[.*?\]\]>', ''
    
    foreach ($pattern in $xssPatterns) {
        if ($contentOutsideCdata -match $pattern) {
            $securityIssues += "Potential XSS pattern detected: $pattern"
        }
    }
    
    # Check for unescaped ]]> inside CDATA (would break CDATA)
    if ($content -match '(?s)<!\[CDATA\[.*?\]\]>.*?\]\]>.*?<!\[CDATA\[') {
        $securityIssues += "Improperly escaped ]]> sequence inside CDATA"
    }
    
    return [PSCustomObject]@{
        IsValid = ($securityIssues.Count -eq 0)
        SecurityIssues = $securityIssues
        SizeBytes = $sizeBytes
    }
}

# === Layer 4: Integration Validation ===

<#
.SYNOPSIS
    Validates that fragment can be loaded and has expected structure.
    
.PARAMETER FragmentPath
    Path to the policy fragment XML file
    
.RETURNS
    PSCustomObject with IsValid, Issues[]
#>
function Test-FragmentIntegration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FragmentPath
    )
    
    $issues = @()
    
    if (-not (Test-Path $FragmentPath)) {
        return [PSCustomObject]@{
            IsValid = $false
            Issues = @("File not found: $FragmentPath")
        }
    }
    
    try {
        # Load as XML to verify structure
        [xml]$xml = Get-Content $FragmentPath -Raw
        
        # Check for expected elements
        if (-not $xml.fragment) {
            $issues += "Root element <fragment> not found"
        }
        
        if (-not $xml.fragment.'set-body') {
            $issues += "Element <set-body> not found"
        }
        
        # Check for HTML content in CDATA
        $bodyContent = $xml.fragment.'set-body'.'#cdata-section'
        if ([string]::IsNullOrWhiteSpace($bodyContent)) {
            $issues += "No CDATA content found in <set-body>"
        }
        elseif ($bodyContent -notmatch '<!DOCTYPE html>') {
            $issues += "CDATA content doesn't start with <!DOCTYPE html>"
        }
        
        # Check for essential HTML structure
        if ($bodyContent) {
            if ($bodyContent -notmatch '<html[^>]*>') {
                $issues += "Missing <html> element in CDATA content"
            }
            if ($bodyContent -notmatch '<head>') {
                $issues += "Missing <head> element in CDATA content"
            }
            if ($bodyContent -notmatch '<body>') {
                $issues += "Missing <body> element in CDATA content"
            }
        }
        
    }
    catch {
        $issues += "Failed to load fragment as XML: $($_.Exception.Message)"
    }
    
    return [PSCustomObject]@{
        IsValid = ($issues.Count -eq 0)
        Issues = $issues
    }
}

# === Combined Validation ===

<#
.SYNOPSIS
    Runs all 4 validation layers and returns comprehensive results.
    
.PARAMETER FragmentPath
    Path to the policy fragment XML file
    
.RETURNS
    PSCustomObject with overall validation status and layer-specific results
#>
function Invoke-FragmentValidation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FragmentPath
    )
    
    Write-Verbose "Starting 4-layer validation for: $FragmentPath"
    
    # Read content once
    $content = if (Test-Path $FragmentPath) { 
        Get-Content $FragmentPath -Raw 
    } else { 
        "" 
    }
    
    # Layer 1: XML Well-Formedness
    Write-Verbose "  Layer 1: XML Well-Formedness"
    $layer1 = Test-XmlWellFormedness -XmlContent $content
    
    # Layer 2: APIM Schema
    Write-Verbose "  Layer 2: APIM Schema Compliance"
    $layer2 = Test-ApimSchema -FragmentPath $FragmentPath
    
    # Layer 3: Security
    Write-Verbose "  Layer 3: Security Scanning"
    $layer3 = Test-SecurityCompliance -FragmentPath $FragmentPath
    
    # Layer 4: Integration
    Write-Verbose "  Layer 4: Integration Validation"
    $layer4 = Test-FragmentIntegration -FragmentPath $FragmentPath
    
    # Calculate overall status
    $overallValid = $layer1.IsValid -and $layer2.IsValid -and $layer3.IsValid -and $layer4.IsValid
    
    $result = [PSCustomObject]@{
        FilePath = $FragmentPath
        IsValid = $overallValid
        Layer1_XmlWellFormedness = $layer1
        Layer2_ApimSchema = $layer2
        Layer3_Security = $layer3
        Layer4_Integration = $layer4
        Summary = if ($overallValid) {
            "✓ All validation layers passed"
        } else {
            "✗ Validation failed - see layer results for details"
        }
    }
    
    Write-Verbose "  Result: $($result.Summary)"
    
    return $result
}

# === Export Functions ===
# Functions are available when this script is dot-sourced

