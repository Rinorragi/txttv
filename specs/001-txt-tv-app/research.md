# Research: TXT TV Application

**Feature**: 001-txt-tv-app  
**Date**: 2026-01-31  
**Phase**: 0 - Research & Technology Decisions

## Overview

This document captures research findings and technology decisions for implementing a TXT TV-style application where APIM policy fragments are the primary implementation surface. The application demonstrates Azure's WAF capabilities while rendering HTML content entirely through API Management transformations.

## Research Areas

### 1. APIM Policy Fragments for HTML Rendering

**Question**: How to use APIM policy fragments to dynamically render HTML content based on route parameters?

**Decision**: Use APIM `<set-body>` transformation with policy fragments containing HTML templates

**Rationale**:
- APIM policies support XML-based transformations with `<set-body>` element
- Policy fragments allow reusable content blocks that can be included in policies
- Route parameters can be extracted using `context.Request.MatchedParameters["pageNumber"]`
- HTML content can be embedded in CDATA sections within policy XML
- HTMX attributes can be included in the HTML to enable dynamic navigation

**Alternatives Considered**:
- **Static HTML files in Blob Storage**: Rejected because it doesn't demonstrate APIM policy capabilities
- **Backend-rendered HTML**: Rejected because backend should be minimal per requirements
- **APIM liquid templates**: Rejected due to complexity and learning curve

**Implementation Pattern**:
```xml
<policies>
    <inbound>
        <set-variable name="pageNumber" value="@(context.Request.MatchedParameters["pageNumber"])" />
        <choose>
            <when condition="@(context.Variables["pageNumber"] == "100")">
                <include-fragment fragment-id="page-100" />
            </when>
            <when condition="@(context.Variables["pageNumber"] == "101")">
                <include-fragment fragment-id="page-101" />
            </when>
            <otherwise>
                <include-fragment fragment-id="error-page" />
            </otherwise>
        </choose>
        <return-response>
            <set-status code="200" reason="OK" />
            <set-header name="Content-Type" exists-action="override">
                <value>text/html; charset=utf-8</value>
            </set-header>
        </return-response>
    </inbound>
</policies>
```

**Best Practices**:
- Keep policy fragments focused (one page per fragment)
- Use CDATA sections for HTML content to avoid XML escaping issues
- Include correlation IDs for tracing
- Set appropriate cache headers for performance

### 2. HTMX for Minimal JavaScript Interactivity

**Question**: How to implement page navigation with minimal JavaScript?

**Decision**: Use HTMX for declarative, server-driven interactivity

**Rationale**:
- HTMX is a tiny library (~14KB) that enables AJAX requests via HTML attributes
- No build process or bundling required
- Perfect for simple navigation: `hx-get="/page/101"` triggers requests
- Supports partial page updates without full refreshes
- Browser history management with `hx-push-url`
- Declarative syntax matches the "simple HTML" requirement

**Alternatives Considered**:
- **Vanilla JavaScript**: Would require more code and complexity
- **Alpine.js**: Overkill for simple navigation
- **Full page refresh**: Poor UX, no smooth transitions

**Implementation Pattern**:
```html
<div id="content">
    <h1>Page 100 - News</h1>
    <p>Content here...</p>
    
    <nav>
        <button hx-get="/page/99" hx-target="#content" hx-push-url="true">← Previous</button>
        <input type="number" id="pageNum" value="100" />
        <button hx-get="/page/{pageNum}" hx-target="#content" hx-push-url="true">Go</button>
        <button hx-get="/page/101" hx-target="#content" hx-push-url="true">Next →</button>
    </nav>
</div>
<script src="https://unpkg.com/htmx.org@1.9.10"></script>
```

**Best Practices**:
- Use CDN for HTMX (no build process)
- Target specific divs for partial updates (#content)
- Enable browser history with hx-push-url
- Add loading indicators for UX

### 3. Text Files to Policy Fragments Conversion

**Question**: How to convert text files containing page content into APIM policy fragments?

**Decision**: PowerShell script that reads text files and generates policy fragment XML

**Rationale**:
- Policy fragments must be XML format with HTML in CDATA sections
- Manual conversion is error-prone and not maintainable
- PowerShell is available in Azure DevOps and GitHub Actions
- Can be automated as part of CI/CD pipeline
- Allows content editors to work with simple text files

**Alternatives Considered**:
- **Manual XML editing**: Not scalable, error-prone
- **Python script**: Would add dependency, PowerShell is native to Azure tooling
- **Azure Functions to read files at runtime**: Defeats the purpose of policy-centric architecture

**Implementation Pattern**:
```powershell
# convert-txt-to-fragment.ps1
param(
    [string]$SourceDir = "content/pages",
    [string]$OutputDir = "infrastructure/modules/apim/fragments"
)

Get-ChildItem "$SourceDir/*.txt" | ForEach-Object {
    $pageNumber = $_.BaseName -replace 'page-', ''
    $content = Get-Content $_.FullName -Raw
    
    $fragmentXml = @"
<fragment>
    <set-body><![CDATA[
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <title>TXT TV - Page $pageNumber</title>
            <link rel="stylesheet" href="/static/style.css">
        </head>
        <body>
            <div id="content">
                <h1>Page $pageNumber</h1>
                <pre>$content</pre>
                <nav>
                    <button hx-get="/page/$([int]$pageNumber - 1)" hx-target="#content">← Prev</button>
                    <button hx-get="/page/$([int]$pageNumber + 1)" hx-target="#content">Next →</button>
                </nav>
            </div>
            <script src="https://unpkg.com/htmx.org@1.9.10"></script>
        </body>
        </html>
    ]]></set-body>
</fragment>
"@
    
    $fragmentXml | Out-File "$OutputDir/page-$pageNumber.xml" -Encoding utf8
}
```

**Best Practices**:
- Validate XML output after generation
- Include fragment-id in Bicep deployment
- Version control generated fragments
- Run conversion in CI/CD before deployment

### 4. F# Azure Functions Minimal Backend

**Question**: How to implement the minimal F# backend that returns "you found through the maze"?

**Decision**: Single HTTP-triggered function with hardcoded 200 OK response

**Rationale**:
- Minimal complexity as per requirements
- HTTP trigger is simplest Azure Functions trigger type
- F# supports concise syntax for simple functions
- No database or external dependencies needed
- Demonstrates backend connectivity without adding business logic

**Alternatives Considered**:
- **Multiple endpoints**: Overcomplicates a demo feature
- **Database-backed responses**: Adds unnecessary complexity
- **C# instead of F#**: F# was specified in requirements

**Implementation Pattern**:
```fsharp
module MazeMessage

open Microsoft.Azure.Functions.Worker
open Microsoft.Azure.Functions.Worker.Http
open System.Net

[<Function("MazeMessage")>]
let run ([<HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "backend-test")>] req: HttpRequestData) =
    let response = req.CreateResponse(HttpStatusCode.OK)
    response.Headers.Add("Content-Type", "text/plain; charset=utf-8")
    response.WriteString("you found through the maze")
    response
```

**Best Practices**:
- Use .NET 10 isolated worker process
- Anonymous auth (APIM handles authentication)
- Simple text/plain response
- No logging complexity (handled by APIM)

### 5. WAF Rules for Common Attacks

**Question**: What WAF rules are needed to protect the application?

**Decision**: Azure WAF with OWASP CRS 3.2+ managed rules plus custom rate limiting

**Rationale**:
- OWASP Core Rule Set provides comprehensive protection
- Covers SQL injection, XSS, path traversal out of the box
- Managed rules updated automatically by Azure
- Custom rate limiting prevents abuse (100 req/min per IP)
- Demonstrates WAF capabilities as per project goals

**Alternatives Considered**:
- **Custom WAF rules only**: Would miss common attack patterns
- **No rate limiting**: Could lead to abuse
- **Stricter rate limits**: Would hinder legitimate testing

**Implementation Pattern** (Bicep):
```bicep
resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2023-05-01' = {
  name: 'txttv-waf-policy'
  location: location
  properties: {
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
        }
      ]
    }
    customRules: [
      {
        name: 'RateLimitPerIP'
        priority: 100
        ruleType: 'RateLimitRule'
        rateLimitThreshold: 100
        rateLimitDuration: 'OneMin'
        action: 'Block'
        matchConditions: [
          {
            matchVariables: [{ variableName: 'RemoteAddr' }]
            operator: 'IPMatch'
            matchValues: ['0.0.0.0/0']
          }
        ]
      }
    ]
  }
}
```

**Best Practices**:
- Start with detection mode, then switch to prevention
- Monitor WAF logs in Application Insights
- Document false positives and create exceptions
- Test with common attack payloads

### 6. Teletext-Style CSS

**Question**: How to style the HTML to resemble traditional teletext?

**Decision**: Simple CSS with monospace font, black background, colored text blocks

**Rationale**:
- Teletext used monospace fonts and limited color palette
- Simple CSS requires no build process or frameworks
- Can be served as static file from APIM or embedded inline
- Nostalgic aesthetic matches YLE Teksti-TV reference

**Implementation Pattern**:
```css
body {
    background-color: #000;
    color: #0f0;
    font-family: 'Courier New', monospace;
    font-size: 16px;
    line-height: 1.5;
    margin: 0;
    padding: 20px;
}

#content {
    max-width: 80ch;
    margin: 0 auto;
}

h1 {
    background-color: #00f;
    color: #fff;
    padding: 10px;
    margin: 0 0 20px 0;
}

pre {
    white-space: pre-wrap;
    word-wrap: break-word;
}

nav {
    margin-top: 20px;
    padding: 10px;
    background-color: #333;
}

button {
    background-color: #0f0;
    color: #000;
    border: none;
    padding: 10px 20px;
    font-family: 'Courier New', monospace;
    cursor: pointer;
    margin-right: 10px;
}

button:hover {
    background-color: #0c0;
}

input[type="number"] {
    width: 60px;
    background-color: #000;
    color: #0f0;
    border: 2px solid #0f0;
    padding: 8px;
    font-family: 'Courier New', monospace;
}
```

**Best Practices**:
- Use high contrast for readability
- Keep design simple and nostalgic
- Ensure accessibility (sufficient color contrast)
- Test on different screen sizes

## Technology Stack Summary

| Component | Technology | Rationale |
|-----------|------------|-----------|
| **IaC** | Bicep | Azure-native, type-safe, required by constitution |
| **API Gateway** | Azure APIM | Primary implementation surface for policy fragments |
| **Security** | Azure WAF | Demonstrates security capabilities, OWASP rules |
| **Backend** | F# Azure Functions | Minimal connectivity test, specified in requirements |
| **Frontend Library** | HTMX 1.9+ | Minimal JavaScript, declarative syntax, no build process |
| **Styling** | Vanilla CSS | Simple teletext aesthetic, no frameworks |
| **Content Storage** | Text files → Policy fragments | Enables content management without code changes |
| **CI/CD** | GitHub Actions | Bicep deployment, policy validation |
| **Monitoring** | Application Insights | APIM traces, WAF logs, function metrics |

## Open Questions & Assumptions

### Resolved During Research
- ✅ How to render HTML in APIM policies: Use `<set-body>` with CDATA
- ✅ How to handle routing: Extract route parameters with `context.Request.MatchedParameters`
- ✅ How to convert text files: PowerShell script generates policy fragment XML
- ✅ How to minimize JavaScript: HTMX provides declarative interactivity
- ✅ How to style like teletext: Simple CSS with monospace font and limited colors

### Assumptions for Implementation
- Page numbers range 100-120 (20 pages total for proof of concept)
- Text files use UTF-8 encoding
- HTMX loaded from CDN (no offline support needed)
- Single Azure region deployment (no geo-distribution)
- APIM Consumption tier sufficient for demo (no Premium features needed)
- Public access (no authentication on page viewing, only on backend test endpoint)

## Next Steps

Phase 1 will produce:
1. **data-model.md**: Entity definitions (Page, Navigation State)
2. **contracts/**: API operation definitions (GET /page/{pageNumber}, GET /, GET /backend-test)
3. **quickstart.md**: Developer setup instructions

Phase 2 (not covered in /speckit.plan):
- tasks.md with implementation checklist
