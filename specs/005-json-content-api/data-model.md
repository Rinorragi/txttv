# Data Model: JSON Content API & Two-API Architecture

**Feature**: 005-json-content-api
**Date**: February 24, 2026

## Entity 1: JSON Content File

**What it represents**: A structured JSON file containing all data for a single TXT TV page. This is the single source of truth for page content — everything else (APIM content fragments, local preview) derives from it.

**Location**: `content/pages/page-{NUMBER}.json`

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `pageNumber` | integer | Yes | 3-digit page identifier (100-999). Must match the filename number |
| `title` | string | Yes | Page headline (e.g., "CVE-2026-12345 - Remote Code Execution") |
| `category` | string | Yes | Content category (e.g., "SECURITY ALERT", "ADVISORY", "NEWS") |
| `severity` | string | No | Severity level: "CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO". Null for non-security content |
| `content` | string | Yes | Main body text. Uses `\n` for line breaks. Supports Unicode box-drawing characters |
| `metadata` | object | No | Additional metadata about the content |
| `metadata.cvss` | number | No | CVSS score (0.0-10.0). Null for non-vulnerability content |
| `metadata.published` | string (ISO 8601) | No | Publication timestamp (e.g., "2026-02-09T08:45:00Z") |
| `navigation` | object | Yes | Navigation links for page traversal |
| `navigation.prev` | integer or null | Yes | Previous page number, or null if first page |
| `navigation.next` | integer or null | Yes | Next page number, or null if last page |
| `navigation.related` | integer[] | Yes | Array of related page numbers (can be empty) |

### Validation Rules

- `pageNumber` must be between 100 and 999 inclusive
- `pageNumber` must match the number in the filename (`page-100.json` → `pageNumber: 100`)
- `title` must be non-empty, max 80 characters (fits TXT TV display width)
- `category` must be one of the defined category values
- `content` must be non-empty, max 2000 characters (APIM fragment size consideration)
- `severity` when present must be one of: CRITICAL, HIGH, MEDIUM, LOW, INFO
- `metadata.cvss` when present must be 0.0-10.0
- `metadata.published` when present must be valid ISO 8601
- `navigation.prev` and `navigation.next` when non-null must be valid page numbers (100-999)
- `navigation.related` entries must be valid page numbers; array max 10 items

### State Transitions

None — JSON content files are static documents. They are created, edited, and version-controlled, but have no runtime state machine.

---

## Entity 2: Content Fragment

**What it represents**: An APIM policy fragment generated from a JSON content file. Wraps the JSON payload in minimal XML to return it as an `application/json` response. The JSON inside the fragment is byte-identical to the source file.

**Location**: `infrastructure/modules/apim/fragments/content-{NUMBER}.xml`

### Structure

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
        <set-body><![CDATA[{...JSON content...}]]></set-body>
    </return-response>
</fragment>
```

### Relationships

- **Derived from**: JSON Content File (1:1 — each JSON file produces exactly one content fragment)
- **Referenced by**: Content Routing Policy (included via `<include-fragment fragment-id="content-{N}">`)
- **Registered in**: APIM Bicep module (as a named fragment resource)

### Validation Rules

- XML must be well-formed
- Must contain exactly one `<fragment>` root element
- Must set `Content-Type: application/json`
- JSON in CDATA must be valid JSON
- Total fragment size must not exceed 256 KB
- Fragment ID must follow pattern `content-{NUMBER}`

---

## Entity 3: Page Template Fragment

**What it represents**: A single shared APIM policy fragment that serves the HTML shell for all TXT TV pages. Contains CSS, navigation JavaScript, and the `fetch()`-based content loader. Page-specific content is loaded at render time from the Content API.

**Location**: `infrastructure/modules/apim/fragments/page-template.xml`

### Structure (conceptual)

```xml
<fragment>
    <return-response>
        <set-status code="200" reason="OK" />
        <set-header name="Content-Type" exists-action="override">
            <value>text/html</value>
        </set-header>
        <set-body><![CDATA[
            <!DOCTYPE html>
            <html>
            <head>
                <style>/* TXT TV CSS */</style>
                <script src="https://cdn.jsdelivr.net/npm/htmx.org@2.0.8/dist/htmx.min.js"></script>
            </head>
            <body>
                <div id="page-content">Loading...</div>
                <nav><!-- prev/next links --></nav>
                <script>
                    // content-renderer.js logic (fetch JSON, render)
                </script>
            </body>
            </html>
        ]]></set-body>
    </return-response>
</fragment>
```

### Relationships

- **Referenced by**: Page Routing Policy (single `<include-fragment fragment-id="page-template">`)
- **Depends on**: Content API (at render time, client fetches JSON from `/content/{pageNumber}`)
- **Generated from**: `src/web/templates/page-template.html` + `src/web/styles/txttv.css` + `src/web/scripts/content-renderer.js` (by `convert-web-to-apim.ps1`)

### Key Difference from Current Architecture

| Current (004) | New (005) |
|---|---|
| 11 monolithic fragments (679 lines each) | 1 shared template fragment |
| Content embedded at build time | Content fetched at render time |
| CSS/JS duplicated in each fragment | CSS/JS in one template |
| ~16-17 KB per fragment | ~5-8 KB for the template |

---

## Entity 4: Content Routing Policy

**What it represents**: An APIM inbound policy that routes `GET /content/{pageNumber}` requests to the appropriate content fragment based on the page number URL parameter.

**Location**: `infrastructure/modules/apim/policies/content-routing-policy.xml`

### Structure (conceptual)

- Extract `pageNumber` from URL template parameter
- Validate: must be 3-digit integer
- `<choose>`/`<when>` block mapping page numbers to content fragments
- `<otherwise>` returns 404 JSON error response

### Relationships

- **Used by**: Content API operation (`get-content.json`)
- **References**: Content Fragment entities (via `<include-fragment>`)
- **Mirrors**: Page Routing Policy structure (same choose/when pattern)

---

## Entity 5: Content API Operation

**What it represents**: An APIM operation definition for the Content API endpoint (`GET /content/{pageNumber}`). Returns structured JSON content for the specified page.

**Location**: `infrastructure/modules/apim/operations/get-content.json`

### Fields

| Field | Value |
|-------|-------|
| Method | GET |
| URL template | `/content/{pageNumber}` |
| Parameter | `pageNumber` (integer, 100-999, required, template) |
| Success response | 200 with `application/json` |
| Error responses | 400 (invalid page number), 404 (page not found) |
| Inbound policy | `content-routing-policy.xml` |

### Relationships

- **Uses**: Content Routing Policy (inbound processing)
- **Registered in**: APIM Bicep module (as an operation on the `txttv-api`)
- **Consumed by**: Page Template Fragment (client-side fetch at render time)

---

## Entity 6: JSON Content Renderer

**What it represents**: A client-side JavaScript module that fetches JSON from the Content API and renders it into the TXT TV page layout.

**Location**: `src/web/scripts/content-renderer.js`

### Responsibilities

- Extract page number from URL (query parameter or path)
- Fetch JSON from Content API endpoint (`/content/{pageNumber}`)
- Parse JSON response
- Render structured fields into DOM elements:
  - Title → header bar
  - Category + severity → category line with color coding
  - Content → `<pre>` block preserving whitespace/box-drawing characters
  - Navigation → prev/next/related links
  - Metadata → footer with CVSS score and publication date
- Handle errors (network failure, 404, malformed JSON) with TXT TV-styled error display

### Relationships

- **Consumed by**: Page Template Fragment (embedded or referenced in HTML)
- **Depends on**: Content API (HTTP endpoint)
- **Depends on**: JSON Content Schema (expected response format)

---

## Entity 7: Local Dev Server

**What it represents**: A PowerShell HTTP listener script that serves the web application locally, mapping both static files and content API requests.

**Location**: `infrastructure/scripts/start-dev-server.ps1`

### Route Mapping

| URL Pattern | Serves From | Content-Type |
|---|---|---|
| `/` | `src/web/index.html` | `text/html` |
| `/page/{N}` or `/page.html?page={N}` | `src/web/page.html` | `text/html` |
| `/content/{N}` | `content/pages/page-{N}.json` | `application/json` |
| `/styles/*.css` | `src/web/styles/*.css` | `text/css` |
| `/scripts/*.js` | `src/web/scripts/*.js` | `application/javascript` |

### Relationships

- **Serves**: JSON Content Files (as Content API emulator)
- **Serves**: Web source files (HTML, CSS, JS)
- **Replaces**: Current `Start-Process` file:// approach

---

## Entity Relationship Diagram

```
JSON Content File (source)
    │
    ├──[convert-json-to-fragment.ps1]──► Content Fragment (APIM)
    │                                        │
    │                                        ▼
    │                               Content Routing Policy
    │                                        │
    │                                        ▼
    │                               Content API Operation
    │                                        │
    │   ┌────────────────────────────────────┘
    │   │ (fetch at render time)
    │   ▼
    │  Page Template Fragment ◄── Page Routing Policy ◄── Page API Operation
    │
    └──[local dev server]──► Browser (direct JSON serving)
```
