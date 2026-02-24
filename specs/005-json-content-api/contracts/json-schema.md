# JSON Content Schema

**Feature**: 005-json-content-api
**Date**: February 24, 2026

## Schema Definition

### Full Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "TXT TV Page Content",
  "description": "Structured content for a single TXT TV page",
  "type": "object",
  "required": ["pageNumber", "title", "category", "content", "navigation"],
  "properties": {
    "pageNumber": {
      "type": "integer",
      "minimum": 100,
      "maximum": 999,
      "description": "3-digit page identifier. Must match filename number."
    },
    "title": {
      "type": "string",
      "minLength": 1,
      "maxLength": 80,
      "description": "Page headline. Max 80 chars to fit TXT TV display width."
    },
    "category": {
      "type": "string",
      "enum": ["SECURITY ALERT", "ADVISORY", "NEWS", "VULNERABILITY", "INCIDENT", "GUIDE", "INDEX"],
      "description": "Content category displayed in the header bar."
    },
    "severity": {
      "type": ["string", "null"],
      "enum": ["CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO", null],
      "description": "Severity level. Null for non-security content."
    },
    "content": {
      "type": "string",
      "minLength": 1,
      "maxLength": 2000,
      "description": "Main body text. Newlines as \\n. Supports Unicode box-drawing characters."
    },
    "metadata": {
      "type": "object",
      "properties": {
        "cvss": {
          "type": ["number", "null"],
          "minimum": 0.0,
          "maximum": 10.0,
          "description": "CVSS score. Null for non-vulnerability content."
        },
        "published": {
          "type": ["string", "null"],
          "format": "date-time",
          "description": "Publication timestamp in ISO 8601 format."
        }
      },
      "additionalProperties": false
    },
    "navigation": {
      "type": "object",
      "required": ["prev", "next", "related"],
      "properties": {
        "prev": {
          "type": ["integer", "null"],
          "minimum": 100,
          "maximum": 999,
          "description": "Previous page number. Null if first page."
        },
        "next": {
          "type": ["integer", "null"],
          "minimum": 100,
          "maximum": 999,
          "description": "Next page number. Null if last page."
        },
        "related": {
          "type": "array",
          "items": {
            "type": "integer",
            "minimum": 100,
            "maximum": 999
          },
          "maxItems": 10,
          "description": "Related page numbers. Can be empty array."
        }
      },
      "additionalProperties": false
    }
  },
  "additionalProperties": false
}
```

---

## Example: Complete Content File

File: `content/pages/page-100.json`

```json
{
  "pageNumber": 100,
  "title": "CVE-2026-12345 - Remote Code Execution",
  "category": "SECURITY ALERT",
  "severity": "CRITICAL",
  "content": "BREAKING: Apache Struts Vulnerability Discovered\n═════════════════════════════════════════════════\nSecurity researchers discovered a critical remote\ncode execution vulnerability affecting Apache\nStruts 2.5.x through 2.6.4.\n\nIMPACT: Allows unauthenticated attackers to\nexecute arbitrary code on vulnerable servers.\n\nAFFECTED SYSTEMS:\n* Apache Struts 2.5.0 - 2.6.4\n* Est. 500,000+ servers worldwide\n* Healthcare, finance sectors most exposed\n\nRECOMMENDED ACTIONS:\n→ Update to Struts 2.6.5+ immediately\n→ Review logs for suspicious activity\n→ Implement WAF rules (see page 105)",
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

---

## Example: Minimal Content File (Non-Security)

File: `content/pages/page-109.json`

```json
{
  "pageNumber": 109,
  "title": "TXT TV Help & Navigation Guide",
  "category": "GUIDE",
  "severity": null,
  "content": "WELCOME TO TXT TV\n══════════════════\n\nNAVIGATION:\n→ Use arrow keys or page number input\n→ Press H for help\n→ Press I for index (page 100)\n\nPAGE RANGES:\n  100-104  Security Alerts\n  105-107  Advisories\n  108      News\n  109      Help\n  110      About",
  "metadata": {
    "published": "2026-01-15T12:00:00Z"
  },
  "navigation": {
    "prev": 108,
    "next": 110,
    "related": [100, 110]
  }
}
```

---

## Validation Rules Summary

| Rule | Field(s) | Check |
|------|----------|-------|
| Required fields present | `pageNumber`, `title`, `category`, `content`, `navigation` | Existence check |
| Page number range | `pageNumber` | 100 ≤ N ≤ 999 |
| Filename consistency | `pageNumber` | Must match `page-{N}.json` filename |
| Title length | `title` | 1-80 characters |
| Category enum | `category` | Must be one of defined values |
| Severity enum | `severity` | Must be one of defined values or null |
| Content length | `content` | 1-2000 characters |
| CVSS range | `metadata.cvss` | 0.0-10.0 or null |
| Published format | `metadata.published` | ISO 8601 or null |
| Navigation page refs | `navigation.prev`, `navigation.next`, `navigation.related[]` | 100-999 or null |
| Related items limit | `navigation.related` | Max 10 items |
| No extra fields | all objects | `additionalProperties: false` |

---

## Generated Content Fragment Format

Given a content file `page-100.json`, the conversion script produces:

```xml
<fragment>
    <return-response>
        <set-status code="200" reason="OK" />
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>
        <set-header name="Cache-Control" exists-action="override">
            <value>public, max-age=3600</value>
        </set-header>
        <set-body><![CDATA[{
  "pageNumber": 100,
  "title": "CVE-2026-12345 - Remote Code Execution",
  ...exact JSON from source file...
}]]></set-body>
    </return-response>
</fragment>
```

**Key constraint**: The JSON inside `<![CDATA[...]]>` must be **byte-identical** to the source `.json` file content (FR-003). The conversion script reads the file and inserts it verbatim.
