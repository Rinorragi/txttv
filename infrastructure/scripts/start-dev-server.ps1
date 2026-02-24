<#
.SYNOPSIS
    Starts a local HTTP development server for TxtTV

.DESCRIPTION
    PowerShell-based HTTP server using System.Net.HttpListener that serves
    the TxtTV web interface and JSON content API from a single origin.
    
    Eliminates CORS issues by serving both Page API (HTML) and Content API
    (JSON) from the same localhost origin. Enables the same two-API fetch
    workflow used in production APIM without requiring deployment.

    Routes:
      /                  → src/web/index.html
      /page/{N}          → src/web/page.html (shared template for all pages)
      /page.html?page=N  → src/web/page.html
      /content/{N}       → content/pages/page-{N}.json
      /styles/*          → src/web/styles/
      /scripts/*         → src/web/scripts/

.PARAMETER Port
    Port number to listen on. Defaults to 8080.

.EXAMPLE
    .\start-dev-server.ps1
    # Starts server on http://localhost:8080/

.EXAMPLE
    .\start-dev-server.ps1 -Port 9090
    # Starts server on http://localhost:9090/

.NOTES
    Author: TxtTV Development Team
    Constitution: v1.2.2 compliant (no Node.js, no external dependencies)
    Press Ctrl+C to stop the server.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateRange(1024, 65535)]
    [int]$Port = 8080
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Path setup
# ---------------------------------------------------------------------------

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$webRoot = Join-Path $repoRoot 'src\web'
$contentRoot = Join-Path $repoRoot 'content\pages'

# Verify directories exist
if (-not (Test-Path $webRoot)) {
    Write-Error "Web directory not found: $webRoot"
    exit 1
}
if (-not (Test-Path $contentRoot)) {
    Write-Error "Content directory not found: $contentRoot"
    exit 1
}

# ---------------------------------------------------------------------------
# MIME type mapping
# ---------------------------------------------------------------------------

$mimeTypes = @{
    '.html' = 'text/html; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.png'  = 'image/png'
    '.ico'  = 'image/x-icon'
    '.svg'  = 'image/svg+xml'
}

function Get-MimeType {
    param([string]$FilePath)
    $ext = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
    if ($mimeTypes.ContainsKey($ext)) {
        return $mimeTypes[$ext]
    }
    return 'application/octet-stream'
}

# ---------------------------------------------------------------------------
# Response helpers
# ---------------------------------------------------------------------------

function Send-FileResponse {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        Send-NotFound -Response $Response
        return
    }

    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    $Response.StatusCode = 200
    $Response.ContentType = Get-MimeType -FilePath $FilePath
    $Response.ContentLength64 = $bytes.Length
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Response.OutputStream.Close()
}

function Send-NotFound {
    param([System.Net.HttpListenerResponse]$Response)

    $body = '{"error":"Not found"}'
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $Response.StatusCode = 404
    $Response.ContentType = 'application/json; charset=utf-8'
    $Response.ContentLength64 = $bytes.Length
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Response.OutputStream.Close()
}

function Send-BadRequest {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [string]$Message = 'Bad request'
    )

    $body = "{`"error`":`"$Message`"}"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $Response.StatusCode = 400
    $Response.ContentType = 'application/json; charset=utf-8'
    $Response.ContentLength64 = $bytes.Length
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Response.OutputStream.Close()
}

# ---------------------------------------------------------------------------
# Route handler
# ---------------------------------------------------------------------------

function Invoke-RouteRequest {
    param([System.Net.HttpListenerContext]$Context)

    $request = $Context.Request
    $response = $Context.Response
    $path = $request.Url.AbsolutePath
    $method = $request.HttpMethod

    # Log the request
    $timestamp = Get-Date -Format 'HH:mm:ss'

    try {
        # Only allow GET requests
        if ($method -ne 'GET') {
            $response.StatusCode = 405
            $response.Close()
            Write-Host "  [$timestamp] $method $path -> 405" -ForegroundColor Red
            return
        }

        # Route: / -> index.html
        if ($path -eq '/' -or $path -eq '/index.html') {
            $filePath = Join-Path $webRoot 'index.html'
            Send-FileResponse -Response $response -FilePath $filePath
            Write-Host "  [$timestamp] GET $path -> 200 (index)" -ForegroundColor Green
            return
        }

        # Route: /page/{N} -> page.html (dynamic pages)
        if ($path -match '^/page/(\d{3})$') {
            $filePath = Join-Path $webRoot 'page.html'
            Send-FileResponse -Response $response -FilePath $filePath
            Write-Host "  [$timestamp] GET $path -> 200 (page)" -ForegroundColor Green
            return
        }

        # Route: /page.html -> page.html (query string style: ?page=N)
        if ($path -eq '/page.html') {
            $filePath = Join-Path $webRoot 'page.html'
            Send-FileResponse -Response $response -FilePath $filePath
            Write-Host "  [$timestamp] GET $path -> 200 (page)" -ForegroundColor Green
            return
        }

        # Route: /content/{N} -> content/pages/page-{N}.json
        if ($path -match '^/content/(\d{3})$') {
            $pageNumber = $Matches[1]
            $jsonFile = Join-Path $contentRoot "page-$pageNumber.json"
            if (Test-Path $jsonFile) {
                Send-FileResponse -Response $response -FilePath $jsonFile
                Write-Host "  [$timestamp] GET $path -> 200 (content)" -ForegroundColor Green
            } else {
                Send-NotFound -Response $response
                Write-Host "  [$timestamp] GET $path -> 404 (content not found)" -ForegroundColor Yellow
            }
            return
        }

        # Route: /content/{invalid} -> 400
        if ($path -match '^/content/') {
            Send-BadRequest -Response $response -Message 'Invalid page number format. Expected 3-digit number.'
            Write-Host "  [$timestamp] GET $path -> 400 (invalid page number)" -ForegroundColor Yellow
            return
        }

        # Route: /styles/* -> src/web/styles/
        if ($path -match '^/styles/(.+)$') {
            $fileName = $Matches[1]
            # Prevent path traversal
            if ($fileName -match '\.\.' -or $fileName -match '[<>|]') {
                Send-BadRequest -Response $response -Message 'Invalid path'
                Write-Host "  [$timestamp] GET $path -> 400 (invalid path)" -ForegroundColor Red
                return
            }
            $filePath = Join-Path $webRoot "styles\$fileName"
            if (Test-Path $filePath) {
                Send-FileResponse -Response $response -FilePath $filePath
                Write-Host "  [$timestamp] GET $path -> 200 (style)" -ForegroundColor Green
            } else {
                Send-NotFound -Response $response
                Write-Host "  [$timestamp] GET $path -> 404 (style not found)" -ForegroundColor Yellow
            }
            return
        }

        # Route: /scripts/* -> src/web/scripts/
        if ($path -match '^/scripts/(.+)$') {
            $fileName = $Matches[1]
            # Prevent path traversal
            if ($fileName -match '\.\.' -or $fileName -match '[<>|]') {
                Send-BadRequest -Response $response -Message 'Invalid path'
                Write-Host "  [$timestamp] GET $path -> 400 (invalid path)" -ForegroundColor Red
                return
            }
            $filePath = Join-Path $webRoot "scripts\$fileName"
            if (Test-Path $filePath) {
                Send-FileResponse -Response $response -FilePath $filePath
                Write-Host "  [$timestamp] GET $path -> 200 (script)" -ForegroundColor Green
            } else {
                Send-NotFound -Response $response
                Write-Host "  [$timestamp] GET $path -> 404 (script not found)" -ForegroundColor Yellow
            }
            return
        }

        # Fallback: 404
        Send-NotFound -Response $response
        Write-Host "  [$timestamp] GET $path -> 404" -ForegroundColor Yellow

    } catch {
        Write-Host "  [$timestamp] GET $path -> 500 ($_)" -ForegroundColor Red
        try {
            $response.StatusCode = 500
            $response.Close()
        } catch {
            # Response may already be closed
        }
    }
}

# ---------------------------------------------------------------------------
# Server startup
# ---------------------------------------------------------------------------

$prefix = "http://localhost:$Port/"
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($prefix)

try {
    $listener.Start()
} catch {
    Write-Error "Failed to start HTTP listener on $prefix - $_"
    Write-Host ""
    Write-Host "If port $Port is in use, try: .\start-dev-server.ps1 -Port 9090" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "  TxtTV Development Server" -ForegroundColor Cyan
Write-Host "  ========================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Listening on: " -NoNewline
Write-Host $prefix -ForegroundColor Green
Write-Host ""
Write-Host "  Routes:" -ForegroundColor Yellow
Write-Host "    /              -> index.html"
Write-Host "    /page/{N}      -> page.html (dynamic)"
Write-Host "    /content/{N}   -> page-{N}.json"
Write-Host "    /styles/*      -> CSS files"
Write-Host "    /scripts/*     -> JS files"
Write-Host ""
Write-Host "  Web root:     $webRoot" -ForegroundColor DarkGray
Write-Host "  Content root: $contentRoot" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Press Ctrl+C to stop" -ForegroundColor DarkGray
Write-Host ""

# ---------------------------------------------------------------------------
# Request loop
# ---------------------------------------------------------------------------

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        Invoke-RouteRequest -Context $context
    }
} finally {
    $listener.Stop()
    $listener.Close()
    Write-Host ""
    Write-Host "  Server stopped." -ForegroundColor Yellow
}
