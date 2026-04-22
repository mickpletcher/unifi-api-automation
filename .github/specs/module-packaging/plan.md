# Implementation Plan

## Summary

Extract all shared functions from `UnifiOps.ps1` into `UnifiOps/UnifiOps.Functions.ps1`. Create `UnifiOps/UnifiOps.psm1` that dot-sources the functions file and exports the public surface. Create `UnifiOps/UnifiOps.psd1` as the module manifest. Update `UnifiOps.ps1` to dot-source the functions file instead of containing the functions inline. No logic is duplicated.

## Design Decisions

1. Shared functions live in `UnifiOps/UnifiOps.Functions.ps1`, not in the psm1 directly. Both the script and the module dot-source this file. This is the single source of truth for all function logic.
2. `Connect-Unifi` is updated to accept `-BaseUrl` and `-Credential` and return the fully connected context. The current signature takes a pre-built context object which is an internal concern. The new signature matches the module interface the spec requires and is cleaner for both usages.
3. `New-UnifiContext` stays internal and is called inside `Connect-Unifi`. It is not exported from the module.
4. Private functions (`New-UnifiContext`, `Invoke-UnifiRequest`, `Test-UnifiLoginPath`, `Get-UnifiApiUri`, `Assert-ExportParameter`) are available within the module session but not listed in `FunctionsToExport` in the manifest.
5. `UnifiOps.ps1` uses `$PSScriptRoot` to locate the functions file so it resolves correctly regardless of working directory.

## Implementation Order

1. Create `UnifiOps/` folder.
2. Extract all functions from `UnifiOps.ps1` into `UnifiOps/UnifiOps.Functions.ps1`. Update `Connect-Unifi` signature to accept `-BaseUrl` and `-Credential` and handle context creation internally.
3. Strip functions from `UnifiOps.ps1` and replace with a dot-source of the functions file. Update the script body to use the new `Connect-Unifi` signature.
4. Create `UnifiOps/UnifiOps.psm1` that dot-sources the functions file.
5. Create `UnifiOps/UnifiOps.psd1` manifest.
6. Run ScriptAnalyzer against `UnifiOps.ps1` and `UnifiOps/` and confirm zero findings.
7. Validate module import and function availability.
8. Validate script still runs correctly.

## File Changes

| File | Change |
| --- | --- |
| `UnifiOps/UnifiOps.Functions.ps1` | New file. All shared functions with updated `Connect-Unifi` signature. |
| `UnifiOps/UnifiOps.psm1` | New file. Dot-sources functions file. |
| `UnifiOps/UnifiOps.psd1` | New file. Module manifest. |
| `UnifiOps.ps1` | Remove inline functions. Add dot-source. Update `Connect-Unifi` call. |

## Validation

1. `Invoke-ScriptAnalyzer -Path .\UnifiOps.ps1` — must return zero findings.
2. `Invoke-ScriptAnalyzer -Path .\UnifiOps\` — must return zero findings.
3. `Import-Module .\UnifiOps\UnifiOps.psd1 -Force` — must complete without error.
4. `(Get-Module UnifiOps).ExportedFunctions.Keys | Sort-Object` — must list all eight public functions.
5. `Connect-Unifi -BaseUrl 'https://192.168.1.1' -Credential (Get-Credential)` — must return context object with `BaseUrl`, `LoginPath`, and `NetworkPrefix` populated.
6. `.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -Credential $cred -Action Test` — must return the same result as before this change.

## Rollout

1. Merge to main after all validation steps pass.
2. No environment changes required. Module is opt-in via `Import-Module`.

## Backout

1. Revert the commit that adds the module folder and updates `UnifiOps.ps1`.
2. Re-run ScriptAnalyzer and confirm clean.
