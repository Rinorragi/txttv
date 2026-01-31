# Tasks: TXT TV Application

**Feature**: 001-txt-tv-app  
**Input**: Design documents from `/specs/001-txt-tv-app/`  
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓, quickstart.md ✓

**Implementation Note**: APIM policy fragments are the PRIMARY implementation surface. Backend F# code is minimal/demo only. Focus on policy design and HTMX-based frontend.

**Tests**: Not explicitly requested in feature specification - focus on implementation and manual validation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

Using **APIM Policy-Centric** structure:
- `infrastructure/modules/` for Bicep modules
- `infrastructure/modules/apim/policies/` for APIM policy XML files
- `infrastructure/modules/apim/fragments/` for policy fragments
- `src/backend/TxtTv.Functions/` for F# backend code
- `content/pages/` for source text files

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Create directory structure per implementation plan (infrastructure/, src/, content/, tests/)
- [ ] T002 Initialize .NET 10 F# Azure Functions project in src/backend/TxtTv.Functions/
- [ ] T003 [P] Create PowerShell script infrastructure/scripts/convert-txt-to-fragment.ps1
- [ ] T004 [P] Create GitHub Actions workflow file .github/workflows/deploy.yml
- [ ] T005 [P] Create .gitignore for Azure Functions and Bicep outputs

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T006 Create Bicep module infrastructure/modules/storage/main.bicep for Azure Blob Storage
- [ ] T007 Create Bicep module infrastructure/modules/backend/main.bicep for Azure Functions
- [ ] T008 Create Bicep module infrastructure/modules/apim/main.bicep for API Management (Consumption tier)
- [ ] T009 Create Bicep module infrastructure/modules/app-gateway/main.bicep for Application Gateway
- [ ] T010 Create Bicep module infrastructure/modules/waf/main.bicep for WAF policy with OWASP CRS 3.2
- [ ] T011 Create dev environment orchestration infrastructure/environments/dev/main.bicep
- [ ] T012 Create dev environment parameters infrastructure/environments/dev/parameters.json
- [ ] T013 [P] Add rate limiting rule in infrastructure/modules/waf/rules/rate-limiting.bicep (100 req/min per IP)
- [ ] T014 [P] Add SQL injection protection rule in infrastructure/modules/waf/rules/sql-injection.bicep
- [ ] T015 [P] Add XSS protection rule in infrastructure/modules/waf/rules/xss-protection.bicep
- [ ] T016 Create global APIM policy infrastructure/modules/apim/policies/global-policy.xml (logging, CORS, security headers)
- [ ] T017 Deploy dev environment infrastructure to Azure (creates all resources)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - View TXT TV Pages (Priority: P1) 🎯 MVP

**Goal**: Users can access the application and view a default TXT TV page with news content

**Independent Test**: Navigate to Application Gateway public IP and verify page 100 displays with news content

### Implementation for User Story 1

- [ ] T018 [P] [US1] Create sample content file content/pages/page-100.txt with breaking news
- [ ] T019 [P] [US1] Create sample content file content/pages/page-101.txt with technology news
- [ ] T020 [P] [US1] Create sample content file content/pages/page-102.txt with weather news
- [ ] T021 [US1] Implement PowerShell conversion script to generate policy fragments from text files (include 2000 character limit validation per FR-013)
- [ ] T021b [US1] Validate generated policy fragments: XML schema check, 2000 char limit enforcement, HTML syntax validation
- [ ] T022 [US1] Run conversion script to create infrastructure/modules/apim/fragments/page-100.xml (initial manual run for MVP; T050 automates in CI/CD)
- [ ] T023 [US1] Run conversion script to create infrastructure/modules/apim/fragments/page-101.xml (initial manual run for MVP; T050 automates in CI/CD)
- [ ] T024 [US1] Run conversion script to create infrastructure/modules/apim/fragments/page-102.xml (initial manual run for MVP; T050 automates in CI/CD)
- [ ] T025 [US1] Create error page fragment infrastructure/modules/apim/fragments/error-page.xml
- [ ] T026 [US1] Create navigation template fragment infrastructure/modules/apim/fragments/navigation-template.xml with HTMX attributes
- [ ] T027 [US1] Add inline teletext CSS to fragments (monospace font, black background, green text, blue header)
- [ ] T028 [US1] Create page routing policy infrastructure/modules/apim/policies/page-routing-policy.xml with choose/when conditions
- [ ] T029 [US1] Create APIM operation definition infrastructure/modules/apim/operations/get-page.json for GET /page/{pageNumber}
- [ ] T030 [US1] Create APIM operation definition infrastructure/modules/apim/operations/get-home.json for GET / (redirect to page 100)
- [ ] T031 [US1] Update APIM Bicep module to deploy policy fragments and operations
- [ ] T032 [US1] Deploy updated APIM configuration to Azure
- [ ] T033 [US1] Verify page 100 displays correctly in browser via Application Gateway public IP

**Checkpoint**: At this point, User Story 1 should be fully functional - users can view TXT TV pages

---

## Phase 4: User Story 2 - Navigate Between Pages (Priority: P2)

**Goal**: Users can navigate between pages using page number input and arrow controls

**Independent Test**: Navigate to page 100, then use next/previous arrows and page number input to move between pages 100-102

### Implementation for User Story 2

- [ ] T034 [P] [US2] Add HTMX script reference to all policy fragments (CDN: https://unpkg.com/htmx.org@1.9.10)
- [ ] T035 [US2] Implement previous page button with hx-get="/page/{currentPage-1}" in navigation template
- [ ] T036 [US2] Implement next page button with hx-get="/page/{currentPage+1}" in navigation template
- [ ] T037 [US2] Implement page number input field with validation (min="100" max="999")
- [ ] T038 [US2] Implement "Go to Page" button with hx-get and hx-include for dynamic page navigation
- [ ] T039 [US2] Add hx-target="#content" to all navigation controls for partial page updates
- [ ] T040 [US2] Add hx-push-url="true" to navigation controls for browser history support
- [ ] T041 [US2] Update page routing policy to handle page number extraction from route parameters
- [ ] T042 [US2] Add page number validation in APIM policy (400 Bad Request for invalid input)
- [ ] T043 [US2] Add boundary handling for first page (disable previous on page 100)
- [ ] T044 [US2] Deploy updated APIM policies and fragments
- [ ] T045 [US2] Test navigation: page 100 → next → page 101, previous → page 100, direct input page 102

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently - users can view and navigate pages

---

## Phase 5: User Story 3 - Content Management via Text Files (Priority: P3)

**Goal**: Content can be updated by modifying text files and redeploying policy fragments

**Independent Test**: Modify content/pages/page-100.txt, run conversion script, redeploy, verify updated content displays

### Implementation for User Story 3

- [ ] T046 [P] [US3] Document conversion script usage in README or quickstart guide
- [ ] T047 [P] [US3] Create additional sample pages: page-103.txt through page-110.txt (8 pages)
- [ ] T048 [US3] Add validation to conversion script: check UTF-8 encoding, max 2000 characters
- [ ] T049 [US3] Add special character escaping in conversion script (handle XML-unsafe characters)
- [ ] T050 [US3] Automate conversion script in GitHub Actions workflow (on content/ file changes)
- [ ] T051 [US3] Update APIM policy routing to handle pages 103-110 in choose/when conditions
- [ ] T052 [US3] Generate policy fragments for pages 103-110 using conversion script
- [ ] T053 [US3] Deploy updated fragments to APIM
- [ ] T054 [US3] Test content update workflow: modify page-105.txt, run script, redeploy, verify changes
- [ ] T055 [US3] Test missing page scenario: navigate to page 500, verify error page displays with "return to page 100" link

**Checkpoint**: All user stories (1-3) should now be independently functional - full content management capability

---

## Phase 6: User Story 4 - Backend Connectivity Test (Priority: P4)

**Goal**: Demonstrate WAF and APIM protection by calling backend F# function through complete security stack

**Independent Test**: Navigate to /backend-test endpoint and verify "you found through the maze" message is returned

### Implementation for User Story 4

- [ ] T056 [P] [US4] Implement F# HTTP trigger function in src/backend/TxtTv.Functions/MazeMessage.fs
- [ ] T057 [P] [US4] Configure function to return 200 OK with "you found through the maze" message
- [ ] T058 [P] [US4] Add function project file TxtTv.Functions.fsproj with .NET 10 SDK
- [ ] T059 [P] [US4] Create host.json with Azure Functions runtime v4 configuration
- [ ] T060 [US4] Deploy F# Function App to Azure
- [ ] T061 [US4] Create backend policy infrastructure/modules/apim/policies/backend-policy.xml to forward requests
- [ ] T062 [US4] Create APIM operation definition infrastructure/modules/apim/operations/get-backend-test.json for GET /backend-test
- [ ] T063 [US4] Configure APIM backend to point to Azure Functions URL
- [ ] T064 [US4] Add correlation ID and X-Backend-Called header in APIM backend policy
- [ ] T065 [US4] Add error handling in APIM policy for backend unavailability (503 response)
- [ ] T066 [US4] Deploy APIM backend policy and operation
- [ ] T067 [US4] Test backend connectivity: navigate to /backend-test via Application Gateway
- [ ] T068 [US4] Verify "you found through the maze" message displays
- [ ] T069 [US4] Check Application Insights for APIM policy traces and correlation IDs

**Checkpoint**: All user stories (1-4) should now be independently functional - complete demonstration ready

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Performance optimization, monitoring, and production readiness

- [ ] T070 [P] Add Application Insights instrumentation to APIM policies (custom dimensions)
- [ ] T071 [P] Create Azure Monitor workbook for WAF metrics (blocks, allowed requests, rule matches)
- [ ] T072 [P] Create Azure Monitor workbook for APIM metrics (page views, response times, errors)
- [ ] T073 [P] Add cache headers to APIM policy responses (Cache-Control: public, max-age=300)
- [ ] T074 [P] Create Pester test infrastructure/tests/infrastructure/bicep-validation.tests.ps1
- [ ] T075 [P] Create Pester test infrastructure/tests/policies/policy-validation.tests.ps1 (XML validation)
- [ ] T076 [P] Create Pester test infrastructure/tests/security/waf-sql-injection.tests.ps1
- [ ] T077 [P] Create Pester test infrastructure/tests/security/waf-xss.tests.ps1
- [ ] T078 [P] Create Pester test infrastructure/tests/integration/page-navigation.tests.ps1
- [ ] T079 Add GitHub Actions workflow validation gates (Bicep lint, policy validation, security scan)
- [ ] T080 [P] Create staging environment infrastructure/environments/staging/main.bicep
- [ ] T081 [P] Create prod environment infrastructure/environments/prod/main.bicep
- [ ] T082 Document rollback procedure in quickstart.md
- [ ] T083 Add performance testing results to plan.md (verify <1s navigation, <2s page load)
- [ ] T084 Create demo video or screenshot of working application
- [ ] T085 [P] Add page number bounds validation task: Validate APIM policy rejects page numbers <100 or >999 per FR-013; add Pester test for edge cases (99, 1000)

---

## Dependencies

### Story Completion Order
1. **Setup (Phase 1)** → Must complete first
2. **Foundational (Phase 2)** → Must complete before any user story
3. **US1 (Phase 3)** → MVP, no dependencies on other stories
4. **US2 (Phase 4)** → Depends on US1 (needs pages to navigate)
5. **US3 (Phase 5)** → Depends on US1 (needs existing pages to update)
6. **US4 (Phase 6)** → Independent of US1-US3 (can be done in parallel after Phase 2)
7. **Polish (Phase 7)** → Should complete after all user stories

### Critical Path
```
Phase 1 (Setup) 
  → Phase 2 (Foundational) 
    → Phase 3 (US1 - View Pages) 
      → Phase 4 (US2 - Navigation) 
        → Phase 5 (US3 - Content Mgmt)
    → Phase 6 (US4 - Backend Test - can run in parallel with US1-US3)
  → Phase 7 (Polish - after all stories complete)
```

### Parallel Opportunities

**Within Phase 2 (Foundational)**:
- T013, T014, T015 (WAF rules) can run in parallel
- Bicep modules (T006-T010) can be developed in parallel, deployed together

**Within Phase 3 (US1)**:
- T018, T019, T020 (content files) can run in parallel
- T025, T026 (fragments) can run in parallel
- T029, T030 (operation definitions) can run in parallel

**Within Phase 4 (US2)**:
- T034, T035, T036, T037, T038 (navigation controls) can run in parallel

**Within Phase 5 (US3)**:
- T046, T047 (documentation and sample pages) can run in parallel

**Within Phase 6 (US4)**:
- T056, T057, T058, T059 (F# function implementation) can run in parallel

**Within Phase 7 (Polish)**:
- T070, T071, T072, T073 (monitoring) can run in parallel
- T074-T078 (test creation) can run in parallel
- T080, T081 (environment creation) can run in parallel

---

## Implementation Strategy

### MVP First (Phase 3 - US1)
**Goal**: Get page 100 displaying in browser
**Effort**: ~2-3 hours
**Deliverable**: Single page viewable through Application Gateway

**Critical tasks**:
- T001-T017 (Setup + Foundation)
- T018-T033 (US1 implementation)

### Incremental Delivery
1. **MVP** (US1): View single page
2. **V1.1** (US1 + US2): Add navigation
3. **V1.2** (US1 + US2 + US3): Add content management
4. **V1.3** (Complete): Add backend test + polish

### Validation Points
- After T033: Page 100 displays ✓
- After T045: Navigation works ✓
- After T055: Content updates work ✓
- After T069: Backend connectivity works ✓
- After T084: Production ready ✓

---

## Task Count Summary

- **Phase 1 (Setup)**: 5 tasks
- **Phase 2 (Foundational)**: 12 tasks (blocking)
- **Phase 3 (US1)**: 17 tasks (MVP) — includes T021b validation
- **Phase 4 (US2)**: 12 tasks
- **Phase 5 (US3)**: 10 tasks
- **Phase 6 (US4)**: 14 tasks
- **Phase 7 (Polish)**: 16 tasks — includes T085 bounds validation

**Total**: 86 tasks

**Parallel opportunities**: 35 tasks marked [P] can run in parallel within their phase

**Estimated MVP effort**: 34 tasks (Phase 1 + Phase 2 + Phase 3)

---

## Notes

- All tasks follow strict checklist format: `- [ ] [ID] [P?] [Story?] Description with file path`
- APIM policy fragments are the PRIMARY implementation - spend most effort here
- F# backend is minimal (1 function, ~10 lines of code)
- HTMX provides all frontend interactivity (no complex JavaScript)
- Bicep modules should be independently deployable
- Test each phase checkpoint before proceeding to next phase
- Rollback via Bicep deployment history if needed
