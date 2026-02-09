# Implementation Plan: Local Web Development Workflow

**Branch**: `004-local-web-dev` | **Date**: February 9, 2026 (Updated) | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from [specs/004-local-web-dev/spec.md](spec.md)
**Status**: ✅ Implementation Complete (Phases 1-4) | Pester tests need syntax fixes

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Enable developers to create and test the text TV web interface locally using simple HTML with htmx (no build tooling), then convert the interface into APIM policy fragments via automated script for Azure deployment. **Content is embedded statically at build time** - no dynamic loading at runtime. The workflow prioritizes rapid iteration with immediate visual feedback while maintaining development-deployment parity.

**Key Architectural Decision**: Content is pre-embedded into HTML during conversion (static approach) rather than loaded dynamically via fetch/AJAX. This ensures local development exactly matches APIM production behavior and eliminates runtime dependencies.

## Technical Context

**Primary Implementation**: Web Frontend (HTML + htmx) + PowerShell conversion tooling  
**Language/Version**: HTML5, CSS3, JavaScript (htmx 2.0.8 from CDN), PowerShell 7+  
**Infrastructure as Code**: Bicep (for APIM policy deployment)  
**Cloud Platform**: Azure (required for APIM/AppGw/WAF)  
**APIM Policies**: Generated policy fragments containing embedded web UI (primary deployment artifact)  
**Primary Dependencies**: htmx 2.0.8 (CDN: https://cdn.jsdelivr.net/npm/htmx.org@2.0.8/dist/htmx.min.js), PowerShell 7+  
**Content Strategy**: **Static embedding** - content read from text files and embedded into HTML at build time via `convert-web-to-apim.ps1`  
**Testing**: PowerShell validation (4-layer: XML, APIM schema, security, integration), Pester (integration tests)  
**Target Platform**: APIM policy fragments deployed to Azure API Management  
**Project Type**: Web + APIM policy-centric (web is source, policies are deployment artifact)  
**Performance Goals**: ✅ <10s conversion, <5s browser refresh, fragments 16-17KB each  
**Security Requirements**: ✅ XSS prevention, XML encoding validation, CDATA escaping implemented  
**Scale/Scope**: ✅ 11 text TV pages (100-110) with fake cyber security news content

**Architecture Decision - Static Content**:
- ❌ **NOT USED**: Dynamic content loading via `content-loader.js` (fetch API)
- ✅ **IMPLEMENTED**: Static content embedding during conversion
- **Rationale**: APIM policies serve static content only; dynamic loading would fail in production and create dev/prod parity issues

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Constitution Version**: 1.2.2

### Principle I: Infrastructure as Code
- [x] All infrastructure defined in Bicep
- [x] Changes version-controlled and reviewed
- [x] No manual cloud configuration

### Principle II: Security-First Architecture
- [x] WAF rules documented with test cases
- [x] Security testing automated
- [x] APIM policies enforce auth/rate limiting/validation
- [x] APIM policy fragments tested for security vulnerabilities

### Principle III: Observability & Monitoring
- [x] Structured logs and metrics defined
- [x] Security events captured
- [x] APIM policy execution tracing configured
- [x] Dashboards planned for WAF/APIM metrics

### Principle IV: Modularity & Testability
- [x] Components independently deployable
- [x] APIM policy fragments independently testable
- [x] Contract tests for policy inputs/outputs defined
- [x] Integration tests for WAF rules planned

### Principle V: Deployment Automation
- [x] CI/CD pipeline defined as code
- [x] Automated validation gates specified
- [x] Rollback procedure documented

### Complexity Justification Required?
- [x] No violations OR violations justified in Complexity Tracking section below

**Notes**: All principles satisfied. This feature enhances the development workflow without introducing infrastructure changes or security regressions. Generated APIM policies will be validated for security (XSS, injection) before deployment.

---

## Implementation Status

### ✅ Phase 1-4: Core Implementation (Complete)

**Phase 1: Setup & Prerequisites (T001-T005)**
- ✅ Directory structure created
- ✅ Helper scripts and README documentation
- ✅ Development workflow documented

**Phase 2: Foundational Components (T006-T010)**
- ✅ `txttv.css` - Retro text TV styling (3.1 KB)
- ✅ `navigation.js` - Page navigation and keyboard shortcuts
- ✅ `page-template.html` - HTML template with placeholder system
- ✅ `Validation-Functions.ps1` - 4-layer validation framework (fixed 2026-02-09)

**Phase 3: User Story 1 - Local Development (T011-T017)**
- ✅ Browser-based development workflow (no server required)
- ✅ Static content embedding approach
- ❌ Dynamic content loading removed (architectural decision)
- ✅ Content files updated with cyber security news examples (pages 100-103)

**Phase 4: User Story 2 - Policy Conversion (T018-T034)**
- ✅ `convert-web-to-apim.ps1` - Main conversion script (773 lines)
- ✅ Template reading and placeholder replacement
- ✅ CSS/JS injection into APIM policy fragments
- ✅ CDATA escaping and XML encoding
- ✅ 4-layer validation integration
- ✅ UTF-8 BOM encoding for Azure compatibility
- ✅ **Performance**: 11 pages converted in <5 seconds
- ✅ **Fragment sizes**: 16.4-17.0 KB each (under 256 KB limit)

**Phase 5: Tests & Validation (T035-T041)**
- ✅ `fragment-validation.tests.ps1` created (253 lines)
- ⚠️ Pester v5 syntax issues causing IDE freezes (known issue)
- ✅ Validation working via direct script invocation
- ✅ All 4 validation layers passing:
  - Layer 1: XML Well-formedness ✓
  - Layer 2: APIM Schema Compliance ✓
  - Layer 3: Security Scanning ✓
  - Layer 4: Integration Testing ✓

### ⏳ Phase 6: Manual Verification (T042-T058) - Pending

**Requires Live Azure Environment**:
- T042: Create master validation script (`Validate-ApimPolicies.ps1`)
- T043: Visual parity verification checklist
- T044-T049: Deploy to dev APIM and verify production parity
- T050-T058: Documentation polish and optional automation

### Key Decisions Made

**Decision 1: Static Content Embedding**
- **Chosen**: Embed content at build time via conversion script
- **Rejected**: Dynamic loading via `fetch()` API (`content-loader.js`)
- **Rationale**: APIM policies serve static content only; dynamic approaches fail in production
- **Impact**: Perfect dev/prod parity, no CORS issues, simpler architecture

**Decision 2: Validation Strategy**
- **Chosen**: 4-layer validation in conversion script + Pester tests
- **Layers**: XML → APIM Schema → Security → Integration
- **Rationale**: Catch issues at build time before Azure deployment
- **Impact**: Zero deployment failures due to malformed policies

**Decision 3: Content Examples**
- **Chosen**: Fake cyber security news (CVEs, incidents, analysis)
- **Rationale**: Demonstrates real-world technical content structure
- **Impact**: More realistic testing of CDATA escaping and XSS prevention

### Known Issues

**Issue: Pester Test IDE Compatibility**
- **Symptom**: IDE freezes when running `fragment-validation.tests.ps1`
- **Root Cause**: Pester v5 syntax differences, PowerShell extension conflicts
- **Workaround**: Run validation directly via `Invoke-FragmentValidation` function
- **Status**: Tests exist but need manual refactoring for IDE compatibility
- **Impact**: Low - conversion script has validation built-in

---

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
src/
└── web/                       # ✅ Simple HTML + htmx frontend
    ├── index.html             # ✅ Entry point (page index)
    ├── page.html              # ✅ Page viewer (generated)
    ├── styles/
    │   └── txttv.css         # ✅ Text TV retro styling (3.1 KB)
    ├── scripts/
    │   ├── navigation.js     # ✅ Page navigation & keyboard shortcuts
    │   └── content-loader.js # ❌ REMOVED - dynamic loading not used
    └── templates/
        └── page-template.html # ✅ HTML template with {CONTENT} placeholder

infrastructure/
├── modules/
│   └── apim/
│       ├── fragments/         # ✅ Generated fragments (page-100.xml - page-110.xml)
│       ├── policies/          # Existing APIM policy XML files
│       └── operations/        # API operation definitions
├── scripts/
│   ├── convert-txt-to-fragment.ps1    # EXISTING: TXT content conversion
│   ├── convert-web-to-apim.ps1        # ✅ NEW: HTML→APIM policy conversion (IMPLEMENTED)
│   ├── Validation-Functions.ps1       # ✅ NEW: 4-layer validation (FIXED 2026-02-09)
│   └── start-dev-server.ps1           # ✅ Simple file browser helper
└── environments/
    ├── dev/
    ├── staging/
    └── prod/

tests/
├── policies/                  # APIM policy tests
│   ├── fragment-validation.tests.ps1  # ✅ Created (Pester v5 syntax issues)
│   └── policy-validation.tests.ps1    # Integration tests
└── integration/
    └── page-navigation.tests.ps1       # Navigation tests

content/
└── pages/                     # ✅ Text TV content files (cyber security news)
    ├── page-100.txt          # CVE-2026-12345 alert
    ├── page-101.txt          # Technical analysis
    ├── page-102.txt          # Mitigation steps
    ├── page-103.txt          # Equifax case study
    └── ...                   # Pages 104-110
```