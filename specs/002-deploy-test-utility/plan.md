# Implementation Plan: Simple Deployment & WAF Testing Utility

**Branch**: `002-deploy-test-utility` | **Date**: February 7, 2026 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-deploy-test-utility/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Replace complex DevOps pipelines with a simple PowerShell-based deployment script that deploys the existing Bicep infrastructure to Azure. Create a command-line utility that sends HTTP requests (GET/POST with JSON/XML payloads) to the deployed service for testing purposes. All requests include HMAC-SHA256 signatures for demonstration. Store example requests in the repository to showcase which patterns are blocked by WAF (SQL injection, XSS) and which are allowed.

## Technical Context

**Primary Implementation**: PowerShell deployment scripts + .NET/F# command-line utility for HTTP testing  
**Language/Version**: PowerShell 7+ for deployment scripts, .NET 10 F# for utility software  
**Infrastructure as Code**: Bicep (existing templates in `infrastructure/` directory)  
**Cloud Platform**: Azure (required for APIM/AppGW/WAF)  
**APIM Policies**: N/A - feature focuses on deployment and testing, not policy development  
**Primary Dependencies**: Azure CLI or PowerShell Az module, .NET SDK 10, existing Bicep modules  
**Storage**: N/A - uses existing Azure Blob Storage defined in infrastructure  
**Testing**: PowerShell Pester tests for deployment scripts, xUnit for F# utility, example request validation  
**Target Platform**: PowerShell console (deployment scripts), cross-platform CLI (.NET utility)  
**Project Type**: infrastructure + cli-utility - deployment automation with testing tool  
**Performance Goals**: Deployment completes in <5 minutes, utility sends requests with <2s latency  
**Security Requirements**: HMAC-SHA256 signature generation, example requests for WAF testing (SQL injection, XSS patterns)  
**Scale/Scope**: Single developer deployment to dev environment, 10-20 example request scenarios

## Constitution Check

*GATE: ✅ PASSED - Phase 0 and Phase 1 complete. Constitution compliance verified.*

**Constitution Version**: 1.1.0

### Principle I: Infrastructure as Code
- [x] All infrastructure defined in Bicep
- [x] Changes version-controlled and reviewed
- [x] No manual cloud configuration

**Status**: ✅ PASS - Feature uses existing Bicep templates, deployment script orchestrates Bicep deployment

### Principle II: Security-First Architecture
- [x] WAF rules documented with test cases
- [x] Security testing automated
- [⚠️] APIM policies enforce auth/rate limiting/validation
- [⚠️] APIM policy fragments tested for security vulnerabilities

**Status**: ⚠️ PARTIAL - WAF testing is core feature requirement. APIM policies exist but are not modified by this feature. Utility demonstrates security patterns without modifying infrastructure security.

**Justification**: Feature focuses on deployment automation and WAF testing, not APIM policy development. Existing APIM policies remain unchanged.

### Principle III: Observability & Monitoring
- [x] Structured logs and metrics defined
- [x] Security events captured
- [x] APIM policy execution tracing configured
- [x] Dashboards planned for WAF/APIM metrics

**Status**: ✅ PASS - Existing infrastructure has monitoring configured. Utility outputs request/response details for observability.

### Principle IV: Modularity & Testability
- [x] Components independently deployable
- [x] APIM policy fragments independently testable
- [x] Contract tests for policy inputs/outputs defined
- [x] Integration tests for WAF rules planned

**Status**: ✅ PASS - Deployment script uses existing modular Bicep templates. Utility is standalone CLI tool. Example requests provide WAF integration tests.

### Principle V: Deployment Automation
- [⚠️] CI/CD pipeline defined as code
- [x] Automated validation gates specified
- [x] Rollback procedure documented

**Status**: ⚠️ JUSTIFIED VIOLATION - Feature explicitly removes CI/CD pipeline per requirements. Simple script-based deployment replaces pipeline complexity for developer environments.

**Justification**: User requirement: "Remove devops pipeline and instead make super simple script to install the azure infrastructure." This is intentional simplification for developer productivity in non-production environments.

### Complexity Justification Required?
- [x] No violations OR violations justified in Complexity Tracking section below

**Overall Assessment**: ✅ ACCEPTABLE - Two justified partial compliance items:
1. APIM policies not modified (feature scope)
2. CI/CD pipeline removed per explicit requirements (intentional simplification)

## Complexity Tracking

**Principle V Violation - No CI/CD Pipeline**:
- **Rationale**: Feature explicitly removes CI/CD complexity to enable rapid developer iteration
- **Scope**: Applies to dev environment only, not production
- **Mitigation**: Deployment script includes validation gates (Bicep build, parameter validation)
- **Trade-off**: Manual deployment risk vs developer velocity - acceptable for dev environment
- **Documentation**: Deployment script includes error handling and rollback instructions

## Project Structure

### Documentation (this feature)

```text
specs/002-deploy-test-utility/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   ├── example-request-format.md
│   └── deployment-config-schema.md
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



