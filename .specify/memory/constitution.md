<!--
Sync Impact Report - Constitution v1.1.0
========================================
Version: 1.0.1 → 1.1.0 (MINOR - Architecture clarification and APIM policy guidance expansion)
Rationale: Clarify project architecture - APIM policy fragments are the primary implementation
surface for TXT TV rendering, not traditional backend code. This materially expands guidance
on APIM policy development and testing requirements.

Change Log (v1.1.0):
- Added "Project Architecture" section explaining AppGW → APIM → F# backend flow
- Expanded Technology Stack to emphasize APIM policy fragments as primary implementation
- Updated Principle II to include APIM policy testing requirements
- Updated Principle III to emphasize APIM policy execution tracing
- Updated Principle IV to include APIM policy modularity and fragment testing
- Clarified F# backend role as minimal/demo, not primary business logic container

Modified Principles:
- Principle II: Added APIM policy security requirements
- Principle III: Added APIM policy execution tracing requirements
- Principle IV: Added APIM policy fragment testing requirements

Added Sections:
- Project Architecture (new section explaining the unique APIM-centric design)

Removed Sections: None

Templates Status:
✅ All templates remain compatible - no updates required

Previous Versions:
- v1.0.1 (2026-01-31): Specified Bicep and .NET F# Azure Functions
- v1.0.0 (2026-01-31): Initial ratification with 5 core principles

Follow-up TODOs: None
-->

# txttv Constitution

## Core Principles

### I. Infrastructure as Code

All infrastructure MUST be defined declaratively using Infrastructure as Code (IaC).
Infrastructure changes MUST be version-controlled and reviewed before deployment.
Manual configuration changes to cloud resources are PROHIBITED.

**Technology**: Bicep (Azure's native IaC DSL) is the required IaC tool for this project.

**Rationale**: Ensures reproducibility, audit trail, and prevents configuration drift in security-critical infrastructure showcasing WAF capabilities. Bicep provides strong Azure integration and type safety.

### II. Security-First Architecture

Security configuration MUST be the primary design constraint, not an afterthought.
All API endpoints MUST be protected by WAF rules with documented test cases.
Security testing MUST be automated and executed on every deployment.

**Requirements**:
- WAF rules defined in code with clear purpose documentation
- Attack scenarios tested automatically (SQL injection, XSS, path traversal, etc.)
- Security findings MUST block deployment until remediated
- APIM policies MUST enforce authentication, rate limiting, and input validation
- APIM policy fragments MUST be tested for security vulnerabilities (injection, XSS in rendered output)
- Policy fragment composition MUST maintain security boundaries

**Rationale**: The project exists to demonstrate WAF capabilities; security testing validates the core value proposition. APIM policies that render TXT TV content must be secure against malicious inputs.

### III. Observability & Monitoring

All components MUST emit structured logs and metrics.
Logging MUST capture security events, WAF decisions, and request flows.
Dashboards MUST visualize WAF blocks, allowed traffic, and performance metrics.

**Required Telemetry**:
- Request/response logging with correlation IDs
- WAF rule match/block events
- APIM policy execution traces (especially policy fragment execution flow)
- APIM transformation and rendering operations
- Application Gateway health metrics
- Security event aggregation
- Backend F# function invocation metrics (when called)

**Rationale**: Observability enables demonstration of WAF behavior and troubleshooting of security policies. APIM policy execution visibility is critical since policy fragments implement the TXT TV rendering logic.

### IV. Modularity & Testability

Infrastructure components MUST be independently deployable and testable.
Each module (APIM, AppGW, WAF, backend) MUST have isolated test scenarios.
Changes to one component MUST NOT require full redeployment of unrelated components.

**Requirements**:
- Infrastructure modules with clear boundaries
- APIM policy fragments MUST be independently testable (unit tests for transformation logic)
- Contract tests for APIM policy inputs/outputs
- Integration tests for WAF rules
- Smoke tests for deployed endpoints
- F# backend functions testable in isolation (when called)

**Rationale**: Enables rapid iteration on WAF configurations and APIM policy fragments without breaking unrelated components. Policy fragment modularity allows incremental development of TXT TV rendering features.

### V. Deployment Automation

All deployments MUST be executed through automated pipelines.
Manual deployment steps are PROHIBITED in production-equivalent environments.
Rollback procedures MUST be automated and tested.

**Requirements**:
- CI/CD pipelines defined as code
- Automated validation gates (lint, security scan, functional tests)
- Blue/green or rolling deployment strategy for zero-downtime updates
- Automated smoke tests post-deployment

**Rationale**: Consistent, repeatable deployments reduce human error in security-critical configurations.

## Project Architecture

**Purpose**: Showcase Azure API Management policy fragment capabilities by rendering a TXT TV-style frontend entirely within APIM policies, protected by Application Gateway WAF.

**Request Flow**:
1. **Client** → **Application Gateway (WAF)** - All requests filtered through WAF rules
2. **Application Gateway** → **APIM** - Protected backend
3. **APIM Policies** intercept requests and render TXT TV content using policy fragments
4. **APIM** → **F# Backend** (minimal/optional) - Demonstrates policy-to-backend integration when needed
5. **Response** rendered by APIM policies, returned through AppGW to client

**Key Design Principle**: APIM policy fragments are the PRIMARY implementation surface, not traditional application code. The F# Azure Function backend serves as a demonstration target but is not where business logic lives—the TXT TV rendering happens entirely in APIM transformation policies.

**Implementation Focus**:
- APIM policy XML fragments for content rendering
- WAF rules protecting the APIM endpoint
- Infrastructure as Code (Bicep) defining all components
- Minimal F# backend for demonstration purposes

## Technology Stack

**Cloud Platform**: Azure (required for APIM, AppGW, WAF integration)

**Infrastructure as Code**: Bicep (Azure's native DSL)

**API Gateway**: Azure API Management (APIM) - **PRIMARY implementation surface via policy fragments**

**Security**: Application Gateway with Web Application Firewall (WAF)

**Backend**: .NET F# Azure Functions (minimal implementation for demonstration; business logic lives in APIM policies)

**APIM Policies**: XML-based policy fragments for:
- Request interception and routing
- TXT TV content rendering and transformation
- Response composition
- Policy fragment composition and reuse

**Testing**: 
- Bicep validation and linting
- APIM policy testing (validation, transformation tests, fragment composition)
- xUnit for F# function tests (if/when backend logic exists)
- WAF rule validation and attack scenario testing
- API endpoint integration tests

**Monitoring**: Azure Monitor, Application Insights, Log Analytics

## Development Workflow

**Branching**: Feature branches following pattern `###-feature-name` where ### is the spec issue/ticket number

**Review Requirements**:
- All infrastructure changes MUST be reviewed by at least one other engineer
- Security-impacting changes (WAF rules, APIM policies) MUST include attack test scenarios
- No direct commits to main branch

**Quality Gates**:
- Infrastructure validation (terraform validate/plan, bicep build)
- Security policy linting
- Automated test suite must pass
- Security scan must show no HIGH/CRITICAL findings

**Documentation Requirements**:
- WAF rules MUST document the attack vector they protect against
- APIM policies MUST document their purpose and configuration parameters
- Deployment procedures MUST be documented in specs/ directory

## Governance

This constitution supersedes all other development practices and guidelines.

**Amendment Process**:
- Proposed amendments MUST be documented with clear rationale
- Amendment proposals require review and approval before adoption
- Amendments MUST include a migration plan if affecting existing code/infrastructure
- Version MUST be incremented per semantic versioning rules

**Compliance Verification**:
- All feature specifications MUST include constitution check section
- Implementation plans MUST validate against all five core principles
- Complexity that violates principles MUST be explicitly justified

**Version Management**:
- MAJOR version: Principle removal/redefinition, incompatible governance changes
- MINOR version: New principle added, expanded guidance, new required sections
- PATCH version: Clarifications, wording improvements, non-semantic fixes

Use `.specify/memory/constitution.md` as the authoritative source for runtime development guidance.

**Version**: 1.1.0 | **Ratified**: 2026-01-31 | **Last Amended**: 2026-01-31
