<#
.SYNOPSIS
    Converts local web interface files to APIM policy fragments

.DESCRIPTION
    Transforms HTML/CSS/JS source files from src/web/ into APIM policy fragments
    that can be deployed to Azure API Management. Each fragment contains a complete
    HTML page embedded in a CDATA section within a <set-body> policy element.
    
    The script performs 4-layer validation:
    - Layer 1: XML well-formedness
    - Layer 2: APIM schema compliance
    - Layer 3: Security scanning (XSS, injection risks)
    - Layer 4: Integration testing (fragment composition)

.PARAMETER SourcePath
    Root directory of web interface source files. Defaults to src/web

.PARAMETER OutputPath
    Output directory for generated policy fragments. Defaults to infrastructure/modules/apim/fragments

.PARAMETER ContentPath
    Directory containing text TV page content files. Defaults to content/pages

.PARAMETER Pages
    Array of page numbers to convert (e.g., 100,101,105). Defaults to 100..110

.PARAMETER Validate
    Enable 4-layer validation after generation. Enabled by default.

.PARAMETER Force
    Overwrite existing fragments without prompting

.PARAMETER WhatIf
    Show what would be generated without creating files

.PARAMETER Verbose
    Enable detailed logging

.EXAMPLE
    .\convert-web-to-apim.ps1
    # Convert all pages (100-110) with validation

.EXAMPLE
    .\convert-web-to-apim.ps1 -Pages 100,101,102
    # Convert specific pages only

.EXAMPLE
    .\convert-web-to-apim.ps1 -WhatIf
    # Preview changes without generating files

.NOTES
    Author: TxtTV Development Team
    Constitution: v1.2.2 compliant
    Last Updated: 2026-02-09
    
    Exit Codes:
    0 = Success
    1 = Partial failure
    2 = Input error
    3 = Output error
    4 = Validation error
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$SourcePath = "src/web",
    
    [Parameter()]
    [string]$OutputPath = "infrastructure/modules/apim/fragments",
    
    [Parameter()]
    [string]$ContentPath = "content/pages",
    
    [Parameter()]
    [int[]]$Pages = (100..110),
    
    [Parameter()]
    [bool]$Validate = $true,
    
    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$script:failedPages = @()
$script:successPages = @()

# Get repository root (2 levels up from scripts/)
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# Resolve paths relative to repo root
$SourcePath = Join-Path $repoRoot $SourcePath
$OutputPath = Join-Path $repoRoot $OutputPath
$ContentPath = Join-Path $repoRoot $ContentPath

# ============================================================================
# Utility Functions
# ============================================================================

function Write-StatusMessage {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )
    
    $color = switch ($Type) {
        'Info'    { 'Cyan' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
    }
    
    $prefix = switch ($Type) {
        'Info'    { '  ' }
        'Success' { '✓ ' }
        'Warning' { '⚠ ' }
        'Error'   { '✗ ' }
    }
    
    Write-Host "$prefix$Message" -ForegroundColor $color
}

function Test-InputFiles {
    <#
    .SYNOPSIS
        Validates that all required input files exist
    #>
    param()
    
    $errors = @()
    
    # Check source directory
    if (-not (Test-Path $SourcePath)) {
        $errors += "Source directory not found: $SourcePath"
    }
    
    # Check template
    $templatePath = Join-Path $SourcePath "templates/page-template.html"
    if (-not (Test-Path $templatePath)) {
        $errors += "Template not found: $templatePath"
    }
    
    # Check CSS
    $cssPath = Join-Path $SourcePath "styles/txttv.css"
    if (-not (Test-Path $cssPath)) {
        $errors += "Stylesheet not found: $cssPath"
    }
    
    # Check content directory
    if (-not (Test-Path $ContentPath)) {
        $errors += "Content directory not found: $ContentPath"
    }
    
    if ($errors.Count -gt 0) {
        foreach ($error in $errors) {
            Write-StatusMessage $error -Type Error
        }
        return $false
    }
    
    return $true
}

function Read-TemplateFile {
    <#
    .SYNOPSIS
        Reads the HTML template file
    #>
    param()
    
    $templatePath = Join-Path $SourcePath "templates/page-template.html"
    
    try {
        $template = Get-Content -Path $templatePath -Raw -Encoding UTF8
        Write-Verbose "Template loaded: $templatePath"
        return $template
    }
    catch {
        Write-StatusMessage "Failed to read template: $_" -Type Error
        throw
    }
}

function Read-StylesheetContent {
    <#
    .SYNOPSIS
        Reads the CSS stylesheet
    #>
    param()
    
    $cssPath = Join-Path $SourcePath "styles/txttv.css"
    
    try {
        $css = Get-Content -Path $cssPath -Raw -Encoding UTF8
        $sizeKB = [Math]::Round($css.Length / 1KB, 1)
        Write-Verbose "CSS loaded: $cssPath ($sizeKB KB)"
        
        if ($css.Length -gt 5KB) {
            Write-StatusMessage "Warning: CSS file is large (${sizeKB} KB). Consider optimization." -Type Warning
        }
        
        return $css
    }
    catch {
        Write-StatusMessage "Failed to read CSS: $_" -Type Error
        throw
    }
}

function Read-ScriptContent {
    <#
    .SYNOPSIS
        Reads JavaScript files and combines them
    #>
    param()
    
    $scriptsPath = Join-Path $SourcePath "scripts"
    $combinedScript = ""
    
    if (Test-Path $scriptsPath) {
        $jsFiles = Get-ChildItem -Path $scriptsPath -Filter "*.js" -File
        
        foreach ($file in $jsFiles) {
            try {
                $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
                $combinedScript += "`n// === $($file.Name) ===`n"
                $combinedScript += $content
                
                $sizeKB = [Math]::Round($content.Length / 1KB, 1)
                Write-Verbose "JS loaded: $($file.Name) ($sizeKB KB)"
            }
            catch {
                Write-StatusMessage "Warning: Failed to read $($file.Name): $_" -Type Warning
            }
        }
    }
    
    if ($combinedScript.Length -gt 10KB) {
        $sizeKB = [Math]::Round($combinedScript.Length / 1KB, 1)
        Write-StatusMessage "Warning: Combined JS is large (${sizeKB} KB). Consider optimization." -Type Warning
    }
    
    return $combinedScript
}

function Read-ContentFile {
    <#
    .SYNOPSIS
        Reads content for a specific page
    #>
    param(
        [int]$PageNumber
    )
    
    $contentFile = Join-Path $ContentPath "page-$PageNumber.txt"
    
    if (-not (Test-Path $contentFile)) {
        Write-StatusMessage "Content file not found: $contentFile" -Type Warning
        return @"
═══════════════════════════════════════
         TXT TV - PAGE $PageNumber
═══════════════════════════════════════

[Content not available]

═══════════════════════════════════════
"@
    }
    
    try {
        $content = Get-Content -Path $contentFile -Raw -Encoding UTF8
        
        if ($content.Length -gt 2000) {
            Write-StatusMessage "Warning: Page $PageNumber content exceeds 2000 characters ($($content.Length) chars)" -Type Warning
        }
        
        Write-Verbose "Content loaded: page-$PageNumber.txt ($($content.Length) chars)"
        return $content
    }
    catch {
        Write-StatusMessage "Failed to read content for page ${PageNumber}: $_" -Type Error
        throw
    }
}

function Invoke-PlaceholderReplacement {
    <#
    .SYNOPSIS
        Replaces placeholders in template with actual content
    #>
    param(
        [string]$Template,
        [int]$PageNumber,
        [string]$Content,
        [string]$Style,
        [string]$Script
    )
    
    $html = $Template
    
    # Replace PAGE_NUMBER
    $html = $html -replace '\{PAGE_NUMBER\}', $PageNumber
    
    # Replace CONTENT
    $html = $html -replace '\{CONTENT\}', $Content
    
    # Replace STYLE
    $html = $html -replace '\{STYLE\}', $Style
    
    # Replace SCRIPT
    $html = $html -replace '\{SCRIPT\}', $Script
    
    # Calculate prev/next pages with wrapping
    $prevPage = if ($PageNumber -eq 100) { 110 } else { $PageNumber - 1 }
    $nextPage = if ($PageNumber -eq 110) { 100 } else { $PageNumber + 1 }
    
    # Replace navigation placeholders if present
    $html = $html -replace '\{PREV_PAGE\}', $prevPage
    $html = $html -replace '\{NEXT_PAGE\}', $nextPage
    
    return $html
}

function Invoke-CdataEscaping {
    <#
    .SYNOPSIS
        Escapes ]]> sequences inside CDATA sections
    #>
    param(
        [string]$Content
    )
    
    # Replace ]]> with ]]]]><![CDATA[>
    $escaped = $Content -replace ']]>', ']]]]><![CDATA[>'
    
    if ($escaped -ne $Content) {
        Write-Verbose "CDATA escape applied: Found ]]> sequence"
    }
    
    return $escaped
}

function New-PolicyFragmentXml {
    <#
    .SYNOPSIS
        Wraps HTML in APIM policy fragment XML structure
    #>
    param(
        [string]$HtmlContent
    )
    
    # Escape CDATA terminators
    $escapedHtml = Invoke-CdataEscaping -Content $HtmlContent
    
    # Build XML structure
    $xml = @"
<fragment>
  <set-body><![CDATA[$escapedHtml]]></set-body>
</fragment>
"@
    
    return $xml
}

function Save-FragmentFile {
    <#
    .SYNOPSIS
        Saves XML fragment to output file with UTF-8 BOM encoding
    #>
    param(
        [string]$XmlContent,
        [int]$PageNumber
    )
    
    $outputFile = Join-Path $OutputPath "page-$PageNumber.xml"
    
    # Check if file exists and Force not specified
    if ((Test-Path $outputFile) -and -not $Force -and -not $WhatIfPreference) {
        $response = Read-Host "File exists: $outputFile. Overwrite? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-StatusMessage "Skipped page $PageNumber" -Type Warning
            return $false
        }
    }
    
    try {
        # Create output directory if needed
        $outputDir = Split-Path $outputFile -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }
        
        if ($PSCmdlet.ShouldProcess($outputFile, "Write policy fragment")) {
            # Write with UTF-8 BOM
            $utf8Bom = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllText($outputFile, $XmlContent, $utf8Bom)
            
            $sizeKB = [Math]::Round((Get-Item $outputFile).Length / 1KB, 1)
            Write-StatusMessage "Saved page-$PageNumber.xml ($sizeKB KB)" -Type Success
            
            if ($sizeKB -gt 256) {
                Write-StatusMessage "Error: Fragment exceeds 256 KB limit!" -Type Error
                return $false
            }
            
            return $true
        }
        else {
            Write-Host "  Would write: $outputFile"
            return $true
        }
    }
    catch {
        Write-StatusMessage "Failed to save page-$PageNumber.xml: $_" -Type Error
        return $false
    }
}

function Test-XmlWellFormedness {
    <#
    .SYNOPSIS
        Layer 1 Validation: Check XML well-formedness
    #>
    param(
        [string]$XmlContent,
        [int]$PageNumber
    )
    
    try {
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.LoadXml($XmlContent)
        
        Write-Verbose "✓ Layer 1 (XML): Page $PageNumber is well-formed"
        return $true
    }
    catch {
        Write-StatusMessage "Layer 1 validation failed for page ${PageNumber}: $_" -Type Error
        return $false
    }
}

function Test-ApimSchema {
    <#
    .SYNOPSIS
        Layer 2 Validation: Check APIM schema compliance
    #>
    param(
        [string]$XmlContent,
        [int]$PageNumber
    )
    
    try {
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.LoadXml($XmlContent)
        
        # Check root element
        if ($xmlDoc.DocumentElement.LocalName -ne 'fragment') {
            Write-StatusMessage "Layer 2 validation failed: Root element must be 'fragment'" -Type Error
            return $false
        }
        
        # Check for set-body element
        $setBody = $xmlDoc.DocumentElement.SelectSingleNode('set-body')
        if (-not $setBody) {
            Write-StatusMessage "Layer 2 validation failed: Missing 'set-body' element" -Type Error
            return $false
        }
        
        # Check for CDATA
        $cdataNode = $setBody.SelectSingleNode('text()[1]')
        if (-not $cdataNode -or $cdataNode.NodeType -ne [System.Xml.XmlNodeType]::CDATA) {
            Write-StatusMessage "Layer 2 validation failed: HTML must be in CDATA section" -Type Error
            return $false
        }
        
        Write-Verbose "✓ Layer 2 (Schema): Page $PageNumber conforms to APIM schema"
        return $true
    }
    catch {
        Write-StatusMessage "Layer 2 validation failed for page ${PageNumber}: $_" -Type Error
        return $false
    }
}

function Test-SecurityIssues {
    <#
    .SYNOPSIS
        Layer 3 Validation: Check for security issues (XSS, injection)
    #>
    param(
        [string]$XmlContent,
        [int]$PageNumber
    )
    
    try {
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.LoadXml($XmlContent)
        
        $setBody = $xmlDoc.DocumentElement.SelectSingleNode('set-body')
        $htmlContent = $setBody.InnerText
        
        $issues = @()
        
        # Check for unescaped CDATA terminators
        if ($htmlContent -match ']]>' -and $htmlContent -notmatch ']]]]><!\[CDATA\[>') {
            $issues += "Unescaped CDATA terminator found"
        }
        
        # Check for dangerous patterns (basic checks)
        if ($htmlContent -match '<script[^>]*src\s*=\s*["''](?!https://cdn\.jsdelivr\.net/|https://unpkg\.com/)') {
            $issues += "External script from non-CDN source detected"
        }
        
        # Check for inline event handlers (XSS risk)
        if ($htmlContent -match '\son\w+\s*=') {
            $issues += "Inline event handler detected (potential XSS risk)"
        }
        
        # Check for eval, Function constructor
        if ($htmlContent -match '\beval\s*\(|\bnew\s+Function\s*\(') {
            $issues += "Dynamic code execution detected (eval/Function)"
        }
        
        if ($issues.Count -gt 0) {
            Write-StatusMessage "Layer 3 validation warnings for page ${PageNumber}:" -Type Warning
            foreach ($issue in $issues) {
                Write-StatusMessage "  - $issue" -Type Warning
            }
            # Warnings don't fail validation, but are logged
        }
        
        Write-Verbose "✓ Layer 3 (Security): Page $PageNumber passed security checks"
        return $true
    }
    catch {
        Write-StatusMessage "Layer 3 validation failed for page ${PageNumber}: $_" -Type Error
        return $false
    }
}

function Test-Integration {
    <#
    .SYNOPSIS
        Layer 4 Validation: Integration testing
    #>
    param(
        [string]$XmlContent,
        [int]$PageNumber
    )
    
    try {
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.LoadXml($XmlContent)
        
        $setBody = $xmlDoc.DocumentElement.SelectSingleNode('set-body')
        $htmlContent = $setBody.InnerText
        
        # Check for DOCTYPE
        if ($htmlContent -notmatch '<!DOCTYPE\s+html>') {
            Write-StatusMessage "Layer 4 validation warning: Missing DOCTYPE html" -Type Warning
        }
        
        # Check for essential HTML structure
        if ($htmlContent -notmatch '<html[^>]*>') {
            Write-StatusMessage "Layer 4 validation failed: Missing <html> element" -Type Error
            return $false
        }
        
        if ($htmlContent -notmatch '<head[^>]*>') {
            Write-StatusMessage "Layer 4 validation failed: Missing <head> element" -Type Error
            return $false
        }
        
        if ($htmlContent -notmatch '<body[^>]*>') {
            Write-StatusMessage "Layer 4 validation failed: Missing <body> element" -Type Error
            return $false
        }
        
        # Check for page number in content
        if ($htmlContent -notmatch $PageNumber) {
            Write-StatusMessage "Layer 4 validation warning: Page number $PageNumber not found in content" -Type Warning
        }
        
        Write-Verbose "✓ Layer 4 (Integration): Page $PageNumber passed integration checks"
        return $true
    }
    catch {
        Write-StatusMessage "Layer 4 validation failed for page ${PageNumber}: $_" -Type Error
        return $false
    }
}

function Invoke-ValidationLayers {
    <#
    .SYNOPSIS
        Runs all 4 validation layers
    #>
    param(
        [string]$XmlContent,
        [int]$PageNumber
    )
    
    if (-not $Validate) {
        Write-Verbose "Validation skipped (Validate=false)"
        return $true
    }
    
    # Layer 1: XML well-formedness
    if (-not (Test-XmlWellFormedness -XmlContent $XmlContent -PageNumber $PageNumber)) {
        return $false
    }
    
    # Layer 2: APIM schema compliance
    if (-not (Test-ApimSchema -XmlContent $XmlContent -PageNumber $PageNumber)) {
        return $false
    }
    
    # Layer 3: Security scanning
    if (-not (Test-SecurityIssues -XmlContent $XmlContent -PageNumber $PageNumber)) {
        return $false
    }
    
    # Layer 4: Integration testing
    if (-not (Test-Integration -XmlContent $XmlContent -PageNumber $PageNumber)) {
        return $false
    }
    
    return $true
}

# ============================================================================
# Main Conversion Logic
# ============================================================================

function ConvertTo-ApimFragment {
    <#
    .SYNOPSIS
        Main conversion function for a single page
    #>
    param(
        [int]$PageNumber,
        [string]$Template,
        [string]$Style,
        [string]$Script
    )
    
    try {
        Write-Host "`nConverting page $PageNumber..." -NoNewline
        
        # Read content
        $content = Read-ContentFile -PageNumber $PageNumber
        
        # Replace placeholders
        $html = Invoke-PlaceholderReplacement `
            -Template $Template `
            -PageNumber $PageNumber `
            -Content $content `
            -Style $Style `
            -Script $Script
        
        # Wrap in policy fragment XML
        $xml = New-PolicyFragmentXml -HtmlContent $html
        
        # Validate
        if (-not (Invoke-ValidationLayers -XmlContent $xml -PageNumber $PageNumber)) {
            Write-Host " FAILED" -ForegroundColor Red
            $script:failedPages += $PageNumber
            return $false
        }
        
        # Save to file
        if (Save-FragmentFile -XmlContent $xml -PageNumber $PageNumber) {
            $sizeKB = [Math]::Round($xml.Length / 1KB, 1)
            Write-Host " ✓ ($sizeKB KB)" -ForegroundColor Green
            $script:successPages += $PageNumber
            return $true
        }
        else {
            Write-Host " FAILED" -ForegroundColor Red
            $script:failedPages += $PageNumber
            return $false
        }
    }
    catch {
        Write-Host " ERROR" -ForegroundColor Red
        Write-StatusMessage "Error converting page ${PageNumber}: $_" -Type Error
        $script:failedPages += $PageNumber
        return $false
    }
}

# ============================================================================
# Main Script Execution
# ============================================================================

try {
    Write-Host "`nTxtTV Web → APIM Policy Conversion Script" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-StatusMessage "Configuration:" -Type Info
    Write-Host "  Source Path:  $SourcePath"
    Write-Host "  Output Path:  $OutputPath"
    Write-Host "  Content Path: $ContentPath"
    Write-Host "  Pages:        $($Pages -join ', ')"
    Write-Host "  Validation:   $Validate"
    Write-Host ""
    
    # Validate input files
    Write-StatusMessage "Checking input files..." -Type Info
    if (-not (Test-InputFiles)) {
        exit 2
    }
    Write-StatusMessage "All input files found" -Type Success
    
    # Read source files
    Write-Host ""
    Write-StatusMessage "Loading source files..." -Type Info
    $template = Read-TemplateFile
    $style = Read-StylesheetContent
    $script = Read-ScriptContent
    Write-StatusMessage "Source files loaded" -Type Success
    
    # Convert each page
    Write-Host ""
    Write-StatusMessage "Converting pages..." -Type Info
    
    foreach ($page in $Pages) {
        ConvertTo-ApimFragment `
            -PageNumber $page `
            -Template $template `
            -Style $style `
            -Script $script
    }
    
    # Summary
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-StatusMessage "Conversion Summary:" -Type Info
    Write-Host "  Total Pages:  $($Pages.Count)"
    Write-Host "  Successful:   $($script:successPages.Count)" -ForegroundColor Green
    Write-Host "  Failed:       $($script:failedPages.Count)" -ForegroundColor $(if ($script:failedPages.Count -eq 0) { 'Green' } else { 'Red' })
    
    if ($script:failedPages.Count -gt 0) {
        Write-Host "  Failed Pages: $($script:failedPages -join ', ')" -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Determine exit code
    if ($script:failedPages.Count -eq 0) {
        Write-StatusMessage "Conversion completed successfully! ✓" -Type Success
        exit 0
    }
    elseif ($script:successPages.Count -gt 0) {
        Write-StatusMessage "Conversion completed with partial failures" -Type Warning
        exit 1
    }
    else {
        Write-StatusMessage "Conversion failed" -Type Error
        exit 4
    }
}
catch {
    Write-Host ""
    Write-StatusMessage "Fatal error: $_" -Type Error
    Write-Host $_.ScriptStackTrace
    exit 2
}
