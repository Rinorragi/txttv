# Data Model: WAF Logging to Log Analytics

**Feature**: 003-waf-logging  
**Phase**: 1 (Design & Contracts)  
**Date**: February 7, 2026

## Overview

This feature does not introduce new application data models or entities. The data model consists of Azure resource configuration (diagnostic settings) and the schema of logs emitted by Azure Application Gateway WAF.

## Azure Resource Model

### Diagnostic Setting

**Resource Type**: `Microsoft.Insights/diagnosticSettings`

**Purpose**: Routes Application Gateway diagnostic logs to Log Analytics workspace

**Properties**:
- `name`: Identifier for the diagnostic setting (e.g., "txttv-dev-appgw-diagnostics")
- `scope`: Reference to parent Application Gateway resource
- `workspaceId`: Log Analytics workspace resource ID (destination for logs)
- `logs`: Array of log category configurations

**Lifecycle**: Created during Application Gateway deployment, updated when log categories change, deleted when Application Gateway is deleted

**Relationships**:
- **Parent**: Application Gateway (1:1 relationship - one diagnostic setting per gateway)
- **Target**: Log Analytics Workspace (N:1 relationship - multiple resources can send logs to same workspace)

---

## Log Entry Schema

### ApplicationGatewayFirewallLog

**Source**: Azure Application Gateway WAF engine

**Purpose**: Records all WAF rule evaluations, matches, and actions taken

**Schema** (fields captured in Log Analytics):

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `TimeGenerated` | datetime | UTC timestamp when event occurred | 2026-02-07T14:23:15.123Z |
| `ResourceId` | string | Full Azure resource ID of Application Gateway | /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/applicationGateways/txttv-dev-appgw |
| `Category` | string | Log category name (always "ApplicationGatewayFirewallLog") | ApplicationGatewayFirewallLog |
| `clientIp_s` | string | Source IP address of request | 203.0.113.42 |
| `clientPort` | int | Source port of request | 54321 |
| `requestUri_s` | string | Requested URI path and query string | /page?id=100' OR '1'='1 |
| `ruleSetType_s` | string | Rule set type (OWASP, custom) | OWASP |
| `ruleSetVersion_s` | string | Rule set version | 3.2 |
| `ruleId_s` | string | Specific rule identifier that matched | 942100 |
| `message_s` | string | Human-readable rule description | SQL Injection Attack Detected via libinjection |
| `action_s` | string | Action taken by WAF | Blocked, Allowed, Matched |
| `severity_s` | string | Rule severity level | Critical, High, Medium, Low |
| `hostname_s` | string | Host header from request | txttv-dev-appgw.westeurope.cloudapp.azure.com |
| `transactionId_g` | string | Unique identifier for the request | 0beec7b5-ea3f-4c3b-9d0f-5c3b1d5f6a |
| `details_message_s` | string | Detailed match information | Matched Data: OR 1=1 found within ARGS:id |
| `details_data_s` | string | Actual data that triggered rule | OR '1'='1 |
| `details_file_s` | string | File involved (for file upload attacks) | upload.exe |
| `details_line_s` | string | Line number in payload | 1 |

**Relationships**:
- **Application Gateway**: Each log entry originates from one Application Gateway (N:1)
- **WAF Rule**: Each log entry references one WAF rule by ruleId (N:1)

---

## Configuration Model

### Bicep Parameter Flow

```
Environment main.bicep
  └─> logAnalytics.id (workspace resource ID)
       └─> Passed to app-gateway module
            └─> Used in diagnostic settings resource
```

**Parameter**: `logAnalyticsWorkspaceId`
- **Type**: `string`
- **Default**: `''` (empty string for backward compatibility)
- **Purpose**: Provides workspace resource ID to diagnostic settings
- **Validation**: None (Azure validates resource ID format at deployment)

---

## State Transitions

### Diagnostic Setting Lifecycle

```
[Not Configured]
    │
    ├─> Deploy infrastructure with logAnalyticsWorkspaceId parameter
    │
    v
[Configured - Logs Flowing]
    │
    ├─> Update log categories (redeploy with modified logs array)
    │
    v
[Configured - Updated Categories]
    │
    ├─> Remove workspace parameter or delete diagnostic setting resource
    │
    v
[Disabled - No Logs]
```

**State**: Not Configured
- **Condition**: Application Gateway deployed without diagnostic settings
- **Behavior**: No WAF logs sent to Log Analytics
- **Valid**: Acceptable for local dev/testing only

**State**: Configured - Logs Flowing
- **Condition**: Diagnostic settings resource exists with valid workspace ID
- **Behavior**: All WAF events logged to Log Analytics within 5 minutes
- **Valid**: Required for all deployed environments (dev/staging/prod)

**State**: Disabled - No Logs
- **Condition**: Diagnostic settings deleted or workspace ID invalid
- **Behavior**: WAF continues functioning, but no observability
- **Valid**: Should never occur in production

---

## Data Retention

**Log Analytics Workspace Retention**: 30 days (configured at workspace level)

**Diagnostic Setting Retention**: Disabled (0 days) - retention managed by workspace

**Rationale**: Log Analytics workspace provides centralized retention policy management. Diagnostic setting retention is legacy feature and should be disabled to avoid confusion.

---

## Validation Rules

### Infrastructure Level

1. **Diagnostic setting name must be unique** within Application Gateway scope
2. **Workspace ID must reference existing workspace** in same subscription
3. **Log category must be valid** for Application Gateway resource type
4. **Workspace and Application Gateway must be in same region** (Azure requirement)

### Application Level

No application-level validation required - Azure enforces all constraints.

---

## Example Data Flow

```
1. HTTP Request arrives at Application Gateway
   ├─> Source: 203.0.113.42:54321
   └─> URI: /page?id=100' OR '1'='1

2. WAF Engine evaluates request against rules
   ├─> Rule Set: OWASP 3.2
   ├─> Rule Matched: 942100 (SQL Injection via libinjection)
   └─> Action: Blocked

3. WAF Event logged
   ├─> Format: JSON structure
   └─> Destination: Application Gateway internal buffer

4. Diagnostic Settings forwards log
   ├─> From: Application Gateway
   ├─> To: Log Analytics workspace
   └─> Latency: <5 minutes

5. Log entry queryable in Log Analytics
   ├─> Table: AzureDiagnostics
   ├─> Category: ApplicationGatewayFirewallLog
   └─> Query: KQL against TimeGenerated, action_s, ruleId_s, etc.
```

---

## No Entities Created

This feature does not create any of the following:
- Application data models (no user data, configuration data, or business entities)
- Database tables or collections
- File system structures
- In-memory caches or state

All data is Azure platform telemetry generated by Application Gateway and stored in Azure Log Analytics.
