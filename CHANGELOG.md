# Changelog

## 2.0.0 - 2026-08-11

### Changed

- Replaced legacy username and password sessions with official API key authentication.
- Replaced private `/api` routes with `/proxy/network/integration/v1` endpoints.
- Replaced site names and client MAC action targets with official UUID identifiers.
- Replaced block and unblock actions with supported guest authorization actions.
- Standardized every operation on one result object.
- Made certificate validation secure by default.
- Added bounded timeouts, safe retries, rate-limit handling, pagination, and API filters.
- Made JSON and CSV exports atomic and stable for empty and one-item results.

### Fixed

- Removed the clean-session `WebRequestSession` type-loading failure.
- Removed strict-mode cleanup errors that masked connection failures.
- Preserved authentication and request exceptions.
- Moved all local validation before network requests.

### Added

- Cross-platform Pester test suite.
- PSScriptAnalyzer enforcement.
- Windows and Ubuntu CI.
- Read-only live integration test option.
- Security, contribution, and migration documentation.
