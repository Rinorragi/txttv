<!--
Sync Impact Report - Constitution v1.2.2
========================================
Version: 1.2.1 → 1.2.2 (PATCH - Web development simplification)
Rationale: Clarify that web frontend development uses simple HTML with htmx loaded from CDN,
eliminating build tooling complexity. No Node.js, webpack, or live-server required for local
development. This aligns with the project's focus on APIM policy fragments as primary implementation
surface - the web frontend is a demonstration UI, not a complex SPA requiring build pipelines.

Change Log (v1.2.2):
- Added Web Frontend subsection to Technology Stack clarifying simple HTML + htmx approach
- Updated Development Workflow to specify no build tooling required for web development
- Clarified that frontend is a demonstration surface, policy fragments are primary implementation
- htmx 2.0.8 loaded directly from jsdelivr CDN (https://cdn.jsdelivr.net/npm/htmx.org@2.0.8/dist/htmx.min.js)
- Local development: open HTML files directly in browser, no server required for static content

Modified Principles: None (clarification only)

Added Sections:
- Technology Stack → Web Frontend: Simple HTML + htmx specification

Removed Sections: None

Templates Status:
✅ All templates remain compatible - no updates required

Previous Versions:
- v1.2.1 (2026-02-07): Path reference convention standardization
- v1.2.0 (2026-02-07): APIM policy guidance expansion, removed infrastructure deployment tests
- v1.1.0 (2026-02-07): APIM policy guidance expansion
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

Infrastructure components MUST be independently deployable.
Each module (APIM, AppGW, WAF, backend) MUST have clear boundaries.
Changes to one component MUST NOT require full redeployment of unrelated components.

**Requirements**:
- Infrastructure modules with clear boundaries and isolated deployment
- APIM policy fragments MUST be independently testable (unit tests for transformation logic)
- Contract tests for APIM policy inputs/outputs
- Integration tests for WAF rules
- Smoke tests for deployed endpoints
- F# backend functions testable in isolation (when called)

**Testing Scope**: Testing focuses on application-level functionality (APIM policies, backend functions, WAF behavior). Infrastructure deployment validation and testing is NOT required - Azure's Bicep validation (`az bicep build`) and ARM deployment validation are sufficient. Do not create Pester tests or other automated tests for infrastructure deployment or Bicep templates.

**Rationale**: Enables rapid iteration on WAF configurations and APIM policy fragments without breaking unrelated components. Policy fragment modularity allows incremental development of TXT TV rendering features. Infrastructure and deployment testing is redundant given Azure's built-in validation.

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

**Web Frontend**: Simple HTML with htmx (no build tooling required)
- htmx 2.0.8 loaded from CDN: https://cdn.jsdelivr.net/npm/htmx.org@2.0.8/dist/htmx.min.js
- Static HTML, CSS, JavaScript files
- No Node.js, webpack, Vite, or other build systems
- No live-server or development server required (open HTML files directly in browser)
- Frontend serves as demonstration UI; APIM policy fragments contain the primary business logic

**Testing**: 
- Bicep validation and linting
- APIM policy testing (validation, transformation tests, fragment composition)
- xUnit for F# function tests (if/when backend logic exists)
- WAF rule validation and attack scenario testing
- API endpoint integration tests

**Monitoring**: Azure Monitor, Application Insights, Log Analytics

## Development Workflow

**Web Frontend Development**:
- Edit HTML, CSS, JavaScript files directly in `src/web/`
- Open `src/web/index.html` in browser to view changes
- No build step or development server required
- Refresh browser to see updates
- htmx loaded from CDN - no package manager or bundler needed

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
- File paths in documentation MUST be relative to repository root (e.g., `infrastructure/README.md`)
- Absolute paths with drive letters are PROHIBITED in documentation and code
- Use forward slashes for cross-platform compatibility in documentation

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

**Version**: 1.2.2 | **Ratified**: 2026-01-31 | **Last Amended**: 2026-02-09
