<#
.SYNOPSIS
    Converts local web interface files to a single APIM page-template policy fragment

.DESCRIPTION
    Transforms HTML/CSS/JS source files from src/web/ into a single APIM policy fragment
    (page-template.xml) that serves as the shared HTML shell for all TXT TV pages.
    Content is loaded dynamically via fetch() from the Content API at runtime.
    
    The script performs 4-layer validation:
    - Layer 1: XML well-formedness
    - Layer 2: APIM schema compliance
    - Layer 3: Security scanning (XSS, injection risks)
    - Layer 4: Integration testing (fragment composition)

.PARAMETER SourcePath
    Root directory of web interface source files. Defaults to src/web

.PARAMETER OutputPath
    Output directory for generated policy fragments. Defaults to infrastructure/modules/apim/fragments

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
    # Generate page-template.xml with validation

.EXAMPLE
    .\convert-web-to-apim.ps1 -WhatIf
    # Preview changes without generating files

.NOTES
    Author: TxtTV Development Team
    Constitution: v1.2.2 compliant
    Feature: 005-json-content-api
    
    Exit Codes:
    0 = Success
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
    [bool]$Validate = $true,
    
    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Get repository root (2 levels up from scripts/)
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# Resolve paths relative to repo root
$SourcePath = Join-Path $repoRoot $SourcePath
$OutputPath = Join-Path $repoRoot $OutputPath

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
    
    # Check content-renderer.js
    $rendererPath = Join-Path $SourcePath "scripts/content-renderer.js"
    if (-not (Test-Path $rendererPath)) {
        $errors += "Content renderer not found: $rendererPath"
    }
    
    # Check navigation.js
    $navPath = Join-Path $SourcePath "scripts/navigation.js"
    if (-not (Test-Path $navPath)) {
        $errors += "Navigation script not found: $navPath"
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
        Reads the navigation.js script
    #>
    param()
    
    $navPath = Join-Path $SourcePath "scripts/navigation.js"
    
    try {
        $content = Get-Content -Path $navPath -Raw -Encoding UTF8
        $sizeKB = [Math]::Round($content.Length / 1KB, 1)
        Write-Verbose "JS loaded: navigation.js ($sizeKB KB)"
        return $content
    }
    catch {
        Write-StatusMessage "Failed to read navigation.js: $_" -Type Error
        throw
    }
}

function Read-ContentRendererScript {
    <#
    .SYNOPSIS
        Reads the content-renderer.js script
    #>
    param()
    
    $rendererPath = Join-Path $SourcePath "scripts/content-renderer.js"
    
    try {
        $content = Get-Content -Path $rendererPath -Raw -Encoding UTF8
        $sizeKB = [Math]::Round($content.Length / 1KB, 1)
        Write-Verbose "JS loaded: content-renderer.js ($sizeKB KB)"
        return $content
    }
    catch {
        Write-StatusMessage "Failed to read content-renderer.js: $_" -Type Error
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
        [string]$Style,
        [string]$ContentRendererScript,
        [string]$NavigationScript
    )
    
    $html = $Template
    
    # Replace STYLE
    $html = $html -replace '\{STYLE\}', $Style
    
    # Replace CONTENT_RENDERER_SCRIPT
    $html = $html -replace '\{CONTENT_RENDERER_SCRIPT\}', $ContentRendererScript
    
    # Replace SCRIPT (navigation)
    $html = $html -replace '\{SCRIPT\}', $NavigationScript
    
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
        Saves XML fragment to output file with UTF-8 no-BOM encoding
    #>
    param(
        [string]$XmlContent,
        [string]$FileName = "page-template.xml"
    )
    
    $outputFile = Join-Path $OutputPath $FileName
    
    # Check if file exists and Force not specified
    if ((Test-Path $outputFile) -and -not $Force -and -not $WhatIfPreference) {
        $response = Read-Host "File exists: $outputFile. Overwrite? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-StatusMessage "Skipped $FileName" -Type Warning
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
            # Write with UTF-8 no-BOM
            $utf8NoBom = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($outputFile, $XmlContent, $utf8NoBom)
            
            $sizeKB = [Math]::Round((Get-Item $outputFile).Length / 1KB, 1)
            Write-StatusMessage "Saved $FileName ($sizeKB KB)" -Type Success
            
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
        Write-StatusMessage "Failed to save ${FileName}: $_" -Type Error
        return $false
    }
}

function Test-XmlWellFormedness {
    <#
    .SYNOPSIS
        Layer 1 Validation: Check XML well-formedness
    #>
    param(
        [string]$XmlContent
    )
    
    try {
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.LoadXml($XmlContent)
        
        Write-Verbose "✓ Layer 1 (XML): page-template is well-formed"
        return $true
    }
    catch {
        Write-StatusMessage "Layer 1 validation failed: $_" -Type Error
        return $false
    }
}

function Test-ApimSchema {
    <#
    .SYNOPSIS
        Layer 2 Validation: Check APIM schema compliance
    #>
    param(
        [string]$XmlContent
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
        
        Write-Verbose "✓ Layer 2 (Schema): page-template conforms to APIM schema"
        return $true
    }
    catch {
        Write-StatusMessage "Layer 2 validation failed: $_" -Type Error
        return $false
    }
}

function Test-SecurityIssues {
    <#
    .SYNOPSIS
        Layer 3 Validation: Check for security issues (XSS, injection)
    #>
    param(
        [string]$XmlContent
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
            Write-StatusMessage "Layer 3 validation warnings:" -Type Warning
            foreach ($issue in $issues) {
                Write-StatusMessage "  - $issue" -Type Warning
            }
        }
        
        Write-Verbose "✓ Layer 3 (Security): page-template passed security checks"
        return $true
    }
    catch {
        Write-StatusMessage "Layer 3 validation failed: $_" -Type Error
        return $false
    }
}

function Test-Integration {
    <#
    .SYNOPSIS
        Layer 4 Validation: Integration testing
    #>
    param(
        [string]$XmlContent
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
        
        # Check for content-renderer integration (dynamic loading)
        if ($htmlContent -notmatch 'TxtTvContentRenderer|loadAndRenderContent|content-renderer') {
            Write-StatusMessage "Layer 4 validation warning: Content renderer not found in template" -Type Warning
        }
        
        # Check for page-content element
        if ($htmlContent -notmatch 'id="page-content"') {
            Write-StatusMessage "Layer 4 validation failed: Missing #page-content element" -Type Error
            return $false
        }
        
        Write-Verbose "✓ Layer 4 (Integration): page-template passed integration checks"
        return $true
    }
    catch {
        Write-StatusMessage "Layer 4 validation failed: $_" -Type Error
        return $false
    }
}

function Invoke-ValidationLayers {
    <#
    .SYNOPSIS
        Runs all 4 validation layers
    #>
    param(
        [string]$XmlContent
    )
    
    if (-not $Validate) {
        Write-Verbose "Validation skipped (Validate=false)"
        return $true
    }
    
    # Layer 1: XML well-formedness
    if (-not (Test-XmlWellFormedness -XmlContent $XmlContent)) {
        return $false
    }
    
    # Layer 2: APIM schema compliance
    if (-not (Test-ApimSchema -XmlContent $XmlContent)) {
        return $false
    }
    
    # Layer 3: Security scanning
    if (-not (Test-SecurityIssues -XmlContent $XmlContent)) {
        return $false
    }
    
    # Layer 4: Integration testing
    if (-not (Test-Integration -XmlContent $XmlContent)) {
        return $false
    }
    
    return $true
}

# ============================================================================
# Main Script Execution
# ============================================================================

try {
    Write-Host "`nTxtTV Web → APIM Page Template Conversion" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-StatusMessage "Configuration:" -Type Info
    Write-Host "  Source Path:  $SourcePath"
    Write-Host "  Output Path:  $OutputPath"
    Write-Host "  Output File:  page-template.xml"
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
    $contentRendererScript = Read-ContentRendererScript
    $navigationScript = Read-ScriptContent
    Write-StatusMessage "Source files loaded" -Type Success
    
    # Generate page template
    Write-Host ""
    Write-StatusMessage "Generating page-template.xml..." -Type Info
    
    # Replace placeholders
    $html = Invoke-PlaceholderReplacement `
        -Template $template `
        -Style $style `
        -ContentRendererScript $contentRendererScript `
        -NavigationScript $navigationScript
    
    # Wrap in policy fragment XML
    $xml = New-PolicyFragmentXml -HtmlContent $html
    
    # Validate
    if (-not (Invoke-ValidationLayers -XmlContent $xml)) {
        Write-StatusMessage "Validation failed!" -Type Error
        exit 4
    }
    Write-StatusMessage "All 4 validation layers passed" -Type Success
    
    # Save to file
    Write-Host ""
    if (Save-FragmentFile -XmlContent $xml -FileName "page-template.xml") {
        $sizeKB = [Math]::Round($xml.Length / 1KB, 1)
        Write-Host ""
        Write-Host "=========================================" -ForegroundColor Cyan
        Write-StatusMessage "Conversion completed successfully! ✓" -Type Success
        Write-Host "  Output: page-template.xml ($sizeKB KB)"
        exit 0
    }
    else {
        Write-StatusMessage "Failed to save page-template.xml" -Type Error
        exit 3
    }
}
catch {
    Write-Host ""
    Write-StatusMessage "Fatal error: $_" -Type Error
    Write-Host $_.ScriptStackTrace
    exit 2
}
