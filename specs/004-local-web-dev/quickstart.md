# Quickstart: Local Web Development Workflow

**Feature**: Local Web Dev → APIM Policy Conversion  
**Target Audience**: Developers working on text TV interface  
**Time to Complete**: 5 minutes

## Prerequisites

Before you begin, ensure you have:

- ✅ **PowerShell 7+** installed (`pwsh --version`)
- ✅ **Web browser** (Chrome, Edge, Firefox, Safari)
- ✅ **Git** (for version control)
- ✅ **Text editor** (VS Code recommended)
- ✅ **Repository cloned** locally

**Note**: No Node.js, npm, or other tooling required! The web interface uses simple HTML with htmx loaded from CDN.

### Install PowerShell 7 (if needed)

**Windows**:
```powershell
winget install Microsoft.PowerShell
```

**macOS/Linux**:
```bash
# See: https://learn.microsoft.com/powershell/scripting/install/installing-powershell
```

---

## Step 1: Open the Web Interface

Simply open the HTML files directly in your browser - no server needed!

```powershell
# Navigate to project root
cd path/to/txttv

# Option 1: Open in default browser (Windows)
Start-Process src/web/index.html

# Option 2: Use helper script
.\infrastructure\scripts\start-dev-server.ps1

# Option 3: Double-click src/web/index.html in File Explorer
```

**Expected Result**: Browser opens showing the text TV interface

---

## Step 2: Make Your First Edit

Edit the HTML files and see changes instantly:

```powershell
# Open index.html in your text editor
code src/web/index.html  # VS Code
# OR
notepad src/web/index.html  # Notepad

# Make a change (e.g., update the title)
# Save the file

# Refresh browser (F5) to see changes
```

**Time**: ~5 seconds per edit cycle

**Note**: htmx is loaded from CDN (https://cdn.jsdelivr.net/npm/htmx.org@2.0.8/dist/htmx.min.js) - no installation needed!

---

## Step 3: Create Web Source Directory (if needed)

Navigate to your project root and create the web development structure:

```powershell
# Navigate to project root
cd path/to/txttv

# Create directory structure
New-Item -ItemType Directory -Force -Path src/web/templates
New-Item -ItemType Directory -Force -Path src/web/styles
New-Item -ItemType Directory -Force -Path src/web/scripts
```

### Create Initial Files

**1. Page Template** (`src/web/templates/page-template.html`):

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>TXT TV - Page {PAGE_NUMBER}</title>
  <style>{STYLE}</style>
</head>
<body>
  <div class="txttv-page">
    <pre>{CONTENT}</pre>
    
    <div class="nav-links">
      <a href="?page={(PAGE_NUMBER - 1) == 99 ? 110 : (PAGE_NUMBER - 1)}">← Previous</a>
      <a href="?page=100">Index</a>
      <a href="?page={(PAGE_NUMBER + 1) == 111 ? 100 : (PAGE_NUMBER + 1)}">Next →</a>
    </div>
  </div>
  
  <script src="https://cdn.jsdelivr.net/npm/htmx.org@2.0.8/dist/htmx.min.js"></script>
  <script>{SCRIPT}</script>
</body>
</html>
```

**2. Stylesheet** (`src/web/styles/txttv.css`):

```css
body {
  margin: 0;
  padding: 20px;
  background-color: #000;
  color: #0f0;
  font-family: 'Courier New', 'Lucida Console', monospace;
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
  color: #fff;
}
```

**3. Navigation Script** (`src/web/scripts/navigation.js`):

```javascript
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

// Performance monitoring
window.addEventListener('load', function() {
  const loadTime = performance.timing.loadEventEnd - performance.timing.navigationStart;
  console.log('Page load time:', loadTime + 'ms');
});
```

**4. Index Page** (`src/web/index.html`):

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>TXT TV - Index</title>
  <link rel="stylesheet" href="styles/txttv.css">
</head>
<body>
  <div class="txttv-page">
    <h1>TXT TV - Local Development</h1>
    
    <h2>Available Pages</h2>
    <ul>
      <li><a href="page.html?page=100">Page 100 - Weather & Sports</a></li>
      <li><a href="page.html?page=101">Page 101 - News</a></li>
      <li><a href="page.html?page=102">Page 102 - TV Programs</a></li>
      <li><a href="page.html?page=103">Page 103 - Finance</a></li>
      <li><a href="page.html?page=104">Page 104 - Traffic</a></li>
      <li><a href="page.html?page=105">Page 105 - Culture</a></li>
      <li><a href="page.html?page=106">Page 106 - Technology</a></li>
      <li><a href="page.html?page=107">Page 107 - Health</a></li>
      <li><a href="page.html?page=108">Page 108 - Lottery</a></li>
      <li><a href="page.html?page=109">Page 109 - Comics</a></li>
      <li><a href="page.html?page=110">Page 110 - Contact</a></li>
    </ul>
    
    <h2>Keyboard Shortcuts</h2>
    <ul>
      <li><code>→</code> or <code>n</code> - Next page</li>
      <li><code>←</code> or <code>p</code> - Previous page</li>
      <li><code>h</code> or <code>Home</code> - Return to index (page 100)</li>
    </ul>
  </div>
  
  <script src="scripts/navigation.js"></script>
</body>
</html>
```

**Time**: ~5 minutes

---

## Step 3: Start Local Development Server

### Start live-server

```powershell
# From project root
cd src/web
live-server --port=3000 --open=/index.html
```

**Expected Output**:
```
Serving "src/web" at http://127.0.0.1:3000
Ready for changes
```

**Your browser** should automatically open to `http://localhost:3000/index.html`

### Test Live Reload

1. Open `src/web/styles/txttv.css` in your editor
2. Change `color: #0f0;` to `color: #0ff;` (green to cyan)
3. Save the file
4. **Browser automatically reloads** with new color!

**Time**: ~2 minutes

---

## Step 4: Edit and Preview

### Make Your Changes

Edit any file in `src/web/`:
- `templates/page-template.html` - Page structure
- `styles/txttv.css` - Styling
- `scripts/navigation.js` - Behavior

**Live reload** updates your browser within 1-2 seconds of saving.

### Preview Content

Content files in `content/pages/` are not yet integrated with local dev. For now:

1. Copy content from `content/pages/page-100.txt`
2. Paste into `<pre>` tag in your template
3. See live preview

**Time**: Continuous iteration

---

## Step 5: Convert to APIM Policy Fragments

### Install Conversion Script

The conversion script should already exist at:
```
infrastructure/scripts/convert-web-to-apim.ps1
```

If not, create it using the specification in [contracts/conversion-script-interface.md](contracts/conversion-script-interface.md).

### Run Conversion

```powershell
# From project root
.\infrastructure\scripts\convert-web-to-apim.ps1
```

**Expected Output**:
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
  XML Well-Formedness:    10/10 passed
  APIM Schema Compliance: 10/10 passed
  Security Scan:          10/10 passed
  Integration Tests:      10/10 passed

✅ Conversion Complete
   Generated: 10 fragments
   Total Size: 55.3 KB
   Time:      4.2 seconds
```

**Generated Files**:
```
infrastructure/modules/apim/fragments/
├── page-100.xml
├── page-101.xml
├── ...
└── page-110.xml
```

**Time**: ~30 seconds

---

## Step 6: Validate Generated Policies

### Inspect Output

Open one of the generated fragments:

```powershell
code infrastructure/modules/apim/fragments/page-100.xml
```

**Verify**:
- ✅ Valid XML structure
- ✅ HTML wrapped in CDATA
- ✅ CSS and JS inline
- ✅ No CDATA escaping issues

### Run Validation Manually

```powershell
.\infrastructure\scripts\Validate-ApimPolicies.ps1
```

**Layers Executed**:
1. XML well-formedness
2. APIM schema compliance
3. Security scanning
4. Integration tests (Pester)

**Time**: ~10 seconds

---

## Step 7: Commit and Deploy

### Stage Changes

```powershell
git add src/web/
git add infrastructure/modules/apim/fragments/
```

### Commit

```powershell
git commit -m "feat: add local web dev UI and generated APIM fragments

- Create web templates, styles, and scripts in src/web/
- Generate APIM policy fragments for pages 100-110
- All fragments validated (XML, schema, security, integration)
- Ready for Bicep deployment"
```

### Deploy (via existing CI/CD)

Push to your feature branch:

```powershell
git push origin 004-local-web-dev
```

**CI/CD pipeline** will:
1. Validate policy fragments
2. Deploy Bicep infrastructure
3. Update APIM with new fragments

**Time**: ~3 minutes

---

## Common Workflows

### Workflow 1: Update UI Styling

```powershell
# 1. Start local server (if not running)
live-server src/web --port=3000

# 2. Edit CSS
code src/web/styles/txttv.css

# 3. Save → Browser auto-reloads → See changes immediately

# 4. Convert to APIM fragments
.\infrastructure\scripts\convert-web-to-apim.ps1

# 5. Commit and push
git add -A
git commit -m "style: update txttv color scheme"
git push
```

### Workflow 2: Add New Page Template Feature

```powershell
# 1. Edit template
code src/web/templates/page-template.html

# 2. Test locally
live-server src/web --port=3000

# 3. Convert specific pages (if script supports -Pages param)
.\infrastructure\scripts\convert-web-to-apim.ps1 -Pages 100,101

# 4. Validate
.\infrastructure\scripts\Validate-ApimPolicies.ps1 -FailFast

# 5. Commit
git add -A
git commit -m "feat: add search functionality to pages"
git push
```

### Workflow 3: Update Content Only

```powershell
# 1. Edit content file
code content/pages/page-100.txt

# 2. Convert (re-generates fragments with new content)
.\infrastructure\scripts\convert-web-to-apim.ps1

# 3. Validate
.\infrastructure\scripts\Validate-ApimPolicies.ps1 -SecurityOnly

# 4. Commit
git add -A
git commit -m "content: update page 100 weather data"
git push
```

---

## Troubleshooting

### Issue: Live server won't start

**Symptoms**: `live-server: command not found`

**Solution**:
```powershell
# Reinstall globally
npm install -g live-server

# Verify npm global bin is in PATH
npm config get prefix
# Add {prefix}/bin to PATH if needed
```

### Issue: Browser doesn't auto-reload

**Symptoms**: Changes saved but browser shows old content

**Solutions**:
1. **Check terminal**: Look for "CSS changed, reloading"
2. **Hard refresh**: Ctrl+Shift+R (Windows/Linux) or Cmd+Shift+R (macOS)
3. **Restart server**: Ctrl+C, then run `live-server` again
4. **Disable cache**: Open DevTools → Network tab → Check "Disable cache"

### Issue: Conversion script fails

**Symptoms**: "Template not found" or "Invalid XML generated"

**Solutions**:
```powershell
# Check file exists
Test-Path src/web/templates/page-template.html

# Check permissions
Get-Acl src/web/templates/page-template.html | Format-List

# Run with verbose logging
.\infrastructure\scripts\convert-web-to-apim.ps1 -Verbose

# Preview without creating files
.\infrastructure\scripts\convert-web-to-apim.ps1 -WhatIf
```

### Issue: Validation errors

**Symptoms**: "Security scan failed" or "XSS pattern detected"

**Solutions**:
```powershell
# View detailed validation report
.\infrastructure\scripts\Validate-ApimPolicies.ps1 -Verbose

# Check specific fragment
$xml = [xml](Get-Content infrastructure/modules/apim/fragments/page-100.xml -Raw)
$xml.fragment.'set-body'.'#cdata-section'

# Fix common issues:
# - Escape ]]> as ]]]]><![CDATA[>
# - Remove inline event handlers (use addEventListener)
# - Use CDN for external scripts (with integrity hash)
```

---

## Next Steps

- ✅ Read [data-model.md](data-model.md) to understand entity relationships
- ✅ Review [contracts/](contracts/) for detailed specifications
- ✅ Explore [research.md](research.md) for technology decisions
- ✅ Check [plan.md](plan.md) for full implementation plan

---

## Quick Reference

### Commands

| Command | Purpose |
|---------|---------|
| `live-server src/web --port=3000` | Start local dev server |
| `.\infrastructure\scripts\convert-web-to-apim.ps1` | Convert web → APIM |
| `.\infrastructure\scripts\Validate-ApimPolicies.ps1` | Validate fragments |
| `git add -A && git commit -m "msg" && git push` | Commit and deploy |

### File Paths

| Path | Purpose |
|------|---------|
| `src/web/templates/page-template.html` | Page HTML structure |
| `src/web/styles/txttv.css` | Styling |
| `src/web/scripts/navigation.js` | Behavior |
| `content/pages/page-100.txt` | Content |
| `infrastructure/modules/apim/fragments/` | Generated policies |

### URLs

| URL | Purpose |
|-----|---------|
| `http://localhost:3000/` | Local dev server |
| `http://localhost:3000/index.html` | Page index |
| `http://localhost:3000/page.html?page=100` | Specific page |

---

**Total Setup Time**: ~15 minutes  
**Typical Iteration Time**: <10 seconds (save → reload)  
**Conversion Time**: ~5 seconds for all pages

**You're ready to start developing! 🚀**
