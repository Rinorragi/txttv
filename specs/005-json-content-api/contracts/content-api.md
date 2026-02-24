# Content API Contract

**Feature**: 005-json-content-api
**Date**: February 24, 2026

## Operation: GET /content/{pageNumber}

### Overview

Returns structured JSON content for a specific TXT TV page. This is the Content API endpoint consumed by the Page API's client-side renderer.

### Request

```
GET /content/{pageNumber}
Host: {apim-gateway-url}
Accept: application/json
```

#### Parameters

| Name | In | Type | Required | Constraints | Description |
|------|-----|------|----------|-------------|-------------|
| `pageNumber` | path (template) | integer | Yes | 100-999, 3 digits | The TXT TV page number to retrieve |

### Responses

#### 200 OK — Content Found

```
HTTP/1.1 200 OK
Content-Type: application/json
Cache-Control: public, max-age=3600
```

**Body**: JSON content matching the JSON Content Schema (see [json-schema.md](json-schema.md))

```json
{
  "pageNumber": 100,
  "title": "CVE-2026-12345 - Remote Code Execution",
  "category": "SECURITY ALERT",
  "severity": "CRITICAL",
  "content": "BREAKING: Apache Struts Vulnerability Discovered\n...",
  "metadata": {
    "cvss": 9.8,
    "published": "2026-02-09T08:45:00Z"
  },
  "navigation": {
    "prev": null,
    "next": 101,
    "related": [101, 102, 103, 105]
  }
}
```

#### 400 Bad Request — Invalid Page Number

```
HTTP/1.1 400 Bad Request
Content-Type: application/json
```

```json
{
  "error": "Invalid page number",
  "message": "Page number must be a 3-digit integer between 100 and 999",
  "pageNumber": null
}
```

Triggered when:
- `pageNumber` is not an integer
- `pageNumber` is less than 100 or greater than 999
- `pageNumber` is missing from the URL

#### 404 Not Found — Page Does Not Exist

```
HTTP/1.1 404 Not Found
Content-Type: application/json
```

```json
{
  "error": "Page not found",
  "message": "No content exists for page 999",
  "pageNumber": 999
}
```

Triggered when:
- `pageNumber` is valid but no content fragment exists for that page number
- Falls through the `<choose>`/`<when>` block to `<otherwise>`

---

## Operation: GET /page/{pageNumber} (Updated)

### Overview

Returns an HTML page shell that loads content dynamically from the Content API. This replaces the current monolithic page fragments with a single shared template.

### Request

```
GET /page/{pageNumber}
Host: {apim-gateway-url}
Accept: text/html
```

#### Parameters

| Name | In | Type | Required | Constraints | Description |
|------|-----|------|----------|-------------|-------------|
| `pageNumber` | path (template) | integer | Yes | 100-999, 3 digits | The TXT TV page number to display |

### Responses

#### 200 OK — Page Template

```
HTTP/1.1 200 OK
Content-Type: text/html
Cache-Control: public, max-age=86400
```

**Body**: HTML document containing:
- TXT TV CSS styles (inline)
- Navigation structure (prev/next links derived from page number)
- htmx library (CDN)
- Content renderer script (inline or linked)
- A `<pre id="page-content">` element that will be populated by the content renderer

The HTML template uses the `pageNumber` URL parameter to construct the Content API fetch URL: `GET /content/{pageNumber}`.

**Note**: The template is shared across all page numbers. The page number is injected into the template via APIM Liquid templating or JavaScript URL parsing, not via separate fragments.

#### 400 Bad Request — Invalid Page Number

Same as the Content API 400 response.

---

## APIM Implementation Mapping

| Contract Element | APIM Implementation |
|---|---|
| `GET /content/{pageNumber}` | Operation `get-content` → `content-routing-policy.xml` → `content-{N}.xml` fragment |
| `GET /page/{pageNumber}` | Operation `get-page` → `page-routing-policy.xml` (updated) → `page-template.xml` fragment |
| 400 response | Input validation in routing policy (regex check on pageNumber) |
| 404 response | `<otherwise>` clause in `<choose>` block |
| Cache-Control | `<set-header>` in fragment or routing policy |

---

## Local Dev Server Mapping

| API Endpoint | Local Server Mapping |
|---|---|
| `GET /content/{pageNumber}` | Read `content/pages/page-{pageNumber}.json` → serve with `application/json` |
| `GET /page/{pageNumber}` | Serve `src/web/page.html` (same file for all page numbers) |
| Static assets | Serve from `src/web/` directory tree |
