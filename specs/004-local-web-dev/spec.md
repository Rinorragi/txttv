# Feature Specification: Local Web Development Workflow

**Feature Branch**: `004-local-web-dev`  
**Created**: February 7, 2026  
**Status**: Draft  
**Input**: User description: "I want the actual text tv app to be locally developed. So figure out strategy to build website that can be run in browser at localhost and then a way to chop it into api management policies in via script."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Local Development Experience (Priority: P1)

A developer needs to create and test the text TV web interface locally on their machine with immediate visual feedback, without deploying to cloud infrastructure.

**Why this priority**: This is the foundation of the entire workflow - without local development capability, developers cannot iterate quickly or test changes before deployment.

**Independent Test**: Can be fully tested by opening the text TV interface files directly in a browser and verifying navigation works between pages, delivering a complete browsing experience without any cloud dependencies.

**Acceptance Scenarios**:

1. **Given** a developer has the project on their machine, **When** they open the text TV interface in their browser, **Then** they can view the text TV pages with static content embedded directly in the HTML
2. **Given** the interface is displayed in the browser, **When** they navigate between text TV pages (e.g., page 100 to 101), **Then** page transitions work correctly without any dynamic content loading
3. **Given** a developer modifies the interface code or content, **When** they re-run the conversion script and refresh the browser, **Then** the browser reflects the updated static content
4. **Given** the local files are accessible, **When** they test the interface across different browsers, **Then** the experience is consistent with all content pre-embedded in HTML

---

### User Story 2 - Policy Conversion Automation (Priority: P2)

A developer needs to convert their locally-developed web interface into API Management policy fragments that can be deployed to Azure, ensuring the production experience matches their local testing.

**Why this priority**: This bridges local development to production deployment - without it, manually converting HTML/CSS/JS to APIM policies would be error-prone and time-consuming.

**Independent Test**: Can be fully tested by running the conversion script on a complete local web app and verifying the generated policy files match the expected APIM fragment structure.

**Acceptance Scenarios**:

1. **Given** a completed local web interface, **When** the developer runs the conversion script, **Then** APIM policy fragments are generated in the correct directory structure
2. **Given** policy fragments are generated, **When** the developer inspects them, **Then** all HTML, CSS, and JavaScript from the local version is present and properly encoded
3. **Given** generated policies, **When** deployed to APIM, **Then** the rendered text TV interface matches the local development version
4. **Given** the web interface includes static assets (CSS, images), **When** conversion runs, **Then** assets are properly embedded or referenced in the policies

---

### User Story 3 - Development-Deployment Parity (Priority: P3)

A developer needs to verify that their local development environment accurately represents what will be deployed to production, minimizing deployment surprises.

**Why this priority**: Ensures confidence in deployments - if local and production differ significantly, the value of local testing diminishes.

**Independent Test**: Can be fully tested by comparing the local browser experience side-by-side with a deployed APIM instance, verifying visual and functional parity.

**Acceptance Scenarios**:

1. **Given** a feature tested locally, **When** deployed via converted policies, **Then** the visual appearance is identical
2. **Given** interactive elements (links, navigation) work locally, **When** deployed to APIM, **Then** the same interactions function correctly
3. **Given** the local dev environment uses test data, **When** deployed, **Then** the production environment correctly integrates with real data sources

---

### Edge Cases

- What happens when content files contain special characters that need XML escaping (e.g., `&`, `<`, `>`, `]]>`)?
- How does the system handle very large content files that would cause the generated HTML to exceed APIM policy size limits (256 KB)?
- What happens when the conversion script encounters malformed HTML in the template or missing content files?
- How does the workflow handle incremental updates - converting only changed pages vs. full rebuild?
- What happens when developers accidentally include dynamic content loading code (fetch, AJAX) that won't work in APIM?
- How does the system handle content with varying character encodings (UTF-8, ASCII, etc.)?

**Note on Removed Components**: Early implementation iterations considered a `content-loader.js` script for dynamic content loading via fetch API. This approach was removed because:
- APIM policy fragments serve static content only
- Dynamic loading adds unnecessary complexity and potential failure points
- Static embedding ensures local development accurately represents production behavior
- Eliminates CORS and path resolution issues when deployed

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST enable developers to view and test the text TV interface locally in a web browser before deployment
- **FR-002**: System MUST embed content statically in HTML at build time (via conversion script) rather than loading content dynamically at runtime
- **FR-003**: Local environment MUST render all text TV pages with the same layout, styling, and navigation as intended for production
- **FR-004**: System MUST provide a conversion script that reads content from text files (e.g., `content/pages/page-100.txt`) and embeds it into HTML template placeholders
- **FR-005**: Conversion script MUST transform the template + content into complete static HTML pages wrapped in APIM policy fragments
- **FR-006**: Generated policy fragments MUST follow the existing project structure under `infrastructure/modules/apim/fragments/`
- **FR-007**: Conversion process MUST handle encoding and escaping requirements for embedding web content in XML policies (including CDATA escaping)
- **FR-008**: System MUST validate generated policies against APIM schema requirements before deployment
- **FR-009**: Content files (e.g., `content/pages/page-*.txt`) MUST contain static text content that gets embedded into the HTML template during conversion
- **FR-010**: System MUST NOT use dynamic content loading (e.g., fetch API, AJAX) to load content at browser runtime
- **FR-011**: Conversion script MUST be idempotent - running it multiple times on the same source produces identical output
- **FR-012**: System MUST document the workflow for developers to iterate locally and deploy to APIM
- **FR-013**: Developers MUST be able to use standard browser debugging capabilities for troubleshooting UI issues

### Assumptions

- The local development approach uses simple HTML with htmx loaded from CDN, requiring no build tooling or package managers
- Content is static and embedded directly in HTML files at build time (via conversion script), NOT loaded dynamically at runtime
- No JavaScript-based dynamic content loading (fetch, AJAX, or similar) is used - all content is pre-embedded in the fragment
- Developers view fully-rendered static HTML files directly in their browser without requiring a development server
- Policy conversion is a command-line script that reads content files and embeds them into HTML templates before wrapping in XML
- The existing Azure infrastructure and deployment process will handle deploying the converted policies
- Development will happen on Windows, macOS, or Linux with a web browser available
- The text TV interface is primarily a content presentation layer without complex backend API interactions
- Content examples use fake cyber security news/incidents (e.g., "Critical vulnerability in Apache Struts", "Ransomware attack on healthcare provider")
- Generated policy fragments will be stored in version control and reviewed before deployment
- The web frontend serves as a demonstration UI; APIM policy fragments contain the primary business logic per project architecture

### Key Entities *(include if feature involves data)*

- **Web Interface Template**: The HTML template file (`page-template.html`) with placeholder markers like `{CONTENT}` that get replaced during conversion
- **Content File**: A plain text file (e.g., `content/pages/page-100.txt`) containing static cyber security news content that gets embedded into the template
- **Policy Fragment**: An APIM policy XML file containing embedded web content (complete static HTML with CSS/JS) that renders a text TV page when deployed
- **Conversion Script**: A command-line PowerShell tool (`convert-web-to-apim.ps1`) that:
  1. Reads the HTML template
  2. Reads content from text files
  3. Replaces placeholders like `{CONTENT}` with actual text content
  4. Embeds CSS and JavaScript inline
  5. Wraps the complete HTML in APIM policy XML with proper CDATA escaping
- **Text TV Page**: The final static HTML output with all content pre-embedded, no runtime dynamic loading required

### Example Content Structure

Content files contain plain text formatted for display in the retro TXT TV interface. Example cyber security news content:

```
CRITICAL: CVE-2026-12345 - Remote Code Execution
═════════════════════════════════════════════════

TXT TV SECURITY ALERT - Page 100

BREAKING: Apache Struts Vulnerability Discovered
-------------------------------------------------
Security researchers discovered a critical remote
code execution vulnerability affecting Apache 
Struts 2.5.x through 2.6.4.

IMPACT: Allows unauthenticated attackers to
execute arbitrary code on vulnerable servers.

AFFECTED SYSTEMS:
* Apache Struts 2.5.0 - 2.6.4
* Est. 500,000+ servers worldwide
* Healthcare, finance sectors most exposed

RECOMMENDED ACTIONS:
1. Update to Struts 2.6.5+ immediately
2. Review logs for suspicious activity
3. Implement WAF rules (see page 105)

More details: Page 101 (Technical Analysis)
Workarounds: Page 102 (Temp Mitigation)
Past Incidents: Page 103 (2017 Equifax)

─────────────────────────────────────────────────
Severity: CRITICAL (CVSS 9.8)
Published: 2026-02-09 08:45 UTC
```

This content gets embedded into the `{CONTENT}` placeholder during conversion, producing a complete static HTML page with no runtime data loading.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can open and view the text TV interface in their browser within 30 seconds of running the conversion script
- **SC-002**: Changes to content files are visible in the browser within 10 seconds (re-run conversion + refresh browser)
- **SC-003**: The conversion script processes all content files and generates policy fragments in under 30 seconds
- **SC-004**: Visual comparison between local static HTML and deployed APIM version shows 100% parity (no runtime differences)
- **SC-005**: Generated policy fragments contain complete static HTML with zero dynamic content loading calls
- **SC-006**: Generated policy fragments deploy successfully to APIM without manual modifications in 100% of cases
- **SC-007**: Developers can navigate all text TV pages (100-110) viewing pre-embedded cyber security news content
- **SC-008**: Documentation enables a new developer to set up, run conversion, and view static pages within 15 minutes
- **SC-009**: All content is verified as static - browser DevTools Network tab shows zero fetch/XHR requests for content
