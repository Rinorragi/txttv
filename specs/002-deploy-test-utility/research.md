# Research: Simple Deployment & WAF Testing Utility

**Feature**: 002-deploy-test-utility  
**Date**: February 7, 2026  
**Plan**: [plan.md](plan.md)

## Overview

This document consolidates research findings for implementing a simple deployment automation script and HTTP testing utility. The research resolves technical unknowns identified in the Technical Context section of the implementation plan.

## Research Areas

### 1. PowerShell Deployment Script Best Practices

**Decision**: Use PowerShell 7+ with Az module for deployment orchestration

**Rationale**:
- PowerShell Az module provides native Bicep deployment support via `New-AzResourceGroupDeployment`
- Cross-platform support (Windows, Linux, macOS) with PowerShell 7+
- Rich error handling and structured output capabilities
- Existing Bicep templates require minimal modification
- Azure CLI is alternative but Az module offers better programmatic control

**Alternatives Considered**:
- Azure CLI (`az deployment`) - Good for simple scripts but less flexible for error handling
- Terraform - Overkill for feature scope, requires state management
- ARM templates - Already using Bicep, no benefit to convert

**Implementation Approach**:
- Main script: `Deploy-Infrastructure.ps1` orchestrates Bicep deployment
- Module pattern: Shared functionality in `.psm1` modules for testability
- Parameter validation: Check Azure context and subscription before deployment
- Error handling: Try-catch blocks with detailed error messages
- Rollback: Document manual rollback steps (automated rollback out of scope)

**References**:
- [PowerShell Az.Resources module documentation](https://docs.microsoft.com/en-us/powershell/module/az.resources/)
- [Bicep deployment with PowerShell](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-powershell)

### 2. HMAC-SHA256 Signature Generation

**Decision**: Use .NET `System.Security.Cryptography.HMACSHA256` class in F# utility

**Rationale**:
- Industry standard for request signing (used by AWS, Azure, OAuth)
- Built into .NET BCL, no external dependencies
- Cryptographically secure and well-tested
- Efficient implementation with streaming support
- Produces 256-bit (32-byte) hash suitable for Base64 encoding

**Signature Format Decision**:
- Header name: `X-TxtTv-Signature`
- Value format: `HMAC-SHA256 <base64-encoded-hash>`
- Signed data: HTTP method + path + sorted query params + body + timestamp
- Timestamp: ISO 8601 format in `X-TxtTv-Timestamp` header (prevents replay attacks)

**Alternatives Considered**:
- HMAC-SHA1 - Deprecated, less secure
- RSA signatures - More complex, requires key management
- JWT - Adds unnecessary complexity for demonstration purposes

**Implementation Example**:
```fsharp
open System.Security.Cryptography
open System.Text

let generateSignature (key: string) (data: string) =
    use hmac = new HMACSHA256(Encoding.UTF8.GetBytes(key))
    let hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(data))
    Convert.ToBase64String(hash)
```

**References**:
- [RFC 2104 - HMAC specification](https://www.ietf.org/rfc/rfc2104.txt)
- [.NET HMACSHA256 documentation](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.hmacsha256)

### 3. Example Request File Format

**Decision**: Use JSON format with structured schema

**Rationale**:
- Human-readable and easy to edit
- Native F# JSON parsing support via `System.Text.Json`
- Allows comments via preprocessing or separate metadata files
- Schema validation possible with JSON Schema
- Git-friendly for version control and diffs

**JSON Schema Design**:
```json
{
  "name": "Test scenario name",
  "description": "What this test demonstrates",
  "expectedBehavior": "allowed" | "blocked",
  "expectedStatusCode": 200,
  "wafPattern": "sql-injection" | "xss" | "none",
  "request": {
    "method": "GET" | "POST",
    "path": "/api/pages/100",
    "headers": {
      "Content-Type": "application/json"
    },
    "body": "Request payload as string"
  }
}
```

**Alternatives Considered**:
- YAML - More readable but requires external parser
- XML - Verbose, less developer-friendly
- Plain text - No structure, hard to parse
- PowerShell hashtables - Not portable outside PowerShell

**Storage Organization**:
- `examples/requests/legitimate/` - Valid requests expected to pass
- `examples/requests/waf-tests/` - Malicious patterns expected to be blocked
- Each file named descriptively: `sql-injection-union-select.json`

**References**:
- [JSON Schema specification](https://json-schema.org/)
- [System.Text.Json documentation](https://docs.microsoft.com/en-us/dotnet/standard/serialization/system-text-json-overview)

### 4. WAF Test Patterns

**Decision**: Focus on OWASP Top 10 patterns already configured in existing WAF rules

**Rationale**:
- Existing infrastructure has SQL injection and XSS WAF rules
- Demonstrates real attack vectors
- OWASP patterns are well-documented and recognizable
- Provides educational value for developers

**SQL Injection Patterns to Test**:
1. **Basic injection**: `' OR '1'='1`
2. **Union-based**: `' UNION SELECT NULL, NULL--`
3. **Stacked queries**: `'; DROP TABLE users--`
4. **Encoded injection**: `%27%20OR%20%271%27=%271`

**XSS Patterns to Test**:
1. **Script tag**: `<script>alert('XSS')</script>`
2. **Event handler**: `<img src=x onerror=alert('XSS')>`
3. **Data URI**: `<a href="data:text/html,<script>alert('XSS')</script>">Click</a>`
4. **Encoded XSS**: `%3Cscript%3Ealert('XSS')%3C/script%3E`

**Legitimate Patterns to Test**:
1. **Normal GET**: Fetch page content
2. **JSON POST**: Valid content submission
3. **XML POST**: Valid XML payload
4. **Special characters**: Valid Unicode content

**Expected WAF Behavior**:
- Malicious patterns: HTTP 403 Forbidden with WAF block message
- Legitimate patterns: HTTP 200 OK with expected response

**References**:
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Azure WAF rule documentation](https://learn.microsoft.com/en-us/azure/web-application-firewall/)
- Existing WAF rules in `infrastructure/modules/waf/rules/`

### 5. F# CLI Framework Selection

**Decision**: Use `Argu` library for command-line argument parsing

**Rationale**:
- Idiomatic F# library with discriminated union-based API
- Automatic help generation
- Type-safe argument parsing
- Supports required/optional arguments, flags, and parameters
- Lightweight dependency (~100KB)

**Alternatives Considered**:
- `System.CommandLine` - More verbose, less F#-idiomatic
- Manual parsing - Error-prone, no help generation
- `FSharp.Core` ParameterAttribute - Limited functionality

**CLI Usage Pattern**:
```bash
# Send single request
dotnet run --project tools/TxtTv.TestUtility -- send --url https://example.com/api/pages/100 --method GET --key mykey

# Load from example file
dotnet run --project tools/TxtTv.TestUtility -- load --file examples/requests/legitimate/get-page-100.json --key mykey

# List available examples
dotnet run --project tools/TxtTv.TestUtility -- list --directory examples/requests
```

**References**:
- [Argu documentation](http://fsprojects.github.io/Argu/)
- [F# CLI best practices](https://fsharpforfunandprofit.com/posts/cli-best-practices/)

### 6. HTTP Client Implementation

**Decision**: Use `System.Net.Http.HttpClient` with `FSharp.Data.Http` for convenience

**Rationale**:
- `HttpClient` is standard .NET HTTP client, well-tested and performant
- Supports all HTTP methods (GET, POST, PUT, DELETE, etc.)
- Header and body manipulation
- Async/await support (F# async)
- `FSharp.Data.Http` provides F#-friendly wrappers

**Error Handling Strategy**:
- Catch `HttpRequestException` for network errors
- Catch `TaskCanceledException` for timeouts
- Display status code, headers, and body for all responses
- Distinguish between client errors (4xx), server errors (5xx), and network failures

**Timeout Configuration**:
- Default: 30 seconds
- Configurable via CLI argument
- Critical for detecting unreachable endpoints

**Alternatives Considered**:
- `FSharp.Data.Http` only - Less control over low-level HTTP details
- `HttpWebRequest` - Legacy API, more verbose
- External libraries (RestSharp, Flurl) - Unnecessary dependencies

**References**:
- [HttpClient best practices](https://docs.microsoft.com/en-us/dotnet/fundamentals/networking/http/httpclient-guidelines)
- [FSharp.Data.Http documentation](https://fsprojects.github.io/FSharp.Data/library/Http.html)

## Implementation Dependencies

### Required Software
- PowerShell 7.0+ (for deployment scripts)
- .NET SDK 10.0+ (for F# utility)
- Azure CLI or PowerShell Az module 10.0+
- Bicep CLI (typically bundled with Azure CLI)

### Azure Permissions Required
- Contributor role on target resource group (for deployment)
- Ability to create/delete resources in subscription
- Ability to assign managed identities (for APIM and Functions)

### Existing Infrastructure Dependencies
- Bicep templates in `infrastructure/` directory
- Environment parameter files in `infrastructure/environments/`
- Valid Azure subscription with sufficient quota

## Risk Mitigation

### Deployment Script Risks
**Risk**: Partial deployment failure leaves resources in inconsistent state  
**Mitigation**: 
- Bicep's declarative nature handles idempotency
- Script validates all parameters before deployment
- Document manual cleanup steps in case of catastrophic failure

**Risk**: Credentials exposed in command-line history  
**Mitigation**:
- Use Azure CLI/PowerShell authentication (no passwords in scripts)
- Document use of environment variables for sensitive parameters
- Add `.gitignore` entries for any local config files

### Testing Utility Risks
**Risk**: Hardcoded secrets in example request files  
**Mitigation**:
- Use placeholder values in examples
- Document that signing key should be provided via CLI argument or env variable
- Add `.gitignore` for any local request files with real secrets

**Risk**: Accidental DDoS of deployed service  
**Mitigation**:
- No looping or batch sending in initial implementation
- Document rate limiting expectations
- Utility sends single requests only

## Open Questions (None)

All technical unknowns have been resolved through this research. Implementation can proceed to Phase 1 (design).

## Summary

Research confirms feasibility of all feature requirements:
1. **PowerShell deployment**: Az module provides robust Bicep deployment support
2. **HMAC signatures**: .NET BCL provides secure, efficient HMACSHA256 implementation
3. **Example requests**: JSON format balances readability and parseability
4. **WAF testing**: Existing WAF rules support OWASP pattern testing
5. **F# CLI**: Argu library provides idiomatic command-line interface
6. **HTTP client**: Standard HttpClient sufficient for all request types

No blockers identified. Proceeding to Phase 1 (data model and contracts).
