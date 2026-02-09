# Technical Research: Local Web Development Workflow

**Feature**: [spec.md](spec.md) | **Date**: February 7, 2026  
**Phase**: Phase 0 - Research & Decision Making

## Research Summary

This document consolidates findings from investigating technologies and approaches for local web development of the text TV interface with automated conversion to APIM policy fragments.

---

## Decision 1: Local Development Approach

### Research Question
What is the simplest, most maintainable approach for local web development that aligns with the project's focus on APIM policy fragments as the primary implementation surface?

### Options Evaluated
1. **Node.js development server** (live-server, Vite, webpack-dev-server) - Requires Node.js, npm, build pipeline
2. **Python http.server** - Built-in, zero-install, manual refresh only
3. **Direct file access** - Open HTML files directly in browser, manual refresh, zero dependencies
4. **PowerShell HttpListener** - Custom solution, full control, more code
5. **VS Code Live Server** - IDE-dependent, not scriptable

### Decision: **Direct file access (simple HTML + htmx)**

**Rationale**:
- ✅ Zero dependencies - no Node.js, npm, or other tooling required
- ✅ Aligns with constitution v1.2.2: "No live-server or development server required (open HTML files directly in browser)"
- ✅ Instant setup - developer opens index.html in browser (<30s from clone)
- ✅ Cross-platform - works identically on Windows, macOS, Linux
- ✅ htmx 2.0.8 loaded from CDN - no package manager needed
- ✅ Manual refresh is acceptable - developers press F5 to see changes (<5s cycle time)
- ✅ Simplifies deployment - what you see locally is what converts to APIM policies
- ✅ Reduces complexity - no build pipeline to maintain
- ✅ Browser DevTools work natively for debugging

**Constitution Alignment**:
Per constitution v1.2.2 Technology Stack:
> **Web Frontend**: Simple HTML with htmx (no build tooling required)
> - htmx 2.0.8 loaded from CDN: https://cdn.jsdelivr.net/npm/htmx.org@2.0.8/dist/htmx.min.js
> - No Node.js, webpack, Vite, or other build systems
> - No live-server or development server required (open HTML files directly in browser)

**Developer Workflow**:
1. Clone repository
2. Open `src/web/index.html` in browser
3. Edit HTML/CSS/JS files
4. Refresh browser (F5) to see changes
5. Run conversion script when ready to deploy

**Helper Script** (optional convenience):
```powershell
# infrastructure/scripts/start-dev-server.ps1
# Simply opens default browser to index.html
param([string]$Page = "index.html")
Start-Process "src/web/$Page"
```

**Alternatives Considered**:
- **Live reload**: Adds unnecessary complexity for <5s manual refresh requirement
- **Build pipeline**: Not needed for simple HTML+htmx (constitution explicitly prohibits)

---

## Decision 2: Policy Fragment Validation Strategy

### Research Question
How should we validate generated APIM policy fragments to ensure correctness, security, and compliance with Azure requirements?

### Multi-Layered Validation Approach

#### Layer 1: XML Well-Formedness
**Tool**: PowerShell XML parser  
**Purpose**: Syntax validation  
**Implementation**:
```powershell
function Test-XmlWellFormedness {
    param([string]$XmlPath)
    try {
        $xml = [xml](Get-Content $XmlPath -Raw)
        return $true
    } catch {
        Write-Error "Invalid XML: $($_.Exception.Message)"
        return $false
    }
}
```

#### Layer 2: APIM Policy Schema Compliance
**Tool**: Custom PowerShell validator  
**Purpose**: Structural validation against APIM requirements  
**Validates**:
- Correct `<fragment>` root element
- Valid child elements (`set-body`, `set-status`, `set-header`, `return-response`)
- CDATA usage for HTML content
- Size limits (256 KB per document)

#### Layer 3: Security & Content Validation
**Tool**: Custom PowerShell security scanner  
**Purpose**: Detect XSS, injection, and encoding issues  
**Checks**:
- XSS patterns (malicious `<script>`, event handlers, `eval()`)
- Unescaped XML characters outside CDATA
- Expression injection in policy code
- Text content length limits (2000 chars)

#### Layer 4: Integration Testing
**Tool**: Pester (existing framework)  
**Purpose**: End-to-end fragment composition validation  
**Tests**:
- All referenced fragments exist
- Fragment ID naming conventions
- Total fragment count within APIM limits (100 for Standard tier)
- Size limits for combined policies
- HTML5 structure validation
- CSS consistency across pages

### Recommended Validation Script

Create `infrastructure/scripts/Validate-ApimPolicies.ps1` implementing all layers:

```powershell
param(
    [string]$FragmentsPath = "infrastructure/modules/apim/fragments",
    [switch]$FailFast,
    [switch]$SecurityOnly
)

# Execute all 4 validation layers
# Layer 1: XML well-formedness
# Layer 2: APIM schema compliance
# Layer 3: Security scanning
# Layer 4: Pester integration tests

# Exit code: 0 = pass, 1 = fail
```

### CI/CD Integration
- **Pre-commit hook**: Run security-only validation
- **Pull request**: Full 4-layer validation
- **Deployment**: Bicep validation + policy tests

**Decision Rationale**: Multi-layered approach provides defense-in-depth, catches issues early (syntax → structure → security → integration), and integrates with existing Pester tests.

---

## Decision 3: HTML to APIM XML Conversion

### Research Question
What are the best practices for embedding HTML/CSS/JavaScript in APIM policy XML fragments?

### Encoding Strategy

#### CDATA Sections (Recommended)
**Decision**: Use CDATA for all HTML content  
**Rationale**:
- No need to escape `<`, `>`, `&`, `"` characters
- Preserves formatting and readability
- APIM expects CDATA for HTML responses
- Existing `convert-txt-to-fragment.ps1` already uses this correctly

**Structure**:
```xml
<fragment>
  <set-body>
    <![CDATA[
      <!DOCTYPE html>
      <html>...</html>
    ]]>
  </set-body>
</fragment>
```

**Special Case**: Escape `]]>` sequences inside CDATA:
```powershell
$content = $content -replace ']]>', ']]]]><![CDATA[>'
```

### APIM Policy Fragment Structure

**Recommended Template**:
```xml
<fragment>
  <set-body>
    <![CDATA[<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>TXT TV - Page {PAGE_NUMBER}</title>
  <style>
    /* Inline CSS - optimal for < 5 KB */
    body { font-family: monospace; background: #000; color: #0f0; }
  </style>
</head>
<body>
  <div class="txttv-page">
    {CONTENT}
  </div>
  
  <!-- External JS via CDN -->
  <script src="https://unpkg.com/htmx.org@1.9.10"></script>
  <script>
    // Inline navigation logic
  </script>
</body>
</html>]]>
  </set-body>
</fragment>
```

**Notes**:
- Fragment contains only `<set-body>` (no `<return-response>`)
- Routing policy handles `<return-response>` with fragment inclusion
- Content-Type header set in routing policy, not fragment

### Size Optimization

**APIM Limits**:
- **256 KB** maximum per policy document
- **100 fragments** per namespace (Standard tier)

**Current Status**:
- Text TV fragments: 5-8 KB (well within limits)
- Text content limited to 2000 chars
- CSS inline: ~2-3 KB
- No minification needed at current sizes

**Optimization Strategies** (if needed in future):
1. **CSS extraction**: Move common CSS to shared fragment
2. **Content chunking**: Split large pages across multiple fragments
3. **Compression**: APIM applies gzip automatically
4. **CDN assets**: External CSS/JS reduces fragment size

### PowerShell Conversion Logic

**Key Operations**:
```powershell
# 1. Read source HTML
$html = Get-Content "src/web/templates/page-template.html" -Raw

# 2. Inject dynamic content
$html = $html -replace '{PAGE_NUMBER}', $pageNumber
$html = $html -replace '{CONTENT}', $textContent

# 3. Escape CDATA terminators
$html = $html -replace ']]>', ']]]]><![CDATA[>'

# 4. Wrap in policy fragment XML
$fragment = @"
<fragment>
  <set-body>
    <![CDATA[$html]]>
  </set-body>
</fragment>
"@

# 5. Save with UTF-8 BOM encoding
[System.IO.File]::WriteAllText($outputPath, $fragment, [System.Text.Encoding]::UTF8)

# 6. Validate generated XML
Test-XmlWellFormedness $outputPath
Test-ApimPolicyStructure $outputPath
Test-ApimPolicySecurity $outputPath
```

### Performance Best Practices

1. **Caching**: Add to routing policy (not fragment):
   ```xml
   <cache-lookup vary-by-developer="false" vary-by-developer-groups="false">
     <vary-by-query-parameter>page</vary-by-query-parameter>
   </cache-lookup>
   ```

2. **Compression**: Automatic via APIM (no action needed)

3. **Inline Small Assets**: CSS < 5 KB should be inline

4. **External Large Assets**: JS frameworks via CDN (htmx.org)

### Common Pitfalls & Solutions

| Pitfall | Solution |
|---------|----------|
| XML parsing errors from unescaped chars | Use CDATA sections |
| `]]>` inside CDATA breaks XML | Escape: `]]]]><![CDATA[>` |
| Wrong content-type (XML instead of HTML) | Set in routing policy: `application/html` |
| Fragment too large (>256 KB) | Split into multiple fragments |
| UTF-8 encoding issues | Use `[System.Text.Encoding]::UTF8` |
| Browser caching stale content | Add cache-control headers |

---

## Resolved Technical Context Items

### Primary Dependencies
**Decision**: Node.js (for live-server)  
**Rationale**: Best balance of features and simplicity, commonly available in dev environments

### Testing Strategy
**Decision**: Multi-layered validation (4 layers: XML → Schema → Security → Integration)  
**Rationale**: Defense-in-depth approach catches issues at appropriate level, integrates with existing Pester tests

### Contract Tests
**Decision**: Pester-based fragment composition and structure validation  
**Rationale**: Leverages existing test framework, validates fragment references and limits

---

## Implementation Recommendations

### Project Structure Decisions
```
src/
├── web/                          # NEW: Local development source
│   ├── index.html               # Entry point
│   ├── styles/txttv.css        # Shared CSS
│   ├── scripts/navigation.js   # Client-side logic
│   └── templates/page-template.html  # Template for conversion

infrastructure/
├── scripts/
│   ├── convert-web-to-apim.ps1      # NEW: Conversion script
│   ├── Validate-ApimPolicies.ps1    # NEW: 4-layer validation
│   └── Validation-Functions.ps1     # Shared validation functions
```

### Development Workflow
1. **Local Dev**: Run `live-server src/web --port=3000`
2. **Edit**: Modify HTML/CSS/JS in `src/web/`
3. **Test**: Browser auto-reloads on save
4. **Convert**: Run `convert-web-to-apim.ps1`
5. **Validate**: Automatic 4-layer validation
6. **Deploy**: Bicep deployment with generated fragments

### Technology Stack Summary
- **Local Server**: Node.js live-server
- **Source Format**: HTML5 + CSS3 + ES6 JavaScript
- **Conversion**: PowerShell 7+ script
- **Target Format**: APIM policy fragment XML with CDATA
- **Validation**: PowerShell + Pester
- **Deployment**: Bicep (existing infrastructure)

---

## Next Steps (Phase 1)

With all research complete and unknowns resolved, proceed to Phase 1:
1. ✅ Create [data-model.md](data-model.md) - Document entities and relationships
2. ✅ Create [contracts/](contracts/) - Define conversion script interfaces
3. ✅ Create [quickstart.md](quickstart.md) - Developer setup guide
4. ✅ Update agent context - Add Node.js and validation tools

**Constitution Re-check**: All NEEDS CLARIFICATION items resolved. Ready for Phase 1 design.
