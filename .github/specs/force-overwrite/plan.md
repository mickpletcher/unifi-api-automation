# Implementation Plan

## Summary

Add a -Force switch to UnifiOps.ps1 and Export-UnifiData. Move the file-exists check into Assert-ExportParameter so it runs before any API call. Default behavior becomes fail-fast when the output file already exists. Passing -Force bypasses the check and overwrites silently.

## Design Decisions

1. The file-exists check lives in Assert-ExportParameter, not in Export-UnifiData. Assert-ExportParameter already runs before the API call. Putting the check there preserves that guarantee and keeps all pre-flight validation in one place.
2. Export-UnifiData receives -Force and passes it to Export-Csv and Set-Content. This keeps the write functions honest — they only overwrite when told to.
3. Assert-ExportParameter receives -Force as a switch so it can conditionally run the file-exists check. The switch defaults to false, which is the fail-fast default.
4. UnifiOps.ps1 passes $Force through to both Assert-ExportParameter and Export-UnifiData at each export call site.

## Implementation Order

1. Add -Force switch to Assert-ExportParameter. Add file-exists check that throws when file exists and -Force is absent.
2. Add -Force switch to Export-UnifiData. Pass -Force to Export-Csv and Set-Content calls.
3. Add -Force switch parameter to UnifiOps.ps1. Update all four export call sites to pass -Force.
4. Update comment-based help in UnifiOps.ps1 to document the -Force parameter.
5. Run ScriptAnalyzer against UnifiOps.ps1 and UnifiOps/ and confirm zero findings.
6. Run manual validation tests.

## File Changes

| File | Change |
| --- | --- |
| `UnifiOps.ps1` | Add -Force switch parameter. Update four export call sites. Add -Force to help block. |
| `UnifiOps/UnifiOps.Functions.ps1` | Add -Force to Assert-ExportParameter and Export-UnifiData. |

## Validation

1. `Invoke-ScriptAnalyzer -Path .\UnifiOps.ps1` — must return zero findings.
2. `Invoke-ScriptAnalyzer -Path .\UnifiOps\ -Recurse` — must return zero findings.
3. Create a file at a target path, call Assert-ExportParameter without -Force, verify error contains the path.
4. Call Assert-ExportParameter with -Force against the same existing file, verify no error.
5. Call Assert-ExportParameter against a path that does not exist without -Force, verify no error.

## Rollout

1. Merge to main after all validation steps pass.
2. Operators using export actions must add -Force if they were relying on silent overwrite.

## Backout

1. Revert the commit that adds -Force to UnifiOps.ps1 and UnifiOps.Functions.ps1.
2. Re-run ScriptAnalyzer and confirm clean.
