# Official API v2 Production Readiness

## Goal

Replace the unreliable legacy implementation with a secure, tested PowerShell 7 interface for the official local UniFi Network API.

## Requirements

1. Use API key authentication and official `/proxy/network/integration/v1` endpoints only.
2. Require HTTPS and validate certificates by default.
3. Accept official site and client UUID identifiers.
4. Follow all paginated list responses through `totalCount`.
5. Retry only safe GET requests after transient failures.
6. Enforce request timeouts and bounded retry counts.
7. Support official guest authorization and unauthorization actions with ShouldProcess.
8. Validate all local inputs before network requests.
9. Return exactly one consistent result object per successful operation.
10. Write stable, atomic JSON and CSV exports.
11. Pass PSScriptAnalyzer with zero findings.
12. Pass cross-platform Pester tests with at least 80 percent command coverage.
13. Document security, migration, development, and live validation procedures.

## Non-goals

1. No compatibility mode for private legacy endpoints.
2. No storage of API keys or controller configuration.
3. No automatic retry of write requests.
4. No live guest access mutation in CI.

## Acceptance

The implementation is complete when local and GitHub validation pass on Windows and Ubuntu. Live controller validation is a separate read-only operator gate because credentials remain local.
