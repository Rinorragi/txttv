# Run WAF Demonstration

# This script demonstrates WAF protection by executing malicious requests
# and verifying they are blocked by Azure Application Gateway WAF

Write-Host "=== TxtTV WAF Demonstration ===" -ForegroundColor Cyan
Write-Host ""

# Check if test utility is built
$utilityPath = "$PSScriptRoot\..\..\tools\TxtTv.TestUtility"
if (-not (Test-Path "$utilityPath\bin\Debug\net10.0\TxtTv.TestUtility.dll")) {
    Write-Host "Building test utility..." -ForegroundColor Yellow
    Push-Location $utilityPath
    dotnet build | Out-Null
    Pop-Location
}

# Get APIM endpoint from user or environment
$endpoint = $env:TXTTV_APIM_ENDPOINT
if (-not $endpoint) {
    Write-Host "Enter your APIM endpoint URL:" -ForegroundColor Yellow
    Write-Host "Example: https://your-apim.azure-api.net" -ForegroundColor Gray
    $endpoint = Read-Host "Endpoint"
}

# Get signature key
$signatureKey = $env:TXTTV_SIGNATURE_KEY
if (-not $signatureKey) {
    Write-Host ""
    Write-Host "Enter your signature key (or press Enter to skip signatures):" -ForegroundColor Yellow
    $signatureKey = Read-Host "Key"
}

# Update example files with actual endpoint
Write-Host ""
Write-Host "Updating example files with endpoint: $endpoint" -ForegroundColor Cyan

Get-ChildItem "$PSScriptRoot\waf-tests\*.json" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $content = $content -replace 'https://your-apim-endpoint\.azure-api\.net', $endpoint
    Set-Content $_.FullName $content
}

# Run WAF tests
Write-Host ""
Write-Host "Executing WAF tests..." -ForegroundColor Cyan
Write-Host "Expected behavior: Malicious requests should be blocked (403/429 status)" -ForegroundColor Gray
Write-Host ""

$loadArgs = @(
    'run'
    '--project'
    "$utilityPath"
    '--'
    'load'
    '-f'
    "$PSScriptRoot\waf-tests"
    '-c'
    '-v'
)

if ($signatureKey) {
    $loadArgs += '-k'
    $loadArgs += $signatureKey
}

& dotnet $loadArgs

Write-Host ""
Write-Host "=== WAF Demonstration Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Results Analysis:" -ForegroundColor Yellow
Write-Host "✅ 403/429 responses indicate WAF is blocking malicious requests" -ForegroundColor Green
Write-Host "⚠️ 200 responses indicate potential security issues - WAF may need tuning" -ForegroundColor Yellow
Write-Host ""
