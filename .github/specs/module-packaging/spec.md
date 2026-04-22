# Module Packaging

## Title

Package UnifiOps as an importable PowerShell module alongside the existing script.

## Problem Statement

UnifiOps.ps1 is a script with a single entry point. Every call re-authenticates, runs one action, and logs out. Operators building automation pipelines cannot reuse a session across multiple calls or compose individual functions. There is no module to import.

## Goals

1. Expose UnifiOps functions as a PowerShell module that can be imported with Import-Module.
2. Allow operators to manage session lifecycle explicitly across multiple calls.
3. Keep the existing UnifiOps.ps1 script intact and working without changes.

## Non Goals

1. No changes to UnifiOps.ps1 behavior or interface.
2. No PowerShell Gallery publishing in this change.
3. No versioned release pipeline in this change.

## Functional Requirements

1. Must create a module folder at `UnifiOps/` containing `UnifiOps.psm1` and `UnifiOps.psd1`.
2. `UnifiOps.psm1` must dot-source or inline the shared functions from UnifiOps.ps1 without duplicating logic.
3. The module must export these public functions: `Connect-Unifi`, `Disconnect-Unifi`, `Get-UnifiSite`, `Get-UnifiClient`, `Get-UnifiDevice`, `Get-UnifiWlan`, `Invoke-UnifiClientAction`, `Export-UnifiData`.
4. `Connect-Unifi` must accept `-BaseUrl` and `-Credential` and return a context object the caller holds and passes to subsequent calls.
5. `UnifiOps.psd1` must declare module version, author, description, PowerShell version requirement, and the list of exported functions.
6. `Import-Module .\UnifiOps\UnifiOps.psd1` must succeed without errors.
7. After import, all exported functions must be callable directly without re-authenticating between calls.

## Non Functional Requirements

1. No logic duplication between UnifiOps.ps1 and the module.
2. Module must pass ScriptAnalyzer with zero findings.
3. PowerShell minimum version declared in the manifest must be 7.0.

## Inputs And Outputs

1. Inputs: `-BaseUrl`, `-Credential` passed to `Connect-Unifi`. Context object passed to all subsequent calls.
2. Outputs: Context object from `Connect-Unifi`. Data objects from query functions. Result objects from export and action functions.

## Acceptance Criteria

1. `Import-Module .\UnifiOps\UnifiOps.psd1` completes without error.
2. `Connect-Unifi -BaseUrl 'https://192.168.1.1' -Credential $cred` returns a context object with `BaseUrl`, `LoginPath`, and `NetworkPrefix` populated.
3. Calling `Get-UnifiClient -Context $ctx -Site 'default'` after Connect-Unifi returns client data without re-authenticating.
4. Calling `Disconnect-Unifi -Context $ctx` closes the session cleanly.
5. `.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -Credential $cred -Action GetClients` still works exactly as before.
6. `Invoke-ScriptAnalyzer -Path .\UnifiOps\` returns zero findings.

## Test Cases

1. Import the module and verify exported function list matches the spec.
2. Run Connect-Unifi against a live controller and verify the returned context has all three fields populated.
3. Call Get-UnifiClient using the context from step 2 and verify data is returned.
4. Call Disconnect-Unifi and verify the session is closed.
5. Run UnifiOps.ps1 directly after the module is imported and verify no conflict or error.

## Risks

1. Dot-sourcing UnifiOps.ps1 into the module will also pull in the script-level param block and try/finally execution block, which will break. The shared functions must be extracted to a separate file or the module must inline them independently.
2. Internal helper functions (New-UnifiContext, Invoke-UnifiRequest, Test-UnifiLoginPath, Get-UnifiApiUri, Assert-ExportParameter) must be available to exported functions but should not be exported publicly.

## Open Questions

None. All decisions resolved before implementation.
