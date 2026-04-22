# Implementation Plan

## Summary

Add a retry loop to Invoke-UnifiRequest that retries on HTTP 5xx and network errors, fails fast on HTTP 4xx, and waits 2 seconds between attempts. Retry count is stored on the context object so it flows through all call sites without changing every function signature. UnifiOps.ps1 exposes -RetryCount which passes through Connect-Unifi into the context.

## Design Decisions

1. Retry count lives on the context object rather than being passed as a parameter to every function. All API calls go through Invoke-UnifiRequest which reads the count from context. This avoids updating every intermediate function signature.
2. Retry count flows in through Connect-Unifi, which passes it to New-UnifiContext where the context is built. This keeps session configuration in one place.
3. HTTP 4xx responses fail immediately. These are client errors that will not succeed on retry. Status code is read from the exception response.
4. Network errors (no status code on the exception) are treated as retryable. A missing response means the request never reached the server or the server dropped the connection.
5. Delay is fixed at 2 seconds using Start-Sleep. Not configurable in this change.
6. Each retry emits Write-Warning with attempt number, total attempts, and the error message.

## Implementation Order

1. Add RetryCount property to New-UnifiContext. Add -RetryCount parameter (default 3) to Connect-Unifi and pass it to New-UnifiContext.
2. Replace the Invoke-RestMethod call in Invoke-UnifiRequest with a retry loop that reads RetryCount from the context.
3. Add -RetryCount parameter (default 3) to UnifiOps.ps1. Pass it to Connect-Unifi. Update help block.
4. Run ScriptAnalyzer against UnifiOps.ps1 and UnifiOps/ and confirm zero findings.
5. Run manual validation tests.

## File Changes

| File | Change |
| --- | --- |
| `UnifiOps/UnifiOps.Functions.ps1` | Update New-UnifiContext to include RetryCount. Update Connect-Unifi to accept and pass -RetryCount. Replace Invoke-RestMethod call in Invoke-UnifiRequest with retry loop. |
| `UnifiOps.ps1` | Add -RetryCount parameter. Pass to Connect-Unifi. Add .PARAMETER help entry. |

## Validation

1. `Invoke-ScriptAnalyzer -Path .\UnifiOps.ps1` — must return zero findings.
2. `Invoke-ScriptAnalyzer -Path .\UnifiOps\ -Recurse` — must return zero findings.
3. Mock a 5xx failure followed by success — verify one warning emitted and result returned.
4. Mock a 4xx failure — verify immediate throw with no warning.
5. Mock three consecutive 5xx failures with -RetryCount 3 — verify error is re-thrown and three warnings emitted.
6. Run a request that succeeds on the first attempt — verify no warning and no retry.

## Rollout

1. Merge to main after all validation steps pass.
2. Default retry count is 3. No operator action required unless they want a different value.

## Backout

1. Revert the commit that updates Invoke-UnifiRequest, New-UnifiContext, Connect-Unifi, and UnifiOps.ps1.
2. Re-run ScriptAnalyzer and confirm clean.
