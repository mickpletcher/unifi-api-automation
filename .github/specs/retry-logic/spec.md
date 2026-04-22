# Retry Logic

## Title

Add basic retry logic to Invoke-UnifiRequest for transient API failures.

## Problem Statement

All API calls go through Invoke-UnifiRequest with no retry behavior. Transient failures such as HTTP 5xx errors, network timeouts, and brief connection drops cause the entire operation to fail immediately. In automation contexts this produces unnecessary failures that a simple retry would have recovered.

## Goals

1. Retry failed API calls on transient errors up to a configurable maximum.
2. Fail fast on non-retryable errors without wasting retry attempts.
3. Expose retry count as a parameter on UnifiOps.ps1 with a sensible default.

## Non Goals

1. No exponential backoff. Fixed delay between retries only.
2. No per-request retry configuration. One retry count applies to all requests in a run.
3. No retry on authentication failures or 4xx client errors.
4. No retry delay configuration. Delay is fixed at 2 seconds.

## Functional Requirements

1. Invoke-UnifiRequest must retry on HTTP 5xx responses and on network-level errors such as timeouts and connection failures.
2. Invoke-UnifiRequest must not retry on HTTP 4xx responses. These must fail immediately.
3. The maximum number of attempts must be configurable via a -RetryCount parameter on Invoke-UnifiRequest. Default is 3.
4. The delay between attempts must be 2 seconds. Not configurable.
5. UnifiOps.ps1 must expose a -RetryCount parameter and pass it through to Invoke-UnifiRequest at every call site.
6. Each retry attempt must emit a Write-Warning with the attempt number, total attempts, and error received.
7. When all attempts are exhausted the original error must be re-thrown.

## Non Functional Requirements

1. Retry logic must not change behavior for successful requests.
2. Auth-related errors (HTTP 401, AUTHENTICATION_FAILED_INVALID_CREDENTIALS) must never be retried.
3. ScriptAnalyzer must pass with zero findings after the change.

## Inputs And Outputs

1. Inputs: -RetryCount on UnifiOps.ps1 (default 3). Passed through to Invoke-UnifiRequest.
2. Outputs: Write-Warning per retry attempt. Original error re-thrown after all attempts fail.

## Acceptance Criteria

1. A simulated 5xx response triggers a retry and emits a warning per attempt.
2. A simulated 4xx response fails immediately with no retry.
3. A successful request on the second attempt returns the response without error.
4. Running with -RetryCount 1 makes exactly one attempt and fails without retrying.
5. The warning message includes the attempt number and total attempts.
6. ScriptAnalyzer returns zero findings.

## Test Cases

1. Mock Invoke-RestMethod to throw an HTTP 503 twice then succeed. Verify two warnings are emitted and the result is returned.
2. Mock Invoke-RestMethod to throw an HTTP 404. Verify it fails immediately with no warning.
3. Mock Invoke-RestMethod to throw an HTTP 503 three times with -RetryCount 3. Verify error is re-thrown after three attempts.
4. Run a successful request and verify no warning is emitted and no retry occurs.

## Risks

1. Distinguishing HTTP 5xx from 4xx requires inspecting exception type and response status code. PowerShell surfaces these differently depending on PS version and error detail availability.

## Open Questions

None. All decisions resolved before implementation.
