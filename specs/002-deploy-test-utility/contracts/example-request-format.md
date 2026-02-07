# Example Request Format Contract

**Feature**: 002-deploy-test-utility  
**Date**: February 7, 2026  
**Plan**: [../plan.md](../plan.md)

## Overview

This document defines the JSON schema and format for example request files stored in the repository. These files enable reproducible testing scenarios and WAF behavior demonstration.

## JSON Schema

### Version
- JSON Schema Draft 2020-12
- Schema URI: `https://txttv.example.com/schemas/test-request.json` (future)

### Root Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "TxtTV Test Request",
  "description": "Schema for HTTP test request definitions",
  "type": "object",
  "required": ["name", "description", "expectedBehavior", "expectedStatusCode", "request"],
  "properties": {
    "name": {
      "type": "string",
      "description": "Human-readable test scenario name",
      "minLength": 1,
      "maxLength": 100,
      "examples": ["Get Page 100", "SQL Injection - Union Select"]
    },
    "description": {
      "type": "string",
      "description": "Detailed explanation of what this test demonstrates",
      "minLength": 1,
      "examples": ["Fetches TXT TV page 100 content", "Tests WAF blocking of UNION-based SQL injection"]
    },
    "expectedBehavior": {
      "type": "string",
      "enum": ["allowed", "blocked"],
      "description": "Whether request should pass through or be blocked by WAF"
    },
    "expectedStatusCode": {
      "type": "integer",
      "minimum": 100,
      "maximum": 599,
      "description": "Expected HTTP status code in response",
      "examples": [200, 403, 404]
    },
    "wafPattern": {
      "type": "string",
      "enum": ["sql-injection", "xss", "path-traversal", "none"],
      "description": "Type of attack pattern (if any)",
      "default": "none"
    },
    "tags": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "Categorization tags for filtering and organization",
      "examples": [["legitimate", "smoke-test"], ["malicious", "owasp-top-10", "sql"]]
    },
    "request": {
      "type": "object",
      "required": ["method", "path"],
      "properties": {
        "method": {
          "type": "string",
          "enum": ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"],
          "description": "HTTP method"
        },
        "path": {
          "type": "string",
          "pattern": "^/",
          "description": "URL path (must start with /)",
          "examples": ["/api/pages/100", "/api/content"]
        },
        "queryParams": {
          "type": "object",
          "description": "Query string parameters as key-value pairs",
          "additionalProperties": {
            "type": "string"
          },
          "examples": [{"page": "100", "format": "json"}]
        },
        "headers": {
          "type": "object",
          "description": "HTTP headers (excluding signature headers which are added automatically)",
          "additionalProperties": {
            "type": "string"
          },
          "examples": [{"Content-Type": "application/json", "Accept": "application/json"}]
        },
        "body": {
          "type": "string",
          "description": "Request body content (JSON, XML, or plain text as string)",
          "examples": ["{\"content\": \"Hello World\"}", "<content>Hello World</content>"]
        }
      }
    }
  }
}
```

## Example Files

### Legitimate GET Request

**File**: `examples/requests/legitimate/get-page-100.json`

```json
{
  "name": "Get Page 100",
  "description": "Fetches TXT TV page 100 (index page) content",
  "expectedBehavior": "allowed",
  "expectedStatusCode": 200,
  "wafPattern": "none",
  "tags": ["legitimate", "smoke-test", "get"],
  "request": {
    "method": "GET",
    "path": "/api/pages/100",
    "headers": {
      "Accept": "application/json"
    }
  }
}
```

### Legitimate POST with JSON

**File**: `examples/requests/legitimate/post-json-content.json`

```json
{
  "name": "Post JSON Content",
  "description": "Submits valid JSON content to API",
  "expectedBehavior": "allowed",
  "expectedStatusCode": 200,
  "wafPattern": "none",
  "tags": ["legitimate", "post", "json"],
  "request": {
    "method": "POST",
    "path": "/api/content",
    "headers": {
      "Content-Type": "application/json",
      "Accept": "application/json"
    },
    "body": "{\"title\": \"Test Page\", \"content\": \"This is test content with Unicode: åäö\"}"
  }
}
```

### Legitimate POST with XML

**File**: `examples/requests/legitimate/post-xml-content.json`

```json
{
  "name": "Post XML Content",
  "description": "Submits valid XML content to API",
  "expectedBehavior": "allowed",
  "expectedStatusCode": 200,
  "wafPattern": "none",
  "tags": ["legitimate", "post", "xml"],
  "request": {
    "method": "POST",
    "path": "/api/content",
    "headers": {
      "Content-Type": "application/xml",
      "Accept": "application/xml"
    },
    "body": "<?xml version=\"1.0\"?><content><title>Test Page</title><text>This is test content</text></content>"
  }
}
```

### SQL Injection - Basic

**File**: `examples/requests/waf-tests/sql-injection-basic.json`

```json
{
  "name": "SQL Injection - Basic OR",
  "description": "Tests WAF blocking of basic SQL injection using OR '1'='1' pattern",
  "expectedBehavior": "blocked",
  "expectedStatusCode": 403,
  "wafPattern": "sql-injection",
  "tags": ["malicious", "owasp-top-10", "sql-injection", "waf-test"],
  "request": {
    "method": "GET",
    "path": "/api/pages/100",
    "queryParams": {
      "id": "' OR '1'='1"
    }
  }
}
```

### SQL Injection - Union Select

**File**: `examples/requests/waf-tests/sql-injection-union.json`

```json
{
  "name": "SQL Injection - Union Select",
  "description": "Tests WAF blocking of UNION-based SQL injection attack",
  "expectedBehavior": "blocked",
  "expectedStatusCode": 403,
  "wafPattern": "sql-injection",
  "tags": ["malicious", "owasp-top-10", "sql-injection", "waf-test"],
  "request": {
    "method": "GET",
    "path": "/api/pages/100",
    "queryParams": {
      "id": "' UNION SELECT NULL, username, password FROM users--"
    }
  }
}
```

### XSS - Script Tag

**File**: `examples/requests/waf-tests/xss-script-tag.json`

```json
{
  "name": "XSS - Script Tag",
  "description": "Tests WAF blocking of script tag injection",
  "expectedBehavior": "blocked",
  "expectedStatusCode": 403,
  "wafPattern": "xss",
  "tags": ["malicious", "owasp-top-10", "xss", "waf-test"],
  "request": {
    "method": "POST",
    "path": "/api/content",
    "headers": {
      "Content-Type": "application/json"
    },
    "body": "{\"content\": \"<script>alert('XSS')</script>\"}"
  }
}
```

### XSS - Event Handler

**File**: `examples/requests/waf-tests/xss-event-handler.json`

```json
{
  "name": "XSS - Event Handler",
  "description": "Tests WAF blocking of XSS via img onerror event handler",
  "expectedBehavior": "blocked",
  "expectedStatusCode": 403,
  "wafPattern": "xss",
  "tags": ["malicious", "owasp-top-10", "xss", "waf-test"],
  "request": {
    "method": "POST",
    "path": "/api/content",
    "headers": {
      "Content-Type": "application/json"
    },
    "body": "{\"content\": \"<img src=x onerror=alert('XSS')>\"}"
  }
}
```

## File Organization

```
examples/requests/
├── legitimate/          # Requests expected to pass
│   ├── get-page-100.json
│   ├── get-page-101.json
│   ├── post-json-content.json
│   └── post-xml-content.json
└── waf-tests/           # Requests expected to be blocked
    ├── sql-injection-basic.json
    ├── sql-injection-union.json
    ├── sql-injection-stacked.json
    ├── xss-script-tag.json
    ├── xss-event-handler.json
    ├── xss-data-uri.json
    └── README.md        # Documentation of WAF patterns
```

## Naming Conventions

### File Names
- Lowercase with hyphens
- Pattern: `{attack-type}-{variant}.json` for WAF tests
- Pattern: `{method}-{description}.json` for legitimate requests
- Examples:
  - `sql-injection-union.json`
  - `get-page-100.json`
  - `post-json-content.json`

### Request Names
- Title case
- Descriptive of action or attack
- Examples:
  - "Get Page 100"
  - "SQL Injection - Union Select"
  - "Post JSON Content"

## Validation Rules

### Required Fields
- All requests MUST have: `name`, `description`, `expectedBehavior`, `expectedStatusCode`, `request`
- Request object MUST have: `method`, `path`

### Conditional Requirements
- If `request.body` is present, `request.headers["Content-Type"]` SHOULD be set
- If `expectedBehavior` is "blocked", `expectedStatusCode` SHOULD be 403
- If `wafPattern` is not "none", `expectedBehavior` SHOULD be "blocked"
- If `request.method` is GET or HEAD, `request.body` SHOULD be empty

### Best Practices
- Use descriptive `name` and `description`
- Add relevant `tags` for filtering
- Document WHY a request should be blocked in `description`
- Include realistic content, not just attack signatures
- Test both positive (allowed) and negative (blocked) cases

## Loading and Execution Contract

### Discovery
1. Utility scans `examples/requests/` recursively
2. Identifies files with `.json` extension
3. Parses each file against schema
4. Reports validation errors before execution

### Execution
1. Utility loads request definition from file
2. Adds signature headers automatically:
   - `X-TxtTV-Signature`: HMAC-SHA256 signature
   - `X-TxtTV-Timestamp`: ISO 8601 timestamp
3. Sends HTTP request to configured base URL
4. Captures response (status, headers, body)
5. Compares actual vs expected behavior
6. Reports match/mismatch

### Output Format
```
[✓] Get Page 100
    Status: 200 OK (expected 200)
    Behavior: allowed (expected allowed)
    Duration: 145ms

[✗] SQL Injection - Basic OR
    Status: 200 OK (expected 403)
    Behavior: allowed (expected blocked)
    Duration: 132ms
    ❌ UNEXPECTED: Request was not blocked by WAF
```

## Extension Points (Future)

- **Request chaining**: Reference previous response data
- **Variables**: Parameterize request values
- **Assertions**: Beyond status code (body content, headers)
- **Pre/post scripts**: Setup and teardown actions
- **Response schema validation**: Validate response structure

## Related Documents

- [Deployment Config Schema](deployment-config-schema.md) - Deployment parameter format
- [Data Model](../data-model.md) - Entity definitions
- [Quickstart Guide](../quickstart.md) - Usage examples
