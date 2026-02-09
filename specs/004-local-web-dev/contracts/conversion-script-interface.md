# Contract: Conversion Script Interface

**Feature**: [spec.md](../spec.md) | **Date**: February 7, 2026  
**Contract Type**: Command-Line Interface

## Overview

This contract defines the interface for the `convert-web-to-apim.ps1` PowerShell script that transforms local web interface files into APIM policy fragments.

## Script Location

```
infrastructure/scripts/convert-web-to-apim.ps1
```

## Command-Line Interface

### Synopsis

```powershell
convert-web-to-apim.ps1 
    [-SourcePath <string>] 
    [-OutputPath <string>] 
    [-ContentPath <string>] 
    [-Pages <int[]>] 
    [-Validate] 
    [-Force] 
    [-WhatIf] 
    [-Verbose]
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| **SourcePath** | string | No | `src/web` | Root directory of web interface source files |
| **OutputPath** | string | No | `infrastructure/modules/apim/fragments` | Output directory for generated policy fragments |
| **ContentPath** | string | No | `content/pages` | Directory containing text TV page content files |
| **Pages** | int[] | No | `100..110` | Array of page numbers to convert (e.g., `100,101,105`) |
| **Validate** | switch | No | `$true` | Enable 4-layer validation after generation (default: enabled) |
| **Force** | switch | No | `$false` | Overwrite existing fragments without prompting |
| **WhatIf** | switch | No | `$false` | Show what would be generated without creating files |
| **Verbose** | switch | No | `$false` | Enable detailed logging |

### Examples

```powershell
# Convert all pages (100-110) with validation
.\infrastructure\scripts\convert-web-to-apim.ps1

# Convert specific pages only
.\infrastructure\scripts\convert-web-to-apim.ps1 -Pages 100,101,102

# Convert without validation (fast mode, for testing)
.\infrastructure\scripts\convert-web-to-apim.ps1 -Validate:$false

# Preview changes without generating files
.\infrastructure\scripts\convert-web-to-apim.ps1 -WhatIf

# Custom paths (non-standard project structure)
.\infrastructure\scripts\convert-web-to-apim.ps1 `
    -SourcePath "custom/web" `
    -OutputPath "custom/fragments" `
    -ContentPath "custom/content"

# Force overwrite without prompts
.\infrastructure\scripts\convert-web-to-apim.ps1 -Force

# Verbose mode for debugging
.\infrastructure\scripts\convert-web-to-apim.ps1 -Verbose
```

## Input Requirements

### 1. Source Template

**Location**: `{SourcePath}/templates/page-template.html`

**Format**: HTML5 with placeholder tokens

**Required Tokens**:
- `{PAGE_NUMBER}`: Replaced with page number (e.g., `100`)
- `{CONTENT}`: Replaced with text content from content file
- `{STYLE}`: Replaced with inline CSS (optional)
- `{SCRIPT}`: Replaced with inline JavaScript (optional)

**Example**:
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>TXT TV - Page {PAGE_NUMBER}</title>
  <style>{STYLE}</style>
</head>
<body>
  <div class="txttv-page">
    <pre>{CONTENT}</pre>
  </div>
  <script>{SCRIPT}</script>
</body>
</html>
```

### 2. Stylesheets

**Location**: `{SourcePath}/styles/txttv.css`

**Format**: CSS3

**Purpose**: Inline CSS embedded in every fragment

**Size Recommendation**: <5 KB (for fast inline inclusion)

### 3. Scripts

**Location**: `{SourcePath}/scripts/*.js`

**Format**: ES6+ JavaScript

**Purpose**: Inline JavaScript embedded in fragments or external CDN references

**Files**:
- `navigation.js`: Page navigation logic
- `content-loader.js`: Dynamic content loading (optional)

### 4. Content Files

**Location**: `{ContentPath}/page-{NUMBER}.txt`

**Format**: UTF-8 plain text

**Constraints**:
- Maximum 2000 characters per page
- Monospaced-friendly formatting
- No HTML markup (plain text only)

**Example** (`page-100.txt`):
```
═══════════════════════════════════════
         TXT TV - PAGE 100
═══════════════════════════════════════

Weather: Helsinki 12°C ☁️

═══════════════════════════════════════
```

## Output Specification

### Policy Fragment XML

**Location**: `{OutputPath}/page-{NUMBER}.xml`

**Format**: APIM Policy Fragment XML

**Structure**:
```xml
<fragment>
  <set-body>
    <![CDATA[
      <!-- Generated HTML with inline CSS/JS -->
      <!DOCTYPE html>
      <html>...</html>
    ]]>
  </set-body>
</fragment>
```

**Properties**:
- **Encoding**: UTF-8 with BOM
- **Size**: Must not exceed 256 KB
- **CDATA Escaping**: `]]>` sequences must be escaped as `]]]]><![CDATA[>`
- **Validation**: Must pass XML well-formedness, APIM schema, security, and integration tests

## Exit Codes

| Code | Meaning | Description |
|------|---------|-------------|
| **0** | Success | All pages converted and validated successfully |
| **1** | Partial Failure | Some pages failed conversion or validation |
| **2** | Input Error | Missing or invalid input files (template, content, CSS) |
| **3** | Output Error | Cannot write to output directory (permissions, disk space) |
| **4** | Validation Error | Generated fragments failed validation |

## Output Messages

### Standard Output (Success)

```
Starting conversion...
  Source: src/web
  Output: infrastructure/modules/apim/fragments
  Pages:  100-110

Reading template: src/web/templates/page-template.html
Reading CSS: src/web/styles/txttv.css (2.3 KB)
Reading JS: src/web/scripts/navigation.js (1.5 KB)

Converting page 100... ✓ (5.2 KB)
Converting page 101... ✓ (5.4 KB)
...
Converting page 110... ✓ (5.8 KB)

Validation Summary:
  XML Well-Formedness:   10/10 passed
  APIM Schema Compliance: 10/10 passed
  Security Scan:         10/10 passed (0 warnings)
  Integration Tests:     10/10 passed

✅ Conversion Complete
   Generated: 10 fragments
   Total Size: 55.3 KB
   Time:      4.2 seconds
```

### Standard Error (Failure)

```
Starting conversion...
  Source: src/web
  Output: infrastructure/modules/apim/fragments
  Pages:  100-110

ERROR: Template not found: src/web/templates/page-template.html
       Please create the template file or specify -SourcePath

Exit code: 2
```

```
Converting page 103... ✗ FAILED
  Error: Content file too large (2340 chars, max 2000)
  File:  content/pages/page-103.txt

❌ Conversion Failed
   Generated: 9/10 fragments
   Errors:    1
   
Exit code: 1
```

## Error Handling

### Missing Input Files

**Behavior**: Script exits with code 2

**Recovery**: Ensure all required files exist before running script

### Invalid HTML Template

**Behavior**: Script exits with code 2 after reporting parse error

**Recovery**: Validate template HTML5 syntax

### Content Too Large

**Behavior**: Script skips page, logs warning, continues with other pages

**Exit Code**: 1 (partial failure) if any pages skipped

### Output Permission Denied

**Behavior**: Script exits with code 3

**Recovery**: Check file permissions on output directory

### Validation Failures

**Behavior**: 
- XML errors: Delete invalid fragment, exit code 4
- Security warnings: Generate fragment, log warning, exit code 0
- Integration test failures: Generate fragments, report failure, exit code 4

## Performance Characteristics

| Metric | Target | Typical |
|--------|--------|---------|
| **Conversion Time (single page)** | <3s | 0.4s |
| **Conversion Time (all 10 pages)** | <30s | 4-6s |
| **Memory Usage** | <100 MB | 30-50 MB |
| **CPU Usage** | <50% (single core) | 20-30% |

## Dependencies

### Required

- PowerShell 7.0 or later
- File system access to:
  - `src/web/` (read)
  - `content/pages/` (read)
  - `infrastructure/modules/apim/fragments/` (read/write)

### Optional

- Pester 5.0+ (for integration tests via `-Validate`)
- Git (for detecting modified pages - future feature)

## Security Considerations

### Input Validation

- Template paths: Must be within project root (prevent path traversal)
- Content files: Scanned for XSS patterns before embedding
- Page numbers: Must be integers 100-999 (prevent injection)

### Output Sanitization

- CDATA terminators escaped automatically
- XML special characters handled via CDATA (no escaping needed)
- File paths sanitized (prevent directory traversal in output names)

### Sensitive Data

- No credentials or secrets should be in template files
- Content files are treated as untrusted input (XSS scanning enabled)

## Validation Integration

When `-Validate` is enabled (default), the script runs:

1. **XML Well-Formedness** (Layer 1)
   - Parse XML with PowerShell parser
   - Fail fast if invalid XML generated

2. **APIM Schema Compliance** (Layer 2)
   - Validate `<fragment>` structure
   - Check CDATA usage
   - Verify size limits

3. **Security Scan** (Layer 3)
   - Detect XSS patterns
   - Check for injection risks
   - Validate character encoding

4. **Integration Tests** (Layer 4, optional)
   - Run Pester tests if available
   - Validate fragment composition
   - Check naming conventions

## Backward Compatibility

### Version 1.0

- Initial implementation with all parameters
- Supports pages 100-110
- CDATA encoding
- 4-layer validation

### Future Changes

- **1.1**: Add `-Incremental` flag (convert only modified pages)
- **1.2**: Add `-Template` parameter (support multiple templates)
- **1.3**: Add `-Minify` flag (optional HTML/CSS minification)

Breaking changes will increment major version.

---

**Related Contracts**:
- [Policy Fragment Schema](policy-fragment-schema.md)
- [Validation Functions](validation-functions.md)
- [Web Template Format](web-template-format.md)
