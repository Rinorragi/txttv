# txttv Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-01-31

## Active Technologies
- .NET 10 F# (Azure Functions runtime v4) + HTMX 1.9+ (frontend interactivity), minimal CSS for teletext styling (001-txt-tv-app)
- Azure Blob Storage (for text files before conversion to policy fragments) (001-txt-tv-app)
- PowerShell 7+ for deployment scripts, .NET 10 F# for utility software + Azure CLI or PowerShell Az module, .NET SDK 10, existing Bicep modules (002-deploy-test-utility)
- N/A - uses existing Azure Blob Storage defined in infrastructure (002-deploy-test-utility)
- Bicep (Azure native IaC DSL) (003-waf-logging)
- Log Analytics workspace (already configured with 30-day retention) (003-waf-logging)
- HTML5/CSS3/JavaScript (ES6+) for web interface; PowerShell 7+ for conversion script + Node.js (for live-server local dev server with live reload); PowerShell 7+ for conversion (004-local-web-dev)
- File-based (local: HTML/CSS/JS source files; Azure: existing Blob Storage for content) (004-local-web-dev)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for .NET 8 F# (Azure Functions runtime v4)

## Code Style

.NET 8 F# (Azure Functions runtime v4): Follow standard conventions

## Recent Changes
- 004-local-web-dev: Added HTML5/CSS3/JavaScript (ES6+) for web interface; PowerShell 7+ for conversion script + Node.js (for live-server local dev server with live reload); PowerShell 7+ for conversion
- 003-waf-logging: Added Bicep (Azure native IaC DSL)
- 002-deploy-test-utility: Added PowerShell 7+ for deployment scripts, .NET 10 F# for utility software + Azure CLI or PowerShell Az module, .NET SDK 10, existing Bicep modules


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
