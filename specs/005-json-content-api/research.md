# Research: JSON Content API & Two-API Architecture

**Feature**: 005-json-content-api
**Date**: February 24, 2026
**Status**: Complete

## Research Topic 1: Minimal APIM Fragment for Returning Raw JSON

### Decision

Use **CDATA-wrapped JSON** inside `<set-body>` with `Content-Type: application/json`. The minimal content fragment pattern:

```xml
<fragment>
    <return-response>
        <set-status code="200" reason="OK" />
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>
        <set-header name="Cache-Control" exists-action="override">
            <value>public, max-age=3600</value>
        </set-header>
        <set-body><![CDATA[{"pageNumber":100,"title":"...","content":"..."}]]></set-body>
    </return-response>
</fragment>
```

### Rationale

- CDATA guarantees byte-identical JSON payload (FR-003 compliance) — no XML entity encoding applied
- JSON string values can contain `<`, `>`, or `&` which would break XML parsing without CDATA
- Consistent with the project's established CDATA pattern (used in all existing `page-*.xml` fragments)
- The existing `apim-policy-fragment-best-practices.md` (004 spec) confirms CDATA is the "preferred approach"
- `application/json` is the standard Content-Type for JSON APIs
- `max-age=3600` (1 hour) balances cacheability with eventual content updates; current HTML fragments use `max-age=300`
- Content fragments will be ~1-2 KB — far below the 256 KB APIM fragment limit

### Alternatives Considered

| Alternative | Why Not |
|---|---|
| Policy expression `@(...)` returning JSON | Adds runtime overhead; content is static. Breaks byte-identical requirement |
| Raw JSON without CDATA | Risky — JSON string values can contain `<` or `&` which breaks XML parsing |
| Entity-encoded JSON | Destroys readability, adds conversion complexity, violates "close to source" principle |
| `@{return "...json...";}` expression | Unnecessary indirection for static content; string escaping issues with quotes |

---

## Research Topic 2: APIM Content Routing Pattern

### Decision

Use the **same `<choose>`/`<when>` pattern** as the existing `page-routing-policy.xml` for the new `content-routing-policy.xml`, with one clause per content fragment.

```xml
<choose>
    <when condition="@(context.Variables.GetValueOrDefault<string>("pageNumber") == "100")">
        <include-fragment fragment-id="content-100" />
    </when>
    <!-- ...one clause per page... -->
    <otherwise>
        <return-response>
            <set-status code="404" reason="Not Found" />
            <set-header name="Content-Type" exists-action="override">
                <value>application/json</value>
            </set-header>
            <set-body>{"error":"Page not found","pageNumber":null}</set-body>
        </return-response>
    </otherwise>
</choose>
```

### Rationale

- APIM's `<include-fragment>` requires a **static string literal** for `fragment-id` — dynamic fragment names are not supported
- The `<choose>`/`<when>` pattern is proven in this project (11 clauses in page-routing-policy.xml)
- With only 11 pages, the verbosity is manageable and explicit
- Each clause is a single line of meaningful difference — low maintenance burden
- The content routing policy mirrors the page routing policy structure, reducing cognitive load

### Alternatives Considered

| Alternative | Why Not |
|---|---|
| Dynamic `fragment-id` via expression | **Not supported by APIM.** Fragment references must be static strings |
| `send-request` to self | Adds ~50-100ms latency per request; defeats policy-only architecture |
| Single fragment with all JSON content | Puts all content in one massive fragment — worse than current state |
| Backend Azure Function serving JSON | Adds infrastructure, cost, and deployment complexity for static content |

---

## Research Topic 3: PowerShell HttpListener Local Dev Server

### Decision

Replace the current `Start-Process` (file:// protocol) approach with a **PowerShell `System.Net.HttpListener`-based HTTP server** that serves from a single origin, eliminating CORS requirements.

**Key design:**
- Serve static files from `src/web/` at the root URL (`/`)
- Map `/content/{N}` to `content/pages/page-{N}.json`
- Single origin `http://localhost:8080/` — no CORS needed (same-origin requests)
- Graceful shutdown via `try/finally` with `$listener.Stop()`

### Rationale

- `HttpListener` is built into .NET / PowerShell — zero external dependencies
- Same-origin serving eliminates CORS complexity entirely (page at `localhost:8080/page.html` fetches from `localhost:8080/content/100`)
- Aligns with constitution v1.2.2 (no Node.js, no external tools)
- Simple regex-based routing covers the two URL patterns needed
- Available in PowerShell 5.1+ and PowerShell 7+ without additional modules

### Implementation Notes

- Use `[System.Net.HttpListener]` with prefix `http://localhost:8080/`
- On Windows, `localhost` works without admin rights or URL reservations
- Synchronous `$listener.GetContext()` loop is sufficient for single-developer local use
- Map file extensions to MIME types: `.html` → `text/html`, `.css` → `text/css`, `.js` → `application/javascript`, `.json` → `application/json`
- Content route regex: `^/content/(\d{3})$` → extracts page number → maps to file
- Handle missing files with 404 responses
- Handle `/page/{N}` by serving `src/web/page.html` (the same HTML shell for all page numbers)

### Alternatives Considered

| Alternative | Why Not |
|---|---|
| Keep `file://` protocol | Blocks `fetch()` and `hx-get` — incompatible with two-API architecture |
| Python `http.server` | External dependency; less route control; not PowerShell-native |
| Node.js dev server | Explicitly prohibited by constitution v1.2.2 |
| .NET Kestrel minimal API | Over-engineered for static files + one route mapping |
| VS Code Live Server extension | Not scriptable, IDE-dependent, no custom route mapping |

---

## Research Topic 4: htmx vs fetch for JSON Content Loading

### Decision

Use **standard `fetch()` API** for JSON content loading, not htmx. htmx remains loaded from CDN (per constitution) for potential HTML-based interactions, but JSON content loading uses native `fetch()`.

### Rationale

- **htmx is designed for HTML responses, not JSON** — it would insert raw JSON text into the DOM as-is
- `fetch()` is a native browser API with zero additional dependencies
- The rendering logic (JSON fields → TXT TV-styled DOM elements) needs custom JavaScript regardless — a template engine adds abstraction without value
- The spec already allows "htmx **or** standard fetch" (FR-006)
- `fetch()` provides clear error handling: `response.ok`, `response.status`, `try/catch`
- Simpler mental model: htmx = HTML swaps, fetch = data loading

### htmx JSON Extension Considered

htmx offers a `client-side-templates` extension that can handle JSON with template engines (Mustache/Handlebars):

```html
<div hx-ext="client-side-templates">
    <div hx-get="/content/100" mustache-template="page-tmpl" hx-trigger="load"></div>
</div>
```

Rejected because:
- Adds 2 CDN dependencies (extension JS + template engine)
- Template engines are over-engineered for rendering 6-7 JSON fields into a `<pre>` block
- The TXT TV rendering has specific formatting requirements (box-drawing characters, severity color coding) that are easier with imperative JS than with templates

### Recommended Client-Side Pattern

```javascript
// content-renderer.js
(function() {
    'use strict';
    
    async function loadAndRenderContent(pageNumber) {
        const contentEl = document.getElementById('page-content');
        
        try {
            const response = await fetch(`/content/${pageNumber}`);
            if (!response.ok) {
                contentEl.textContent = `Error: Page ${pageNumber} not found`;
                return;
            }
            
            const data = await response.json();
            
            // Render structured fields into TXT TV layout
            contentEl.textContent = [
                `${data.category}: ${data.title}`,
                '═'.repeat(45),
                '',
                data.content,
                '',
                '─'.repeat(45),
                `Severity: ${data.severity} | CVSS: ${data.metadata.cvss}`,
                `Published: ${data.metadata.published}`
            ].join('\n');
            
            document.title = `TXT TV - Page ${data.pageNumber}`;
            
        } catch (err) {
            contentEl.textContent = 'Error loading content. Check console.';
            console.error('[TxtTV] Content load failed:', err);
        }
    }
    
    // Extract page number from URL
    const pageNumber = new URLSearchParams(window.location.search).get('page') || '100';
    loadAndRenderContent(pageNumber);
})();
```

### Alternatives Considered

| Alternative | Why Not |
|---|---|
| htmx `hx-get` for JSON | htmx doesn't parse JSON; inserts raw text into DOM |
| htmx `client-side-templates` + Mustache | Adds 2 CDN dependencies; over-engineered for simple rendering |
| htmx `hx-on::after-request` interceptor | Hacky — intercepts response to manually parse; defeats htmx's purpose |
| Content API returns HTML instead of JSON | Defeats the purpose of the two-API split; not format-agnostic |
| XMLHttpRequest | Legacy API; `fetch()` is the modern standard |

---

## Research Topic 5: JSON Schema Validation in PowerShell

### Decision

Use **PowerShell's `ConvertFrom-Json`** for basic parsing validation, plus **custom validation functions** for schema compliance. No external JSON Schema library needed.

### Rationale

- PowerShell 7+ `ConvertFrom-Json` handles parsing validation natively
- The content schema has only 7 top-level fields — a simple validation function is sufficient
- Adding a JSON Schema library (like `Newtonsoft.Json.Schema`) would introduce a NuGet dependency, violating the "no build tooling" principle
- Custom validation provides clearer error messages specific to the TXT TV domain

### Validation Pattern

```powershell
function Test-ContentJson {
    param([string]$FilePath)
    
    $json = Get-Content $FilePath -Raw | ConvertFrom-Json -ErrorAction Stop
    
    # Required fields
    $required = @('pageNumber', 'title', 'content', 'navigation')
    foreach ($field in $required) {
        if (-not $json.PSObject.Properties[$field]) {
            throw "Missing required field: $field"
        }
    }
    
    # Type checks
    if ($json.pageNumber -isnot [int]) { throw "pageNumber must be integer" }
    if ($json.pageNumber -lt 100 -or $json.pageNumber -gt 999) { throw "pageNumber must be 100-999" }
    if ([string]::IsNullOrWhiteSpace($json.title)) { throw "title must be non-empty string" }
    if ([string]::IsNullOrWhiteSpace($json.content)) { throw "content must be non-empty string" }
    
    return $true
}
```

---

## Summary of Decisions

| Topic | Decision | Key Factor |
|---|---|---|
| JSON in APIM fragments | CDATA-wrapped JSON in `<set-body>` | Byte-identical requirement (FR-003); XML safety |
| Content routing | `<choose>`/`<when>` pattern | `<include-fragment>` requires static `fragment-id` |
| Local dev server | PowerShell `HttpListener` | Required for `fetch()`; no external dependencies |
| Content loading | Standard `fetch()` API | htmx expects HTML, not JSON; fetch is native |
| JSON validation | Custom PowerShell functions | No external libraries needed; simple schema |
