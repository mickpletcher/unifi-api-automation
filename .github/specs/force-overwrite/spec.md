# Force Overwrite Switch

## Title

Add an optional -Force switch to export actions that controls file overwrite behavior.

## Problem Statement

Export actions currently overwrite existing files silently. Operators running exports on a schedule or in automation pipelines have no protection against accidentally stomping a previous export. There is no way to require explicit intent to overwrite.

## Goals

1. Default export behavior protects existing files by failing fast when the output path already exists.
2. Passing -Force allows overwrite explicitly.

## Non Goals

1. No changes to non-export actions.
2. No backup or versioning of overwritten files.
3. No -Force behavior for directory creation. Parent directories are still created automatically.

## Functional Requirements

1. Add a -Force switch parameter to UnifiOps.ps1.
2. Add a -Force switch parameter to Export-UnifiData in UnifiOps.Functions.ps1.
3. If the output file already exists and -Force is not set, the export must terminate with a clear error before any API call is made.
4. If the output file already exists and -Force is set, the export overwrites the file silently.
5. If the output file does not exist, behavior is unchanged regardless of -Force.
6. The -Force check must run inside Assert-ExportParameter so it executes before the API call.
7. The error message must include the conflicting file path.

## Non Functional Requirements

1. Non-export actions must be unaffected.
2. ScriptAnalyzer must pass with zero findings after the change.
3. Existing export behavior for new files must be identical to current behavior.

## Inputs And Outputs

1. Inputs: -Force switch on UnifiOps.ps1 and Export-UnifiData.
2. Outputs: Terminating error when file exists and -Force is absent. Silent overwrite when -Force is present.

## Acceptance Criteria

1. Running an export action against an existing file without -Force throws an error naming the file.
2. Running the same export with -Force succeeds and overwrites the file.
3. Running an export to a path that does not exist behaves the same with or without -Force.
4. Running a non-export action with -Force set produces no error or change in behavior.
5. Error message format matches the pattern used by Assert-ExportParameter: "OutputPath '<value>': <reason>."

## Test Cases

1. Create a file at the target path, run an export without -Force, verify terminating error.
2. Create a file at the target path, run an export with -Force, verify file is overwritten.
3. Run an export to a new path without -Force, verify success.
4. Run GetClients with -Force set, verify no error and no behavioral change.

## Risks

1. Changing the default from silent overwrite to fail-fast is a breaking change for any operator already relying on silent overwrite. This is intentional and correct but should be noted.

## Open Questions

None. All decisions resolved before implementation.
