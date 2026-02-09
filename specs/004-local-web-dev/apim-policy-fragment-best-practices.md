# APIM Policy Fragment Best Practices for HTML/CSS/JS Embedding

**Context**: Converting retro text TV HTML pages into Azure API Management policy fragments  
**Date**: 2026-02-07  
**Based on**: Microsoft Learn documentation, existing TxtTV implementation analysis

---

## Table of Contents

1. [XML Encoding](#1-xml-encoding)
2. [APIM Policy Structure](#2-apim-policy-structure)
3. [Size Limits & Workarounds](#3-size-limits--workarounds)
4. [Performance Optimization](#4-performance-optimization)
5. [Common Pitfalls](#5-common-pitfalls)
6. [Recommended Templates](#6-recommended-templates)
7. [PowerShell Conversion Logic](#7-powershell-conversion-logic)
8. [Testing Approach](#8-testing-approach)

---

## 1. XML Encoding

### CDATA vs Entity Encoding

**RECOMMENDED: Use CDATA Sections**

CDATA (Character Data) sections are the **preferred approach** for embedding HTML in APIM policy fragments because:

- ✅ **Cleaner syntax**: No need to escape every `<`, `>`, `&` character
- ✅ **Better maintainability**: HTML remains human-readable
- ✅ **Reduced errors**: Less prone to XML parsing issues
- ✅ **Performance**: No need to decode entities at runtime

```xml
<fragment>
    <set-body><![CDATA[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>TXT TV - Page 100</title>
    <style>
        body { color: #0f0; }
    </style>
</head>
<body>
    <h1>Welcome</h1>
</body>
</html>]]></set-body>
</fragment>
```

**When to Use Entity Encoding Instead:**

Use entity encoding (`&lt;`, `&gt;`, `&amp;`, `&quot;`, `&apos;`) when:
- You need to dynamically inject content using policy expressions (CDATA doesn't allow `@{}` expressions inside)
- You have very short HTML snippets
- You're working with mixed content (XML + HTML)

```xml
<!-- Entity encoding example (less common for full HTML pages) -->
<set-body>
    &lt;html&gt;&lt;body&gt;Hello&lt;/body&gt;&lt;/html&gt;
</set-body>
```

### Character Encoding Best Practices

1. **Always use UTF-8 encoding** for text files and policy XML
   - Set `charset=UTF-8` in HTML meta tag
   - Save PowerShell scripts with UTF-8 encoding
   - Use `-Encoding utf8` parameter in `Out-File`

2. **Handle special characters in content**:
   ```powershell
   # If content contains CDATA end delimiter, escape it
   $content = Get-Content $txtFile -Raw -Encoding UTF8
   $content = $content -replace ']]>', ']]]]><![CDATA[>'
   ```

3. **Escape XML-unsafe characters ONLY in dynamic content**:
   ```powershell
   # Only needed if injecting into CDATA or using outside CDATA
   $escapedContent = $content `
       -replace '&', '&amp;' `
       -replace '<', '&lt;' `
       -replace '>', '&gt;'
   ```

### CDATA Limitations & Workarounds

**Problem**: Cannot use policy expressions inside CDATA

```xml
<!-- ❌ This DOESN'T work - policy expressions ignored in CDATA -->
<set-body><![CDATA[
    <h1>User: @(context.User.Id)</h1>
]]></set-body>
```

**Solution 1**: Split CDATA and use concatenation
```xml
<set-body>@{
    string userId = context.User.Id;
    string html = $"<![CDATA[<h1>User: {userId}</h1>]]>";
    return html;
}</set-body>
```

**Solution 2**: Pre-process variables in PowerShell (RECOMMENDED for TxtTV)
```powershell
# Generate fragment with pre-calculated values
$fragmentXml = @"
<fragment>
    <set-body><![CDATA[<!DOCTYPE html>
<html>
<head><title>TXT TV - Page $pageNumber</title></head>
<body>
    <h1>PAGE $pageNumber</h1>
    <pre>$escapedContent</pre>
    <button hx-get="/page/$nextPage">Next</button>
</body>
</html>]]></set-body>
</fragment>
"@
```

---

## 2. APIM Policy Structure

### Fragment vs Policy

**Understanding the Difference:**

- **Fragment** (`<fragment>`): Reusable policy snippet, stored separately, referenced via `<include-fragment>`
- **Policy** (`<policies>`): Complete policy document with `<inbound>`, `<backend>`, `<outbound>`, `<on-error>` sections

### Correct Fragment Structure

**✅ Recommended Structure for HTML Response Fragments:**

```xml
<fragment>
    <!-- Set the HTTP response body -->
    <set-body><![CDATA[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Page Title</title>
    <style>
        /* Inline CSS here */
    </style>
</head>
<body>
    <!-- HTML content -->
    <script>
        // Inline JavaScript here
    </script>
</body>
</html>]]></set-body>
</fragment>
```

**Key Points:**
- Fragments contain only policy statements (no `<policies>`, `<inbound>`, etc.)
- Use `<set-body>` to define response body content
- Include complete HTML document with `<!DOCTYPE>`, `<html>`, `<head>`, `<body>`

### Return-Response in Routing Policy (NOT Fragment)

Fragments should NOT contain `<return-response>`. Instead, use it in the main routing policy:

```xml
<!-- page-routing-policy.xml -->
<policies>
    <inbound>
        <base />
        
        <!-- Determine which page to show -->
        <set-variable name="pageNumber" 
                      value="@(context.Request.MatchedParameters["pageNumber"])" />
        
        <!-- Include the appropriate fragment -->
        <choose>
            <when condition="@(context.Variables["pageNumber"].ToString() == "100")">
                <include-fragment fragment-id="page-100" />
            </when>
            <when condition="@(context.Variables["pageNumber"].ToString() == "101")">
                <include-fragment fragment-id="page-101" />
            </when>
            <otherwise>
                <include-fragment fragment-id="error-page" />
            </otherwise>
        </choose>
        
        <!-- Return the response set by the fragment -->
        <return-response>
            <set-status code="200" reason="OK" />
            <set-header name="Content-Type" exists-action="override">
                <value>text/html; charset=utf-8</value>
            </set-header>
        </return-response>
    </inbound>
</policies>
```

### Setting Content-Type Header

**Two Approaches:**

**Option 1: In routing policy (RECOMMENDED for consistent headers)**
```xml
<return-response>
    <set-status code="200" reason="OK" />
    <set-header name="Content-Type" exists-action="override">
        <value>text/html; charset=utf-8</value>
    </set-header>
</return-response>
```

**Option 2: In each fragment (if headers vary per page)**
```xml
<fragment>
    <set-header name="Content-Type" exists-action="override">
        <value>text/html; charset=utf-8</value>
    </set-header>
    <set-body><![CDATA[<!DOCTYPE html>...]]></set-body>
</fragment>
```

**Other Useful Headers:**
```xml
<!-- Security headers -->
<set-header name="X-Content-Type-Options" exists-action="override">
    <value>nosniff</value>
</set-header>
<set-header name="X-Frame-Options" exists-action="override">
    <value>DENY</value>
</set-header>

<!-- Caching -->
<set-header name="Cache-Control" exists-action="override">
    <value>public, max-age=3600</value>
</set-header>
```

---

## 3. Size Limits & Workarounds

### APIM Policy Size Constraints

**Hard Limits (as of 2026):**
- **Policy document size**: 256 KB maximum (all tiers)
- **Fragment size**: 256 KB maximum per fragment
- **Total fragments**: No documented limit, but practical limit ~1000 fragments per APIM instance

**TxtTV Implementation Constraints:**
- Each page limited to 2000 characters of text content
- With HTML/CSS/JS template, each fragment is ~5-8 KB
- Well within 256 KB limit per fragment

### Size Calculation Example

```powershell
# Calculate fragment size
$fragmentXml = @"
<fragment>
    <set-body><![CDATA[...]]></set-body>
</fragment>
"@

$fragmentSizeKB = [System.Text.Encoding]::UTF8.GetByteCount($fragmentXml) / 1KB
Write-Host "Fragment size: $([math]::Round($fragmentSizeKB, 2)) KB"

if ($fragmentSizeKB -gt 256) {
    Write-Error "Fragment exceeds 256 KB limit!"
}
```

### Workarounds for Large Content

**Strategy 1: Extract External Assets (CDN)**

❌ **Before (large inline CSS/JS):**
```xml
<fragment>
    <set-body><![CDATA[<!DOCTYPE html>
<html>
<head>
    <style>
        /* 50 KB of CSS here */
    </style>
</head>
<body>
    <script>
        // 100 KB of JavaScript
    </script>
</body>
</html>]]></set-body>
</fragment>
```

✅ **After (external CDN references):**
```xml
<fragment>
    <set-body><![CDATA[<!DOCTYPE html>
<html>
<head>
    <link rel="stylesheet" href="https://cdn.example.com/styles.css">
</head>
<body>
    <script src="https://cdn.example.com/app.js"></script>
</body>
</html>]]></set-body>
</fragment>
```

**Strategy 2: Fragment Composition**

Split large pages into multiple fragments:

```xml
<!-- page-100-header.xml -->
<fragment>
    <set-variable name="htmlHeader" value="<![CDATA[<!DOCTYPE html>...]]>" />
</fragment>

<!-- page-100-content.xml -->
<fragment>
    <set-variable name="htmlContent" value="<![CDATA[<div>...</div>]]>" />
</fragment>

<!-- page-100-footer.xml -->
<fragment>
    <set-variable name="htmlFooter" value="<![CDATA[</body></html>]]>" />
</fragment>

<!-- Combine in routing policy -->
<policies>
    <inbound>
        <include-fragment fragment-id="page-100-header" />
        <include-fragment fragment-id="page-100-content" />
        <include-fragment fragment-id="page-100-footer" />
        <set-body>@{
            string header = context.Variables.GetValueOrDefault<string>("htmlHeader", "");
            string content = context.Variables.GetValueOrDefault<string>("htmlContent", "");
            string footer = context.Variables.GetValueOrDefault<string>("htmlFooter", "");
            return header + content + footer;
        }</set-body>
        <return-response>
            <set-status code="200" reason="OK" />
            <set-header name="Content-Type" exists-action="override">
                <value>text/html; charset=utf-8</value>
            </set-header>
        </return-response>
    </inbound>
</policies>
```

**Strategy 3: Minification**

```powershell
# Minify CSS/JS before embedding
function Compress-Css($css) {
    $css = $css -replace '\s+', ' '  # Collapse whitespace
    $css = $css -replace '\s*{\s*', '{'
    $css = $css -replace '\s*}\s*', '}'
    $css = $css -replace '\s*:\s*', ':'
    $css = $css -replace '\s*;\s*', ';'
    return $css.Trim()
}

function Compress-JavaScript($js) {
    # Basic minification (use proper tools for production)
    $js = $js -replace '//.*', ''  # Remove single-line comments
    $js = $js -replace '\s+', ' '   # Collapse whitespace
    return $js.Trim()
}
```

---

## 4. Performance Optimization

### Inline vs External Assets

**Decision Matrix:**

| Asset Type | Size | Recommendation | Reason |
|------------|------|----------------|--------|
| Critical CSS | < 5 KB | Inline | Eliminate render-blocking request |
| Full CSS | > 5 KB | External (CDN) | Reduce policy size, enable caching |
| JavaScript | Any | External (CDN) | Better caching, parallel downloads |
| Images | Any | External (CDN or Storage) | APIM policies not for binary data |
| Fonts | Any | External (CDN) | Large files, good caching |

**TxtTV Recommendation:**

✅ **Current approach is optimal** for this use case:
- Small inline CSS (~2 KB) - eliminates extra HTTP request
- External htmx.js via CDN - enables browser caching
- No images/fonts - pure text-based interface

### APIM Caching Strategies

**Enable Response Caching for Static Pages:**

```xml
<!-- In page-routing-policy.xml -->
<policies>
    <inbound>
        <base />
        
        <!-- Check cache first -->
        <cache-lookup vary-by-developer="false" 
                      vary-by-developer-groups="false" 
                      downstream-caching-type="public" 
                      must-revalidate="false" 
                      caching-type="internal">
            <vary-by-query-parameter>pageNumber</vary-by-query-parameter>
        </cache-lookup>
        
        <!-- Route to fragment -->
        <choose>
            <when condition="@(context.Variables["pageNumber"].ToString() == "100")">
                <include-fragment fragment-id="page-100" />
            </when>
        </choose>
        
        <return-response>
            <set-status code="200" reason="OK" />
            <set-header name="Content-Type" exists-action="override">
                <value>text/html; charset=utf-8</value>
            </set-header>
            <set-header name="Cache-Control" exists-action="override">
                <value>public, max-age=3600</value>
            </set-header>
        </return-response>
    </inbound>
    
    <outbound>
        <base />
        
        <!-- Store in cache for 1 hour -->
        <cache-store duration="3600" />
    </outbound>
</policies>
```

**Caching Best Practices:**
- ✅ Cache static pages (news content that doesn't change frequently)
- ✅ Set appropriate `max-age` based on content update frequency
- ✅ Use `vary-by-query-parameter` if content varies by parameters
- ❌ Don't cache user-specific content
- ❌ Don't cache error pages

### Minification Best Practices

**CSS Minification:**
```powershell
# Remove comments, collapse whitespace, minimize selectors
$css = @"
body {
    background-color: #000;
    color: #0f0;
}
"@

$minifiedCss = $css `
    -replace '/\*[\s\S]*?\*/', '' `  # Remove comments
    -replace '\s+', ' ' `              # Collapse whitespace
    -replace '\s*{\s*', '{' `
    -replace '\s*}\s*', '}' `
    -replace '\s*:\s*', ':' `
    -replace '\s*;\s*', ';'
```

**HTML Minification:**
```powershell
# Collapse whitespace in HTML (preserve <pre> content!)
$html = $html -replace '>\s+<', '><'
$html = $html -replace '\s{2,}', ' '
```

**⚠️ Warning**: Don't minify content inside `<pre>` tags or user-generated content!

### CDN vs Inline Assets

**Use CDN for:**
- ✅ Third-party libraries (htmx, jQuery, Bootstrap)
- ✅ Large custom CSS/JS files (> 5 KB)
- ✅ Images, fonts, media files
- ✅ Assets shared across multiple pages

**Use Inline for:**
- ✅ Critical CSS (above-the-fold styles)
- ✅ Small page-specific styles (< 5 KB)
- ✅ Configuration/initialization scripts (< 1 KB)

**TxtTV Current Implementation Analysis:**

```html
<!-- ✅ GOOD: Small inline CSS (eliminates HTTP request) -->
<style>
    /* ~2 KB of CSS - inline is optimal */
</style>

<!-- ✅ GOOD: External htmx.js via CDN -->
<script src="https://unpkg.com/htmx.org@1.9.10"></script>
```

---

## 5. Common Pitfalls

### XML Parsing Errors

**Issue 1: Unescaped CDATA End Delimiter**

❌ **Problem:**
```xml
<set-body><![CDATA[
    <script>
        var data = "This contains ]]> which breaks CDATA";
    </script>
]]></set-body>
```

✅ **Solution:**
```powershell
# Escape ]]> in content
$content = $content -replace ']]>', ']]]]><![CDATA[>'
```

**Issue 2: Invalid XML Characters**

❌ **Problem:**
```xml
<!-- Control characters (0x00-0x1F except tab, newline, carriage return) -->
<set-body><![CDATA[Content with  character]]></set-body>
```

✅ **Solution:**
```powershell
# Remove or escape control characters
$content = $content -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', ''
```

**Issue 3: Mismatched Quotes in Attributes**

❌ **Problem:**
```xml
<set-header name="X-Custom" value="Value with "quotes"" />
```

✅ **Solution:**
```xml
<!-- Use entity encoding for attribute values -->
<set-header name="X-Custom" value="Value with &quot;quotes&quot;" />
```

### Content-Type Mismatches

**Issue: Browser treats HTML as text**

❌ **Symptom**: Browser shows HTML source code instead of rendering

**Root Causes:**
1. Missing `Content-Type` header
2. Incorrect content type (`text/plain` instead of `text/html`)
3. Header set in wrong policy section

✅ **Solution:**
```xml
<!-- Set in return-response or outbound section -->
<return-response>
    <set-status code="200" reason="OK" />
    <set-header name="Content-Type" exists-action="override">
        <value>text/html; charset=utf-8</value>
    </set-header>
</return-response>
```

### Browser Compatibility Issues

**Issue 1: DOCTYPE Missing**

❌ **Triggers Quirks Mode:**
```html
<html>
<body>...</body>
</html>
```

✅ **Standards Mode:**
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body>...</body>
</html>
```

**Issue 2: Missing Charset**

❌ **Can cause encoding issues:**
```html
<head>
    <title>Page</title>
</head>
```

✅ **Proper charset declaration:**
```html
<head>
    <meta charset="UTF-8">
    <title>Page</title>
</head>
```

**Issue 3: Mobile Viewport**

❌ **Poor mobile experience:**
```html
<head>
    <title>Page</title>
</head>
```

✅ **Responsive design:**
```html
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Page</title>
</head>
```

### Policy Expression Pitfalls

**Issue 1: Expressions in CDATA Don't Work**

❌ **Problem:**
```xml
<set-body><![CDATA[
    <h1>User: @(context.User.Id)</h1>
]]></set-body>
```

✅ **Solution:**
```xml
<set-body>@{
    return $"<h1>User: {context.User.Id}</h1>";
}</set-body>
```

**Issue 2: Type Conversion Errors**

❌ **Runtime error:**
```csharp
@{
    var pageNum = context.Variables["pageNumber"];  // Object type
    return pageNum + 1;  // Error: can't add to Object
}
```

✅ **Proper type casting:**
```csharp
@{
    int pageNum = context.Variables.GetValueOrDefault<int>("pageNumber", 100);
    return pageNum + 1;
}
```

---

## 6. Recommended Templates

### Base Fragment Template

```xml
<fragment>
    <set-body><![CDATA[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TXT TV - Page {{PAGE_NUMBER}}</title>
    <style>
{{CSS_CONTENT}}
    </style>
</head>
<body>
    <div class="header">
        <span class="page-number">PAGE {{PAGE_NUMBER}}</span> - TXT TV
    </div>
    <div id="content">
        <pre class="content">{{TEXT_CONTENT}}</pre>
    </div>
    <nav>
        <button hx-get="/page/{{PREV_PAGE}}" 
                hx-target="body" 
                hx-push-url="true" 
                {{DISABLE_PREV}}>&#9664; Previous</button>
        
        <input type="number" id="pageNum" value="{{PAGE_NUMBER}}" min="100" max="999" />
        
        <button hx-get="/page/{pageNum}" 
                hx-include="#pageNum" 
                hx-target="body" 
                hx-push-url="true" 
                onclick="this.setAttribute('hx-get', '/page/' + document.getElementById('pageNum').value); htmx.process(this);">
            Go to Page
        </button>
        
        <button hx-get="/page/{{NEXT_PAGE}}" 
                hx-target="body" 
                hx-push-url="true">Next &#9654;</button>
    </nav>
    <script src="https://unpkg.com/htmx.org@1.9.10"></script>
</body>
</html>]]></set-body>
</fragment>
```

### Error Page Fragment Template

```xml
<fragment>
    <set-status code="404" reason="Not Found" />
    <set-header name="Content-Type" exists-action="override">
        <value>text/html; charset=utf-8</value>
    </set-header>
    <set-body><![CDATA[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TXT TV - Page Not Found</title>
    <style>
body {
    background-color: #000;
    color: #f00;
    font-family: 'Courier New', Courier, monospace;
    padding: 20px;
}
    </style>
</head>
<body>
    <h1>ERROR 404</h1>
    <p>Page not found</p>
    <p><a href="/page/100">Return to page 100</a></p>
</body>
</html>]]></set-body>
</fragment>
```

### Routing Policy Template

```xml
<policies>
    <inbound>
        <base />
        
        <!-- Extract and validate page number -->
        <set-variable name="pageNumber" 
                      value="@(context.Request.MatchedParameters["pageNumber"])" />
        
        <choose>
            <when condition="@{
                string pageStr = (string)context.Variables["pageNumber"];
                int page;
                if (!int.TryParse(pageStr, out page)) return true;
                if (page < 100 || page > 999) return true;
                return false;
            }">
                <return-response>
                    <set-status code="400" reason="Bad Request" />
                    <set-header name="Content-Type" exists-action="override">
                        <value>application/json</value>
                    </set-header>
                    <set-body>@{
                        var pageNumber = context.Variables.GetValueOrDefault<string>("pageNumber", "unknown");
                        return new JObject(
                            new JProperty("error", "Invalid page number"),
                            new JProperty("message", "Page number must be an integer between 100 and 999"),
                            new JProperty("requestedValue", pageNumber)
                        ).ToString();
                    }</set-body>
                </return-response>
            </when>
        </choose>
        
        <!-- Route to fragment -->
        <choose>
            {{#each pages}}
            <when condition="@(context.Variables["pageNumber"].ToString() == "{{number}}")">
                <include-fragment fragment-id="page-{{number}}" />
            </when>
            {{/each}}
            <otherwise>
                <include-fragment fragment-id="error-page" />
            </otherwise>
        </choose>
        
        <!-- Return response -->
        <return-response>
            <set-status code="200" reason="OK" />
            <set-header name="Content-Type" exists-action="override">
                <value>text/html; charset=utf-8</value>
            </set-header>
            <set-header name="Cache-Control" exists-action="override">
                <value>public, max-age=3600</value>
            </set-header>
        </return-response>
    </inbound>
    
    <backend>
        <base />
    </backend>
    
    <outbound>
        <base />
    </outbound>
    
    <on-error>
        <base />
    </on-error>
</policies>
```

---

## 7. PowerShell Conversion Logic

### Complete Conversion Script

```powershell
<#
.SYNOPSIS
    Converts text files to APIM policy fragments with HTML embedding.

.DESCRIPTION
    Reads text content files and generates XML policy fragments with:
    - Proper CDATA encapsulation
    - UTF-8 encoding
    - Size validation
    - Character escaping for CDATA safety
    - Navigation logic

.PARAMETER SourceDir
    Directory containing page-*.txt files

.PARAMETER OutputDir
    Directory for generated fragment XML files

.PARAMETER MaxCharacters
    Maximum allowed characters per page content

.PARAMETER CssFile
    Path to shared CSS file (optional)
#>

param(
    [string]$SourceDir = "content/pages",
    [string]$OutputDir = "infrastructure/modules/apim/fragments",
    [int]$MaxCharacters = 2000,
    [string]$CssFile = ""
)

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Load shared CSS if provided
$sharedCss = ""
if ($CssFile -and (Test-Path $CssFile)) {
    $sharedCss = Get-Content $CssFile -Raw -Encoding UTF8
} else {
    # Default inline CSS
    $sharedCss = @"
body {
    background-color: #000;
    color: #0f0;
    font-family: 'Courier New', Courier, monospace;
    font-size: 16px;
    line-height: 1.4;
    margin: 0;
    padding: 20px;
    min-height: 100vh;
}
.header {
    background-color: #00f;
    color: #fff;
    padding: 10px;
    text-align: center;
    margin-bottom: 20px;
}
.page-number {
    color: #ff0;
    font-weight: bold;
}
.content {
    white-space: pre-wrap;
    word-wrap: break-word;
    margin-bottom: 20px;
}
nav {
    display: flex;
    gap: 10px;
    align-items: center;
    padding: 10px;
    background-color: #333;
    flex-wrap: wrap;
}
button {
    background-color: #00f;
    color: #fff;
    border: 2px solid #0ff;
    padding: 10px 20px;
    cursor: pointer;
    font-family: 'Courier New', Courier, monospace;
    font-size: 14px;
}
button:hover:not(:disabled) {
    background-color: #0ff;
    color: #000;
}
button:disabled {
    background-color: #555;
    color: #888;
    cursor: not-allowed;
    border-color: #666;
}
input[type="number"] {
    background-color: #000;
    color: #0f0;
    border: 2px solid #0ff;
    padding: 10px;
    font-family: 'Courier New', Courier, monospace;
    font-size: 14px;
    width: 80px;
}
.htmx-request {
    opacity: 0.5;
}
"@
}

# Minify CSS (optional - reduces fragment size)
function Compress-Css($css) {
    $css = $css -replace '/\*[\s\S]*?\*/', ''  # Remove comments
    $css = $css -replace '\s+', ' '             # Collapse whitespace
    $css = $css -replace '\s*{\s*', '{'
    $css = $css -replace '\s*}\s*', '}'
    $css = $css -replace '\s*:\s*', ':'
    $css = $css -replace '\s*;\s*', ';'
    return $css.Trim()
}

# Escape CDATA-unsafe sequences
function Escape-CDataContent($content) {
    # Escape ]]> sequence which would break CDATA
    $content = $content -replace ']]>', ']]]]><![CDATA[>'
    return $content
}

# Validate content doesn't contain XML control characters
function Test-XmlSafeContent($content) {
    # Check for control characters (except tab, newline, carriage return)
    if ($content -match '[\x00-\x08\x0B\x0C\x0E-\x1F]') {
        return $false
    }
    return $true
}

$successCount = 0
$errorCount = 0

# Process each page file
Get-ChildItem "$SourceDir/page-*.txt" -ErrorAction SilentlyContinue | ForEach-Object {
    $pageNumber = $_.BaseName -replace 'page-', ''
    
    try {
        # Read content
        $content = Get-Content $_.FullName -Raw -Encoding UTF8
        
        # Validate character limit
        if ($content.Length -gt $MaxCharacters) {
            Write-Error "Page $pageNumber exceeds $MaxCharacters character limit ($($content.Length) chars)"
            $script:errorCount++
            return
        }
        
        # Validate XML-safe content
        if (-not (Test-XmlSafeContent $content)) {
            Write-Warning "Page $pageNumber contains control characters - cleaning..."
            $content = $content -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', ''
        }
        
        # Escape CDATA-unsafe sequences
        $escapedContent = Escape-CDataContent $content
        
        # Calculate navigation
        $prevPage = [int]$pageNumber - 1
        $nextPage = [int]$pageNumber + 1
        $disablePrev = if ([int]$pageNumber -le 100) { 'disabled' } else { '' }
        
        # Optional: Compress CSS
        # $cssContent = Compress-Css $sharedCss
        $cssContent = $sharedCss
        
        # Generate fragment XML
        $fragmentXml = @"
<fragment>
    <set-body><![CDATA[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TXT TV - Page $pageNumber</title>
    <style>
$cssContent
    </style>
</head>
<body>
    <div class="header">
        <span class="page-number">PAGE $pageNumber</span> - TXT TV
    </div>
    <div id="content">
        <pre class="content">$escapedContent</pre>
    </div>
    <nav>
        <button hx-get="/page/$prevPage" hx-target="body" hx-push-url="true" $disablePrev>&#9664; Previous</button>
        <input type="number" id="pageNum" value="$pageNumber" min="100" max="999" />
        <button hx-get="/page/{pageNum}" hx-include="#pageNum" hx-target="body" hx-push-url="true" 
                onclick="this.setAttribute('hx-get', '/page/' + document.getElementById('pageNum').value); htmx.process(this);">
            Go to Page
        </button>
        <button hx-get="/page/$nextPage" hx-target="body" hx-push-url="true">Next &#9654;</button>
    </nav>
    <script src="https://unpkg.com/htmx.org@1.9.10"></script>
</body>
</html>]]></set-body>
</fragment>
"@
        
        # Calculate fragment size
        $fragmentSizeKB = [System.Text.Encoding]::UTF8.GetByteCount($fragmentXml) / 1KB
        
        # Validate size limit
        if ($fragmentSizeKB -gt 256) {
            Write-Error "Page $pageNumber fragment exceeds 256 KB limit ($([math]::Round($fragmentSizeKB, 2)) KB)"
            $script:errorCount++
            return
        }
        
        # Write fragment file
        $outputPath = Join-Path $OutputDir "page-$pageNumber.xml"
        $fragmentXml | Out-File $outputPath -Encoding utf8 -NoNewline
        
        Write-Host "Generated: page-$pageNumber.xml ($($content.Length) chars, $([math]::Round($fragmentSizeKB, 2)) KB)" -ForegroundColor Green
        $script:successCount++
    }
    catch {
        Write-Error "Failed to process page $pageNumber`: $_"
        $script:errorCount++
    }
}

Write-Host ""
Write-Host "Conversion complete: $successCount succeeded, $errorCount failed" -ForegroundColor Cyan
```

### Testing Fragment XML Validity

```powershell
<#
.SYNOPSIS
    Validates APIM policy fragment XML files.
#>

param(
    [string]$FragmentDir = "infrastructure/modules/apim/fragments"
)

$errorCount = 0

Get-ChildItem "$FragmentDir/*.xml" | ForEach-Object {
    try {
        # Test XML validity
        [xml]$xml = Get-Content $_.FullName -Raw -Encoding UTF8
        
        # Validate root element
        if ($xml.DocumentElement.LocalName -ne "fragment") {
            Write-Error "$($_.Name): Root element must be <fragment>"
            $script:errorCount++
            return
        }
        
        # Check for CDATA sections
        $cdataCount = ($xml.InnerXml -split '<!\[CDATA\[').Count - 1
        
        Write-Host "$($_.Name): Valid ✓ ($cdataCount CDATA sections)" -ForegroundColor Green
    }
    catch {
        Write-Error "$($_.Name): Invalid XML - $_"
        $script:errorCount++
    }
}

if ($errorCount -eq 0) {
    Write-Host "All fragments valid!" -ForegroundColor Green
} else {
    Write-Host "$errorCount fragment(s) have errors" -ForegroundColor Red
    exit 1
}
```

---

## 8. Testing Approach

### Unit Testing: Validate Conversions

```powershell
<#
.SYNOPSIS
    Tests fragment generation and validity.
#>

Describe "APIM Fragment Conversion" {
    BeforeAll {
        $testDir = "TestDrive:\content\pages"
        $outputDir = "TestDrive:\fragments"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
    }
    
    It "Generates valid XML fragment" {
        # Create test content
        "Test content" | Out-File "$testDir\page-100.txt" -Encoding UTF8
        
        # Run conversion
        .\convert-txt-to-fragment.ps1 -SourceDir $testDir -OutputDir $outputDir
        
        # Validate output
        "$outputDir\page-100.xml" | Should -Exist
        
        # Parse XML
        [xml]$xml = Get-Content "$outputDir\page-100.xml" -Raw
        $xml.DocumentElement.LocalName | Should -Be "fragment"
    }
    
    It "Escapes CDATA end delimiter" {
        # Content with ]]>
        "Data: ]]> here" | Out-File "$testDir\page-101.txt" -Encoding UTF8
        
        .\convert-txt-to-fragment.ps1 -SourceDir $testDir -OutputDir $outputDir
        
        # Should not throw XML parsing error
        { [xml]$xml = Get-Content "$outputDir\page-101.xml" -Raw } | Should -Not -Throw
    }
    
    It "Rejects content exceeding size limit" {
        # Generate large content
        $largeContent = "x" * 3000
        $largeContent | Out-File "$testDir\page-102.txt" -Encoding UTF8
        
        # Should fail
        .\convert-txt-to-fragment.ps1 -SourceDir $testDir -OutputDir $outputDir -MaxCharacters 2000
        
        "$outputDir\page-102.xml" | Should -Not -Exist
    }
}
```

### Integration Testing: Deploy and Verify

```powershell
<#
.SYNOPSIS
    Tests deployed APIM fragments return correct HTML.
#>

param(
    [string]$ApimBaseUrl = "https://txttv-apim.azure-api.net"
)

Describe "APIM Fragment Integration Tests" {
    It "Returns HTML for page 100" {
        $response = Invoke-WebRequest -Uri "$ApimBaseUrl/page/100" -UseBasicParsing
        
        $response.StatusCode | Should -Be 200
        $response.Headers["Content-Type"] | Should -Match "text/html"
        $response.Content | Should -Match "<!DOCTYPE html>"
        $response.Content | Should -Match "PAGE 100"
    }
    
    It "Contains navigation buttons" {
        $response = Invoke-WebRequest -Uri "$ApimBaseUrl/page/105" -UseBasicParsing
        
        $response.Content | Should -Match '<button.*hx-get="/page/104"'  # Previous
        $response.Content | Should -Match '<button.*hx-get="/page/106"'  # Next
    }
    
    It "Disables previous button on page 100" {
        $response = Invoke-WebRequest -Uri "$ApimBaseUrl/page/100" -UseBasicParsing
        
        $response.Content | Should -Match '<button.*disabled.*Previous'
    }
    
    It "Returns 404 for non-existent page" {
        { Invoke-WebRequest -Uri "$ApimBaseUrl/page/999" -UseBasicParsing } | Should -Throw
    }
    
    It "Returns 400 for invalid page number" {
        { Invoke-WebRequest -Uri "$ApimBaseUrl/page/abc" -UseBasicParsing } | Should -Throw
    }
}
```

### Visual Testing: Browser Validation

```powershell
<#
.SYNOPSIS
    Opens pages in browser for manual visual inspection.
#>

param(
    [string]$ApimBaseUrl = "https://txttv-apim.azure-api.net",
    [int[]]$Pages = @(100, 101, 102, 103)
)

foreach ($page in $Pages) {
    Write-Host "Opening page $page..." -ForegroundColor Cyan
    Start-Process "$ApimBaseUrl/page/$page"
    Start-Sleep -Seconds 2
}
```

### Performance Testing: Response Times

```powershell
<#
.SYNOPSIS
    Measures fragment response times.
#>

param(
    [string]$ApimBaseUrl = "https://txttv-apim.azure-api.net",
    [int]$Iterations = 10
)

$pages = 100..110
$results = @()

foreach ($page in $pages) {
    $times = @()
    
    for ($i = 0; $i -lt $Iterations; $i++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $null = Invoke-WebRequest -Uri "$ApimBaseUrl/page/$page" -UseBasicParsing
        $sw.Stop()
        $times += $sw.ElapsedMilliseconds
    }
    
    $avgTime = ($times | Measure-Object -Average).Average
    $results += [PSCustomObject]@{
        Page = $page
        AvgResponseTime = [math]::Round($avgTime, 2)
    }
}

$results | Format-Table -AutoSize
Write-Host "Overall avg: $([math]::Round(($results.AvgResponseTime | Measure-Object -Average).Average, 2)) ms" -ForegroundColor Green
```

---

## Summary & Recommendations

### For TxtTV Project

✅ **Current Implementation is Excellent:**
- ✅ Proper CDATA usage
- ✅ UTF-8 encoding throughout
- ✅ Inline CSS (small size, eliminates HTTP request)
- ✅ External htmx.js via CDN
- ✅ Fragment size well within limits (~5-8 KB per fragment)
- ✅ Clean XML structure

### Potential Improvements

1. **Add Caching** (Easy win for performance):
   ```xml
   <cache-lookup vary-by-query-parameter>pageNumber</cache-lookup>
   <cache-store duration="3600" />
   ```

2. **Add Security Headers** (Best practice):
   ```xml
   <set-header name="X-Content-Type-Options" exists-action="override">
       <value>nosniff</value>
   </set-header>
   ```

3. **Add Fragment Size Validation** to conversion script (already in code above)

4. **Consider CSS Minification** if adding more styles (minor optimization)

### Key Takeaways

1. **CDATA is King**: Always use CDATA for embedding HTML - cleaner, safer, more maintainable
2. **Size Management**: Monitor fragment sizes, keep under 256 KB
3. **Encoding Discipline**: UTF-8 everywhere, escape `]]>` sequences
4. **Testing is Critical**: Validate XML, test in browser, measure performance
5. **Cache Aggressively**: Static content benefits greatly from APIM caching
6. **Keep CSS Inline** for small styles, use CDN for large assets

---

**Document Version**: 1.0  
**Last Updated**: 2026-02-07  
**Maintained By**: TxtTV Project Team
