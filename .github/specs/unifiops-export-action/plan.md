# Implementation Plan

## Summary

Implement export actions in `UnifiOps.ps1` with minimal disruption to existing behavior.

## Design

1. Add output parameters and action values in top level `param` block.
2. Add helper function to enforce export input rules.
3. Add helper function to write JSON or CSV data.
4. Extend switch block with four export actions that call existing query functions then write file.

## File Changes

| File | Change |
| --- | --- |
| `UnifiOps.ps1` | Add params, helpers, and export action cases |
| `.github/specs/unifiops-export-action/tasks.md` | Track implementation status |

## Validation

1. Run `Invoke-ScriptAnalyzer -Path .\UnifiOps.ps1`.
2. Run export commands against test UniFi endpoint and verify file output.
3. Run existing `GetClients` action and compare behavior with current baseline.

## Rollout

1. Merge code with docs update if needed.
2. Validate in one non production environment.

## Backout

1. Revert commit for export changes.
2. Re run analyzer and smoke test existing actions.
