# Implementation Plan: WAF Logging to Log Analytics

**Branch**: `003-waf-logging` | **Date**: February 7, 2026 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-waf-logging/spec.md`

**Note**: This implementation plan configures Application Gateway diagnostic settings to send WAF logs to Log Analytics workspace for security monitoring, troubleshooting, and compliance.

## Summary

Configure Application Gateway to automatically send all WAF diagnostic logs to the existing Log Analytics workspace in each environment (dev/staging/prod). This enables security teams to monitor blocked requests, operations teams to troubleshoot false positives, and compliance teams to verify 30-day log retention. Implementation is pure infrastructure configuration in Bicep—no application code changes required.

## Technical Context

**Primary Implementation**: Infrastructure (Bicep) - Add diagnostic settings to Application Gateway module  
**Language/Version**: Bicep (Azure native IaC DSL)  
**Infrastructure as Code**: Bicep  
**Cloud Platform**: Azure (Application Gateway, Log Analytics, Azure Monitor)  
**APIM Policies**: N/A (no policy changes needed)  
**Primary Dependencies**: 
- Existing Log Analytics workspace (already deployed in each environment)
- Existing Application Gateway with WAF enabled
- Azure Monitor diagnostic settings API  
**Storage**: Log Analytics workspace (already configured with 30-day retention)  
**Testing**: Bicep validation, PowerShell tests to verify diagnostic settings exist, integration tests with test traffic  
**Target Platform**: Application Gateway (existing resource, adding diagnostic settings configuration)  
**Project Type**: Infrastructure-only change  
**Performance Goals**: <5 minutes log latency from WAF event to Log Analytics queryability  
**Security Requirements**: WAF logs must capture all security events (blocks, rate limits, rule matches) with full request context  
**Scale/Scope**: Single diagnostic setting per Application Gateway, applies to all three environments (dev/staging/prod)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Constitution Version**: 1.1.0

### Principle I: Infrastructure as Code
- [x] All infrastructure defined in Bicep (diagnostic settings will be added to app-gateway/main.bicep)
- [x] Changes version-controlled and reviewed (changes go through feature branch 003-waf-logging)
- [x] No manual cloud configuration (diagnostic settings configured declaratively in Bicep)

**Status**: ✅ PASS

### Principle II: Security-First Architecture
- [x] WAF rules documented with test cases (WAF rules already exist from feature 001, not modified here)
- [x] Security testing automated (existing WAF tests remain in place)
- [x] APIM policies enforce auth/rate limiting/validation (existing policies not modified)
- [x] APIM policy fragments tested for security vulnerabilities (N/A - no policy changes)

**Status**: ✅ PASS - This feature enhances security visibility by enabling log analysis of WAF events

### Principle III: Observability & Monitoring
- [x] Structured logs and metrics defined (ApplicationGatewayFirewallLog category captures structured WAF events)
- [x] Security events captured (diagnostic settings will capture all WAF block/allow decisions)
- [x] APIM policy execution tracing configured (existing configuration not modified)
- [x] Dashboards planned for WAF/APIM metrics (Log Analytics queries enable dashboard creation post-implementation)

**Status**: ✅ PASS - This feature directly implements observability for WAF security events

### Principle IV: Modularity & Testability
- [x] Components independently deployable (diagnostic settings can be deployed independently of other changes)
- [x] APIM policy fragments independently testable (N/A - no policy changes)
- [x] Contract tests for policy inputs/outputs defined (N/A - no API contract changes)
- [x] Integration tests for WAF rules planned (new test: verify diagnostic settings exist and logs flow)

**Status**: ✅ PASS

### Principle V: Deployment Automation
- [x] CI/CD pipeline defined as code (using PowerShell deployment scripts from feature 002)
- [x] Automated validation gates specified (Bicep validation will catch diagnostic setting errors)
- [x] Rollback procedure documented (standard Bicep rollback: redeploy previous version)

**Status**: ✅ PASS

### Complexity Justification Required?
- [x] No violations - All constitution principles satisfied

**Overall Gate Status**: ✅ PASS - Proceed to Phase 0 Research

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

**Files Modified**:

```text
infrastructure/
├── modules/
│   └── app-gateway/
│       └── main.bicep         # ADD: diagnostic settings resource at end of file
└── environments/
    ├── dev/
    │   └── main.bicep         # UPDATE: pass logAnalytics.id to app-gateway module
    ├── staging/
    │   └── main.bicep         # UPDATE: pass logAnalytics.id to app-gateway module
    └── prod/
        └── main.bicep         # UPDATE: pass logAnalytics.id to app-gateway module

tests/
└── infrastructure/
    └── diagnostic-settings.tests.ps1  # NEW: Pester tests to verify diagnostic settings
```

**No changes to**:
- APIM policies or fragments
- WAF rules
- Backend F# code
- Storage or APIM modules

---

## Phase 0: Research (✅ COMPLETE)

**Status**: All NEEDS CLARIFICATION items resolved

**Key Findings**:
1. **Diagnostic settings**: Use `Microsoft.Insights/diagnosticSettings@2021-05-01-preview` with scope property
2. **Log category**: `ApplicationGatewayFirewallLog` captures all WAF security events
3. **Workspace integration**: Pass `logAnalytics.id` as module parameter from environment deployment
4. **Retention**: Managed at Log Analytics workspace level (30 days), disable diagnostic setting retention
5. **Testing**: Pester tests for configuration + integration test with 5-minute wait for log flow

**Research Document**: [research.md](research.md)

---

## Phase 1: Design & Contracts (✅ COMPLETE)

**Status**: Design completed, ready for implementation

**Deliverables**:
1. **Data Model** ([data-model.md](data-model.md))
   - Documented ApplicationGatewayFirewallLog schema
   - Defined diagnostic settings resource model
   - Documented configuration parameter flow
   - Defined state transitions and validation rules

2. **Contracts** ([contracts/bicep-module-contract.md](contracts/bicep-module-contract.md))
   - Bicep module input contract (new `logAnalyticsWorkspaceId` parameter)
   - Environment main.bicep contract (how to pass workspace ID)
   - Azure resource contract (expected diagnostic settings state)
   - Log Analytics query contract (guaranteed fields and query patterns)
   - Testing contracts (infrastructure and integration tests)

3. **Quickstart Guide** ([quickstart.md](quickstart.md))
   - 5-step guide: Deploy → Generate traffic → Query logs → Troubleshoot → Verify retention
   - Sample KQL queries for common scenarios
   - Troubleshooting section for common issues
   - Next steps for dashboards and alerts

4. **Agent Context Update**
   - Updated `.github/agents/copilot-instructions.md` with diagnostic settings technology

**Constitution Re-Check**: ✅ PASS (no changes from Phase 0)
- Infrastructure as Code: Bicep diagnostic settings resource
- Security-First: Enhances security visibility
- Observability: Directly implements WAF event logging
- Modularity: Independent deployment
- Automation: PowerShell deployment scripts

---

## Phase 2: Implementation Planning

**Note**: Phase 2 (task breakdown) is handled by `/speckit.tasks` command, not `/speckit.plan`.

This plan stops here. To proceed with implementation:

```
/speckit.tasks
```

---

## Summary

**Feature**: WAF Logging to Log Analytics
**Branch**: 003-waf-logging
**Type**: Infrastructure-only change (Bicep)
**Complexity**: Low (single diagnostic settings resource + parameter passing)

**Files to Modify**:
1. `infrastructure/modules/app-gateway/main.bicep` - Add diagnostic settings resource
2. `infrastructure/environments/dev/main.bicep` - Pass workspace ID
3. `infrastructure/environments/staging/main.bicep` - Pass workspace ID
4. `infrastructure/environments/prod/main.bicep` - Pass workspace ID
5. `tests/infrastructure/diagnostic-settings.tests.ps1` - New test file

**No Breaking Changes**: Backward compatible (optional parameter with default)

**Estimated Effort**: 2-4 hours
- Bicep changes: 1 hour
- Testing: 1-2 hours (including 5-minute log ingestion wait)
- Documentation updates: 30 minutes
- Deployment to all environments: 30 minutes

**Dependencies**:
- ✅ Log Analytics workspace exists (deployed in feature 001)
- ✅ Application Gateway exists (deployed in feature 001)
- ✅ PowerShell deployment scripts exist (created in feature 002)

**Ready for**: Task breakdown and implementation