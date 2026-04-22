# Implementation Plan

## Summary

Add comment-based help to UnifiOps.ps1 and to the eight public functions in UnifiOps.Functions.ps1. No logic changes. Help blocks are inserted above the param block in the script and above each function definition in the functions file.

## Design Decisions

1. Comment-based help in UnifiOps.ps1 goes above the param block. PowerShell requires this placement for script-level help to be discoverable via Get-Help.
2. Each action gets its own .EXAMPLE block in the script help. This gives operators `Get-Help .\UnifiOps.ps1 -Examples` as a full action reference.
3. Public functions get .SYNOPSIS and .EXAMPLE only. Full .DESCRIPTION and .PARAMETER blocks are not required since the function signatures are simple and the script-level help covers the broader context.
4. Private functions (New-UnifiContext, Invoke-UnifiRequest, Test-UnifiLoginPath, Get-UnifiApiUri, Assert-ExportParameter) get no help. They are not part of the public surface.

## Implementation Order

1. Add comment-based help block to UnifiOps.ps1 above the param block.
2. Add comment-based help to each of the eight public functions in UnifiOps.Functions.ps1.
3. Run ScriptAnalyzer against UnifiOps.ps1 and UnifiOps/ and confirm zero findings.
4. Validate Get-Help output for the script and for at least two module functions.

## File Changes

| File | Change |
| --- | --- |
| `UnifiOps.ps1` | Add comment-based help block above param block |
| `UnifiOps/UnifiOps.Functions.ps1` | Add .SYNOPSIS and .EXAMPLE to eight public functions |

## Validation

1. `Invoke-ScriptAnalyzer -Path .\UnifiOps.ps1` — must return zero findings.
2. `Invoke-ScriptAnalyzer -Path .\UnifiOps\ -Recurse` — must return zero findings.
3. `(Get-Help .\UnifiOps.ps1 -Examples).examples.example.Count` — must equal 13.
4. `Get-Help .\UnifiOps.ps1 -Parameter Action` — must return a description listing all valid action values.
5. `Import-Module .\UnifiOps\UnifiOps.psd1 -Force; (Get-Help Connect-Unifi).Synopsis` — must return a non-empty string.
6. `Import-Module .\UnifiOps\UnifiOps.psd1 -Force; (Get-Help Export-UnifiData).examples` — must return at least one example.

## Rollout

1. Merge to main after all validation steps pass.
2. No environment changes required.

## Backout

1. Revert the commit that adds help blocks to UnifiOps.ps1 and UnifiOps.Functions.ps1.
2. Re-run ScriptAnalyzer and confirm clean.
