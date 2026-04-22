# Action Help Text

## Title

Add PowerShell comment-based help to UnifiOps.ps1 and all public module functions.

## Problem Statement

Running `Get-Help .\UnifiOps.ps1` returns nothing useful. Module functions have no help either. Operators have no in-shell reference for parameters, actions, or usage examples without reading the README.

## Goals

1. Add comment-based help to UnifiOps.ps1 covering all actions with real command examples.
2. Add comment-based help to each public function in UnifiOps.Functions.ps1.

## Non Goals

1. No separate `-Action Help` switch. PowerShell native help is sufficient.
2. No external help file (.xml). Comment-based help only.
3. No changes to script or module behavior.

## Functional Requirements

1. UnifiOps.ps1 must have a comment-based help block with Synopsis, Description, and one Example per action.
2. Each Example must use a real BaseUrl and show a complete, copy-paste ready command.
3. Each public function in UnifiOps.Functions.ps1 must have a Synopsis and at least one Example.
4. Private functions (New-UnifiContext, Invoke-UnifiRequest, Test-UnifiLoginPath, Get-UnifiApiUri, Assert-ExportParameter) do not require help.
5. `Get-Help .\UnifiOps.ps1 -Examples` must return one example per action.
6. `Get-Help Connect-Unifi` after Import-Module must return a synopsis and example.

## Non Functional Requirements

1. Help text must use plain language. No filler or marketing copy.
2. No changes to script logic or function signatures.
3. ScriptAnalyzer must still pass with zero findings after help is added.

## Inputs And Outputs

1. Inputs: None. Help is static comment-based text.
2. Outputs: Help content displayed via Get-Help.

## Acceptance Criteria

1. `Get-Help .\UnifiOps.ps1` returns a synopsis and description.
2. `Get-Help .\UnifiOps.ps1 -Examples` returns at least one example per action (13 total).
3. `Get-Help .\UnifiOps.ps1 -Parameter Action` returns a description of the Action parameter and its valid values.
4. After `Import-Module .\UnifiOps\UnifiOps.psd1`, `Get-Help Connect-Unifi` returns a synopsis and example.
5. `Invoke-ScriptAnalyzer -Path .\UnifiOps.ps1` returns zero findings.
6. `Invoke-ScriptAnalyzer -Path .\UnifiOps\` returns zero findings.

## Test Cases

1. Run `Get-Help .\UnifiOps.ps1 -Full` and verify all 13 actions have examples.
2. Run `Get-Help .\UnifiOps.ps1 -Parameter Credential` and verify the description explains PSCredential usage.
3. Import the module and run `Get-Help Export-UnifiData` and verify synopsis and example are present.
4. Run ScriptAnalyzer against both files and verify zero findings.

## Risks

1. Long comment-based help blocks add visual noise at the top of the script. Acceptable tradeoff for in-shell discoverability.

## Open Questions

None. All decisions resolved before implementation.
