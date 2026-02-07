---
description: "Task list for WAF Logging to Log Analytics feature implementation"
---

# Tasks: WAF Logging to Log Analytics

**Input**: Design documents from `/specs/003-waf-logging/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Tests are NOT explicitly requested in the feature specification. Test tasks below are for validation only (infrastructure verification).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `- [ ] [ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: No setup required - all infrastructure already exists from previous features

✅ **SKIP** - Log Analytics workspace, Application Gateway, and deployment scripts already exist

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure changes that enable ALL user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T001 Add `logAnalyticsWorkspaceId` parameter to infrastructure/modules/app-gateway/main.bicep
- [x] T002 Add diagnostic settings resource to infrastructure/modules/app-gateway/main.bicep using Microsoft.Insights/diagnosticSettings@2021-05-01-preview
- [x] T003 [P] Update infrastructure/environments/dev/main.bicep to pass logAnalytics.id to app-gateway module
- [x] T004 [P] Update infrastructure/environments/staging/main.bicep to pass logAnalytics.id to app-gateway module
- [x] T005 [P] Update infrastructure/environments/prod/main.bicep to pass logAnalytics.id to app-gateway module
- [x] T006 Run Bicep validation: `az bicep build --file infrastructure/modules/app-gateway/main.bicep`
- [ ] T007 Deploy to dev environment using infrastructure/scripts/Deploy-Infrastructure.ps1 -Environment dev

**Checkpoint**: Foundation ready - diagnostic settings configured, user story validation can begin

---

## Phase 3: User Story 1 - Security Team Monitors WAF Activity (Priority: P1) 🎯 MVP

**Goal**: Enable security administrators to view all WAF-blocked requests in Log Analytics to identify security threats and attack patterns

**Independent Test**: Deploy infrastructure with diagnostic settings, send malicious request (SQL injection), wait 5 minutes, query Log Analytics to verify blocked request is logged with full details (source IP, URI, rule ID, action)

### Validation for User Story 1

- [X] T008 [US1] Infrastructure tests removed per constitution v1.2.0 - Azure Bicep validation is sufficient
- [X] T009 [US1] Infrastructure tests removed per constitution v1.2.0 - Azure Bicep validation is sufficient
- [X] T010 [US1] Infrastructure tests removed per constitution v1.2.0 - Azure Bicep validation is sufficient
- [X] T011 [US1] Infrastructure tests removed per constitution v1.2.0 - Azure Bicep validation is sufficient

### Integration Testing for User Story 1

- [ ] T012 [US1] Generate test traffic: Send SQL injection request to Application Gateway endpoint
- [ ] T013 [US1] Wait 5 minutes for log ingestion
- [ ] T014 [US1] Query Log Analytics using KQL from quickstart.md to verify blocked request logged
- [ ] T015 [US1] Verify log entry contains required fields: clientIp_s, requestUri_s, action_s, ruleId_s, message_s
- [ ] T016 [US1] Verify action_s equals "Blocked" for malicious request

**Checkpoint**: Security team can now query and view blocked WAF requests in Log Analytics

---

## Phase 4: User Story 2 - Operations Team Troubleshoots False Positives (Priority: P2)

**Goal**: Enable operations team to investigate when legitimate requests are blocked by WAF, find exact rule that blocked, and make informed tuning decisions

**Independent Test**: Generate legitimate request that triggers WAF (e.g., page ID with single quote), locate log entry in Log Analytics by timestamp/IP, verify sufficient detail to determine false positive

### Validation for User Story 2

- [ ] T017 [P] [US2] Generate borderline legitimate request that triggers WAF rule (e.g., `/page?id=100'test`)
- [ ] T018 [US2] Wait 5 minutes for log ingestion
- [ ] T019 [US2] Query Log Analytics by timestamp and source IP using KQL from quickstart.md
- [ ] T020 [US2] Verify log entry shows specific rule ID (e.g., 942100) and matched pattern
- [ ] T021 [US2] Verify details_message_s field contains enough context to understand why request was blocked
- [ ] T022 [US2] Test query: Search for similar patterns using `summarize` to identify recurring false positive trends

**Checkpoint**: Operations team can troubleshoot false positives using log details

---

## Phase 5: User Story 3 - Compliance Auditor Reviews Security Posture (Priority: P3)

**Goal**: Enable compliance auditors to verify 30-day log retention, query historical logs, and demonstrate complete audit trail

**Independent Test**: Check Log Analytics workspace retention settings, query logs from multiple days ago, verify all event types are captured

### Validation for User Story 3

- [ ] T023 [P] [US3] Query Log Analytics workspace retention settings using PowerShell: `Get-AzOperationalInsightsWorkspace`
- [ ] T024 [US3] Verify retentionInDays equals 30
- [ ] T025 [US3] Generate multiple event types: blocked request, allowed request, rate limit trigger
- [ ] T026 [US3] Query Log Analytics for events from 1+ days ago using `where TimeGenerated > ago(7d)`
- [ ] T027 [US3] Verify different event types are distinguishable by action_s field (Blocked, Allowed, Matched)
- [ ] T028 [US3] Test query: Count total WAF events using `summarize TotalEvents = count()`
- [ ] T029 [US3] Test query: Verify OldestLog timestamp using `min(TimeGenerated)` to confirm retention

**Checkpoint**: Compliance requirements satisfied - 30-day retention verified, historical logs queryable

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T030 [P] Update infrastructure/README.md with diagnostic settings deployment information
- [x] T031 [P] Add KQL query examples from quickstart.md to infrastructure/README.md
- [x] T032 [P] Document troubleshooting steps for "no logs appearing" scenario
- [ ] T033 Deploy to staging environment using infrastructure/scripts/Deploy-Infrastructure.ps1 -Environment staging
- [ ] T034 Deploy to prod environment using infrastructure/scripts/Deploy-Infrastructure.ps1 -Environment prod
- [ ] T035 Run quickstart.md validation against dev environment
- [ ] T036 Verify all 3 environments (dev/staging/prod) have diagnostic settings configured
- [ ] T037 Create example dashboard query for "Blocked requests by IP" visualization (optional enhancement)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: ✅ SKIP - Infrastructure already exists
- **Foundational (Phase 2)**: No dependencies - can start immediately - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User stories can proceed in parallel after T007 (dev deployment)
  - Or sequentially in priority order (US1 → US2 → US3)
- **Polish (Phase 6)**: Depends on all user stories being validated

### User Story Dependencies

- **User Story 1 (US1)**: Depends on Foundational (T001-T007) - No dependencies on other stories
- **User Story 2 (US2)**: Depends on Foundational (T001-T007) - Can run in parallel with US1
- **User Story 3 (US3)**: Depends on Foundational (T001-T007) - Can run in parallel with US1/US2

### Within Each User Story

1. **Foundational phase** (T001-T007):
   - T001-T002: Sequential (parameter before resource)
   - T003-T005: Parallel [P] (different environment files)
   - T006: Depends on T001-T002 (validation after code changes)
   - T007: Depends on T001-T006 (deployment after validation)

2. **User Story 1** (T008-T016):
   - T008-T010: Sequential (building test file)
   - T011: Depends on T008-T010 (run tests after writing)
   - T012-T016: Sequential (generate traffic → wait → query → verify)

3. **User Story 2** (T017-T022):
   - All tasks sequential (T017 → T018 → T019 → T020 → T021 → T022)
   - T017 can start in parallel with US1's T012 (different test scenarios)

4. **User Story 3** (T023-T029):
   - T023-T024: Sequential (query → verify)
   - T025: Can run in parallel with T023 (different activities)
   - T026-T029: Sequential (query → verify → test queries)

5. **Polish phase** (T030-T037):
   - T030-T032: Parallel [P] (documentation updates)
   - T033-T034: Sequential (staging before prod)
   - T035-T037: Can run in parallel after deployments

### Parallel Opportunities

**After T007 (dev deployed), launch in parallel**:
- User Story 1 validation (T008-T016)
- User Story 2 validation (T017-T022) - can share T012 traffic generation
- User Story 3 validation (T023-T029)

**Within Foundational Phase**:
```bash
# Parallel: Update all 3 environment files simultaneously
Task T003: infrastructure/environments/dev/main.bicep
Task T004: infrastructure/environments/staging/main.bicep
Task T005: infrastructure/environments/prod/main.bicep
```

**Within Polish Phase**:
```bash
# Parallel: All documentation updates
Task T030: infrastructure/README.md (diagnostic settings)
Task T031: infrastructure/README.md (KQL examples)
Task T032: infrastructure/README.md (troubleshooting)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 2: Foundational (T001-T007) → Diagnostic settings deployed
2. Complete Phase 3: User Story 1 (T008-T016) → Security monitoring validated
3. **STOP and VALIDATE**: Test User Story 1 independently - verify blocked requests appear in logs
4. Deploy/demo if ready - security team can start using Log Analytics

**Result**: Core value delivered - security team can monitor WAF blocks

### Incremental Delivery

1. Complete Foundational → Diagnostic settings configured in all environments
2. Add User Story 1 → Test independently → **Security monitoring operational** (MVP!)
3. Add User Story 2 → Test independently → **Ops team can troubleshoot false positives**
4. Add User Story 3 → Test independently → **Compliance requirements satisfied**
5. Add Polish → All environments deployed, documentation complete

### Parallel Team Strategy

With multiple developers (after T007 dev deployment):

1. Team completes Foundational together (T001-T007)
2. Once dev is deployed:
   - **Tester A**: User Story 1 validation (T008-T016)
   - **Tester B**: User Story 2 validation (T017-T022)
   - **Tester C**: User Story 3 validation (T023-T029)
3. Merge results, proceed to Polish phase

**Optimal for**: Single developer (2-4 hours total), sequential execution

---

## Estimated Effort

| Phase | Tasks | Estimated Time |
|-------|-------|----------------|
| Phase 1: Setup | 0 tasks | 0 min (skip) |
| Phase 2: Foundational | T001-T007 | 60 min |
| Phase 3: User Story 1 | T008-T016 | 45 min |
| Phase 4: User Story 2 | T017-T022 | 30 min |
| Phase 5: User Story 3 | T023-T029 | 30 min |
| Phase 6: Polish | T030-T037 | 45 min |
| **Total** | **37 tasks** | **210 min (3.5 hours)** |

**Note**: Includes 15 minutes total wait time for log ingestion (5 min × 3 user stories)

---

## Notes

- **[P] tasks**: Different files, can run in parallel
- **[Story] label**: Maps task to specific user story for traceability
- **No new infrastructure**: Log Analytics workspace and Application Gateway already exist
- **Pure Bicep changes**: No application code modified
- **Backward compatible**: Optional parameter with default value
- **5-minute wait**: Required after generating traffic for log ingestion (Azure diagnostic latency)
- **Stop at any checkpoint**: Each user story independently validates a complete use case
- **Tests are validation**: Not unit tests - infrastructure verification and integration testing