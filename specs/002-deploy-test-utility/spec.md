# Feature Specification: Simple Deployment & WAF Testing Utility

**Feature Branch**: `002-deploy-test-utility`  
**Created**: February 7, 2026  
**Status**: Draft  
**Input**: User description: "Remove devops pipeline and instead make super simple script to install the azure infrastructure. Then with the script in hand make a utility software that can call the service and see that it responses. It should send simple http requests to fetch content and to add json or xml content to get and post requests. These requests are for testing purposes and thus examples can be stored in the repository. I want all the requests to have some form of signature in place with custom key. Server does not need to validate it. This is to showcase what kind of requests are blocked by waf and what are not."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deploy Infrastructure (Priority: P1)

As a developer, I want to deploy the Azure infrastructure using a simple script so that I can quickly set up the environment without complex DevOps pipelines.

**Why this priority**: This is the foundation requirement - without the ability to deploy infrastructure, no testing can occur. It's the essential first step that unlocks all other functionality.

**Independent Test**: Can be fully tested by running the deployment script and verifying that Azure resources are created successfully. Delivers a working infrastructure environment ready for use.

**Acceptance Scenarios**:

1. **Given** I have Azure credentials configured, **When** I run the deployment script, **Then** all required Azure resources are created successfully
2. **Given** infrastructure already exists, **When** I run the deployment script again, **Then** it updates existing resources without errors
3. **Given** deployment fails, **When** I check the output, **Then** I see clear error messages indicating what went wrong
4. **Given** I want to remove infrastructure, **When** I run the cleanup script, **Then** all resources are deleted from Azure

---

### User Story 2 - Send Test Requests (Priority: P2)

As a developer, I want to send HTTP requests (GET and POST) with JSON and XML payloads to the deployed service so that I can verify the service is responding correctly.

**Why this priority**: Once infrastructure is deployed, the ability to verify it's working is the next critical step. This validates the deployment and provides immediate feedback.

**Independent Test**: Can be tested by running the utility with example requests against a deployed service and verifying responses are received. Delivers confidence that the service is operational.

**Acceptance Scenarios**:

1. **Given** the service is deployed, **When** I send a GET request to fetch content, **Then** I receive the expected content response
2. **Given** the service is deployed, **When** I send a POST request with JSON payload, **Then** I receive a success response
3. **Given** the service is deployed, **When** I send a POST request with XML payload, **Then** I receive a success response
4. **Given** a request fails, **When** I review the output, **Then** I see the HTTP status code and error details

---

### User Story 3 - Add Request Signatures (Priority: P3)

As a developer, I want all test requests to include a custom signature header so that I can demonstrate how request authentication should look (even though validation is not required).

**Why this priority**: This adds a realistic element to testing but is not essential for basic verification. It's useful for documentation and demonstration purposes.

**Independent Test**: Can be tested by inspecting request headers in the utility output and verifying the signature is present and follows the expected format.

**Acceptance Scenarios**:

1. **Given** I configure a custom signing key, **When** I send any request, **Then** the request includes a signature header
2. **Given** I send multiple requests, **When** I inspect the signatures, **Then** each signature is unique based on the request content
3. **Given** no signing key is provided, **When** I send a request, **Then** a default signature is generated

---

### User Story 4 - Store Example Requests (Priority: P4)

As a developer, I want pre-defined example requests stored in the repository so that I can quickly run common test scenarios without manually crafting requests.

**Why this priority**: This is a convenience feature that improves usability but is not essential for core functionality. Examples can be added incrementally.

**Independent Test**: Can be tested by loading example requests from files and successfully executing them against the service.

**Acceptance Scenarios**:

1. **Given** example requests exist in the repository, **When** I run the utility with an example file, **Then** the request is sent using the stored parameters
2. **Given** multiple example files exist, **When** I list available examples, **Then** I see all available test scenarios
3. **Given** I want to add a new example, **When** I create a new example file, **Then** it follows the documented format

---

### User Story 5 - Demonstrate WAF Behavior (Priority: P5)

As a developer, I want to send requests that showcase WAF blocking behavior so that I can understand which patterns are flagged as malicious (SQL injection, XSS) and which are allowed.

**Why this priority**: This is valuable for understanding security boundaries but depends on all previous stories being complete. It's primarily educational/demonstrative.

**Independent Test**: Can be tested by sending known-malicious payloads and verifying they are blocked by WAF, while safe payloads pass through.

**Acceptance Scenarios**:

1. **Given** the WAF is configured, **When** I send a request with SQL injection patterns, **Then** the WAF blocks the request with a 403 status
2. **Given** the WAF is configured, **When** I send a request with XSS patterns, **Then** the WAF blocks the request with a 403 status
3. **Given** the WAF is configured, **When** I send a legitimate request, **Then** the request passes through successfully
4. **Given** I want to understand blocking, **When** I review WAF test examples, **Then** each example is documented with expected behavior

---

### Edge Cases

- What happens when Azure credentials are not configured or are invalid?
- How does the deployment script handle partial failures (some resources created, others failed)?
- What happens when the service endpoint is unreachable or times out?
- How does the utility handle malformed JSON or XML in request payloads?
- What happens when the signing key contains special characters?
- How does the system behave when sending extremely large payloads?
- What happens when network connectivity is lost mid-request?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a deployment script that creates all necessary Azure infrastructure resources
- **FR-002**: Deployment script MUST be runnable from the command line with minimal prerequisites
- **FR-003**: Deployment script MUST provide clear success/failure feedback to the user
- **FR-004**: System MUST provide a cleanup script to remove all deployed Azure resources
- **FR-005**: Utility software MUST send HTTP GET requests to fetch content from the deployed service
- **FR-006**: Utility software MUST send HTTP POST requests with JSON payloads
- **FR-007**: Utility software MUST send HTTP POST requests with XML payloads
- **FR-008**: Utility software MUST display response status codes and content
- **FR-009**: All requests MUST include a custom signature header
- **FR-010**: Signature generation MUST use a configurable custom key
- **FR-011**: Server is NOT REQUIRED to validate signatures (demonstration purposes only)
- **FR-012**: System MUST store example requests in the repository for common test scenarios
- **FR-013**: Example requests MUST include both legitimate and WAF-triggering patterns
- **FR-014**: Example requests MUST cover SQL injection test patterns
- **FR-015**: Example requests MUST cover XSS (Cross-Site Scripting) test patterns
- **FR-016**: Utility software MUST support loading and executing requests from example files
- **FR-017**: Deployment script MUST support updating existing infrastructure
- **FR-018**: Utility software MUST handle connection failures gracefully with clear error messages
- **FR-019**: Utility software MUST support configuring the target service endpoint
- **FR-020**: Example request files MUST be documented with expected behavior (allowed/blocked by WAF)

### Key Entities

- **Deployment Script**: Command-line executable that creates Azure infrastructure; takes configuration parameters; outputs deployment status and resource identifiers
- **Cleanup Script**: Command-line executable that removes Azure infrastructure; takes resource identifiers or configuration; confirms before deletion
- **Utility Software**: Command-line or GUI application that sends HTTP requests; takes endpoint URL, request type, payload, and signing key; outputs response status and content
- **Example Request**: File containing request definition; includes HTTP method, endpoint path, headers, payload (JSON or XML); documented with expected WAF behavior
- **Custom Signature**: Header value computed from request content and custom key; unique per request; demonstrates authentication pattern without requiring server validation
- **Azure Infrastructure**: Collection of Azure resources including APIM, Application Gateway, WAF, backend services, and storage as defined in existing Bicep templates

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developer can deploy complete Azure infrastructure in under 5 minutes by running a single script
- **SC-002**: Developer can verify service is operational within 30 seconds using the utility software
- **SC-003**: 100% of example requests execute successfully against the deployed service
- **SC-004**: WAF blocks 100% of malicious pattern requests (SQL injection, XSS) while allowing 100% of legitimate requests
- **SC-005**: All test scenarios are reproducible by any developer using the stored example requests
- **SC-006**: Infrastructure cleanup completes successfully and removes all resources
- **SC-007**: Utility software successfully sends requests with all supported content types (JSON, XML, plain text)
- **SC-008**: Every request includes a valid signature header that follows the documented format
- **SC-009**: Developer can understand WAF behavior by examining example requests and their documented outcomes
- **SC-010**: Deployment script succeeds on first attempt when Azure credentials are properly configured

## Assumptions

- Azure CLI or PowerShell Az module is available on the developer's machine
- Developer has valid Azure subscription credentials with permissions to create resources
- Existing Bicep templates in the repository are functional and up-to-date
- The signature algorithm will use HMAC-SHA256 (industry standard for request signing)
- Example request files will use JSON format for request definitions
- The utility software will be command-line based for simplicity
- Network connectivity to Azure is available during deployment
- The target environment is development/testing, not production
- WAF rules are already configured in the existing infrastructure templates
- Developers are familiar with basic command-line operations

## Dependencies

- Existing Bicep infrastructure templates in `infrastructure/` directory
- Azure subscription and appropriate permissions
- Azure CLI or PowerShell Az module installation
- Network access to Azure services
- Existing WAF rule configurations (SQL injection, XSS protection)
- Example content files in `content/pages/` directory
- Git repository access for storing and retrieving example requests

## Out of Scope

- Automated CI/CD pipeline integration (explicitly removed per requirements)
- Production-grade deployment with multiple environments
- Server-side signature validation logic
- Real-time monitoring or logging dashboard
- Automated rollback mechanisms
- Load testing or performance benchmarking
- User authentication beyond demonstration signatures
- Database state management between deployments
- Automated infrastructure testing beyond basic validation
