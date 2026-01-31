# Implementation Plan: TXT TV Application

**Branch**: `001-txt-tv-app` | **Date**: 2026-01-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-txt-tv-app/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Build a public internet-facing TXT TV application similar to YLE Teksti-TV with page-based navigation. The primary implementation uses APIM policy fragments to render HTML content and handle routing. Content is managed through text files converted to policy fragments. A minimal F# Azure Function backend serves as a connectivity test ("you found through the maze" message). The entire stack is protected by Application Gateway WAF, demonstrating Azure's security capabilities.

**Technical Approach**: APIM policies intercept all requests and render HTML directly using policy fragments that contain page content. When a user navigates to `/page/200`, the APIM policy extracts the page number, retrieves the corresponding policy fragment (converted from text file), and transforms it into an HTMX-based HTML response. The F# backend is intentionally minimal and rarely called—the application demonstrates policy-centric architecture.

## Technical Context

**Primary Implementation**: APIM policy fragments (XML-based transformation policies)  
**Language/Version**: .NET 10 F# (Azure Functions runtime v4)  
**Infrastructure as Code**: Bicep  
**Cloud Platform**: Azure (APIM, Application Gateway, WAF, Azure Functions)  
**APIM Policies**: Policy fragments for TXT TV page rendering, routing, content transformation, navigation logic  
**Primary Dependencies**: HTMX 1.9+ (frontend interactivity), minimal CSS for teletext styling  
**Storage**: Azure Blob Storage (for text files before conversion to policy fragments)  
**Testing**: APIM policy validation (XML linting), WAF rule testing (attack scenarios), Bicep validation, integration tests  
**Target Platform**: Azure API Management (primary), Azure Functions Consumption Plan (backend)  
**Project Type**: apim-policy-centric  
**Performance Goals**: <1s page navigation (95th percentile), <2s initial page load, support 100 concurrent users  
**Security Requirements**: WAF rules for SQL injection/XSS/path traversal, APIM rate limiting (100 req/min per IP), input validation in policies  
**Scale/Scope**: Single region deployment, 10-20 policy fragments (pages 100-120), proof of concept scope

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Constitution Version**: 1.1.0

### Principle I: Infrastructure as Code
- [x] All infrastructure defined in Bicep (Application Gateway, WAF, APIM, Azure Functions, Blob Storage)
- [x] Changes version-controlled and reviewed (via Git and PR process)
- [x] No manual cloud configuration (all resources deployed via Bicep templates)

### Principle II: Security-First Architecture
- [x] WAF rules documented with test cases (SQL injection, XSS, path traversal scenarios)
- [x] Security testing automated (WAF rule validation in CI/CD pipeline)
- [x] APIM policies enforce auth/rate limiting/validation (100 req/min per IP, input validation)
- [x] APIM policy fragments tested for security vulnerabilities (XSS in rendered HTML, injection attacks)

### Principle III: Observability & Monitoring
- [x] Structured logs and metrics defined (Application Insights for APIM and Functions)
- [x] Security events captured (WAF blocks, policy execution traces)
- [x] APIM policy execution tracing configured (request/response logging with correlation IDs)
- [x] Dashboards planned for WAF/APIM metrics (Azure Monitor workbooks for WAF blocks, page views)

### Principle IV: Modularity & Testability
- [x] Components independently deployable (APIM, AppGW, WAF, Functions as separate Bicep modules)
- [x] APIM policy fragments independently testable (XML validation, transformation tests)
- [x] Contract tests for policy inputs/outputs defined (page parameter validation, HTML output validation)
- [x] Integration tests for WAF rules planned (automated attack scenarios)

### Principle V: Deployment Automation
- [x] CI/CD pipeline defined as code (GitHub Actions workflow for Bicep deployment)
- [x] Automated validation gates specified (Bicep lint, APIM policy validation, security scan)
- [x] Rollback procedure documented (Bicep deployment history, previous version rollback)

### Complexity Justification Required?
- [x] No violations - all principles satisfied

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
infrastructure/
├── modules/
│   ├── apim/
│   │   ├── main.bicep                    # APIM resource definition
│   │   ├── policies/
│   │   │   ├── global-policy.xml         # Global APIM policy (logging, CORS)
│   │   │   ├── page-routing-policy.xml   # Page route handling (extract page number)
│   │   │   └── backend-policy.xml        # Backend connectivity test policy
│   │   ├── fragments/
│   │   │   ├── page-100.xml              # Page 100 content fragment
│   │   │   ├── page-101.xml              # Page 101 content fragment
│   │   │   ├── page-102.xml              # Page 102 content fragment
│   │   │   ├── navigation-template.xml   # HTMX navigation HTML fragment
│   │   │   └── error-page.xml            # 404 page not found fragment
│   │   └── operations/
│   │       ├── get-page.json             # API operation: GET /page/{pageNumber}
│   │       ├── get-home.json             # API operation: GET / (redirects to page 100)
│   │       └── get-backend-test.json     # API operation: GET /backend-test
│   ├── app-gateway/
│   │   ├── main.bicep                    # Application Gateway definition
│   │   └── backend-pools.bicep           # Backend pool configuration (APIM)
│   ├── waf/
│   │   ├── main.bicep                    # WAF policy definition
│   │   └── rules/
│   │       ├── sql-injection.bicep       # SQL injection prevention rules
│   │       ├── xss-protection.bicep      # XSS prevention rules
│   │       └── rate-limiting.bicep       # Rate limiting rules
│   ├── backend/
│   │   └── main.bicep                    # Azure Functions resource definition
│   └── storage/
│       └── main.bicep                    # Blob Storage for content files
├── environments/
│   ├── dev/
│   │   ├── main.bicep                    # Dev environment orchestration
│   │   └── parameters.json               # Dev-specific parameters
│   ├── staging/
│   │   ├── main.bicep                    # Staging environment orchestration
│   │   └── parameters.json               # Staging-specific parameters
│   └── prod/
│       ├── main.bicep                    # Prod environment orchestration
│       └── parameters.json               # Prod-specific parameters
└── scripts/
    ├── convert-txt-to-fragment.ps1       # Convert text files to policy fragments
    └── deploy.ps1                        # Deployment orchestration script

src/
└── backend/
    └── TxtTv.Functions/
        ├── TxtTv.Functions.fsproj        # F# project file
        ├── MazeMessage.fs                # HTTP trigger: returns "you found through the maze"
        └── host.json                     # Functions host configuration

content/
└── pages/
    ├── page-100.txt                      # Source content for page 100
    ├── page-101.txt                      # Source content for page 101
    └── page-102.txt                      # Source content for page 102

tests/
├── infrastructure/
│   ├── bicep-validation.tests.ps1        # Bicep linting and validation tests
│   └── resource-deployment.tests.ps1     # Deployment smoke tests
├── policies/
│   ├── policy-validation.tests.ps1       # APIM policy XML validation
│   ├── fragment-composition.tests.ps1    # Policy fragment composition tests
│   └── transformation.tests.ps1          # HTML transformation output tests
├── security/
│   ├── waf-sql-injection.tests.ps1       # SQL injection attack scenarios
│   ├── waf-xss.tests.ps1                 # XSS attack scenarios
│   └── waf-path-traversal.tests.ps1      # Path traversal attack scenarios
└── integration/
    ├── page-navigation.tests.ps1         # End-to-end page navigation tests
    └── backend-connectivity.tests.ps1    # Backend "maze" message test

.github/
└── workflows/
    └── deploy.yml                        # GitHub Actions CI/CD pipeline
```

**Structure Decision**: Using Option 1 (APIM Policy-Centric) because the primary implementation is APIM policy fragments that render TXT TV pages. The infrastructure is organized around APIM as the core component, with policy fragments as the main implementation surface. F# backend is minimal (single HTTP trigger). Content files are converted to policy fragments via PowerShell script.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations - all constitution principles are satisfied by the proposed architecture.