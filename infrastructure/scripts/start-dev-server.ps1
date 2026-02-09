<#
.SYNOPSIS
    Opens the TxtTV web interface in the default browser

.DESCRIPTION
    Simple helper script that opens src/web/index.html in the default browser.
    No development server required - HTML files are opened directly via file:/// protocol.
    
    Per constitution v1.2.2: Simple HTML + htmx from CDN, no build tooling.

.PARAMETER Page
    Optional page number to open directly (100-110). Defaults to index.

.EXAMPLE
    .\start-dev-server.ps1
    # Opens index.html in default browser

.EXAMPLE
    .\start-dev-server.ps1 -Page 100
    # Opens page.html?page=100 directly

.NOTES
    Author: TxtTV Development Team
    Constitution: v1.2.2 compliant (no Node.js, no server process)
    Last Updated: 2026-02-09
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateRange(100, 110)]
    [int]$Page
)

$ErrorActionPreference = 'Stop'

# Get repository root (2 levels up from scripts/)
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$webRoot = Join-Path $repoRoot "src\web"

# Verify web directory exists
if (-not (Test-Path $webRoot)) {
    Write-Error "Web directory not found: $webRoot"
    Write-Host "Expected structure: src/web/{index.html,page.html,styles/,scripts/}"
    exit 1
}

# Build file path
if ($Page) {
    $htmlFile = Join-Path $webRoot "page.html"
    $url = "file:///$($htmlFile -replace '\\', '/')?page=$Page"
    Write-Host "Opening page $Page in browser..." -ForegroundColor Cyan
} else {
    $htmlFile = Join-Path $webRoot "index.html"
    $url = "file:///$($htmlFile -replace '\\', '/')"
    Write-Host "Opening TxtTV index in browser..." -ForegroundColor Cyan
}

# Verify HTML file exists
if (-not (Test-Path $htmlFile)) {
    Write-Error "HTML file not found: $htmlFile"
    exit 1
}

# Open in default browser
try {
    Start-Process $url
    Write-Host "✓ Browser opened successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "Development Tips:" -ForegroundColor Yellow
    Write-Host "  • Edit files in src/web/ and press F5 to see changes"
    Write-Host "  • No build step or server process required"
    Write-Host "  • htmx loaded from CDN (no npm install needed)"
    Write-Host ""
} catch {
    Write-Error "Failed to open browser: $_"
    Write-Host "You can manually open: $htmlFile"
    exit 1
}
