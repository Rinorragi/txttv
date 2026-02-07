# Example Requests for TXT TV Testing

This directory contains pre-defined HTTP request definitions for testing the deployed TXT TV service. These examples demonstrate both legitimate requests and requests that should be blocked by the Web Application Firewall (WAF).

## Directory Structure

```
examples/requests/
├── legitimate/          # Requests expected to succeed (200 OK)
│   ├── get-page-100.json
│   ├── post-json-content.json
│   └── post-xml-content.json
└── waf-tests/           # Requests expected to be blocked (403 Forbidden)
    ├── sql-injection-basic.json
    ├── sql-injection-union.json
    ├── xss-script-tag.json
    ├── xss-event-handler.json
    └── README.md
```

## File Format

Each example request is stored as a JSON file following this schema:

```json
{
  "name": "Test scenario name",
  "description": "What this test demonstrates",
  "expectedBehavior": "allowed" or "blocked",
  "expectedStatusCode": 200,
  "wafPattern": "sql-injection" | "xss" | "none",
  "tags": ["category", "subcategory"],
  "request": {
    "method": "GET" | "POST" | "PUT" | "DELETE",
    "path": "/api/pages/100",
    "queryParams": {
      "key": "value"
    },
    "headers": {
      "Content-Type": "application/json"
    },
    "body": "Request payload as string"
  }
}
```

For complete schema documentation, see:
- [specs/002-deploy-test-utility/contracts/example-request-format.md](../../specs/002-deploy-test-utility/contracts/example-request-format.md)

## Usage with Test Utility

### List Available Examples

```bash
dotnet run --project tools/TxtTv.TestUtility -- list --directory examples/requests
```

### Run a Single Example

```bash
dotnet run --project tools/TxtTv.TestUtility -- load \
  --file examples/requests/legitimate/get-page-100.json \
  --key your-signing-key
```

### Run All Legitimate Examples

```powershell
Get-ChildItem examples/requests/legitimate/*.json | ForEach-Object {
    dotnet run --project tools/TxtTv.TestUtility -- load --file $_.FullName --key mykey
}
```

### Run All WAF Test Examples

```powershell
Get-ChildItem examples/requests/waf-tests/*.json | ForEach-Object {
    dotnet run --project tools/TxtTv.TestUtility -- load --file $_.FullName --key mykey
}
```

## Expected Behavior

### Legitimate Requests
- **Expected Status**: 200 OK (or appropriate success code)
- **WAF Action**: Allowed through
- **Purpose**: Verify normal functionality works correctly

### WAF Test Requests
- **Expected Status**: 403 Forbidden
- **WAF Action**: Blocked with security warning
- **Purpose**: Verify WAF correctly identifies and blocks malicious patterns

## Creating New Examples

1. Copy an existing example file
2. Modify the request details
3. Set appropriate `expectedBehavior` and `expectedStatusCode`
4. Document what the test demonstrates in the `description` field
5. Add relevant `tags` for categorization

Example:

```json
{
  "name": "My Custom Test",
  "description": "Tests my specific scenario",
  "expectedBehavior": "allowed",
  "expectedStatusCode": 200,
  "wafPattern": "none",
  "tags": ["custom", "testing"],
  "request": {
    "method": "GET",
    "path": "/api/pages/101",
    "headers": {
      "Accept": "application/json"
    }
  }
}
```

## Security Note

⚠️ **The malicious patterns in waf-tests/ are for testing purposes only**

These examples contain real attack patterns (SQL injection, XSS) that should be blocked by the WAF. Do not use these patterns against production systems or systems you don't own. These are strictly for testing the TXT TV demo environment's security capabilities.

## Additional Resources

- [Quickstart Guide](../../specs/002-deploy-test-utility/quickstart.md)
- [Deployment Configuration](../../specs/002-deploy-test-utility/contracts/deployment-config-schema.md)
- [Feature Specification](../../specs/002-deploy-test-utility/spec.md)
