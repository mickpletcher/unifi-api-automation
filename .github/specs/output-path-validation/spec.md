# Output Path Validation

## Title

Add deep output path validation with clear error messages to all file-writing actions.

## Problem Statement

The current `Assert-ExportParameter` function only checks whether `-OutputPath` was supplied. Operators passing invalid paths, directory paths, mismatched extensions, or paths on missing drives receive cryptic PowerShell runtime errors instead of actionable messages.

## Goals

1. Validate output paths before any API call or file write is attempted.
2. Cover all failure modes: invalid characters, directory targets, extension mismatch, and missing drive.
3. Apply to all current and future file-writing actions.

## Non Goals

1. No pre-flight write permission check. Let the OS surface permission errors naturally.
2. No path length enforcement beyond what the OS enforces.
3. No UNC or mapped network drive reachability check.

## Functional Requirements

1. Must reject paths containing invalid filesystem characters and name the offending characters in the error.
2. Must reject paths that point to an existing directory instead of a file.
3. Must reject paths where the drive or root does not exist on the current machine.
4. Must emit a Write-Warning when the file extension does not match `-OutputFormat`. Must not terminate.
5. Valid extension pairings: `.json` for `Json`, `.csv` for `Csv`. All other extensions trigger the warning.
6. All terminating errors must include the supplied path and a plain-English reason in the message.
7. Validation must run in `Assert-ExportParameter` so every file-writing action gets it automatically.
8. No API call must be made if validation fails.

## Non Functional Requirements

1. Existing non-export actions must be unaffected.
2. Invalid character detection must use `[System.IO.Path]::GetInvalidPathChars()` for OS portability.
3. Error messages must be consistent in structure: "OutputPath '<value>': <reason>."

## Inputs And Outputs

1. Inputs: `-OutputPath`, `-OutputFormat`
2. Outputs: Terminating error with structured message on hard failures. Write-Warning on extension mismatch. No output on valid input.

## Acceptance Criteria

1. Passing a path with invalid characters throws an error that includes the path and names the invalid characters found.
2. Passing a path to an existing directory throws an error stating the path must target a file, not a directory.
3. Passing a path on a drive that does not exist throws an error stating the drive is not available.
4. Passing `-OutputPath .\output.csv -OutputFormat Json` emits a warning about extension mismatch and does not terminate.
5. All error messages follow the format: "OutputPath '<value>': <reason>."
6. Running `GetClients` or any non-export action with no `-OutputPath` produces no validation output.

## Test Cases

1. Pass `C:\>bad\file.json` and verify error message contains the path and identifies `>` as invalid.
2. Pass an existing directory path (e.g. `C:\Temp`) and verify error states it must be a file path.
3. Pass a path on a non-existent drive (e.g. `Q:\export.json`) and verify error states the drive is not available.
4. Pass `.\clients.csv -OutputFormat Json` and verify a warning is written but execution continues.
5. Pass `.\clients.json -OutputFormat Json` and verify no warning or error is produced.
6. Run `-Action GetClients` with no `-OutputPath` and verify no validation error is thrown.

## Risks

1. Invalid character sets differ between Windows and Linux. Using `GetInvalidPathChars()` handles this but must be tested on the target platform.
2. Extension mismatch is a warning, not an error. Downstream consumers must handle files that may have misleading extensions.

## Open Questions

None. All decisions resolved before implementation.
