# Implementation Plan

## Summary

Update nine switch cases in UnifiOps.ps1 to return a consistent PSCustomObject with Success, Action, Data, and ItemCount. Query actions wrap the API response .data array. Login and Test move connection info into a nested Data object. BlockClient, UnblockClient, and Logout set Data and ItemCount to null. Export actions are untouched. README examples updated from .data (lowercase) to .Data.

## Design Decisions

1. Only UnifiOps.ps1 switch cases change. No changes to functions in UnifiOps.Functions.ps1. The wrapping happens at the script layer, not the function layer, so module callers who call Get-UnifiClient directly still get the raw response and can handle it themselves.
2. Export actions are not touched. Their shape is already consistent and includes action-specific fields (OutputPath, OutputFormat) that do not fit the standard shape cleanly.
3. Data is null for actions that produce no collection payload (BlockClient, UnblockClient, Logout). ItemCount is also null for these.
4. For Login and Test, connection metadata goes into a nested PSCustomObject in Data. ItemCount is null since there is no collection.

## Implementation Order

1. Update Login and Test switch cases.
2. Update GetSites, GetClients, GetDevices, GetWlans switch cases.
3. Update BlockClient and UnblockClient switch cases.
4. Update Logout switch case.
5. Update README.md pipeline examples from .data to .Data.
6. Run ScriptAnalyzer and confirm zero findings.
7. Validate return shapes.

## File Changes

| File | Change |
| --- | --- |
| `UnifiOps.ps1` | Update nine switch cases to return standard shape |
| `README.md` | Update pipeline examples that reference .data (lowercase) |

## Validation

1. `Invoke-ScriptAnalyzer -Path .\UnifiOps.ps1` — must return zero findings.
2. Verify GetClients return shape has Success, Action, Data, ItemCount at top level.
3. Verify Test return shape has Data.SitesFound accessible.
4. Verify BlockClient return shape has Data = null and ItemCount = null.
5. Verify all README pipeline examples use .Data (uppercase).

## Rollout

1. Merge to main after all validation steps pass.
2. Breaking change: any caller using .data (lowercase) on query results must update to .Data.

## Backout

1. Revert the commit that updates UnifiOps.ps1 and README.md.
2. Re-run ScriptAnalyzer and confirm clean.
