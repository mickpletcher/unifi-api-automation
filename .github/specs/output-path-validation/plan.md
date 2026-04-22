# Implementation Plan

## Summary

Extend `Assert-ExportParameter` in `UnifiOps.ps1` to run four validation checks in order before any file write or API call occurs. All call sites already use this function so no switch cases need changes. The function signature stays the same.

## Design Decisions

1. Extend `Assert-ExportParameter` rather than creating a new function. The function is already called by every export action. Adding validation there means zero call site changes.
2. Combine `GetInvalidPathChars()` and `GetInvalidFileNameChars()` for invalid character detection, then subtract `\`, `/`, and `:` which are valid in paths. `GetInvalidPathChars()` alone only returns control characters and pipe on Windows, missing common invalid chars like `<`, `>`, `*`, `?`, and `"`. The combined set covers the full Windows-invalid character list while staying portable.
3. Run drive existence check before directory check. Checking `Test-Path` against a path on a missing drive would throw a cryptic error rather than our own message.
4. Skip drive check for relative paths. `Split-Path -Qualifier` returns empty for relative paths. There is no drive to validate in that case.
5. Extension mismatch is `Write-Warning`, not `throw`. User confirmed this must not terminate.

## Implementation Order

1. Add invalid character check to `Assert-ExportParameter`.
2. Add drive existence check to `Assert-ExportParameter`.
3. Add directory target check to `Assert-ExportParameter`.
4. Add extension mismatch warning to `Assert-ExportParameter`.
5. Run ScriptAnalyzer and confirm zero findings.

## File Changes

| File | Change |
| --- | --- |
| `UnifiOps.ps1` | Extend `Assert-ExportParameter` with four validation checks |
| `.github/specs/output-path-validation/tasks.md` | Track implementation status |

## Validation

1. `Invoke-ScriptAnalyzer -Path .\UnifiOps.ps1` — must return zero findings.
2. `Assert-ExportParameter -Action ExportClients -OutputPath 'C:\>bad\file.json' -OutputFormat Json` — must throw with message containing the path and the invalid character.
3. `Assert-ExportParameter -Action ExportClients -OutputPath 'C:\Temp' -OutputFormat Json` — must throw stating path must target a file, not a directory (only if C:\Temp exists).
4. `Assert-ExportParameter -Action ExportClients -OutputPath 'Q:\export.json' -OutputFormat Json` — must throw stating drive Q: is not available (assumes Q: does not exist).
5. `Assert-ExportParameter -Action ExportClients -OutputPath '.\clients.csv' -OutputFormat Json` — must emit a warning and not throw.
6. `Assert-ExportParameter -Action ExportClients -OutputPath '.\clients.json' -OutputFormat Json` — must produce no output.

## Rollout

1. Merge to main after ScriptAnalyzer passes and manual validation steps confirm expected output.
2. No config or environment changes required.

## Backout

1. Revert the commit that modified `Assert-ExportParameter`.
2. Re-run ScriptAnalyzer and confirm clean.
