# Data Model: TXT TV Application

**Feature**: 001-txt-tv-app  
**Date**: 2026-01-31  
**Phase**: 1 - Design

## Overview

This document defines the data entities and their relationships for the TXT TV application. Since the primary implementation is APIM policy-based rendering, the data model is intentionally simple with minimal state management.

## Entities

### 1. Page

Represents a single TXT TV page with news content.

**Attributes**:
- `pageNumber` (integer, required): Unique identifier for the page (range: 100-999)
- `content` (string, required): The news article text content displayed on the page
- `title` (string, optional): Page title/headline (extracted from first line of content)
- `lastModified` (datetime, derived): Timestamp when content file was last updated

**Constraints**:
- `pageNumber` must be between 100 and 999 (traditional teletext range)
- `content` must not exceed 2000 characters (readability limit)
- `content` must be plain text (no HTML or rich formatting in source files)

**Storage**:
- **Source**: Text files in `content/pages/page-{pageNumber}.txt`
- **Runtime**: APIM policy fragments in XML format
- **Transformation**: PowerShell script converts text files to policy fragment XML during build

**Example** (Source text file `content/pages/page-100.txt`):
```
BREAKING NEWS - Technology Update

Microsoft announces new Azure features including
enhanced API Management policy capabilities
and improved Web Application Firewall rules.

The updates focus on developer productivity
and security automation.

More details on page 101.
```

**Example** (Generated policy fragment):
```xml
<fragment fragment-id="page-100">
    <set-body><![CDATA[
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>TXT TV - Page 100</title>
            <style>
                /* Inline CSS for teletext styling */
            </style>
        </head>
        <body>
            <div id="content">
                <h1>Page 100</h1>
                <pre>BREAKING NEWS - Technology Update

Microsoft announces new Azure features including
enhanced API Management policy capabilities
and improved Web Application Firewall rules.

The updates focus on developer productivity
and security automation.

More details on page 101.</pre>
                <nav>
                    <button hx-get="/page/99" hx-target="#content" hx-push-url="true">← Previous</button>
                    <input type="number" id="pageNum" value="100" min="100" max="999" />
                    <button hx-get="#" 
                            hx-include="[id='pageNum']" 
                            hx-target="#content" 
                            hx-push-url="true">Go to Page</button>
                    <button hx-get="/page/101" hx-target="#content" hx-push-url="true">Next →</button>
                </nav>
            </div>
            <script src="https://unpkg.com/htmx.org@1.9.10"></script>
        </body>
        </html>
    ]]></set-body>
</fragment>
```

### 2. Navigation State

Represents the current navigation context for a user session.

**Attributes**:
- `currentPage` (integer, required): The page number currently being viewed
- `previousPage` (integer, optional): The previous page visited (for back navigation)
- `nextPage` (integer, optional): Suggested next page (default: currentPage + 1)

**Constraints**:
- `currentPage` must be a valid page number (exists in policy fragments)
- `previousPage` and `nextPage` calculated at runtime, not persisted
- No server-side session state (navigation is stateless via URL parameters)

**Implementation**:
- Client-side only (browser URL and history API)
- HTMX manages navigation via `hx-push-url` attribute
- APIM extracts `pageNumber` from route: `/page/{pageNumber}`

**State Transitions**:
```
Initial Load → Page 100 (default)
User enters page 105 → Navigation to /page/105
User clicks Next → Navigation to /page/106
User clicks Previous → Navigation to /page/105
Invalid page (e.g., 999) → Error page with link to page 100
```

### 3. Navigation Template

Reusable navigation component structure.

**Attributes**:
- `previousPageNumber` (integer): Calculated as currentPage - 1
- `nextPageNumber` (integer): Calculated as currentPage + 1
- `enablePrevious` (boolean): False if currentPage = 100 (first page)
- `enableNext` (boolean): False if currentPage = last available page

**Implementation**:
Policy fragment that generates navigation HTML based on current page context.

**Example** (Navigation fragment template):
```xml
<fragment fragment-id="navigation-template">
    <set-variable name="currentPage" value="@(int.Parse(context.Request.MatchedParameters["pageNumber"]))" />
    <set-variable name="previousPage" value="@((int)context.Variables["currentPage"] - 1)" />
    <set-variable name="nextPage" value="@((int)context.Variables["currentPage"] + 1)" />
    
    <set-body><![CDATA[
        <nav>
            <button hx-get="/page/@{context.Variables["previousPage"]}" 
                    hx-target="#content" 
                    hx-push-url="true"
                    @{if ((int)context.Variables["currentPage"] <= 100) { "disabled"; }}>
                ← Previous
            </button>
            <input type="number" id="pageNum" 
                   value="@{context.Variables["currentPage"]}" 
                   min="100" max="999" />
            <button hx-get="/page/[pageNum]" 
                    hx-target="#content" 
                    hx-push-url="true">
                Go to Page
            </button>
            <button hx-get="/page/@{context.Variables["nextPage"]}" 
                    hx-target="#content" 
                    hx-push-url="true">
                Next →
            </button>
        </nav>
    ]]></set-body>
</fragment>
```

### 4. Error Page

Fallback page displayed when requested page doesn't exist.

**Attributes**:
- `requestedPage` (integer): The page number that was requested but not found
- `errorMessage` (string): "Page {requestedPage} not found"
- `defaultRedirect` (integer): Always 100 (redirect to home page)

**Implementation**:
Policy fragment that handles 404 scenarios.

**Example**:
```xml
<fragment fragment-id="error-page">
    <set-variable name="requestedPage" value="@(context.Request.MatchedParameters["pageNumber"])" />
    <set-body><![CDATA[
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <title>TXT TV - Page Not Found</title>
            <style>/* Teletext CSS */</style>
        </head>
        <body>
            <div id="content">
                <h1>Page Not Found</h1>
                <pre>Page @{context.Variables["requestedPage"]} does not exist.

Available pages: 100-120

Click below to return to the home page.</pre>
                <nav>
                    <button hx-get="/page/100" hx-target="#content" hx-push-url="true">
                        Go to Page 100
                    </button>
                </nav>
            </div>
            <script src="https://unpkg.com/htmx.org@1.9.10"></script>
        </body>
        </html>
    ]]></set-body>
</fragment>
```

## Entity Relationships

```
┌─────────────┐
│    Page     │
│             │
│ pageNumber  │──────┐
│ content     │      │
│ title       │      │ 1:1
│ lastModified│      │ (current page)
└─────────────┘      │
                     │
                     ▼
            ┌────────────────┐
            │ Navigation     │
            │ State          │
            │                │
            │ currentPage    │
            │ previousPage   │
            │ nextPage       │
            └────────────────┘
                     │
                     │ uses
                     ▼
            ┌────────────────┐
            │ Navigation     │
            │ Template       │
            │                │
            │ HTML structure │
            └────────────────┘

If page not found:
            ┌────────────────┐
            │ Error Page     │
            │                │
            │ requestedPage  │
            │ errorMessage   │
            └────────────────┘
```

## Data Flow

### 1. Page View Request Flow

```
1. User navigates to /page/100
2. Application Gateway WAF validates request
3. Request forwarded to APIM
4. APIM policy extracts pageNumber from route
5. APIM policy chooses appropriate fragment:
   - If pageNumber in [100-120]: Load page-{pageNumber} fragment
   - Else: Load error-page fragment
6. APIM policy sets Content-Type: text/html
7. APIM policy returns response with status 200
8. Browser renders HTML with HTMX navigation
```

### 2. Content Update Flow

```
1. Content editor modifies content/pages/page-100.txt
2. Git commit triggers CI/CD pipeline
3. Pipeline runs convert-txt-to-fragment.ps1 script
4. Script generates infrastructure/modules/apim/fragments/page-100.xml
5. Bicep deployment updates APIM policy fragments
6. Next request to /page/100 returns updated content
```

### 3. Backend Test Flow

```
1. User navigates to /backend-test
2. Application Gateway WAF validates request
3. Request forwarded to APIM
4. APIM policy forwards request to F# Azure Function
5. Function returns "you found through the maze"
6. APIM policy logs the request/response
7. Response returned to user
```

## Validation Rules

### Page Number Validation
- Must be numeric integer
- Must be in range 100-999
- Implemented in APIM policy using `<choose>` conditions

### Content Validation
- Text files must be UTF-8 encoded
- Maximum 2000 characters (enforced in conversion script)
- No HTML tags in source content (enforced in conversion script)
- Special characters escaped in policy fragment generation

### Navigation Validation
- Previous button disabled on page 100
- Next button disabled if page exceeds available range
- Direct page input validated (100-999 range)

## No Persistent State

**Important Design Decision**: The TXT TV application is intentionally stateless.

- No user accounts or authentication (except backend test endpoint)
- No session storage or cookies
- No database for page content (policy fragments are the "database")
- No server-side navigation history
- All state managed client-side via URL and browser history

**Rationale**:
- Simplifies infrastructure (no database needed)
- Improves scalability (no session state to manage)
- Aligns with demo/proof-of-concept scope
- Focuses on APIM policy capabilities, not data persistence

## Performance Considerations

- Policy fragments cached by APIM (reduces policy evaluation time)
- Static assets (HTMX, CSS) cached by browser
- No database queries (content embedded in policy fragments)
- Minimal backend calls (only for connectivity test)
- Expected response time: <100ms for page rendering

## Security Considerations

- Page numbers validated to prevent injection attacks
- HTML content in CDATA sections to avoid XSS
- WAF protects against malicious page number inputs
- No user-generated content (only admin-created text files)
- APIM rate limiting prevents abuse (100 req/min per IP)
