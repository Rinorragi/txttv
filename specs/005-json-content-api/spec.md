# Feature Specification: JSON Content API & Two-API Architecture

**Feature Branch**: `005-json-content-api`  
**Created**: February 24, 2026  
**Status**: Draft  
**Input**: User description: "JSON content schema + two-API refinement: Replace txt content files with structured JSON, split monolithic page fragments into a Page API (HTML shell) and Content API (JSON data), enable htmx/fetch content loading. Content APIM policy fragments should be as close to the source JSON files as possible for easier local testing."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - JSON Content Files & Content API (Priority: P1)

A developer needs page content stored as structured JSON files that can be served directly through a dedicated Content API endpoint. The content APIM policy fragments should mirror the JSON source files as closely as possible, enabling easy local testing — what you see in the JSON file is essentially what the API returns.

**Why this priority**: This is the foundation of the entire two-API split. Without structured JSON content files and a Content API to serve them, the Page API has nothing to load. JSON files also unlock JavaScript-based rendering and structured metadata (titles, severity, navigation links) that plain text cannot provide.

**Independent Test**: Can be fully tested by creating a JSON content file, running the conversion script to generate a content fragment, and verifying the APIM fragment returns JSON that matches the source file. Locally, the JSON file can be fetched directly by the browser for identical behavior.

**Acceptance Scenarios**:

1. **Given** a content file `content/pages/page-100.json` exists with structured fields (title, content, navigation), **When** the conversion script runs, **Then** an APIM content fragment is generated at `infrastructure/modules/apim/fragments/content-100.xml` that returns the JSON payload with `Content-Type: application/json`
2. **Given** a generated content fragment, **When** inspected, **Then** the JSON inside the fragment is byte-identical to the source `.json` file (no transformation/encoding of the JSON body itself)
3. **Given** the Content API is deployed to APIM, **When** a client sends `GET /content/{pageNumber}`, **Then** the response body is the JSON content with appropriate headers
4. **Given** a developer modifies a `.json` content file, **When** they re-run the conversion script, **Then** the updated content fragment reflects the change and the local JSON file produces identical output when fetched directly

---

### User Story 2 - Page API with Dynamic Content Loading (Priority: P2)

A developer needs the Page API (`GET /page/{pageNumber}`) to serve an HTML shell (template with styles, navigation, htmx) that loads content dynamically from the Content API at render time. This separates presentation from data and eliminates the current 16-17 KB monolithic fragments that duplicate CSS/JS/content.

**Why this priority**: With content served separately (US1), the page template needs to be refactored to fetch and render JSON content. This completes the two-API architecture and delivers the modularity benefit — one shared page template instead of N duplicated full-page fragments.

**Independent Test**: Can be fully tested by opening the page in a browser pointed at a local HTTP server, verifying the HTML shell loads, then verifying it fetches JSON from the Content API (or local file) and renders the TXT TV page correctly.

**Acceptance Scenarios**:

1. **Given** a browser requests `GET /page/100`, **When** the Page API responds, **Then** the response is an HTML page containing the TXT TV styles, navigation, and a script that fetches content from `GET /content/100`
2. **Given** the HTML shell has loaded, **When** the content fetch completes, **Then** the page displays the structured content (title, severity, body text) in the retro TXT TV style
3. **Given** a page template fragment exists in APIM, **When** the routing policy processes a request for any page number 100-110, **Then** the same template fragment is used (not N separate full-page fragments)
4. **Given** the developer is working locally, **When** they open the page in a browser via the local dev server, **Then** htmx/fetch loads content from the local JSON file and renders identically to the APIM-deployed version

---

### User Story 3 - Local Development with JSON Content (Priority: P3)

A developer needs the local development workflow to support the two-API pattern — a local HTTP server serves both the HTML pages and JSON content files, enabling the same htmx/fetch flow that works in APIM production.

**Why this priority**: Without a local HTTP server, `file://` protocol blocks fetch requests. This story ensures developers can iterate locally with the same content-loading behavior as production.

**Independent Test**: Can be fully tested by running `start-dev-server.ps1`, opening the page in a browser, and verifying JSON content loads and renders correctly with no CORS or protocol errors.

**Acceptance Scenarios**:

1. **Given** a developer runs the local dev server script, **When** they open the TXT TV page in their browser, **Then** the HTML template loads and fetches JSON content from the local server
2. **Given** the content JSON files are in `content/pages/`, **When** the local server receives a request for `/content/100`, **Then** it serves `content/pages/page-100.json` with `Content-Type: application/json`
3. **Given** a developer edits a JSON content file, **When** they refresh the browser, **Then** the updated content appears immediately (no conversion step needed for local preview)
4. **Given** the local server is running, **When** the developer uses browser DevTools, **Then** the Network tab shows one HTML request and one JSON content request per page view

---

### Edge Cases

- What happens when a JSON content file contains invalid JSON syntax? The conversion script and client renderer must handle parse errors gracefully
- What happens when a JSON content file is missing a required field (e.g., `content` or `pageNumber`)? Schema validation should catch this at conversion time
- How does the system handle content with characters that need JSON string escaping (newlines, quotes, backslashes, Unicode)?
- What happens when the Content API returns a non-200 status (e.g., 404 for unknown page)? The page template must display a user-friendly error in TXT TV style
- What happens when the JSON file exceeds the APIM fragment size limit (256 KB)? The conversion script must validate and reject oversized content
- How does the system handle concurrent content updates — can two developers edit different JSON files and merge without conflicts? (JSON files are independent per page, so merge conflicts are page-scoped)
- What happens when the local dev server is not running but a developer opens the HTML file directly? The page should show a clear error message about needing the local server

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Content files MUST be stored as structured JSON at `content/pages/page-{NUMBER}.json` with a defined schema containing at minimum `pageNumber`, `title`, `content`, and `navigation` fields
- **FR-002**: System MUST provide a Content API operation (`GET /content/{pageNumber}`) in APIM that returns JSON content with `Content-Type: application/json`
- **FR-003**: Content APIM fragments MUST contain JSON that is as close to the source `.json` file as possible — ideally byte-identical JSON payload with only the minimal XML wrapper required by APIM
- **FR-004**: System MUST provide a Page API operation (`GET /page/{pageNumber}`) in APIM that returns an HTML template shell with styles, navigation, and a script that loads content from the Content API
- **FR-005**: The Page API MUST serve one shared page template that works for all page numbers, not N separate full-page fragments
- **FR-006**: The HTML page template MUST use htmx or standard fetch to load JSON content from the Content API endpoint and render it into the page
- **FR-007**: A conversion script MUST read `.json` content files and generate APIM content fragments wrapped in minimal XML (`<fragment><return-response>...<set-body>{JSON}</set-body></return-response></fragment>`)
- **FR-008**: The conversion script MUST validate each JSON content file against the defined schema before generating fragments (fail fast on invalid content)
- **FR-009**: The conversion script MUST validate generated XML fragments for well-formedness and APIM schema compliance
- **FR-010**: A local HTTP development server script (`start-dev-server.ps1`) MUST serve HTML files from `src/web/` and JSON content files from `content/pages/` to enable the same fetch-based workflow locally
- **FR-011**: The local server MUST map requests for `/content/{pageNumber}` to the corresponding `content/pages/page-{NUMBER}.json` file
- **FR-012**: The client-side JavaScript MUST parse the JSON response and render structured fields (title, severity, content body, navigation links) into the TXT TV-styled page
- **FR-013**: The conversion script MUST be idempotent — running it multiple times on unchanged source files produces identical output
- **FR-014**: Generated content fragments MUST be stored under `infrastructure/modules/apim/fragments/` following existing project conventions
- **FR-015**: The system MUST handle the Content API returning errors (404, 500) by displaying a TXT TV-styled error message in the page template

### Assumptions

- The existing 004-local-web-dev feature infrastructure (CSS, navigation.js, APIM modules, Bicep) remains in place and is extended, not replaced
- htmx 2.0.8 from CDN is used for content loading (`hx-get` targeting the content API endpoint), consistent with constitution v1.2.2
- A local HTTP server (PowerShell-based, no Node.js) is required for local development because `file://` protocol blocks fetch/htmx requests
- JSON content files are human-editable and version-controlled; no CMS or database backend
- The Page API serves a single shared template fragment; page-specific content comes exclusively from the Content API
- Content fragments contain raw JSON (not HTML-wrapped) — the client-side JS handles all rendering
- The existing `page-routing-policy.xml` will be updated to serve the template fragment instead of per-page monolithic fragments
- A new `content-routing-policy.xml` will route content requests to per-page content fragments
- Content examples continue to use fake cyber security news/incidents
- The `convert-txt-to-fragment.ps1` script becomes superseded by the new JSON-aware conversion script (or refactored)
- The existing monolithic `page-*.xml` fragments (100-110) will be replaced by a single page template fragment + 11 content fragments
- APIM Liquid templating may be used in the page template fragment for injecting the page number into the content API URL

### Key Entities

- **JSON Content File**: A structured JSON file (`content/pages/page-{NUMBER}.json`) containing page data with fields for title, category, severity, content body text, metadata, and navigation links. This is the single source of truth for page content
- **Content Fragment**: An APIM policy fragment (`content-{NUMBER}.xml`) that wraps the JSON content in minimal XML and returns it as `application/json`. The JSON payload inside should be identical to the source `.json` file
- **Page Template Fragment**: A single APIM policy fragment (`page-template.xml`) containing the HTML shell with CSS, navigation, and JavaScript that fetches content from the Content API. Shared across all page numbers
- **Content Routing Policy**: An APIM policy (`content-routing-policy.xml`) that routes `GET /content/{pageNumber}` to the correct content fragment via `include-fragment`
- **Page Routing Policy**: The updated APIM policy (`page-routing-policy.xml`) that serves the shared page template for all `GET /page/{pageNumber}` requests, injecting the page number for the client to use when fetching content
- **JSON Content Renderer**: A client-side JavaScript module that parses JSON from the Content API and renders it into the TXT TV page structure (title bar, content area, navigation links, metadata footer)
- **Local Dev Server**: A PowerShell HTTP listener script (`start-dev-server.ps1`) that serves HTML from `src/web/` and maps `/content/{N}` requests to `content/pages/page-{N}.json`

### JSON Content Schema

Content files follow this structure:

```json
{
  "pageNumber": 100,
  "title": "CVE-2026-12345 - Remote Code Execution",
  "category": "SECURITY ALERT",
  "severity": "CRITICAL",
  "content": "BREAKING: Apache Struts Vulnerability Discovered\n-------------------------------------------------\nSecurity researchers discovered a critical remote\ncode execution vulnerability affecting Apache\nStruts 2.5.x through 2.6.4.\n\nIMPACT: Allows unauthenticated attackers to\nexecute arbitrary code on vulnerable servers.\n\nAFFECTED SYSTEMS:\n* Apache Struts 2.5.0 - 2.6.4\n* Est. 500,000+ servers worldwide\n* Healthcare, finance sectors most exposed\n\nRECOMMENDED ACTIONS:\n→ Update to Struts 2.6.5+ immediately\n→ Review logs for suspicious activity\n→ Implement WAF rules (see page 105)",
  "metadata": {
    "cvss": 9.8,
    "published": "2026-02-09T08:45:00Z"
  },
  "navigation": {
    "prev": null,
    "next": 101,
    "related": [101, 102, 103, 105]
  }
}
```

**Benefits over plain text**:
- Structured fields parseable by JavaScript without regex or string splitting
- Navigation links are machine-readable (no "see page 105" string parsing)
- Metadata (severity, CVSS score) usable for UI rendering decisions (color coding, icons)
- JSON-to-APIM fragment conversion is trivial — wrap in minimal XML, no encoding gymnastics
- Content API returns standard `application/json` — browser-native format

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Content fragments contain JSON byte-identical to their source `.json` files — zero transformation of the JSON payload
- **SC-002**: The page template makes exactly one fetch request to the Content API per page view (verifiable via browser DevTools Network tab)
- **SC-003**: Total fragment count reduces from 11+ monolithic fragments (16-17 KB each) to 1 page template fragment + 11 small content fragments (<2 KB each)
- **SC-004**: The conversion script processes all JSON content files and generates content fragments in under 10 seconds
- **SC-005**: Local development workflow produces visually identical rendering to APIM-deployed version (same JSON → same rendered page)
- **SC-006**: A new developer can set up the local environment, start the dev server, and view pages within 10 minutes using documentation
- **SC-007**: JSON content files pass schema validation in 100% of cases before fragment generation proceeds
- **SC-008**: The page template fragment serves all 11 pages (100-110) without any page-specific hardcoding — one template for all
- **SC-009**: Modifying a JSON content file and refreshing the browser shows the updated content within 5 seconds (no conversion step needed for local preview; conversion only needed for APIM deployment)
