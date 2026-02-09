# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
  
  NOTE: For txttv project - APIM policy fragments are the PRIMARY implementation surface.
  Backend F# code is minimal/demo only. Focus on policy design and testing.
-->

**Primary Implementation**: [e.g., APIM policy fragments, Backend API, Frontend UI, or NEEDS CLARIFICATION]  
**Language/Version**: [e.g., .NET 10 F# or NEEDS CLARIFICATION]  
**Infrastructure as Code**: [e.g., Bicep or NEEDS CLARIFICATION]  
**Cloud Platform**: [e.g., Azure (required for APIM/AppGW/WAF), AWS, GCP, or NEEDS CLARIFICATION]  
**APIM Policies**: [if applicable, e.g., Policy fragments for TXT TV rendering, transformation logic, or N/A]  
**Primary Dependencies**: [e.g., Azure Functions SDK, APIM policy libraries, FastAPI, or NEEDS CLARIFICATION]  
**Storage**: [if applicable, e.g., Azure SQL, Cosmos DB, Blob Storage, or N/A]  
**Testing**: [e.g., APIM policy validation, xUnit, Bicep validation, WAF rule testing, or NEEDS CLARIFICATION]  
**Target Platform**: [e.g., Azure Functions, APIM, Azure App Service, AKS, or NEEDS CLARIFICATION]
**Project Type**: [apim-policy-centric/infrastructure/backend-api/web/mobile - determines source structure]  
**Performance Goals**: [domain-specific, e.g., 1000 req/s, <100ms p95 latency, or NEEDS CLARIFICATION]  
**Security Requirements**: [e.g., WAF rules for SQL injection/XSS, APIM rate limiting, policy input validation, or NEEDS CLARIFICATION]  
**Scale/Scope**: [domain-specific, e.g., regional deployment, 10k concurrent users, policy fragment count, or NEEDS CLARIFICATION]

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Constitution Version**: [e.g., 1.1.0]

### Principle I: Infrastructure as Code
- [ ] All infrastructure defined in Bicep
- [ ] Changes version-controlled and reviewed
- [ ] No manual cloud configuration

### Principle II: Security-First Architecture
- [ ] WAF rules documented with test cases
- [ ] Security testing automated
- [ ] APIM policies enforce auth/rate limiting/validation
- [ ] APIM policy fragments tested for security vulnerabilities

### Principle III: Observability & Monitoring
- [ ] Structured logs and metrics defined
- [ ] Security events captured
- [ ] APIM policy execution tracing configured
- [ ] Dashboards planned for WAF/APIM metrics

### Principle IV: Modularity & Testability
- [ ] Components independently deployable
- [ ] APIM policy fragments independently testable
- [ ] Contract tests for policy inputs/outputs defined
- [ ] Integration tests for WAF rules planned

### Principle V: Deployment Automation
- [ ] CI/CD pipeline defined as code
- [ ] Automated validation gates specified
- [ ] Rollback procedure documented

### Complexity Justification Required?
- [ ] No violations OR violations justified in Complexity Tracking section below

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
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
# [REMOVE IF UNUSED] Option 1: APIM Policy-Centric (for txttv: AppGW → APIM policies → F# backend)
infrastructure/
├── modules/
│   ├── apim/
│   │   ├── policies/          # APIM policy XML files
│   │   ├── fragments/         # Reusable policy fragments
│   │   └── operations/        # API operation definitions
│   ├── app-gateway/
│   ├── waf/
│   └── backend/              # F# Azure Functions (minimal)
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── scripts/

src/
└── backend/                   # F# Azure Functions (optional/demo)
    └── TxtTv.Functions/

tests/
├── infrastructure/            # Bicep validation
├── policies/                  # APIM policy tests, fragment validation
├── security/                  # WAF rule tests, attack scenarios
└── integration/               # End-to-end API tests

# [REMOVE IF UNUSED] Option 2: Infrastructure-focused (generic IaC projects)
infrastructure/
├── modules/
│   ├── apim/
│   ├── app-gateway/
│   ├── waf/
│   └── backend/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── scripts/

src/
└── [backend API if applicable]

tests/
├── infrastructure/
├── security/          # WAF rule tests, attack scenarios
└── integration/

# [REMOVE IF UNUSED] Option 3: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [REMOVE IF UNUSED] Option 4: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/