# Standardized Return Objects

## Title

Standardize return objects across all actions for consistent pipeline use.

## Problem Statement

Actions return inconsistent shapes. Query actions (GetSites, GetClients, GetDevices, GetWlans) return raw API responses with lowercase .data and .meta properties. Control actions (BlockClient, UnblockClient) return raw API responses. Login and Test return flat PSCustomObjects with different field sets. Export actions have their own shape. Operators cannot write generic pipeline code that works across actions without knowing which shape each action returns.

## Goals

1. Every action returns a PSCustomObject with a consistent top-level shape.
2. Data-bearing actions always expose results through a .Data property.
3. ItemCount is always present for actions that return collections.

## Non Goals

1. No changes to what data is fetched or how the API is called.
2. No changes to export actions. Their return shape is already standardized.
3. No changes to error behavior.

## Functional Requirements

1. All non-export actions must return a PSCustomObject with these fields: Success, Action, Data, ItemCount.
2. Success must be a boolean. Always true on success.
3. Action must be the string value of the -Action parameter that was run.
4. Data must contain the result payload. For query actions this is the items array. For Login and Test this is a nested object with connection info. For BlockClient, UnblockClient, and Logout this is null.
5. ItemCount must be an integer for query actions equal to the count of items in Data. For all other actions it must be null.
6. Export actions are unchanged. They already return Success, Action, OutputPath, OutputFormat, and ItemCount.

## Non Functional Requirements

1. No changes to API call logic or function internals.
2. ScriptAnalyzer must pass with zero findings.
3. This is a breaking change for any caller accessing .data (lowercase) on query results. This is intentional.

## Inputs And Outputs

1. Inputs: No new parameters. Return shape change only.
2. Outputs: Consistent PSCustomObject for all non-export actions.

## Acceptance Criteria

1. Running GetClients returns an object where .Success is true, .Action is 'GetClients', .Data is an array, and .ItemCount equals the array length.
2. Running Test returns an object where .Data contains BaseUrl, LoginPath, NetworkPrefix, and SitesFound.
3. Running BlockClient returns an object where .Data is null and .ItemCount is null.
4. Running Logout returns an object where .Data is null and .ItemCount is null.
5. Running Login returns an object where .Data contains BaseUrl, LoginPath, and NetworkPrefix.
6. All thirteen actions return an object with a Success property equal to true.

## Test Cases

1. Run GetClients and pipe .Data to Where-Object to filter by IP. Verify it works without accessing .data (lowercase).
2. Run Test and verify .Data.SitesFound is accessible.
3. Run BlockClient and verify .ItemCount is null.
4. Run all thirteen actions and verify each returns a Success property.

## Risks

1. Breaking change. Any script using .data (lowercase) on query results will break. Operators must update to .Data (uppercase D).

## Open Questions

None. All decisions resolved before implementation.
