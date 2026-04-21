# UnifiOps Export Actions

## Title

Add export actions for UniFi data retrieval in `UnifiOps.ps1`.

## Problem Statement

Current actions return objects to the console only. Operators need a repeatable way to export results to files for reporting and downstream automation.

## Goals

1. Add export actions for sites, clients, devices, and wlans.
2. Allow JSON and CSV output formats.
3. Return clear metadata about export results.

## Non Goals

1. No scheduled export support in this change.
2. No remote storage integration in this change.

## Functional Requirements

1. Add these action values to `-Action`.
   1. `ExportSites`
   2. `ExportClients`
   3. `ExportDevices`
   4. `ExportWlans`
2. Add `-OutputPath` parameter. It is required for export actions.
3. Add `-OutputFormat` parameter with values `Json` and `Csv`. Default is `Json`.
4. Export actions reuse existing API query functions.
5. Create parent directory for output path when missing.
6. Return result object with `Success`, `Action`, `OutputPath`, `OutputFormat`, and `ItemCount`.

## Non Functional Requirements

1. Existing non export actions continue to behave the same.
2. Export write errors fail fast with clear message.

## Inputs And Outputs

1. Inputs:
   1. `-Action`
   2. `-OutputPath`
   3. `-OutputFormat`
2. Outputs:
   1. File written to target path.
   2. Structured result object on success.

## Acceptance Criteria

1. Running `ExportClients` writes a file at the requested path.
2. Running `ExportDevices` with `-OutputFormat Csv` writes a valid CSV file.
3. Running export action without `-OutputPath` throws clear validation error.
4. Running current action `GetClients` is unchanged.

## Test Cases

1. Export sites to JSON and verify file exists and contains array data.
2. Export clients to CSV and verify row count is greater than zero when data exists.
3. Run non export action and verify no file write occurs.

## Risks

1. CSV conversion may flatten nested properties unexpectedly.
2. Large datasets may require memory tuning later.

## Open Questions

1. Should CSV export select a curated property set or full object projection.
2. Should output files overwrite by default or require `-Force`.
