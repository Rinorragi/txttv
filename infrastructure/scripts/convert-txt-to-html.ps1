<#
.SYNOPSIS
    Converts content/pages/*.txt files to local HTML preview pages.

.DESCRIPTION
    Generates standalone HTML files from txt content files with teletext-style
    formatting for local development preview. Each HTML file includes navigation
    and can be opened directly in a browser.

.PARAMETER SourceDir
    Source directory containing page-*.txt files. Default: content/pages

.PARAMETER OutputDir
    Output directory for generated HTML preview files. Default: preview/pages

.PARAMETER CreateIndex
    Create an index.html page with links to all pages. Default: $true

.EXAMPLE
    .\convert-txt-to-html.ps1
    .\convert-txt-to-html.ps1 -SourceDir "content/pages" -OutputDir "preview/pages"
    .\convert-txt-to-html.ps1 -CreateIndex $false
#>

param(
    [string]$SourceDir = "content/pages",
    [string]$OutputDir = "preview/pages",
    [switch]$CreateIndex = $true
)

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "Created output directory: $OutputDir" -ForegroundColor Cyan
}

# Teletext CSS styling (inline for standalone HTML files)
$teletextCss = @"
/* TxtTV Retro Stylesheet - Preview Version */
body {
    margin: 0;
    padding: 20px;
    background-color: #000;
    color: #0f0;
    font-family: 'Courier New', 'Lucida Console', monospace;
    font-size: 16px;
    line-height: 1.4;
    min-height: 100vh;
}

.txttv-page {
    max-width: 800px;
    margin: 0 auto;
}

pre {
    margin: 0;
    white-space: pre-wrap;
    word-wrap: break-word;
    color: #0f0;
}

#page-content {
    margin-bottom: 20px;
}

.nav-links {
    margin-top: 20px;
    padding: 15px 0;
    border-top: 2px solid #0f0;
    border-bottom: 2px solid #0f0;
    display: flex;
    gap: 20px;
    flex-wrap: wrap;
    justify-content: center;
}

.nav-links a {
    color: #0ff;
    text-decoration: none;
    font-weight: bold;
    padding: 8px 16px;
    border: 1px solid #0ff;
    transition: all 0.2s ease;
}

.nav-links a:hover {
    background-color: #0ff;
    color: #000;
}

.nav-links a.disabled {
    color: #555;
    border-color: #555;
    pointer-events: none;
    cursor: not-allowed;
}

.status-bar {
    margin-top: 20px;
    padding: 10px;
    background-color: #111;
    border: 1px solid #0f0;
    color: #ff0;
    text-align: center;
    font-size: 14px;
}

.keyboard-help {
    margin-top: 20px;
    padding: 15px;
    background-color: #001a00;
    border: 1px solid #0f0;
    color: #0f0;
}

.keyboard-help h3 {
    color: #0ff;
    margin: 0 0 10px 0;
    font-size: 1em;
}

.keyboard-help p {
    margin: 0;
    font-size: 14px;
}

kbd {
    background-color: #333;
    border: 1px solid #0ff;
    border-radius: 3px;
    padding: 2px 6px;
    font-family: 'Courier New', 'Lucida Console', monospace;
    color: #0ff;
}

/* Index Page Styles */
.page-selector {
    padding: 40px 20px;
    text-align: center;
}

.page-selector h1 {
    color: #0ff;
    margin-bottom: 30px;
    font-size: 2em;
    text-transform: uppercase;
}

.page-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
    gap: 15px;
    max-width: 800px;
    margin: 0 auto 30px;
}

.page-link {
    background-color: #111;
    border: 2px solid #0f0;
    color: #0ff;
    padding: 20px;
    text-decoration: none;
    display: block;
    font-size: 1.2em;
    font-weight: bold;
    transition: all 0.3s ease;
}

.page-link:hover {
    background-color: #0f0;
    color: #000;
    transform: scale(1.05);
}

.info-box {
    max-width: 600px;
    margin: 20px auto;
    padding: 15px;
    background-color: #001a00;
    border: 1px solid #0f0;
    text-align: left;
}

.info-box h2 {
    color: #ff0;
    margin: 0 0 10px 0;
    font-size: 1em;
}
"@

$successCount = 0
$errorCount = 0
$pageNumbers = @()

# Get all page files
$pageFiles = Get-ChildItem "$SourceDir/page-*.txt" -ErrorAction SilentlyContinue | Sort-Object Name

if ($pageFiles.Count -eq 0) {
    Write-Warning "No page-*.txt files found in $SourceDir"
    exit 1
}

# Determine page range
$minPage = ($pageFiles | ForEach-Object { [int]($_.BaseName -replace 'page-', '') } | Measure-Object -Minimum).Minimum
$maxPage = ($pageFiles | ForEach-Object { [int]($_.BaseName -replace 'page-', '') } | Measure-Object -Maximum).Maximum

Write-Host "`nConverting pages $minPage-$maxPage..." -ForegroundColor Cyan

# Process each page file
$pageFiles | ForEach-Object {
    $pageNumber = [int]($_.BaseName -replace 'page-', '')
    $pageNumbers += $pageNumber
    
    try {
        $content = Get-Content $_.FullName -Raw -Encoding UTF8
        
        # HTML escape the content
        $escapedContent = $content -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
        
        # Calculate navigation
        $prevPage = $pageNumber - 1
        $nextPage = $pageNumber + 1
        $prevDisabled = if ($pageNumber -le $minPage) { ' class="disabled"' } else { '' }
        $nextDisabled = if ($pageNumber -ge $maxPage) { ' class="disabled"' } else { '' }
        $prevLink = if ($pageNumber -le $minPage) { '#' } else { "page-$prevPage.html" }
        $nextLink = if ($pageNumber -ge $maxPage) { '#' } else { "page-$nextPage.html" }
        
        # Generate HTML
        $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="TXT TV - Page $pageNumber Preview">
  <title>TXT TV - Page $pageNumber</title>
  <style>
$teletextCss
  </style>
</head>
<body>
  <div class="txttv-page">
    <!-- Page Content -->
    <pre id="page-content">$escapedContent</pre>
    
    <!-- Navigation Links -->
    <div class="nav-links">
      <a href="$prevLink"$prevDisabled title="Previous page (← or P)">← Previous ($prevPage)</a>
      <a href="index.html" title="Home/Index (H)">📺 Index</a>
      <a href="$nextLink"$nextDisabled title="Next page (→ or N)">Next ($nextPage) →</a>
    </div>
    
    <!-- Keyboard Shortcuts Help -->
    <div class="keyboard-help">
      <h3>Keyboard Shortcuts</h3>
      <p>
        <kbd>←</kbd> or <kbd>P</kbd> Previous page &nbsp;|&nbsp;
        <kbd>→</kbd> or <kbd>N</kbd> Next page &nbsp;|&nbsp;
        <kbd>H</kbd> Home/Index
      </p>
    </div>
    
    <!-- Status Bar -->
    <div class="status-bar">
      Page <strong>$pageNumber</strong> of $($pageFiles.Count) ($minPage-$maxPage) &nbsp;|&nbsp; 
      <span style="color: #0f0;">●</span> Local Preview Mode &nbsp;|&nbsp;
      $($content.Length) characters
    </div>
  </div>
  
  <!-- Keyboard Navigation Script -->
  <script>
    document.addEventListener('keydown', function(e) {
      switch(e.key.toLowerCase()) {
        case 'arrowleft':
        case 'p':
          if ($pageNumber > $minPage) window.location.href = 'page-$prevPage.html';
          break;
        case 'arrowright':
        case 'n':
          if ($pageNumber < $maxPage) window.location.href = 'page-$nextPage.html';
          break;
        case 'h':
          window.location.href = 'index.html';
          break;
      }
    });
  </script>
</body>
</html>
"@
        
        $outputPath = Join-Path $OutputDir "page-$pageNumber.html"
        $html | Out-File $outputPath -Encoding utf8
        
        Write-Host "✓ Generated: page-$pageNumber.html ($($content.Length) chars)" -ForegroundColor Green
        $script:successCount++
    }
    catch {
        Write-Error "Failed to process page $pageNumber`: $_"
        $script:errorCount++
    }
}

# Create index page if requested
if ($CreateIndex) {
    Write-Host "`nGenerating index page..." -ForegroundColor Cyan
    
    $pageLinks = ($pageNumbers | Sort-Object | ForEach-Object {
        "      <a href=`"page-$_.html`" class=`"page-link`">$_</a>"
    }) -join "`n"
    
    $indexHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="TXT TV - Page Index">
  <title>TXT TV - Index</title>
  <style>
$teletextCss
  </style>
</head>
<body>
  <div class="page-selector">
    <h1>📺 TXT TV - Page Index</h1>
    
    <div class="info-box">
      <h2>Local Preview Mode</h2>
      <p>
        Available pages: $minPage-$maxPage ($($pageNumbers.Count) pages)<br>
        Click a page number to view content<br>
        Use keyboard shortcuts for navigation
      </p>
    </div>
    
    <div class="page-grid">
$pageLinks
    </div>
    
    <div class="keyboard-help">
      <h3>Navigation Tips</h3>
      <p>
        Once on a page, use <kbd>←</kbd>/<kbd>→</kbd> or <kbd>P</kbd>/<kbd>N</kbd> to navigate between pages.<br>
        Press <kbd>H</kbd> to return to this index.
      </p>
    </div>
  </div>
</body>
</html>
"@
    
    $indexPath = Join-Path $OutputDir "index.html"
    $indexHtml | Out-File $indexPath -Encoding utf8
    Write-Host "✓ Generated: index.html" -ForegroundColor Green
}

Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "Conversion Complete!" -ForegroundColor Green
Write-Host "  Succeeded: $successCount" -ForegroundColor Green
Write-Host "  Failed: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Gray" })
Write-Host "  Output: $OutputDir" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

if ($CreateIndex) {
    $indexFullPath = Resolve-Path (Join-Path $OutputDir "index.html")
    Write-Host "`nOpen in browser: file:///$($indexFullPath -replace '\\', '/')" -ForegroundColor Yellow
}

Write-Host ""
