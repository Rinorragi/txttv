<#
.SYNOPSIS
    Converts JSON content files to APIM policy fragments.

.DESCRIPTION
    Reads structured JSON content files from content/pages/ and generates
    minimal APIM policy fragments that return the JSON payload wrapped in
    CDATA. The JSON inside each fragment is byte-identical to the source file.

    Performs schema validation before generation:
    - Required fields: pageNumber, title, category, content, navigation
    - Type checks per contracts/json-schema.md
    - pageNumber must match filename
    - Fragment size must be < 256 KB

.PARAMETER SourceDir
    Source directory containing page-*.json files. Default: content/pages

.PARAMETER OutputDir
    Output directory for generated content fragments. Default: infrastructure/modules/apim/fragments

.PARAMETER SingleFile
    Path to a single JSON file to convert (instead of entire directory)

.EXAMPLE
    .\convert-json-to-fragment.ps1
    # Convert all JSON content files

.EXAMPLE
    .\convert-json-to-fragment.ps1 -SingleFile "content/pages/page-100.json"
    # Convert a single file

.NOTES
    Feature: 005-json-content-api
    Constitution: v1.2.2 compliant
    FR Coverage: FR-003, FR-007, FR-008, FR-009, FR-013
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SourceDir = "content/pages",

    [Parameter()]
    [string]$OutputDir = "infrastructure/modules/apim/fragments",

    [Parameter()]
    [string]$SingleFile = ""
)

$ErrorActionPreference = 'Stop'

# Get repository root (2 levels up from scripts/)
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# Resolve paths relative to repo root
if (-not [System.IO.Path]::IsPathRooted($SourceDir)) {
    $SourceDir = Join-Path $repoRoot $SourceDir
}
if (-not [System.IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir = Join-Path $repoRoot $OutputDir
}
if ($SingleFile -and -not [System.IO.Path]::IsPathRooted($SingleFile)) {
    $SingleFile = Join-Path $repoRoot $SingleFile
}

# Valid category and severity values per json-schema.md
$ValidCategories = @("SECURITY ALERT", "ADVISORY", "NEWS", "VULNERABILITY", "INCIDENT", "GUIDE", "INDEX")
$ValidSeverities = @("CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO", $null)

# ============================================================================
# Validation Functions (Research Topic 5: Custom PowerShell validation)
# ============================================================================

function Test-ContentJson {
    <#
    .SYNOPSIS
        Validates a JSON content file against the TXT TV content schema
    #>
    param(
        [string]$FilePath
    )

    $errors = @()
    $fileName = Split-Path $FilePath -Leaf

    # Parse JSON
    try {
        $rawJson = Get-Content $FilePath -Raw -Encoding UTF8
        $json = $rawJson | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return @("Invalid JSON syntax: $_")
    }

    # Required fields
    $required = @('pageNumber', 'title', 'category', 'content', 'navigation')
    foreach ($field in $required) {
        if (-not $json.PSObject.Properties[$field]) {
            $errors += "Missing required field: $field"
        }
    }

    # If required fields are missing, return early
    if ($errors.Count -gt 0) { return $errors }

    # pageNumber validation
    if ($json.pageNumber -isnot [int] -and $json.pageNumber -isnot [long]) {
        $errors += "pageNumber must be an integer, got: $($json.pageNumber.GetType().Name)"
    }
    elseif ($json.pageNumber -lt 100 -or $json.pageNumber -gt 999) {
        $errors += "pageNumber must be 100-999, got: $($json.pageNumber)"
    }
    else {
        # Validate filename matches pageNumber
        $expectedFilename = "page-$($json.pageNumber).json"
        if ($fileName -ne $expectedFilename) {
            $errors += "pageNumber $($json.pageNumber) does not match filename '$fileName' (expected '$expectedFilename')"
        }
    }

    # title validation
    if ([string]::IsNullOrWhiteSpace($json.title)) {
        $errors += "title must be a non-empty string"
    }
    elseif ($json.title.Length -gt 80) {
        $errors += "title exceeds 80 character limit ($($json.title.Length) chars)"
    }

    # category validation
    if ($json.category -notin $ValidCategories) {
        $errors += "category must be one of: $($ValidCategories -join ', '). Got: '$($json.category)'"
    }

    # severity validation (optional, can be null)
    if ($json.PSObject.Properties['severity'] -and $null -ne $json.severity) {
        if ($json.severity -notin @("CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO")) {
            $errors += "severity must be CRITICAL, HIGH, MEDIUM, LOW, INFO, or null. Got: '$($json.severity)'"
        }
    }

    # content validation
    if ([string]::IsNullOrWhiteSpace($json.content)) {
        $errors += "content must be a non-empty string"
    }
    elseif ($json.content.Length -gt 2000) {
        $errors += "content exceeds 2000 character limit ($($json.content.Length) chars)"
    }

    # metadata validation (optional)
    if ($json.PSObject.Properties['metadata'] -and $null -ne $json.metadata) {
        if ($json.metadata.PSObject.Properties['cvss'] -and $null -ne $json.metadata.cvss) {
            if ($json.metadata.cvss -lt 0 -or $json.metadata.cvss -gt 10) {
                $errors += "metadata.cvss must be 0.0-10.0, got: $($json.metadata.cvss)"
            }
        }
        if ($json.metadata.PSObject.Properties['published'] -and $null -ne $json.metadata.published) {
            try {
                [datetime]::Parse($json.metadata.published) | Out-Null
            }
            catch {
                $errors += "metadata.published must be valid ISO 8601 date, got: '$($json.metadata.published)'"
            }
        }
    }

    # navigation validation
    if (-not $json.navigation.PSObject.Properties['prev']) {
        $errors += "navigation.prev is required (use null for first page)"
    }
    if (-not $json.navigation.PSObject.Properties['next']) {
        $errors += "navigation.next is required (use null for last page)"
    }
    if (-not $json.navigation.PSObject.Properties['related']) {
        $errors += "navigation.related is required (use empty array [])"
    }

    # navigation.prev/next range check
    if ($null -ne $json.navigation.prev) {
        if ($json.navigation.prev -lt 100 -or $json.navigation.prev -gt 999) {
            $errors += "navigation.prev must be 100-999 or null, got: $($json.navigation.prev)"
        }
    }
    if ($null -ne $json.navigation.next) {
        if ($json.navigation.next -lt 100 -or $json.navigation.next -gt 999) {
            $errors += "navigation.next must be 100-999 or null, got: $($json.navigation.next)"
        }
    }

    # navigation.related validation
    if ($json.navigation.related -is [array]) {
        if ($json.navigation.related.Count -gt 10) {
            $errors += "navigation.related exceeds 10 item limit ($($json.navigation.related.Count) items)"
        }
        foreach ($rel in $json.navigation.related) {
            if ($rel -lt 100 -or $rel -gt 999) {
                $errors += "navigation.related contains invalid page number: $rel"
            }
        }
    }

    return $errors
}

# ============================================================================
# Fragment Generation (Research Topic 1: CDATA-wrapped JSON)
# ============================================================================

function ConvertTo-ContentFragment {
    <#
    .SYNOPSIS
        Converts a validated JSON file to an APIM content fragment
    #>
    param(
        [string]$FilePath
    )

    # Read raw JSON content (byte-identical requirement FR-003)
    $rawJson = Get-Content $FilePath -Raw -Encoding UTF8

    # Remove trailing newline/whitespace for clean CDATA wrapping
    $rawJson = $rawJson.TrimEnd()

    # Build minimal XML fragment (Research Topic 1 pattern)
    $fragmentXml = @"
<fragment>
    <return-response>
        <set-status code="200" reason="OK" />
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>
        <set-header name="Cache-Control" exists-action="override">
            <value>public, max-age=3600</value>
        </set-header>
        <set-body><![CDATA[$rawJson]]></set-body>
    </return-response>
</fragment>
"@

    return $fragmentXml
}

function Test-FragmentXml {
    <#
    .SYNOPSIS
        Validates generated XML fragment for well-formedness (FR-009)
    #>
    param(
        [string]$XmlContent,
        [int]$PageNumber
    )

    $errors = @()

    # XML well-formedness check
    try {
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.LoadXml($XmlContent)
    }
    catch {
        $errors += "XML is not well-formed: $_"
        return $errors
    }

    # Check root element
    if ($xmlDoc.DocumentElement.LocalName -ne 'fragment') {
        $errors += "Root element must be 'fragment', got: '$($xmlDoc.DocumentElement.LocalName)'"
    }

    # Check for return-response
    $returnResponse = $xmlDoc.DocumentElement.SelectSingleNode('return-response')
    if (-not $returnResponse) {
        $errors += "Missing 'return-response' element"
    }

    # Check for set-body with CDATA
    $setBody = $returnResponse.SelectSingleNode('set-body')
    if (-not $setBody) {
        $errors += "Missing 'set-body' element"
    }
    else {
        # Verify CDATA contains valid JSON
        $cdataText = $setBody.InnerText
        try {
            $cdataText | ConvertFrom-Json -ErrorAction Stop | Out-Null
        }
        catch {
            $errors += "JSON inside CDATA is invalid: $_"
        }
    }

    # Fragment size check (< 256 KB)
    $sizeBytes = [System.Text.Encoding]::UTF8.GetByteCount($XmlContent)
    if ($sizeBytes -gt 262144) {
        $sizeKB = [Math]::Round($sizeBytes / 1KB, 1)
        $errors += "Fragment exceeds 256 KB limit ($sizeKB KB)"
    }

    return $errors
}

# ============================================================================
# Main Execution
# ============================================================================

Write-Host "`nTxtTV JSON → Content Fragment Conversion" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Determine files to process
if ($SingleFile) {
    if (-not (Test-Path $SingleFile)) {
        Write-Error "File not found: $SingleFile"
        exit 2
    }
    $jsonFiles = @(Get-Item $SingleFile)
}
else {
    $jsonFiles = @(Get-ChildItem "$SourceDir/page-*.json" -ErrorAction SilentlyContinue)
    if ($jsonFiles.Count -eq 0) {
        Write-Error "No page-*.json files found in $SourceDir"
        exit 2
    }
}

Write-Host "  Source: $SourceDir"
Write-Host "  Output: $OutputDir"
Write-Host "  Files:  $($jsonFiles.Count)`n"

$successCount = 0
$errorCount = 0

foreach ($file in $jsonFiles) {
    $pageNumber = [int]($file.BaseName -replace 'page-', '')
    Write-Host "Processing page $pageNumber..." -NoNewline

    # Step 1: Schema validation (FR-008)
    $validationErrors = Test-ContentJson -FilePath $file.FullName
    if ($validationErrors.Count -gt 0) {
        Write-Host " VALIDATION FAILED" -ForegroundColor Red
        foreach ($err in $validationErrors) {
            Write-Host "    ✗ $err" -ForegroundColor Red
        }
        $errorCount++
        continue
    }

    # Step 2: Generate fragment
    $fragmentXml = ConvertTo-ContentFragment -FilePath $file.FullName

    # Step 3: Validate generated XML (FR-009)
    $xmlErrors = Test-FragmentXml -XmlContent $fragmentXml -PageNumber $pageNumber
    if ($xmlErrors.Count -gt 0) {
        Write-Host " XML VALIDATION FAILED" -ForegroundColor Red
        foreach ($err in $xmlErrors) {
            Write-Host "    ✗ $err" -ForegroundColor Red
        }
        $errorCount++
        continue
    }

    # Step 4: Write output file
    $outputFile = Join-Path $OutputDir "content-$pageNumber.xml"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($outputFile, $fragmentXml, $utf8NoBom)

    $sizeKB = [Math]::Round($fragmentXml.Length / 1KB, 1)
    Write-Host " ✓ content-$pageNumber.xml ($sizeKB KB)" -ForegroundColor Green
    $successCount++
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Conversion complete: $successCount succeeded, $errorCount failed" -ForegroundColor $(if ($errorCount -eq 0) { 'Green' } else { 'Yellow' })

if ($errorCount -gt 0) {
    exit 1
}
exit 0
