# Feature Specification: WAF Logging to Log Analytics

**Feature Branch**: `003-waf-logging`  
**Created**: February 7, 2026  
**Status**: Draft  
**Input**: User description: "ensure that waf logs to our own log analytics workspace"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Security Team Monitors WAF Activity (Priority: P1)

Security administrators need to view all WAF-blocked requests in real-time to identify potential security threats and attack patterns targeting the TXT TV application.

**Why this priority**: Without visibility into WAF activity, the security team cannot detect ongoing attacks, tune WAF rules, or investigate security incidents. This is the core value of WAF logging.

**Independent Test**: Deploy infrastructure with diagnostic settings enabled, generate test traffic (including malicious requests), and verify that WAF logs appear in Log Analytics workspace within 5 minutes. Success means being able to query and view blocked requests.

**Acceptance Scenarios**:

1. **Given** the Application Gateway is deployed with WAF enabled, **When** a malicious request (SQL injection, XSS, etc.) is blocked by WAF, **Then** the blocked request details are logged to Log Analytics within 5 minutes
2. **Given** WAF logs are flowing to Log Analytics, **When** security admin queries the workspace, **Then** they can see request details including source IP, URI, matched rule, and action taken
3. **Given** normal legitimate traffic is flowing, **When** WAF allows requests through, **Then** both allowed and blocked requests are logged for complete audit trail

---

### User Story 2 - Operations Team Troubleshoots False Positives (Priority: P2)

Operations team needs to investigate when legitimate user requests are incorrectly blocked by WAF rules, so they can adjust rule sensitivity and restore user access.

**Why this priority**: False positives impact user experience and require quick resolution. Complete logging enables root cause analysis and rule tuning decisions.

**Independent Test**: Generate a legitimate request that triggers a WAF rule, locate the log entry in Log Analytics, and use the logged details to understand why it was blocked. Success means having sufficient detail to make informed rule adjustment decisions.

**Acceptance Scenarios**:

1. **Given** a user reports blocked access, **When** operations team searches logs by timestamp and source IP, **Then** they can find the exact WAF rule that blocked the request
2. **Given** log details show the matched pattern, **When** team analyzes the request body/headers, **Then** they can determine if it's a false positive or legitimate block
3. **Given** historical logs are available, **When** team queries for similar patterns, **Then** they can identify trends and recurring false positive patterns

---

### User Story 3 - Compliance Auditor Reviews Security Posture (Priority: P3)

Compliance auditors need to verify that all web application firewall activity is logged and retained according to security policies (30 days minimum) for audit and compliance purposes.

**Why this priority**: Regulatory compliance requires demonstrable logging and retention. While important, this is lower priority than operational use of logs since it's a verification activity.

**Independent Test**: Deploy infrastructure, generate various types of traffic over several days, then verify log retention settings and query historical logs. Success means demonstrating 30-day retention and complete audit trail.

**Acceptance Scenarios**:

1. **Given** WAF has been running for multiple days, **When** auditor queries logs from 7 days ago, **Then** all logs from that period are still available and queryable
2. **Given** Log Analytics workspace is configured, **When** auditor checks retention settings, **Then** workspace shows 30-day retention policy is active
3. **Given** different types of WAF events occurred (blocks, rate limits, etc.), **When** auditor queries by event type, **Then** all event categories are captured and distinguishable

---

### Edge Cases

- What happens when Log Analytics workspace is unavailable or deleted? (WAF should continue functioning but logs will be lost)
- How does system handle high-volume attack scenarios that generate thousands of logs per minute? (Azure handles throttling, but we should verify no log loss)
- What if diagnostic settings are accidentally disabled? (No logs flow; monitoring alerts should detect this)
- How are logs handled during Application Gateway restart or update? (Brief gap acceptable, but should resume automatically)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Application Gateway MUST send all WAF diagnostic logs to the designated Log Analytics workspace
- **FR-002**: Diagnostic settings MUST capture ApplicationGatewayFirewallLog category at minimum
- **FR-003**: Log Analytics workspace MUST retain WAF logs for at least 30 days
- **FR-004**: Logs MUST include request details: timestamp, source IP, URI, HTTP method, matched rule ID, action taken (block/allow), and rule severity
- **FR-005**: Diagnostic settings MUST be configured automatically as part of infrastructure deployment (no manual steps)
- **FR-006**: Each environment (dev, staging, prod) MUST log to its own dedicated Log Analytics workspace
- **FR-007**: Log Analytics workspace MUST be created before Application Gateway to ensure workspace ID is available during gateway deployment
- **FR-008**: Logs MUST be queryable within 5 minutes of the WAF event occurring (near real-time)

### Key Entities

- **WAF Diagnostic Log**: Represents a single WAF event (block or allow decision) containing request metadata, matched rule information, timestamp, source details, and action taken
- **Log Analytics Workspace**: Central repository for all WAF logs from an environment, configured with 30-day retention and linked to Application Insights
- **Diagnostic Setting**: Configuration that routes Application Gateway WAF logs to the target Log Analytics workspace

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of WAF-blocked requests are logged to Log Analytics workspace
- **SC-002**: WAF logs appear in Log Analytics within 5 minutes of the security event
- **SC-003**: Security team can query and retrieve WAF logs from the past 30 days
- **SC-004**: Operations team can identify the specific WAF rule that blocked a request within 2 minutes of searching logs
- **SC-005**: Infrastructure deployment completes successfully with diagnostic settings configured (no manual intervention required)

## Scope & Boundaries

### In Scope

- Configuring Application Gateway diagnostic settings to send WAF logs to Log Analytics
- Ensuring Log Analytics workspace exists with appropriate retention (30 days)
- Automating diagnostic settings configuration as part of infrastructure deployment
- Logging both blocked and allowed requests for complete audit trail

### Out of Scope

- Custom log analysis dashboards or visualizations (can be added later)
- Real-time alerting on specific attack patterns (future enhancement)
- Log forwarding to external SIEM systems (not required for MVP)
- Custom log retention policies beyond 30 days (30 days is sufficient for initial implementation)
- Historical log migration (only logs after implementation will be captured)

## Assumptions

- Log Analytics workspace already exists in each environment (created in feature 001-txt-tv-app)
- Application Gateway is the only source of WAF logs (no other WAF solutions in use)
- Standard Azure diagnostic settings are sufficient (no custom log formats needed)
- 30-day retention meets compliance requirements (no longer retention needed initially)
- Log Analytics workspace has sufficient capacity for expected log volume
- Network connectivity between Application Gateway and Log Analytics is reliable

## Dependencies

- Log Analytics workspace must exist before Application Gateway deployment (created in environment main.bicep)
- Application Gateway must be deployed with WAF enabled (WAF SKU tier)
- Azure RBAC permissions to configure diagnostic settings on Application Gateway
- Bicep deployment scripts must support passing workspace resource ID to Application Gateway module
