# Implementation Tasks: Simple Deployment & WAF Testing Utility

**Feature**: 002-deploy-test-utility  
**Branch**: `002-deploy-test-utility`  
**Created**: February 7, 2026  
**Plan**: [plan.md](plan.md) | **Spec**: [spec.md](spec.md)

## Task Overview

This document provides a complete, ordered list of implementation tasks for the Simple Deployment & WAF Testing Utility feature. Tasks are organized by user story (P1-P5) to enable independent implementation and testing of each capability.

**Total Tasks**: 47  
**Estimated Duration**: 3-4 days for MVP (Phase 1-3), 5-6 days for complete feature

## Task Execution Order

### Dependencies Graph

```
Phase 1 (Setup) → Phase 2 (Foundational) → Phase 3 (US1) → Phase 4 (US2) → Phase 5 (US3) → Phase 6 (US4) → Phase 7 (US5) → Phase 8 (Polish)
```

**Story Dependencies**:
- US1 (Deploy Infrastructure) - No dependencies, can start immediately
- US2 (Send Test Requests) - **Depends on**: US1 (needs deployed service)
- US3 (Add Signatures) - **Depends on**: US2 (enhances request sending)
- US4 (Store Examples) - **Depends on**: US2 and US3 (needs working utility)
- US5 (Demonstrate WAF) - **Depends on**: US1-US4 (needs all previous functionality)

### MVP Scope (Recommended First Implementation)

Complete **Phase 1-3 (US1: Deploy Infrastructure)** first for a minimal viable product:
- ✅ Project setup
- ✅ Deployment scripts with validation
- ✅ Basic infrastructure deployment capability
- **Value**: Developers can deploy infrastructure without CI/CD pipeline

---

## Phase 1: Setup & Project Initialization

**Goal**: Set up project structure and foundational components

### Tasks

- [ ] T001 Create project directory structure per implementation plan
  - Create `infrastructure/scripts/lib/`
  - Create `tools/TxtTv.TestUtility/`
  - Create `examples/requests/legitimate/`
  - Create `examples/requests/waf-tests/`
  - Create `tests/deployment/`
  - Create `tests/utility/`
  - **Files**: Directory structure only

- [ ] T002 [P] Create F# project for test utility in tools/TxtTv.TestUtility/TxtTv.TestUtility.fsproj
  - Initialize .NET 10 F# console project
  - Configure output type as executable
  - Set target framework to net10.0
  - **Files**: tools/TxtTv.TestUtility/TxtTv.TestUtility.fsproj

- [ ] T003 [P] Add Argu NuGet package to F# project
  - Add Argu package reference for CLI argument parsing
  - Add FSharp.Data for HTTP operations
  - Add System.Text.Json for JSON parsing
  - **Files**: tools/TxtTv.TestUtility/TxtTv.TestUtility.fsproj

- [ ] T004 [P] Create .gitignore entries for generated files
  - Add `bin/`, `obj/` for .NET builds
  - Add local parameter files
  - Add `*.user` files
  - **Files**: .gitignore (update)

- [ ] T005 Create README for examples directory at examples/requests/README.md
  - Document example request file format
  - Explain legitimate vs waf-tests organization
  - Provide quick usage examples
  - **Files**: examples/requests/README.md

---

## Phase 2: Foundational Components (Blocking Prerequisites)

**Goal**: Implement shared infrastructure used by all user stories

**Must Complete Before User Stories**: These components are used across multiple stories

### Tasks

- [ ] T006 [P] Create PowerShell module for Bicep helpers in infrastructure/scripts/lib/BicepHelpers.psm1
  - Function: Test-BicepTemplate (validates Bicep syntax)
  - Function: Invoke-BicepBuild (compiles Bicep to ARM JSON)
  - Export module functions
  - **Files**: infrastructure/scripts/lib/BicepHelpers.psm1

- [ ] T007 [P] Create PowerShell module for Azure authentication in infrastructure/scripts/lib/AzureAuth.psm1
  - Function: Test-AzureAuthentication (checks if logged in)
  - Function: Get-AzureSubscriptionContext (gets current subscription)
  - Function: Set-AzureSubscriptionContext (sets subscription)
  - **Files**: infrastructure/scripts/lib/AzureAuth.psm1

- [ ] T008 [P] Create PowerShell module for error handling in infrastructure/scripts/lib/ErrorHandling.psm1
  - Function: Write-DeploymentLog (structured logging)
  - Function: Format-ErrorMessage (error formatting)
  - Function: Exit-WithError (error exit handling)
  - **Files**: infrastructure/scripts/lib/ErrorHandling.psm1

- [ ] T009 [P] Create CLI argument types in tools/TxtTv.TestUtility/CliArguments.fs
  - Define Argu discriminated union for commands (Send, Load, List)
  - Define argument types (url, method, key, file, directory)
  - Configure help text
  - **Files**: tools/TxtTv.TestUtility/CliArguments.fs

---

## Phase 3: User Story 1 - Deploy Infrastructure (P1)

**Goal**: Enable developers to deploy Azure infrastructure with a simple PowerShell script

**Independent Test Criteria**: 
- Run deployment script against dev environment
- Verify all Azure resources created successfully
- Check deployment completes in <5 minutes
- Confirm cleanup script removes all resources

### Tasks

- [ ] T010 [US1] Create main deployment script at infrastructure/scripts/Deploy-Infrastructure.ps1
  - Define parameters (Environment, SubscriptionId, ResourceGroupName, Location, WhatIf, Verbose)
  - Import helper modules
  - Set error action preference
  - **Files**: infrastructure/scripts/Deploy-Infrastructure.ps1

- [ ] T011 [US1] Implement parameter validation in Deploy-Infrastructure.ps1
  - Validate Environment is dev/staging/prod
  - Check SubscriptionId format if provided
  - Validate ResourceGroupName format
  - Load parameters file path
  - **Files**: infrastructure/scripts/Deploy-Infrastructure.ps1

- [ ] T012 [US1] Implement Azure authentication check in Deploy-Infrastructure.ps1
  - Call Test-AzureAuthentication
  - Display current subscription info
  - Prompt for confirmation with subscription details
  - Handle -Confirm:$false parameter
  - **Files**: infrastructure/scripts/Deploy-Infrastructure.ps1

- [ ] T013 [US1] Implement Bicep template validation in Deploy-Infrastructure.ps1
  - Locate environment-specific main.bicep
  - Call Test-BicepTemplate
  - Build template with Invoke-BicepBuild
  - Display validation results
  - Exit on validation failure
  - **Files**: infrastructure/scripts/Deploy-Infrastructure.ps1

- [ ] T014 [US1] Implement resource group creation/verification in Deploy-Infrastructure.ps1
  - Check if resource group exists
  - Create if missing using New-AzResourceGroup
  - Apply standard tags
  - Log resource group status
  - **Files**: infrastructure/scripts/Deploy-Infrastructure.ps1

- [ ] T015 [US1] Implement Bicep deployment execution in Deploy-Infrastructure.ps1
  - Generate unique deployment name with timestamp
  - Call New-AzResourceGroupDeployment
  - Pass parameters file
  - Set deployment mode to Incremental
  - Handle -WhatIf parameter for dry-run
  - Implement timeout handling ($TimeoutMinutes parameter)
  - **Files**: infrastructure/scripts/Deploy-Infrastructure.ps1

- [ ] T016 [US1] Implement deployment progress monitoring in Deploy-Infrastructure.ps1
  - Poll Get-AzResourceGroupDeployment for status
  - Display progress percentage
  - Show resource provisioning states
  - Update console output without scrolling (Write-Progress)
  - **Files**: infrastructure/scripts/Deploy-Infrastructure.ps1

- [ ] T017 [US1] Implement deployment result output in Deploy-Infrastructure.ps1
  - Collect deployment outputs
  - Format success message with endpoints
  - List created/updated resources
  - Display correlation ID
  - Return structured JSON output if -Json parameter present
  - **Files**: infrastructure/scripts/Deploy-Infrastructure.ps1

- [ ] T018 [US1] Implement error handling for deployment failures in Deploy-Infrastructure.ps1
  - Catch deployment exceptions
  - Extract detailed error messages
  - Show failed resource details
  - Suggest corrective actions based on error code
  - Log correlation ID for troubleshooting
  - **Files**: infrastructure/scripts/Deploy-Infrastructure.ps1

- [ ] T019 [US1] Create cleanup script at infrastructure/scripts/Remove-Infrastructure.ps1
  - Define parameters (Environment, ResourceGroupName, Force, DeleteResourceGroup, PreserveData)
  - Import helper modules
  - Implement authentication check
  - **Files**: infrastructure/scripts/Remove-Infrastructure.ps1

- [ ] T020 [US1] Implement resource deletion logic in Remove-Infrastructure.ps1
  - Prompt for confirmation unless -Force
  - List resources to be deleted
  - Delete individual resources or entire resource group
  - Handle -PreserveData to skip storage accounts
  - Display deletion progress
  - **Files**: infrastructure/scripts/Remove-Infrastructure.ps1

- [ ] T021 [US1] Create deployment script tests at tests/deployment/Deploy-Infrastructure.tests.ps1
  - Test parameter validation
  - Test authentication check (mock)
  - Test Bicep validation call
  - Test dry-run mode (-WhatIf)
  - Use Pester testing framework
  - **Files**: tests/deployment/Deploy-Infrastructure.tests.ps1

---

## Phase 4: User Story 2 - Send Test Requests (P2)

**Goal**: Create utility to send HTTP GET/POST requests with JSON/XML payloads

**Independent Test Criteria**:
- Send GET request to deployed APIM endpoint
- Send POST with JSON payload
- Send POST with XML payload
- Verify responses display status code, headers, and body

### Tasks

- [ ] T022 [P] [US2] Create HTTP client module in tools/TxtTv.TestUtility/HttpClient.fs
  - Define HttpRequest record type
  - Define HttpResponse record type
  - Function to create HttpClient with timeout
  - **Files**: tools/TxtTv.TestUtility/HttpClient.fs

- [ ] T023 [US2] Implement GET request function in HttpClient.fs
  - Function: sendGetRequest (url, headers) -> HttpResponse
  - Build HttpRequestMessage
  - Send request async
  - Capture status, headers, body
  - Handle timeouts and network errors
  - **Files**: tools/TxtTv.TestUtility/HttpClient.fs

- [ ] T024 [US2] Implement POST request function in HttpClient.fs
  - Function: sendPostRequest (url, headers, body, contentType) -> HttpResponse
  - Build HttpRequestMessage with body
  - Set Content-Type header
  - Send request async
  - Return HttpResponse
  - **Files**: tools/TxtTv.TestUtility/HttpClient.fs

- [ ] T025 [P] [US2] Create response formatter in tools/TxtTv.TestUtility/ResponseFormatter.fs
  - Function: formatResponse (response, includeHeaders) -> string
  - Pretty-print status code with color
  - Format headers as table
  - Pretty-print JSON bodies
  - Display XML bodies with indentation
  - **Files**: tools/TxtTv.TestUtility/ResponseFormatter.fs

- [ ] T026 [US2] Implement Send command handler in tools/TxtTv.TestUtility/Program.fs
  - Parse CLI arguments for Send command
  - Extract url, method, headers, body parameters
  - Call sendGetRequest or sendPostRequest
  - Format and display response
  - Return exit code based on success/failure
  - **Files**: tools/TxtTv.TestUtility/Program.fs

- [ ] T027 [US2] Create HTTP client tests at tests/utility/HttpClient.tests.fs
  - Test GET request to mock server
  - Test POST with JSON body
  - Test POST with XML body
  - Test timeout handling
  - Test network error handling
  - Use xUnit testing framework
  - **Files**: tests/utility/HttpClient.tests.fs

---

## Phase 5: User Story 3 - Add Request Signatures (P3)

**Goal**: Add HMAC-SHA256 signature headers to all requests

**Independent Test Criteria**:
- Send request and verify X-TxtTv-Signature header present
- Verify signature changes with different request content
- Test with custom signing key
- Test with default key when none provided

### Tasks

- [ ] T028 [P] [US3] Create signature generator module in tools/TxtTv.TestUtility/SignatureGenerator.fs
  - Function: generateSignature (key, method, path, queryParams, body, timestamp) -> string
  - Implement HMAC-SHA256 using System.Security.Cryptography
  - Sort query parameters for consistent signing
  - Concatenate signed data elements
  - Return Base64-encoded signature
  - **Files**: tools/TxtTv.TestUtility/SignatureGenerator.fs

- [ ] T029 [US3] Implement signature header addition in HttpClient.fs
  - Generate timestamp in ISO 8601 format
  - Call generateSignature with request details and key
  - Add X-TxtTv-Signature header
  - Add X-TxtTv-Timestamp header
  - **Files**: tools/TxtTv.TestUtility/HttpClient.fs

- [ ] T030 [US3] Add signing key parameter to CLI arguments in CliArguments.fs
  - Add --key parameter
  - Make it optional with default value
  - Document in help text
  - **Files**: tools/TxtTv.TestUtility/CliArguments.fs

- [ ] T031 [US3] Update Send command to use signing key in Program.fs
  - Read key from CLI argument or environment variable
  - Pass key to HTTP client functions
  - Display signature in verbose output
  - **Files**: tools/TxtTv.TestUtility/Program.fs

- [ ] T032 [US3] Create signature generator tests at tests/utility/SignatureGenerator.tests.fs
  - Test signature generation with known input/output
  - Test signature uniqueness with different inputs
  - Test with special characters in key
  - Test timestamp inclusion
  - **Files**: tests/utility/SignatureGenerator.tests.fs

---

## Phase 6: User Story 4 - Store Example Requests (P4)

**Goal**: Store pre-defined example requests in repository as JSON files

**Independent Test Criteria**:
- List all example files in directory
- Load example request from JSON file
- Execute loaded request against service
- Verify example follows documented schema

### Tasks

- [ ] T033 [P] [US4] Create request loader module in tools/TxtTv.TestUtility/RequestLoader.fs
  - Define TestRequest record matching JSON schema
  - Function: loadRequestFromFile (filePath) -> TestRequest
  - Parse JSON using System.Text.Json
  - Validate required fields
  - Return structured request
  - **Files**: tools/TxtTv.TestUtility/RequestLoader.fs

- [ ] T034 [P] [US4] Implement List command handler in Program.fs
  - Accept --directory parameter
  - Scan directory recursively for .json files
  - Group by subdirectory (legitimate vs waf-tests)
  - Display categorized list
  - **Files**: tools/TxtTv.TestUtility/Program.fs

- [ ] T035 [US4] Implement Load command handler in Program.fs
  - Accept --file parameter and --key
  - Load request using RequestLoader
  - Display request details (name, description)
  - Execute request via HTTP client
  - Compare actual vs expected behavior
  - Display test result (PASSED/FAILED)
  - **Files**: tools/TxtTv.TestUtility/Program.fs

- [ ] T036 [P] [US4] Create legitimate example: GET page 100 at examples/requests/legitimate/get-page-100.json
  - Set name, description
  - Configure GET /api/pages/100
  - Set expectedBehavior: allowed
  - Set expectedStatusCode: 200
  - **Files**: examples/requests/legitimate/get-page-100.json

- [ ] T037 [P] [US4] Create legitimate example: POST JSON at examples/requests/legitimate/post-json-content.json
  - Configure POST /api/content
  - Set Content-Type: application/json
  - Include sample JSON body
  - Set expectedBehavior: allowed
  - **Files**: examples/requests/legitimate/post-json-content.json

- [ ] T038 [P] [US4] Create legitimate example: POST XML at examples/requests/legitimate/post-xml-content.json
  - Configure POST /api/content
  - Set Content-Type: application/xml
  - Include sample XML body
  - Set expectedBehavior: allowed
  - **Files**: examples/requests/legitimate/post-xml-content.json

- [ ] T039 [US4] Create request loader tests at tests/utility/RequestLoader.tests.fs
  - Test loading valid JSON file
  - Test handling missing required fields
  - Test invalid JSON format
  - Test file not found
  - **Files**: tests/utility/RequestLoader.tests.fs

---

## Phase 7: User Story 5 - Demonstrate WAF Behavior (P5)

**Goal**: Create example requests showcasing WAF blocking patterns

**Independent Test Criteria**:
- Run SQL injection examples against deployed service
- Verify WAF blocks with 403 status
- Run XSS examples and verify blocking
- Run legitimate requests and verify they pass
- All documented expectations match actual behavior

### Tasks

- [ ] T040 [P] [US5] Create WAF example: SQL injection basic at examples/requests/waf-tests/sql-injection-basic.json
  - Configure query param with ' OR '1'='1
  - Set expectedBehavior: blocked
  - Set expectedStatusCode: 403
  - Set wafPattern: sql-injection
  - Document expected behavior
  - **Files**: examples/requests/waf-tests/sql-injection-basic.json

- [ ] T041 [P] [US5] Create WAF example: SQL injection union at examples/requests/waf-tests/sql-injection-union.json
  - Configure query param with UNION SELECT
  - Set expectedBehavior: blocked
  - Set expectedStatusCode: 403
  - Set wafPattern: sql-injection
  - **Files**: examples/requests/waf-tests/sql-injection-union.json

- [ ] T042 [P] [US5] Create WAF example: XSS script tag at examples/requests/waf-tests/xss-script-tag.json
  - Configure POST body with <script>alert('XSS')</script>
  - Set expectedBehavior: blocked
  - Set expectedStatusCode: 403
  - Set wafPattern: xss
  - **Files**: examples/requests/waf-tests/xss-script-tag.json

- [ ] T043 [P] [US5] Create WAF example: XSS event handler at examples/requests/waf-tests/xss-event-handler.json
  - Configure POST body with <img src=x onerror=...>
  - Set expectedBehavior: blocked
  - Set expectedStatusCode: 403
  - Set wafPattern: xss
  - **Files**: examples/requests/waf-tests/xss-event-handler.json

- [ ] T044 [US5] Create WAF patterns documentation at examples/requests/waf-tests/README.md
  - Explain OWASP Top 10 patterns included
  - Document expected WAF behavior for each pattern
  - Provide references to Azure WAF rules
  - Explain how to interpret test results
  - **Files**: examples/requests/waf-tests/README.md

- [ ] T045 [US5] Create integration test script at tests/integration/waf-example-requests.tests.ps1
  - Load all example requests
  - Execute against deployed environment
  - Verify actual behavior matches expected
  - Report test summary (passed/failed counts)
  - Use Pester framework
  - **Files**: tests/integration/waf-example-requests.tests.ps1

---

## Phase 8: Polish & Cross-Cutting Concerns

**Goal**: Documentation, CI/CD (if needed), and final quality checks

### Tasks

- [ ] T046 Update root README.md with feature documentation
  - Add section for deployment scripts usage
  - Add section for test utility usage
  - Link to quickstart guide
  - Add examples of common commands
  - **Files**: README.md

- [ ] T047 Create comprehensive testing script for full validation
  - Script that runs all unit tests
  - Runs all integration tests
  - Executes deployment to test environment
  - Runs all example requests
  - Generates test report
  - **Files**: tests/Run-AllTests.ps1

---

## Parallel Execution Opportunities

Tasks marked with **[P]** can be executed in parallel with other **[P]** tasks in the same phase, as they work on different files with no dependencies.

### Phase 1 Parallel Group
- T002, T003, T004, T005 can all run simultaneously

### Phase 2 Parallel Group
- T006, T007, T008, T009 can all run simultaneously (different files)

### Phase 3 Parallel Group (Within US1)
- T021 (tests) can be developed in parallel with T010-T020 (implementation)

### Phase 4 Parallel Group (Within US2)
- T022, T025 can start together (different modules)
- T027 (tests) can be developed in parallel with implementation

### Phase 5 Parallel Group (Within US3)
- T028 can be developed before T029-T031 integrate it
- T032 (tests) can be developed in parallel

### Phase 6 Parallel Group (Within US4)
- T033, T034, T035 form the core, then T036-T038 (examples) can all be created in parallel
- T039 (tests) in parallel with examples

### Phase 7 Parallel Group (Within US5)
- T040-T043 (all example files) can be created simultaneously
- T044, T045 can be done in parallel with examples

---

## Implementation Strategy

### Incremental Delivery Approach

1. **MVP First (US1)**: Complete Phase 1-3 to enable basic deployment
   - **Delivers**: Infrastructure deployment without CI/CD
   - **Testing**: Manual deployment to dev environment
   - **Duration**: ~1-1.5 days

2. **Add Testing Capability (US2-US3)**: Complete Phase 4-5
   - **Delivers**: HTTP testing with signatures
   - **Testing**: Send requests to deployed service
   - **Duration**: ~1 day

3. **Add Examples (US4-US5)**: Complete Phase 6-7
   - **Delivers**: Repository-stored examples and WAF demonstrations
   - **Testing**: Run all examples, verify WAF behavior
   - **Duration**: ~1 day

4. **Polish**: Complete Phase 8
   - **Delivers**: Documentation, comprehensive tests
   - **Duration**: ~0.5 days

### Quality Gates

Each phase should pass these gates before moving to the next:

**After Phase 3 (US1)**:
- [ ] Deployment script successfully deploys to dev environment
- [ ] All deployed resources show "Succeeded" status
- [ ] Cleanup script removes all resources
- [ ] Deployment completes in <5 minutes

**After Phase 5 (US2-US3)**:
- [ ] Utility sends GET request successfully
- [ ] Utility sends POST with JSON successfully
- [ ] Utility sends POST with XML successfully
- [ ] All requests include signature headers

**After Phase 7 (US4-US5)**:
- [ ] All legitimate examples execute successfully
- [ ] All WAF test examples blocked with 403
- [ ] List command displays all examples
- [ ] Load command executes requests correctly

**After Phase 8 (Polish)**:
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Documentation complete and accurate
- [ ] README.md updated with examples

---

## Validation Checklist

### Functional Validation

- [ ] Deployment script creates all infrastructure resources
- [ ] Deployment script handles errors gracefully
- [ ] Cleanup script removes all resources
- [ ] Test utility sends GET requests
- [ ] Test utility sends POST requests with JSON
- [ ] Test utility sends POST requests with XML
- [ ] All requests include HMAC-SHA256 signatures
- [ ] Example requests load from JSON files
- [ ] WAF blocks malicious patterns (SQL injection, XSS)
- [ ] WAF allows legitimate requests

### Non-Functional Validation

- [ ] Deployment completes in <5 minutes
- [ ] HTTP requests complete in <2 seconds
- [ ] Error messages are clear and actionable
- [ ] CLI help text is comprehensive
- [ ] Code follows F# and PowerShell style guidelines
- [ ] All functions have error handling
- [ ] Tests achieve >80% code coverage

### Documentation Validation

- [ ] Quickstart guide tested end-to-end
- [ ] All example requests documented
- [ ] README.md updated
- [ ] Contract documentation matches implementation
- [ ] Data model matches actual structures

---

## Notes

- **No Backend Changes**: This feature does not modify the F# Azure Functions backend
- **No APIM Policy Changes**: Existing APIM policies remain unchanged
- **No WAF Rule Changes**: Uses existing WAF rules for testing
- **Tests are Optional**: Per specification, tests are only generated if explicitly requested or TDD approach specified

This task breakdown enables:
✅ Independent user story implementation
✅ Clear acceptance criteria per story
✅ Parallel task execution opportunities
✅ Incremental delivery with early value
✅ Clear quality gates between phases
