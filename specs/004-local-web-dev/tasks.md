# Tasks: Local Web Development Workflow

**Input**: Design documents from `specs/004-local-web-dev/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are OPTIONAL in this feature. Test tasks are included based on quickstart.md test scenarios.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Create directory structure: src/web/, src/web/templates/, src/web/styles/, src/web/scripts/
- [ ] T002 [P] Create directory structure: infrastructure/modules/apim/fragments/
- [ ] T003 [P] Create directory structure: content/pages/
- [ ] T004 [P] Create README.md in src/web/ documenting the local development workflow
- [ ] T005 [P] Create helper script infrastructure/scripts/start-dev-server.ps1 to open HTML in browser

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core components that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T006 [P] Create txttv.css stylesheet in src/web/styles/txttv.css with retro text TV styling (black background, green text, monospace font)
- [ ] T007 [P] Create navigation.js in src/web/scripts/navigation.js with keyboard shortcuts (arrow keys, p/n for prev/next, h for home)
- [ ] T008 Create page-template.html in src/web/templates/page-template.html with placeholders: {PAGE_NUMBER}, {CONTENT}, {STYLE}, {SCRIPT}
- [ ] T009 [P] Create Validation-Functions.ps1 in infrastructure/scripts/ implementing Test-XmlWellFormedness function
- [ ] T010 [P] Add Test-ApimSchema function to Validation-Functions.ps1 for fragment structure validation (fragment, set-body, CDATA)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Local Development Experience (Priority: P1) 🎯 MVP

**Goal**: Enable developers to create and test the text TV interface locally in browser with immediate visual feedback

**Independent Test**: Open src/web/index.html directly in browser and verify navigation works between pages 100-110 with static content displayed

### Implementation for User Story 1

- [ ] T011 [P] [US1] Create index.html in src/web/index.html as landing page with page selector/index (100-110)
- [ ] T012 [P] [US1] Create page.html in src/web/page.html as page viewer template with htmx integration
- [ ] T013 [P] [US1] Create page-100.txt in content/pages/page-100.txt with CVE-2026-12345 critical vulnerability alert content
- [ ] T014 [P] [US1] Create page-101.txt in content/pages/page-101.txt with technical analysis content
- [ ] T015 [P] [US1] Create page-102.txt in content/pages/page-102.txt with mitigation steps content
- [ ] T016 [P] [US1] Create page-103.txt in content/pages/page-103.txt with Equifax 2017 case study content
- [ ] T017 [US1] Test browser workflow: open index.html, navigate to pages, verify keyboard shortcuts work, confirm no dynamic content loading (Network tab shows zero fetch/XHR for content)
- [ ] T017b [US1] Test change iteration speed (SC-002): modify content file, re-run conversion, refresh browser, verify changes visible within 10 seconds total

**Checkpoint**: At this point, User Story 1 should be fully functional - local interface works in browser with static content

---

## Phase 4: User Story 2 - Policy Conversion Automation (Priority: P2)

**Goal**: Convert locally-developed web interface into APIM policy fragments via automated script

**Independent Test**: Run convert-web-to-apim.ps1 and verify generated XML fragments under infrastructure/modules/apim/fragments/ match expected APIM structure with embedded HTML

### Implementation for User Story 2

- [ ] T018 [US2] Create convert-web-to-apim.ps1 in infrastructure/scripts/ with parameter definitions: SourcePath, OutputPath, ContentPath, Pages, Validate, Force, WhatIf, Verbose
- [ ] T019 [US2] Implement template reading logic in convert-web-to-apim.ps1: read page-template.html from src/web/templates/
- [ ] T020 [US2] Implement content file reading: read page-{NUMBER}.txt from content/pages/
- [ ] T021 [US2] Implement placeholder replacement: replace {PAGE_NUMBER}, {CONTENT} tokens in template
- [ ] T022 [US2] Implement CSS injection: read txttv.css and inject into {STYLE} placeholder
- [ ] T023 [US2] Implement JavaScript injection: read navigation.js and inject into {SCRIPT} placeholder (or use CDN reference for htmx)
- [ ] T024 [US2] Implement CDATA escaping: wrap HTML in CDATA section, escape any ]]> sequences in content
- [ ] T025 [US2] Implement XML fragment generation: wrap HTML in <fragment><set-body> structure per policy-fragment-schema.md
- [ ] T026 [US2] Implement UTF-8 BOM encoding: write generated fragments with UTF-8 BOM for Azure compatibility
- [ ] T027 [US2] Add Test-SecurityCompliance function to Validation-Functions.ps1: scan for XSS patterns, script injection, validate encoding
- [ ] T028 [US2] Add Test-FragmentIntegration function to Validation-Functions.ps1: validate fragment size (<256 KB), test CDATA escaping
- [ ] T029 [US2] Add Invoke-FragmentValidation function to Validation-Functions.ps1: orchestrate 4-layer validation (XML → Schema → Security → Integration)
- [ ] T030 [US2] Integrate validation into convert-web-to-apim.ps1: call Invoke-FragmentValidation for each generated fragment
- [ ] T031 [US2] Implement -Force parameter handling: skip overwrite prompts when specified
- [ ] T032 [US2] Implement -WhatIf parameter: show what would be generated without creating files
- [ ] T033 [US2] Add verbose logging: output detailed progress and validation results when -Verbose specified
- [ ] T034 [US2] Test conversion: run script on pages 100-103, verify fragments generated in <5 seconds, all 4 validation layers pass, fragment sizes 16-17 KB
- [ ] T034b [US2] Test idempotency (FR-011): run conversion twice on same input, verify bit-identical output and no file timestamp changes

**Checkpoint**: At this point, User Story 2 should be fully functional - conversion script generates valid APIM fragments from local web source

---

## Phase 5: User Story 3 - Development-Deployment Parity (Priority: P3)

**Goal**: Verify local development environment accurately represents production deployment

**Independent Test**: Deploy generated fragments to dev APIM, open side-by-side with local HTML, verify visual and functional parity

### Tests for User Story 3

- [ ] T035 [P] [US3] Create fragment-validation.tests.ps1 in tests/policies/ for Pester integration tests
- [ ] T036 [P] [US3] Add XML well-formedness tests to fragment-validation.tests.ps1: validate all generated fragments parse correctly
- [ ] T037 [P] [US3] Add APIM schema tests to fragment-validation.tests.ps1: validate fragment structure (fragment, set-body, CDATA)
- [ ] T038 [P] [US3] Add security scanning tests to fragment-validation.tests.ps1: verify no XSS patterns, proper encoding
- [ ] T039 [P] [US3] Add size limit tests to fragment-validation.tests.ps1: verify fragments under 256 KB
- [ ] T040 [P] [US3] Add CDATA escaping tests to fragment-validation.tests.ps1: verify ]]> sequences properly escaped
- [ ] T041b [P] [US3] Create error handling tests: test malformed HTML template, missing content files, verify graceful error messages
- [ ] T041c [P] [US3] Create edge case tests: test content with special XML characters (&, <, >, ]]>), verify proper escaping
- [ ] T041 [US3] Run all Pester tests and verify they pass (note: may have Pester v5 syntax compatibility issues with IDE)

### Manual Verification for User Story 3

- [ ] T042 Create Validate-ApimPolicies.ps1 in infrastructure/scripts/ as master validation script for CI/CD integration
- [ ] T043 [P] Create visual-parity-checklist.md documenting side-by-side comparison criteria (layout, colors, fonts, navigation, content)
- [ ] T044 [P] Create sample routing policy in infrastructure/modules/apim/policies/routing-example.xml showing include-fragment usage
- [ ] T045 [P] Create API operation definition in infrastructure/modules/apim/operations/get-page.xml mapping GET /page/{id} to fragments
- [ ] T046 Deploy generated fragments to dev APIM environment (requires Azure access)
- [ ] T047 Configure routing policy in dev APIM to serve fragments on /page/{id} endpoints
- [ ] T048 Open local src/web/page.html in browser (local version)
- [ ] T049 Open https://[apim-dev].azure-api.net/page/100 in browser (deployed version)
- [ ] T050 Perform visual parity verification using visual-parity-checklist.md: compare layout, styling, navigation, content rendering
- [ ] T051 Test navigation parity: verify keyboard shortcuts work identically in both local and deployed versions
- [ ] T052 Test content parity: verify all pages 100-110 display identical content in both environments
- [ ] T053 Verify performance: confirm page load times are comparable (<2 second difference)

**Checkpoint**: All user stories should now be independently functional with verified dev-prod parity

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and production readiness

- [ ] T054 [P] Update README.md in repository root with quickstart instructions from quickstart.md
- [ ] T055 [P] Create tests/integration/page-navigation.tests.ps1 for end-to-end navigation testing (if needed)
- [ ] T056 [P] Create GitHub Actions workflow .github/workflows/validate-policies.yml to run Validate-ApimPolicies.ps1 on PR
- [ ] T057 [P] Create troubleshooting section in src/web/README.md documenting common issues (CDATA escaping, encoding, size limits)
- [ ] T058 [P] Create VS Code tasks.json with task to run conversion script (optional convenience)
- [ ] T059 Run all quickstart.md validation scenarios and verify documentation accuracy
- [ ] T060 Code review: verify all tasks completed, CDATA escaping correct, validation comprehensive
- [ ] T061 [P] Create content files for pages 104-110 with additional cyber security news content (optional: spec focuses on 4 core examples 100-103)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Depends on US1 templates and content existing - Tests conversion of US1 artifacts
- **User Story 3 (P3)**: Depends on US2 conversion script existing - Tests output of US2 conversion

### Within Each User Story

**User Story 1**:
- T011-T012 (HTML files) can run in parallel
- T013-T016 (content files) can run in parallel
- T017 (testing) depends on all prior tasks

**User Story 2**:
- T018 (script shell) must be first
- T019-T026 (core conversion logic) sequential (each builds on previous)
- T027-T029 (validation functions) can run in parallel with T023-T026
- T030-T033 (parameter handling) can be added in any order after T018
- T034 (testing) depends on all prior tasks

**User Story 3**:
- T035-T040 (Pester tests) can all run in parallel
- T041b-T041c (error/edge tests) can run in parallel
- T042-T045 (documentation/policies) can all run in parallel
- T046-T053 (manual verification) must be sequential
- T041, T041b, T041c testing depends on T035-T040

### Parallel Opportunities

- **Phase 1**: T002, T003, T004, T005 can run in parallel (different directories/files)
- **Phase 2**: T006, T007, T009, T010 can run in parallel (different files)
- **Phase 3 (US1)**: T011-T016 can run in parallel (all different files)
- **Phase 5 (US3)**: T035-T040 can run in parallel (different test functions), T041b-T041c can run in parallel, T042-T045 can run in parallel (different files)
- **Phase 6**: T054-T058, T061 can run in parallel (different files)

---

## Parallel Example: User Story 1

```bash
# Launch all content files for User Story 1 together:
Task: "Create page-100.txt in content/pages/page-100.txt with CVE content"
Task: "Create page-101.txt in content/pages/page-101.txt with technical analysis"
Task: "Create page-102.txt in content/pages/page-102.txt with mitigation steps"
Task: "Create page-103.txt in content/pages/page-103.txt with case study"

# Launch HTML files for User Story 1 together:
Task: "Create index.html in src/web/index.html"
Task: "Create page.html in src/web/page.html"
```

---

## Parallel Example: User Story 2 Validation

```bash
# Launch validation function implementations together:
Task: "Add Test-SecurityCompliance to Validation-Functions.ps1"
Task: "Add Test-FragmentIntegration to Validation-Functions.ps1"
Task: "Add Invoke-FragmentValidation to Validation-Functions.ps1"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T005)
2. Complete Phase 2: Foundational (T006-T010) - CRITICAL - blocks all stories
3. Complete Phase 3: User Story 1 (T011-T017)
4. **STOP and VALIDATE**: Test User Story 1 independently - open in browser, verify static content works
5. Deploy/demo if ready (functional local web interface)

### Incremental Delivery

1. Complete Setup + Foundational (T001-T010) → Foundation ready
2. Add User Story 1 (T011-T017) → Test independently → **MVP CHECKPOINT** (local development works!)
3. Add User Story 2 (T018-T034) → Test independently → **CONVERSION CHECKPOINT** (can generate APIM fragments!)
4. Add User Story 3 (T035-T053) → Test independently → **PARITY CHECKPOINT** (prod matches local!)
5. Polish (T054-T061) → **PRODUCTION READY**

Each checkpoint adds value without breaking previous functionality.

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together (T001-T010)
2. Once Foundational is done:
   - Developer A: User Story 1 (T011-T017)
   - Developer B: User Story 2 (T018-T034) - can start after US1 templates exist
   - Developer C: User Story 3 tests (T035-T041) - can start after US2 conversion exists
3. Stories complete and integrate independently

---

## Validation Checklist (Per User Story)

### User Story 1 Validation
- [ ] Can open index.html in browser without server
- [ ] Can navigate between pages 100-110
- [ ] Keyboard shortcuts work (arrows, p/n, h)
- [ ] Content displays correctly in retro text TV style
- [ ] No dynamic content loading (Network tab shows zero fetch for content)
- [ ] Change iteration completes within 10 seconds (T017b)

### User Story 2 Validation
- [ ] Conversion script runs in <5 seconds for 11 pages
- [ ] All 4 validation layers pass (XML, Schema, Security, Integration)
- [ ] Fragments generated in correct directory structure
- [ ] Fragment sizes 16-17 KB (under 256 KB limit)
- [ ] UTF-8 BOM encoding present
- [ ] CDATA escaping correct (no unescaped ]]> sequences)
- [ ] Idempotency verified: duplicate runs produce identical output (T034b)

### User Story 3 Validation
- [ ] Visual parity verified between local and deployed
- [ ] Navigation parity verified (same keyboard shortcuts)
- [ ] Content parity verified (identical rendering)
- [ ] Performance parity verified (<2s load time difference)
- [ ] All Pester tests pass (or run via direct validation if IDE issues)
- [ ] Error handling tested: malformed HTML, missing files (T041b)
- [ ] Edge cases tested: special XML characters properly escaped (T041c)

---

## Known Issues

### Pester v5 IDE Compatibility
**Issue**: fragment-validation.tests.ps1 may cause IDE freezes when run via PowerShell extension  
**Root Cause**: Pester v5 syntax differences, test discovery conflicts  
**Workaround**: Run validation directly via `Invoke-FragmentValidation` function from Validation-Functions.ps1  
**Impact**: Low - conversion script has validation built-in, Pester tests are supplementary  

---

## Notes

- [P] tasks = different files, no dependencies - can run in parallel
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All content uses fake cyber security news examples (CVEs, incidents, analysis)
- Static content architecture: NO dynamic loading at runtime (content-loader.js removed)
- Exact file paths included in task descriptions for clarity
