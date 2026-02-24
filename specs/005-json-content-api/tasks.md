# Tasks: JSON Content API & Two-API Architecture

**Input**: Design documents from `/specs/005-json-content-api/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are included in the Polish phase to update existing test suites for new infrastructure.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Content source**: `content/pages/` (JSON content files)
- **APIM fragments**: `infrastructure/modules/apim/fragments/` (generated XML)
- **APIM policies**: `infrastructure/modules/apim/policies/` (routing XML)
- **APIM operations**: `infrastructure/modules/apim/operations/` (operation JSON)
- **Scripts**: `infrastructure/scripts/` (PowerShell conversion & dev server)
- **Web source**: `src/web/` (HTML, JS, CSS — client-side)
- **Bicep IaC**: `infrastructure/modules/apim/main.bicep`
- **Tests**: `tests/` (Pester tests)

---

## Phase 1: Setup

**Purpose**: Create the structured JSON content files that are the single source of truth for all downstream tasks.

- [ ] T001 Create JSON content files for pages 100-110 by converting existing .txt files to structured JSON format in content/pages/page-{100-110}.json

**Details for T001**: Convert each `content/pages/page-{N}.txt` to `content/pages/page-{N}.json` following the schema defined in `contracts/json-schema.md`. Each file must include `pageNumber`, `title`, `category`, `content`, `navigation` (with correct `prev`/`next` chain), and optionally `severity` and `metadata`. Content text should preserve the original `.txt` body using `\n` for line breaks. Page 100 has `prev: null`, page 110 has `next: null`.

**Checkpoint**: All 11 JSON content files valid and ready for downstream consumption

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

No foundational phase tasks are required. The JSON content files created in Setup are the only shared prerequisite, and they are sufficient for all three user stories to begin.

**Checkpoint**: Foundation ready — user story implementation can now begin

---

## Phase 3: User Story 1 — JSON Content Files & Content API (Priority: P1) 🎯 MVP

**Goal**: Create the Content API that serves structured JSON through APIM content fragments generated from the JSON source files with byte-identical payloads.

**Independent Test**: Run `convert-json-to-fragment.ps1` on any JSON content file → verify generated XML fragment returns JSON identical to source. Deploy to APIM → `GET /content/100` returns the JSON with `Content-Type: application/json`.

**FR Coverage**: FR-001, FR-002, FR-003, FR-007, FR-008, FR-009, FR-013, FR-014

### Implementation for User Story 1

- [ ] T002 [P] [US1] Create conversion script with JSON schema validation and XML generation in infrastructure/scripts/convert-json-to-fragment.ps1
- [ ] T003 [P] [US1] Create content routing policy with choose/when dispatch and 404 handling in infrastructure/modules/apim/policies/content-routing-policy.xml
- [ ] T004 [P] [US1] Create Content API operation definition for GET /content/{pageNumber} in infrastructure/modules/apim/operations/get-content.json
- [ ] T005 [US1] Generate content fragments for pages 100-110 by running convert-json-to-fragment.ps1 (output: infrastructure/modules/apim/fragments/content-{100-110}.xml)
- [ ] T006 [US1] Register content fragments, content routing policy, and get-content operation in infrastructure/modules/apim/main.bicep

### Task Details — Phase 3

**T002 — convert-json-to-fragment.ps1**: PowerShell script that:
1. Accepts input path (single file or directory) and output directory
2. Reads each `.json` file and validates against schema (required fields: `pageNumber`, `title`, `category`, `content`, `navigation`; type checks per `contracts/json-schema.md`)
3. Validates `pageNumber` matches filename number
4. Wraps raw JSON in CDATA inside minimal XML fragment: `<fragment><return-response><set-status code="200"/><set-header Content-Type: application/json/><set-header Cache-Control: public, max-age=3600/><set-body><![CDATA[...JSON...]]></set-body></return-response></fragment>`  
5. Validates generated XML is well-formed (`[xml]` cast)
6. Checks fragment size < 256 KB
7. Writes to `content-{N}.xml` in output directory
8. Must be idempotent (FR-013): same input → identical output
9. Reference: research.md Topic 1 (CDATA pattern), Topic 5 (validation approach)

**T003 — content-routing-policy.xml**: APIM policy using `<choose>`/`<when>` pattern (research.md Topic 2):
- Extract `pageNumber` from URL template parameter into context variable
- One `<when>` clause per page (100-110) with `<include-fragment fragment-id="content-{N}" />`
- `<otherwise>` returns 404 JSON: `{"error":"Page not found","pageNumber":null}` with `Content-Type: application/json`
- Input validation: pageNumber must be 3-digit integer (400 response for invalid)
- Reference: existing `page-routing-policy.xml` for structural pattern

**T004 — get-content.json**: APIM operation definition following existing `get-page.json` pattern:
- Method: GET, URL template: `/content/{pageNumber}`
- Template parameter: `pageNumber` (integer, required)
- Response codes: 200 (application/json), 400 (invalid page number), 404 (not found)
- Inbound policy reference: `content-routing-policy.xml`

**T005 — Generate fragments**: Run T002's script against all 11 JSON files. Verify each `content-{N}.xml` has valid XML and byte-identical JSON payload. This is an execution step, not a code-writing step.

**T006 — Bicep registration**: Update `infrastructure/modules/apim/main.bicep` to:
- Register 11 content fragments (`content-100` through `content-110`)
- Register `content-routing-policy` as a named policy
- Register `get-content` operation on `txttv-api` with the content routing policy
- Follow existing patterns for fragment and operation registration in the Bicep file

**Checkpoint**: Content API is fully deployable. `GET /content/{N}` returns JSON for pages 100-110, 404 for unknown pages. JSON payloads are byte-identical to source files.

---

## Phase 4: User Story 2 — Page API with Dynamic Content Loading (Priority: P2)

**Goal**: Replace 11 monolithic full-page APIM fragments with a single shared HTML template that dynamically loads JSON content from the Content API via `fetch()`.

**Independent Test**: Open page in browser (via local dev server or APIM) → HTML shell loads → fetch request to `/content/{N}` visible in Network tab → content rendered in TXT TV style. Same template used for all 11 pages.

**FR Coverage**: FR-004, FR-005, FR-006, FR-012, FR-015

### Implementation for User Story 2

- [ ] T007 [P] [US2] Create content-renderer.js with fetch-based JSON loading and TXT TV rendering in src/web/scripts/content-renderer.js
- [ ] T008 [P] [US2] Update page-template.html with dynamic content loading placeholder and script references in src/web/templates/page-template.html
- [ ] T009 [P] [US2] Update page.html for local development content loading in src/web/page.html
- [ ] T010 [US2] Update convert-web-to-apim.ps1 to generate single page-template.xml fragment in infrastructure/scripts/convert-web-to-apim.ps1
- [ ] T011 [US2] Generate page-template.xml fragment by running updated convert-web-to-apim.ps1 (output: infrastructure/modules/apim/fragments/page-template.xml)
- [ ] T012 [US2] Update page-routing-policy.xml to serve shared page-template for all page numbers in infrastructure/modules/apim/policies/page-routing-policy.xml
- [ ] T013 [US2] Update Bicep to register page-template fragment and remove old monolithic page-N fragment registrations in infrastructure/modules/apim/main.bicep

### Task Details — Phase 4

**T007 — content-renderer.js**: Client-side JavaScript module (ES6, IIFE pattern):
1. Extract page number from URL (query param `?page=N` or path `/page/{N}`)
2. `fetch('/content/${pageNumber}')` with error handling
3. Parse JSON response → render into DOM:
   - `data.category` + `data.title` → header bar
   - `data.severity` → severity badge with color coding (CRITICAL=red, HIGH=orange, etc.)
   - `data.content` → `<pre>` block preserving whitespace and box-drawing characters
   - `data.navigation` → prev/next links, related page links
   - `data.metadata` → footer (CVSS score, published date)
4. Error handling (FR-015): network failure, 404, malformed JSON → TXT TV-styled error display
5. Set `document.title` to `TXT TV - Page {N}`
6. Reference: research.md Topic 4 (fetch pattern with recommended code sample)

**T008 — page-template.html**: Update the existing template to:
1. Replace static `{CONTENT}` placeholder with `<div id="page-content">Loading...</div>`
2. Keep existing CSS (`txttv.css`) and navigation (`navigation.js`) references
3. Add `<script src="/scripts/content-renderer.js"></script>` reference
4. Keep htmx 2.0.8 CDN script tag (per constitution v1.2.2)
5. Inject page number as a data attribute or meta tag for content-renderer.js to read
6. The template must work for ALL page numbers (FR-005) — no page-specific content

**T009 — page.html**: Update for local dev use:
1. Mirror the same structure as page-template.html but with relative paths for local serving
2. Include content-renderer.js reference
3. Support `?page=N` query parameter for page number

**T010 — convert-web-to-apim.ps1**: Update conversion script to:
1. Read `src/web/templates/page-template.html`
2. Inline CSS from `src/web/styles/txttv.css`
3. Inline JS from `src/web/scripts/content-renderer.js` and `src/web/scripts/navigation.js`
4. Wrap in APIM fragment XML: `<fragment><return-response><set-status code="200"/><set-header Content-Type: text/html/><set-body><![CDATA[...HTML...]]></set-body></return-response></fragment>`
5. Output single `page-template.xml` (not per-page fragments)
6. The page number must be extractable at render time — use APIM policy expression to inject into HTML (e.g., `@(context.Variables.GetValueOrDefault<string>("pageNumber"))` in a `<meta>` tag or data attribute)

**T011 — Generate page-template.xml**: Run T010's updated script. Verify output is valid XML with complete HTML shell. This is an execution step.

**T012 — page-routing-policy.xml**: Update existing policy:
1. Change all 11 `<when>` clauses to include the same `page-template` fragment instead of individual `page-{N}` fragments
2. Or simplify: single `<include-fragment fragment-id="page-template" />` with page number validation only
3. Keep 400 validation for invalid page numbers
4. Keep `pageNumber` extraction into context variable (content-renderer.js needs it)

**T013 — Bicep update for US2**: Update `infrastructure/modules/apim/main.bicep` to:
1. Register `page-template` as a new fragment
2. Remove the 11 old monolithic `page-100` through `page-110` fragment registrations
3. Update page routing policy reference if needed
4. Net result: fragment count changes from 11 monolithic → 1 template + 11 content (from T006)

**Checkpoint**: Two-API architecture complete. Page API serves shared template, Content API serves JSON. Browser shows TXT TV pages via fetch-based loading. Old monolithic fragments removed.

---

## Phase 5: User Story 3 — Local Development with JSON Content (Priority: P3)

**Goal**: Provide a PowerShell HTTP server that serves the same two-API pattern locally, enabling developers to iterate on content and templates without deploying to APIM.

**Independent Test**: Run `start-dev-server.ps1` → open `http://localhost:8080/page/100` in browser → HTML loads → JSON fetched from `localhost:8080/content/100` → page renders. Edit a JSON file → refresh → updated content appears immediately.

**FR Coverage**: FR-010, FR-011

### Implementation for User Story 3

- [ ] T014 [US3] Rewrite start-dev-server.ps1 with PowerShell HttpListener serving HTML and JSON content in infrastructure/scripts/start-dev-server.ps1

### Task Details — Phase 5

**T014 — start-dev-server.ps1**: Complete rewrite using `System.Net.HttpListener` (research.md Topic 3):
1. Listen on `http://localhost:8080/`
2. Route mapping:
   - `/` → serve `src/web/index.html` (`text/html`)
   - `/page/{N}` or `/page.html?page={N}` → serve `src/web/page.html` (`text/html`)
   - `/content/{N}` → serve `content/pages/page-{N}.json` (`application/json`) — FR-011
   - `/styles/*.css` → serve from `src/web/styles/` (`text/css`)
   - `/scripts/*.js` → serve from `src/web/scripts/` (`application/javascript`)
3. Content route regex: `^/content/(\d{3})$` → extract page number → map to file
4. MIME type mapping for: `.html`, `.css`, `.js`, `.json`
5. 404 response for missing files/pages
6. Graceful shutdown via `try/finally` with `$listener.Stop()`
7. Console output: log each request URL and status code
8. No CORS needed (same-origin serving from `localhost:8080`)
9. Synchronous `GetContext()` loop (sufficient for single-developer local use)

**Checkpoint**: Local development workflow complete. Developers can edit JSON content files and see changes immediately in the browser without conversion or deployment steps.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Update existing test suites for the new two-API architecture, clean up superseded files, and validate the developer workflow.

- [ ] T015 [P] Update fragment-validation.tests.ps1 to validate content fragment XML structure in tests/policies/fragment-validation.tests.ps1
- [ ] T016 [P] Update policy-validation.tests.ps1 to validate content routing policy in tests/policies/policy-validation.tests.ps1
- [ ] T017 [P] Update WAF SQL injection tests to cover Content API endpoint in tests/security/waf-sql-injection.tests.ps1
- [ ] T018 [P] Update WAF XSS tests to cover Content API endpoint in tests/security/waf-xss.tests.ps1
- [ ] T019 [P] Update page navigation integration tests for two-API fetch flow in tests/integration/page-navigation.tests.ps1
- [ ] T020 Remove superseded .txt content files from content/pages/
- [ ] T021 Run quickstart.md validation to verify end-to-end developer workflow

### Task Details — Phase 6

**T015 — fragment-validation.tests.ps1**: Add Pester tests for content fragments:
- Validate each `content-{N}.xml` is well-formed XML
- Validate `<fragment>` root element structure
- Validate `Content-Type: application/json` header
- Validate CDATA JSON is parseable
- Validate fragment size < 256 KB

**T016 — policy-validation.tests.ps1**: Add Pester tests for content routing:
- Validate `content-routing-policy.xml` is well-formed XML
- Validate each page 100-110 has a corresponding `<when>` clause
- Validate `<otherwise>` returns 404 JSON
- Validate `<include-fragment>` IDs match existing content fragments

**T017-T018 — WAF tests**: Extend existing WAF test files to include:
- SQL injection attempts on `/content/{pageNumber}` (e.g., `/content/100' OR 1=1`)
- XSS payloads in pageNumber parameter (e.g., `/content/<script>alert(1)</script>`)
- Verify WAF blocks malicious requests to Content API

**T019 — integration tests**: Update to verify:
- Page API returns HTML template (not monolithic fragment)
- Content API returns JSON matching source files
- Two-request flow: one HTML + one JSON per page view
- Navigation links work across the two-API pattern

**T020 — .txt cleanup**: Remove `content/pages/page-{100-110}.txt` files since JSON files are now the source of truth. Keep `.txt` files only if there's a documented reason for backward compatibility.

**T021 — quickstart validation**: Follow `specs/005-json-content-api/quickstart.md` step-by-step:
1. Run `start-dev-server.ps1`
2. Open pages in browser
3. Verify JSON content loads and renders
4. Edit a JSON file, refresh, verify update appears
5. Run conversion script, verify fragments generated
6. Confirm all success criteria (SC-001 through SC-009) are achievable

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: No tasks — Setup is sufficient
- **User Story 1 (Phase 3)**: Depends on Setup (T001) — JSON files must exist
- **User Story 2 (Phase 4)**: Depends on Setup (T001) — can be developed in parallel with US1 using local JSON files
- **User Story 3 (Phase 5)**: Depends on Setup (T001) — can be developed in parallel with US1 and US2
- **Polish (Phase 6)**: Depends on all three user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Setup (T001). No dependencies on other stories. Produces the Content API that US2 consumes at render time.
- **User Story 2 (P2)**: Can start after Setup (T001). Development can proceed in parallel with US1 — content-renderer.js works against local JSON or any HTTP server serving JSON. Full APIM integration testing requires US1 content fragments.
- **User Story 3 (P3)**: Can start after Setup (T001). Fully independent — the local dev server reads JSON files directly and serves web files. No dependency on US1 or US2 for core functionality. Full end-to-end local test requires US2's updated page.html/content-renderer.js.

### Within Each User Story

- Models/data before services/scripts
- Scripts/policies before Bicep registration
- Generation steps after script creation
- Core implementation before integration

### Parallel Opportunities Per Phase

**Phase 3 (US1)**: T002, T003, T004 can all run in parallel (different files)
**Phase 4 (US2)**: T007, T008, T009 can all run in parallel (different files)
**Phase 6 (Polish)**: T015-T019 can all run in parallel (different test files)

---

## Parallel Example: User Story 1

```
# These three tasks can run simultaneously (different files, no dependencies):
T002: Create convert-json-to-fragment.ps1        → infrastructure/scripts/
T003: Create content-routing-policy.xml           → infrastructure/modules/apim/policies/
T004: Create get-content.json                     → infrastructure/modules/apim/operations/

# After T002 completes:
T005: Generate content-{100-110}.xml              → infrastructure/modules/apim/fragments/

# After T003, T004, T005 all complete:
T006: Register in Bicep                           → infrastructure/modules/apim/main.bicep
```

## Parallel Example: User Story 2

```
# These three tasks can run simultaneously (different files, no dependencies):
T007: Create content-renderer.js                  → src/web/scripts/
T008: Update page-template.html                   → src/web/templates/
T009: Update page.html                            → src/web/

# After T007 and T008 complete:
T010: Update convert-web-to-apim.ps1              → infrastructure/scripts/

# After T010 completes:
T011: Generate page-template.xml                  → infrastructure/modules/apim/fragments/

# T012 can run in parallel with T010-T011 (different file):
T012: Update page-routing-policy.xml              → infrastructure/modules/apim/policies/

# After T011 and T012 complete:
T013: Update Bicep                                → infrastructure/modules/apim/main.bicep
```

## Parallel Example: Cross-Story

```
# After Setup (T001) completes, all three stories can begin in parallel:
Story 1: T002-T006  (Content API infrastructure)
Story 2: T007-T013  (Page API dynamic loading)
Story 3: T014       (Local dev server)

# Polish after all stories complete:
T015-T019 can all run in parallel (different test files)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001 — create JSON content files)
2. Complete Phase 3: User Story 1 (T002-T006 — Content API)
3. **STOP and VALIDATE**: Deploy Content API → `GET /content/100` returns correct JSON
4. Verify SC-001 (byte-identical JSON), SC-004 (conversion < 10s), SC-007 (schema validation)

### Incremental Delivery

1. Setup (T001) → JSON content files ready
2. Add User Story 1 (T002-T006) → Content API works → **MVP deployed**
3. Add User Story 2 (T007-T013) → Full two-API architecture → SC-002, SC-003, SC-008 met
4. Add User Story 3 (T014) → Local dev workflow → SC-005, SC-006, SC-009 met
5. Polish (T015-T021) → Tests updated, cleanup done

### Each Story Adds Value Without Breaking Previous

- **After US1**: Content API is live, JSON files are source of truth (old page fragments still serve pages)
- **After US2**: Pages use shared template + Content API (old fragments removed, size reduction achieved)
- **After US3**: Developers can iterate locally with full two-API fidelity

---

## FR-to-Task Traceability

| FR | Description | Tasks |
|-----|------------|-------|
| FR-001 | JSON content files with schema | T001 |
| FR-002 | Content API operation | T004, T006 |
| FR-003 | Byte-identical JSON in fragments | T002, T005 |
| FR-004 | Page API HTML shell | T008, T011 |
| FR-005 | Shared page template | T008, T012, T013 |
| FR-006 | fetch-based content loading | T007, T008 |
| FR-007 | Conversion script | T002 |
| FR-008 | Schema validation | T002 |
| FR-009 | XML validation | T002 |
| FR-010 | Local HTTP dev server | T014 |
| FR-011 | Content route mapping | T014 |
| FR-012 | Client-side renderer | T007 |
| FR-013 | Idempotent conversion | T002 |
| FR-014 | Fragment storage conventions | T005, T006 |
| FR-015 | Error handling for Content API | T003, T007 |

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- JSON content files (T001) are the single prerequisite for all three stories
- Conversion script (T002) is the most complex individual task — budget time accordingly
