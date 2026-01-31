<#
.SYNOPSIS
    Converts text files in content/pages to APIM policy fragments.

.DESCRIPTION
    Reads text files from the source directory and generates XML policy fragments
    with embedded HTML for the TXT TV application. Includes character limit validation
    and special character escaping.

.PARAMETER SourceDir
    Source directory containing page-*.txt files. Default: content/pages

.PARAMETER OutputDir
    Output directory for generated policy fragments. Default: infrastructure/modules/apim/fragments

.PARAMETER MaxCharacters
    Maximum allowed characters per page content. Default: 2000

.EXAMPLE
    .\convert-txt-to-fragment.ps1
    .\convert-txt-to-fragment.ps1 -SourceDir "content/pages" -OutputDir "infrastructure/modules/apim/fragments"
#>

param(
    [string]$SourceDir = "content/pages",
    [string]$OutputDir = "infrastructure/modules/apim/fragments",
    [int]$MaxCharacters = 2000
)

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Teletext CSS styling
$teletextCss = @"
body {
    background-color: #000;
    color: #0f0;
    font-family: 'Courier New', Courier, monospace;
    font-size: 16px;
    line-height: 1.4;
    margin: 0;
    padding: 20px;
    min-height: 100vh;
}
.header {
    background-color: #00f;
    color: #fff;
    padding: 10px;
    text-align: center;
    margin-bottom: 20px;
}
.page-number {
    color: #ff0;
    font-weight: bold;
}
.content {
    white-space: pre-wrap;
    word-wrap: break-word;
    margin-bottom: 20px;
}
nav {
    display: flex;
    gap: 10px;
    align-items: center;
    padding: 10px;
    background-color: #333;
    flex-wrap: wrap;
}
button {
    background-color: #00f;
    color: #fff;
    border: 2px solid #0ff;
    padding: 10px 20px;
    cursor: pointer;
    font-family: 'Courier New', Courier, monospace;
    font-size: 14px;
}
button:hover:not(:disabled) {
    background-color: #0ff;
    color: #000;
}
button:disabled {
    background-color: #555;
    color: #888;
    cursor: not-allowed;
    border-color: #666;
}
input[type="number"] {
    background-color: #000;
    color: #0f0;
    border: 2px solid #0ff;
    padding: 10px;
    font-family: 'Courier New', Courier, monospace;
    font-size: 14px;
    width: 80px;
}
.htmx-request {
    opacity: 0.5;
}
"@

$successCount = 0
$errorCount = 0

Get-ChildItem "$SourceDir/page-*.txt" -ErrorAction SilentlyContinue | ForEach-Object {
    $pageNumber = $_.BaseName -replace 'page-', ''
    
    try {
        $content = Get-Content $_.FullName -Raw -Encoding UTF8
        
        # Validate character limit per FR-013 and data model constraint
        if ($content.Length -gt $MaxCharacters) {
            Write-Error "Page $pageNumber exceeds $MaxCharacters character limit ($($content.Length) chars)"
            $script:errorCount++
            return
        }
        
        # Escape XML-unsafe characters for CDATA content
        $escapedContent = $content -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
        
        # Calculate navigation page numbers
        $prevPage = [int]$pageNumber - 1
        $nextPage = [int]$pageNumber + 1
        $disablePrev = if ([int]$pageNumber -le 100) { 'disabled' } else { '' }
        
        $fragmentXml = @"
<fragment>
    <set-body><![CDATA[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TXT TV - Page $pageNumber</title>
    <style>
$teletextCss
    </style>
</head>
<body>
    <div class="header">
        <span class="page-number">PAGE $pageNumber</span> - TXT TV
    </div>
    <div id="content">
        <pre class="content">$escapedContent</pre>
    </div>
    <nav>
        <button hx-get="/page/$prevPage" hx-target="body" hx-push-url="true" $disablePrev>&#9664; Previous</button>
        <input type="number" id="pageNum" value="$pageNumber" min="100" max="999" />
        <button hx-get="/page/{pageNum}" hx-include="#pageNum" hx-target="body" hx-push-url="true" 
                onclick="this.setAttribute('hx-get', '/page/' + document.getElementById('pageNum').value); htmx.process(this);">
            Go to Page
        </button>
        <button hx-get="/page/$nextPage" hx-target="body" hx-push-url="true">Next &#9654;</button>
    </nav>
    <script src="https://unpkg.com/htmx.org@1.9.10"></script>
</body>
</html>]]></set-body>
</fragment>
"@
        
        $outputPath = Join-Path $OutputDir "page-$pageNumber.xml"
        $fragmentXml | Out-File $outputPath -Encoding utf8
        
        Write-Host "Generated: page-$pageNumber.xml ($($content.Length) chars)" -ForegroundColor Green
        $script:successCount++
    }
    catch {
        Write-Error "Failed to process page $pageNumber`: $_"
        $script:errorCount++
    }
}

Write-Host ""
Write-Host "Conversion complete: $successCount succeeded, $errorCount failed" -ForegroundColor Cyan
