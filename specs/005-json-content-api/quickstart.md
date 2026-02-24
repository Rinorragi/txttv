# Quickstart: JSON Content API & Two-API Architecture

**Feature**: 005-json-content-api
**Date**: February 24, 2026

## Prerequisites

- PowerShell 7+ (`pwsh`)
- A web browser (Edge, Chrome, Firefox)
- Git (for branch checkout)

No Node.js, npm, or build tooling required.

## Setup (< 5 minutes)

### 1. Check out the feature branch

```powershell
git checkout 005-json-content-api
```

### 2. Verify JSON content files exist

```powershell
Get-ChildItem content/pages/*.json | Select-Object Name
```

Expected: `page-100.json` through `page-110.json` (11 files).

### 3. Start the local dev server

```powershell
./infrastructure/scripts/start-dev-server.ps1
```

This starts a PowerShell HTTP server on `http://localhost:8080/`.

### 4. Open the TXT TV page

Navigate to: **http://localhost:8080/page/100**

You should see the TXT TV page with content loaded dynamically from the Content API.

## Key URLs (local dev server)

| URL | Description |
|-----|-------------|
| `http://localhost:8080/page/100` | TXT TV page 100 (HTML shell + JSON content) |
| `http://localhost:8080/page/110` | TXT TV page 110 |
| `http://localhost:8080/content/100` | Raw JSON content for page 100 |
| `http://localhost:8080/` | Index / entry page |

## Editing Content

### Edit a JSON content file

```powershell
# Open the content file in your editor
code content/pages/page-100.json
```

Edit the `title`, `content`, or other fields. Save the file.

### Preview locally (instant)

Refresh the browser — the local dev server serves the updated JSON file directly. No conversion step needed.

### Generate APIM content fragments (for deployment)

```powershell
./infrastructure/scripts/convert-json-to-fragment.ps1 `
    -SourceDir content/pages `
    -OutputDir infrastructure/modules/apim/fragments
```

This generates `content-100.xml` through `content-110.xml` in the fragments directory.

## Adding a New Page

### 1. Create the JSON content file

```powershell
# Copy an existing page as template
Copy-Item content/pages/page-100.json content/pages/page-111.json
```

Edit `page-111.json`:
- Set `pageNumber` to `111`
- Update `title`, `category`, `content`, `navigation`
- Update adjacent pages' `navigation.next`/`navigation.prev` as needed

### 2. Regenerate content fragments

```powershell
./infrastructure/scripts/convert-json-to-fragment.ps1 `
    -SourceDir content/pages `
    -OutputDir infrastructure/modules/apim/fragments
```

### 3. Update routing policy

Add a new `<when>` clause to `infrastructure/modules/apim/policies/content-routing-policy.xml`:

```xml
<when condition="@(context.Variables.GetValueOrDefault<string>("pageNumber") == "111")">
    <include-fragment fragment-id="content-111" />
</when>
```

### 4. Register fragment in Bicep

Add the new fragment resource to `infrastructure/modules/apim/main.bicep`.

## Architecture Overview

```
Browser                              APIM (Production)
  │                                    │
  ├─GET /page/100─────────────────────►│ Page Routing Policy
  │◄──HTML shell (shared template)─────│   → page-template fragment
  │                                    │
  ├─GET /content/100──────────────────►│ Content Routing Policy
  │◄──JSON content────────────────────│   → content-100 fragment
  │                                    │
  │  (browser renders JSON into HTML)  │

Browser                              Local Dev Server (PowerShell)
  │                                    │
  ├─GET /page/100─────────────────────►│ Serves src/web/page.html
  │◄──HTML shell──────────────────────│
  │                                    │
  ├─GET /content/100──────────────────►│ Serves content/pages/page-100.json
  │◄──JSON content────────────────────│
  │                                    │
  │  (same browser rendering)          │
```

## Running Tests

```powershell
# Validate JSON content files
./infrastructure/scripts/convert-json-to-fragment.ps1 -ValidateOnly

# Run policy validation tests
Invoke-Pester tests/policies/ -Output Detailed

# Run integration tests (requires local dev server running)
Invoke-Pester tests/integration/ -Output Detailed
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `fetch()` fails with CORS error | Make sure you're using the local dev server, not `file://` |
| Page shows "Loading..." forever | Check if the dev server is running; check browser console for errors |
| Content fragment generation fails | Run with `-Verbose` flag; check JSON files for syntax errors |
| Port 8080 already in use | Stop the existing server or use `-Port 8081` parameter |
