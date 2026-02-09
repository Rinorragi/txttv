# Contract: Policy Fragment Schema

**Feature**: [spec.md](../spec.md) | **Date**: February 7, 2026  
**Contract Type**: Data Format Specification

## Overview

This contract defines the XML schema and structure requirements for APIM policy fragments that render the text TV interface.

## XML Schema

### Fragment Root Element

```xml
<fragment>
  <!-- Policy elements -->
</fragment>
```

**Requirements**:
- Root element MUST be `<fragment>`
- Namespace declarations are optional
- No attributes on root element

### Set-Body Element

```xml
<set-body>
  <![CDATA[
    <!-- HTML content -->
  ]]>
</set-body>
```

**Requirements**:
- Child of `<fragment>`
- MUST contain CDATA section
- CDATA contains complete HTML document
- No template expressions (`@{...}`) in HTML content (static rendering)

## Complete Fragment Example

```xml
<fragment>
  <set-body>
    <![CDATA[<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>TXT TV - Page 100</title>
  <style>
    body {
      margin: 0;
      padding: 20px;
      background-color: #000;
      color: #0f0;
      font-family: 'Courier New', monospace;
      font-size: 16px;
      line-height: 1.4;
    }
    .txttv-page {
      max-width: 800px;
      margin: 0 auto;
    }
    pre {
      margin: 0;
      white-space: pre-wrap;
      word-wrap: break-word;
    }
    .nav-links {
      margin-top: 20px;
      padding-top: 10px;
      border-top: 1px solid #0f0;
    }
    .nav-links a {
      color: #0ff;
      text-decoration: none;
      margin-right: 20px;
    }
    .nav-links a:hover {
      text-decoration: underline;
    }
  </style>
</head>
<body>
  <div class="txttv-page">
    <pre>═══════════════════════════════════════
         TXT TV - PAGE 100
═══════════════════════════════════════

Weather Forecast:
  Helsinki: ☁️  12°C
  Turku:    🌧  10°C
  Oulu:     ❄️   5°C

Sports Results:
  Football: Team A 2-1 Team B
  Hockey:   Team C 3-2 Team D

═══════════════════════════════════════</pre>
    
    <div class="nav-links">
      <a href="?page=110">← Previous (110)</a>
      <a href="?page=100">Index</a>
      <a href="?page=101">Next (101) →</a>
    </div>
  </div>
  
  <script src="https://unpkg.com/htmx.org@1.9.10" 
          integrity="sha384-D1Kt99CQMDuVetoL1lrYwg5t+9QdHe7NLX/SoJYkXDFfX37iInKRy5xLSi8nO7UC"
          crossorigin="anonymous"></script>
  <script>
    // Keyboard navigation
    document.addEventListener('keydown', function(e) {
      const currentPage = parseInt(new URLSearchParams(window.location.search).get('page') || '100');
      let nextPage = null;
      
      if (e.key === 'ArrowLeft' || e.key === 'p') {
        nextPage = currentPage === 100 ? 110 : currentPage - 1;
      } else if (e.key === 'ArrowRight' || e.key === 'n') {
        nextPage = currentPage === 110 ? 100 : currentPage + 1;
      } else if (e.key === 'h' || e.key === 'Home') {
        nextPage = 100;
      }
      
      if (nextPage !== null) {
        window.location.href = '?page=' + nextPage;
      }
    });
    
    // Display page load time
    window.addEventListener('load', function() {
      const loadTime = performance.timing.loadEventEnd - performance.timing.navigationStart;
      console.log('Page load time:', loadTime + 'ms');
    });
  </script>
</body>
</html>]]>
  </set-body>
</fragment>
```

## Validation Rules

### XML Structure

| Rule | Requirement | Validation |
|------|-------------|------------|
| **Well-Formed** | Valid XML syntax | Parse with XML parser |
| **Root Element** | Must be `<fragment>` | Check `DocumentElement.LocalName` |
| **Set-Body** | Must contain `<set-body>` | Check `fragment.ChildNodes` |
| **CDATA** | HTML must be in CDATA section | Check `FirstChild.NodeType == CDATA` |
| **Encoding** | UTF-8 with BOM | Check file encoding |

### Size Limits

| Component | Limit | Validation |
|-----------|-------|------------|
| **Total Fragment** | 256 KB | Check file size |
| **Text Content** | 2000 chars | Extract text from HTML, count |
| **Inline CSS** | Recommended <5 KB | Measure `<style>` block |
| **Inline JS** | Recommended <10 KB | Measure `<script>` blocks (excluding CDN) |

### CDATA Escaping

**Rule**: Any `]]>` sequence inside CDATA must be escaped

**Pattern**: `]]>` → `]]]]><![CDATA[>`

**Example**:
```xml
<!-- WRONG: Will break XML parsing -->
<![CDATA[
  <script>
    // Example: if (x]]>y) { ... }  <-- Breaks XML
  </script>
]]>

<!-- CORRECT: Escaped terminator -->
<![CDATA[
  <script>
    // Example: if (x]]]]><![CDATA[>y) { ... }  <-- Valid XML
  </script>
]]>
```

**Validation**:
```powershell
# Check for unescaped CDATA terminators
$cdataContent = $xml.fragment.'set-body'.'#cdata-section'
if ($cdataContent -match ']]>' -and $cdataContent -notmatch ']]]]><!\[CDATA\[>') {
    Write-Error "Unescaped CDATA terminator found"
}
```

### HTML Requirements

| Requirement | Description | Example |
|-------------|-------------|---------|
| **DOCTYPE** | HTML5 doctype required | `<!DOCTYPE html>` |
| **Lang Attribute** | Specify language | `<html lang="en">` |
| **Charset** | UTF-8 encoding meta tag | `<meta charset="UTF-8">` |
| **Viewport** | Responsive meta tag | `<meta name="viewport" content="width=device-width, initial-scale=1.0">` |
| **Title** | Page title with page number | `<title>TXT TV - Page 100</title>` |

### CSS Requirements

| Requirement | Description |
|-------------|-------------|
| **Inline Only** | All CSS must be in `<style>` tags (no external stylesheets) |
| **Scoped Selectors** | Use `.txttv-page` prefix to avoid conflicts |
| **Monospace Font** | Use monospace font family for retro aesthetic |
| **Dark Theme** | Black background, green/cyan text (text TV aesthetic) |

### JavaScript Requirements

| Requirement | Description |
|-------------|-------------|
| **External Libraries** | CDN links allowed (htmx, etc.) |
| **Inline Scripts** | Small scripts inline in `<script>` tags |
| **ES6+** | Modern JavaScript syntax supported |
| **No External Calls** | No fetch/XHR to external APIs in production |
| **Keyboard Navigation** | Support arrow keys for page navigation |

## Security Constraints

### XSS Prevention

**Validation Rules**:
```powershell
# Forbidden patterns (unless whitelisted)
$xssPatterns = @(
    '<script[^>]*>(?!https://unpkg\.com)',  # Script tags (except CDN)
    'javascript:',                          # JavaScript protocol
    'on\w+\s*=',                           # Event handlers (onclick, etc.)
    'eval\(',                              # eval() calls
    'innerHTML\s*=',                       # innerHTML assignments
    'document\.write'                       # document.write()
)

foreach ($pattern in $xssPatterns) {
    if ($content -match $pattern) {
        Write-Warning "Potential XSS risk: Pattern '$pattern' detected"
    }
}
```

**Allowed Exceptions**:
- `<script src="https://unpkg.com/...">` (CDN with integrity hash)
- Event handlers for keyboard navigation (`document.addEventListener`)

### Content Validation

| Check | Description | Action |
|-------|-------------|--------|
| **Malicious URLs** | Check href/src attributes | Warn if not relative or trusted CDN |
| **User Input** | No dynamic content from request body | Error if `@{context.Request}` found |
| **SQL Injection** | No database queries in JavaScript | Warn if SQL keywords detected |
| **Command Injection** | No system commands | Error if shell patterns detected |

## File Naming Convention

**Pattern**: `page-{NUMBER}.xml`

**Examples**:
- `page-100.xml`
- `page-101.xml`
- `page-110.xml`

**Rules**:
- Must start with `page-`
- Followed by page number (100-999)
- Must end with `.xml`
- No spaces or special characters

## Fragment Metadata (Future)

**Planned for v1.1**:

```xml
<fragment version="1.1" generated="2026-02-07T12:00:00Z" generator="convert-web-to-apim.ps1">
  <metadata>
    <page-number>100</page-number>
    <template>page-template.html</template>
    <content-source>page-100.txt</content-source>
    <size-bytes>5432</size-bytes>
  </metadata>
  <set-body>
    <![CDATA[...]]>
  </set-body>
</fragment>
```

**Note**: Metadata is optional and for tooling use only. APIM ignores unknown elements.

## APIM Integration

### Inclusion in Routing Policy

```xml
<policies>
  <inbound>
    <choose>
      <when condition="@(context.Request.Url.Query.GetValueOrDefault("page", "100") == "100")">
        <include-fragment fragment-id="page-100" />
      </when>
      <!-- More pages -->
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

**Notes**:
- Fragment ID matches file name (without `.xml`)
- `<return-response>` is in routing policy, not fragment
- `Content-Type` header set in routing policy

### Deployment via Bicep

```bicep
resource policyFragment 'Microsoft.ApiManagement/service/policyFragments@2023-03-01-preview' = {
  name: 'page-100'
  parent: apimService
  properties: {
    description: 'TXT TV Page 100'
    format: 'xml'
    value: loadTextContent('fragments/page-100.xml')
  }
}
```

## Compatibility

### APIM Versions

| Version | Supported | Notes |
|---------|-----------|-------|
| **2023-03-01-preview** | ✅ Yes | Policy fragments API |
| **2022-08-01** | ✅ Yes | Standard support |
| **2021-08-01** | ⚠️ Limited | No native fragment support |

### Browser Compatibility

| Browser | Minimum Version | Notes |
|---------|----------------|-------|
| **Chrome** | 90+ | Full support |
| **Firefox** | 88+ | Full support |
| **Safari** | 14+ | Full support |
| **Edge** | 90+ | Full support |
| **IE 11** | ❌ No | Not supported (ES6 required) |

---

**Related Contracts**:
- [Conversion Script Interface](conversion-script-interface.md)
- [Validation Functions](validation-functions.md)
- [Web Template Format](web-template-format.md)
