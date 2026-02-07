# Data Model: Simple Deployment & WAF Testing Utility

**Feature**: 002-deploy-test-utility  
**Date**: February 7, 2026  
**Plan**: [plan.md](plan.md)

## Overview

This document defines the data entities and their relationships for the deployment automation and testing utility. These entities represent configuration, request definitions, and runtime state without implementation details.

## Core Entities

### 1. Deployment Configuration

**Purpose**: Defines Azure infrastructure deployment parameters

**Attributes**:
- `environment`: Environment name (dev, staging, prod)
- `subscriptionId`: Azure subscription identifier
- `resourceGroupName`: Target resource group name
- `location`: Azure region (e.g., eastus, westeurope)
- `baseName`: Prefix for resource naming
- `apimPublisherEmail`: Email for APIM publisher contact
- `apimPublisherName`: Name for APIM publisher
- `bicepTemplatePath`: Path to main Bicep template file
- `parametersFilePath`: Path to environment-specific parameters JSON
- `deploymentName`: Unique name for deployment tracking
- `timestamp`: Deployment initiation time

**Validation Rules**:
- `environment` must be one of: dev, staging, prod
- `subscriptionId` must be valid GUID format
- `resourceGroupName` must follow Azure naming rules (3-90 chars, alphanumeric and hyphens)
- `location` must be valid Azure region
- `baseName` must be 3-10 characters, alphanumeric only
- `apimPublisherEmail` must be valid email format
- `bicepTemplatePath` and `parametersFilePath` must exist on filesystem

**State Transitions**:
1. **Pending** → Deployment not yet started
2. **Validating** → Bicep template validation in progress
3. **Deploying** → Azure resource deployment in progress
4. **Completed** → Deployment successful
5. **Failed** → Deployment encountered error
6. **RolledBack** → Resources removed after failure

**Relationships**:
- References → Azure Subscription (external)
- References → Bicep Template (filesystem)
- References → Parameters File (filesystem)
- Produces → Deployment Result

---

### 2. Deployment Result

**Purpose**: Captures outcome of deployment operation

**Attributes**:
- `deploymentName`: Unique deployment identifier
- `status`: Deployment status (Completed, Failed, PartiallySucceeded)
- `startTime`: When deployment began
- `endTime`: When deployment finished
- `duration`: Elapsed time
- `resourcesCreated`: List of created resource names and types
- `resourcesUpdated`: List of updated resource names
- `resourcesFailed`: List of resources that failed deployment
- `outputs`: Key-value pairs of Bicep output values
- `errorMessages`: Detailed error descriptions if failed
- `correlationId`: Azure deployment correlation ID for troubleshooting

**Validation Rules**:
- `status` must be one of: Completed, Failed, PartiallySucceeded
- `startTime` must precede `endTime`
- `duration` must be positive
- If `status` is Failed, `errorMessages` must not be empty
- If `status` is Completed, `resourcesFailed` must be empty

**Relationships**:
- Produced by → Deployment Configuration
- Contains → Resource Info (multiple)

---

### 3. Test Request

**Purpose**: Defines an HTTP request to send to deployed service

**Attributes**:
- `name`: Human-readable test scenario name
- `description`: What the test demonstrates
- `method`: HTTP method (GET, POST, PUT, DELETE, PATCH)
- `path`: URL path (relative to base URL)
- `queryParams`: Key-value pairs for query string
- `headers`: Key-value pairs for HTTP headers
- `body`: Request payload (string, can be JSON/XML/plain text)
- `contentType`: MIME type of request body
- `expectedBehavior`: Expected outcome (allowed, blocked)
- `expectedStatusCode`: Expected HTTP status code
- `wafPattern`: Attack pattern category (sql-injection, xss, none)
- `tags`: Categorization tags (legitimate, malicious, edge-case)

**Validation Rules**:
- `name` must be non-empty, max 100 characters
- `method` must be valid HTTP method
- `path` must start with `/`
- `contentType` required if `body` is present
- `expectedBehavior` must be one of: allowed, blocked
- `expectedStatusCode` must be valid HTTP status code (100-599)
- `wafPattern` must be one of: sql-injection, xss, path-traversal, none
- If `wafPattern` is not "none", `expectedBehavior` should be "blocked"

**State Transitions**:
1. **Defined** → Request created but not sent
2. **Pending** → Queued for sending
3. **Executing** → HTTP request in flight
4. **Completed** → Response received
5. **Failed** → Network error or timeout

**Relationships**:
- Produces → Test Response
- References → Test Request File (optional, if loaded from file)

---

### 4. Test Response

**Purpose**: Captures HTTP response from deployed service

**Attributes**:
- `requestName`: Name of originating request
- `statusCode`: HTTP status code received
- `statusText`: HTTP status reason phrase
- `headers`: Response headers (key-value pairs)
- `body`: Response body content
- `contentType`: Response content type
- `duration`: Request-response time (milliseconds)
- `timestamp`: When response was received
- `errorMessage`: Error description if request failed
- `behaviorMatch`: Whether actual behavior matches expected
- `statusCodeMatch`: Whether status code matches expected

**Validation Rules**:
- `statusCode` must be valid HTTP status code (100-599)
- `duration` must be non-negative
- `timestamp` must be valid date-time
- `behaviorMatch` is true only if actual matches `Test Request.expectedBehavior`
- `statusCodeMatch` is true only if `statusCode` matches `Test Request.expectedStatusCode`

**Relationships**:
- Produced by → Test Request
- References → Test Request (for validation comparison)

---

### 5. Request Signature

**Purpose**: HMAC-SHA256 signature for request authentication

**Attributes**:
- `algorithm`: Signature algorithm (HMAC-SHA256)
- `key`: Secret key used for signing (not stored, runtime only)
- `signedData`: Canonical string that was signed
- `timestamp`: ISO 8601 timestamp included in signed data
- `signatureValue`: Base64-encoded HMAC hash
- `headerName`: HTTP header name for signature (X-TxtTv-Signature)
- `timestampHeaderName`: HTTP header name for timestamp (X-TxtTv-Timestamp)

**Signed Data Format**:
```
{HTTP_METHOD}\n
{URL_PATH}\n
{SORTED_QUERY_PARAMS}\n
{REQUEST_BODY}\n
{TIMESTAMP}
```

**Validation Rules**:
- `algorithm` must be "HMAC-SHA256"
- `key` must be non-empty, minimum 16 characters recommended
- `timestamp` must be ISO 8601 format
- `signatureValue` must be valid Base64 string
- Timestamp should be within ±5 minutes of current time (prevents replay attacks)

**Relationships**:
- Attached to → Test Request (one per request)
- Uses → Signing Key (runtime configuration)

---

### 6. Test Request File

**Purpose**: Persistent storage of test request definitions

**Attributes**:
- `filePath`: Absolute path to JSON file
- `fileName`: File name without path
- `category`: File category (legitimate, waf-tests)
- `lastModified`: File modification timestamp
- `isValid`: Whether file parses as valid JSON
- `validationErrors`: JSON schema validation errors if any
- `requestDefinition`: Parsed Test Request entity

**Validation Rules**:
- `filePath` must exist on filesystem
- `fileName` must have `.json` extension
- `category` must be one of: legitimate, waf-tests, custom
- File content must be valid JSON
- JSON must conform to Test Request schema

**Relationships**:
- Contains → Test Request (one per file)
- Located in → Examples Directory

---

### 7. Deployment Script Configuration

**Purpose**: Runtime configuration for deployment scripts

**Attributes**:
- `azureAuthentication`: Authentication method (az-cli, az-powershell, service-principal)
- `verbose`: Enable verbose logging
- `whatIf`: Dry-run mode (validate without deploying)
- `confirmBeforeDeploy`: Prompt user for confirmation
- `timeoutMinutes`: Maximum deployment duration
- `retryAttempts`: Number of retry attempts on failure
- `tags`: Additional Azure resource tags
- `skipValidation`: Skip Bicep validation (not recommended)

**Validation Rules**:
- `azureAuthentication` must be one of supported methods
- `timeoutMinutes` must be positive, max 120
- `retryAttempts` must be 0-5
- If `skipValidation` is true, warning must be displayed

**Relationships**:
- Used by → Deployment Script
- Affects → Deployment Configuration

---

### 8. Utility Configuration

**Purpose**: Runtime configuration for test utility

**Attributes**:
- `baseUrl`: Base URL of deployed service (e.g., https://txttv-dev-appgw.azurewebsites.net)
- `signingKey`: Secret key for HMAC signature generation
- `defaultTimeout`: Default request timeout (seconds)
- `outputFormat`: Response display format (table, json, detailed)
- `verifyTls`: Whether to verify TLS certificates
- `examplesDirectory`: Path to example request files directory
- `logLevel`: Logging verbosity (quiet, normal, verbose, debug)

**Validation Rules**:
- `baseUrl` must be valid HTTPS URL (HTTP allowed for local testing only)
- `signingKey` must be non-empty if signatures required
- `defaultTimeout` must be 1-300 seconds
- `outputFormat` must be one of: table, json, detailed
- `examplesDirectory` must exist on filesystem

**Relationships**:
- Used by → Test Utility Application
- References → Examples Directory

---

## Entity Relationships Diagram

```
Deployment Configuration
    │
    ├──→ Validates Using: Bicep Template
    ├──→ Produces: Deployment Result
    │       └──→ Contains: Resource Info (multiple)
    └──→ Configured By: Deployment Script Configuration

Test Request File
    │
    ├──→ Contains: Test Request
    │       ├──→ Attached: Request Signature
    │       └──→ Produces: Test Response
    │
    └──→ Located In: Examples Directory

Utility Configuration
    │
    ├──→ Uses: Signing Key
    ├──→ References: Examples Directory
    └──→ Affects: Test Request execution
```

## Data Persistence

### Filesystem Storage
- **Deployment configurations**: `infrastructure/environments/{env}/parameters.json`
- **Test request files**: `examples/requests/{category}/*.json`
- **Bicep templates**: `infrastructure/modules/**/*.bicep`

### Runtime-Only (No Persistence)
- Deployment Result (displayed to console, not saved)
- Test Response (displayed to console, not saved unless explicitly exported)
- Request Signature (generated per request)
- Signing Key (provided via CLI argument or environment variable)

### Optional Logging
- Deployment logs: Can be saved to `logs/deployment-{timestamp}.log`
- Test results: Can be exported to `logs/test-results-{timestamp}.json`

## Data Format Standards

### Date/Time Format
- ISO 8601: `2026-02-07T14:30:00Z`
- Used in: timestamps, deployment times, request signatures

### Resource Naming
- Azure convention: lowercase, alphanumeric, hyphens
- Pattern: `{baseName}-{environment}-{resourceType}`
- Example: `txttv-dev-apim`

### JSON Schema Version
- JSON Schema Draft 2020-12
- Used for: Test Request File validation

### HTTP Standards
- HTTP/1.1 or HTTP/2
- Standard headers: `Content-Type`, `Authorization`, `X-TxtTv-Signature`
- Standard status codes: 2xx (success), 4xx (client error), 5xx (server error)

## Security Considerations

### Sensitive Data
- **Signing keys**: Never stored in files, passed via CLI or environment variables
- **Azure credentials**: Managed by Azure CLI/PowerShell, not by scripts
- **APIM keys**: Retrieved from Azure at deployment time, not hardcoded

### Data Sanitization
- Log output: Sanitize signatures and keys before display
- Error messages: Avoid exposing internal paths or credentials
- Example files: Use placeholder values for sensitive fields

## Future Extensions (Out of Current Scope)

- Test result history database
- Automated test scheduling
- Response assertion rules beyond status code matching
- Performance metrics storage
- Test report generation
