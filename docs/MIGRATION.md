# Migrating from UnifiOps 1.x

UnifiOps 2.0 removes the private legacy API integration. It does not include a compatibility mode.

## Authentication

Replace `Credential` with a UniFi Network API key stored as a SecureString.

```powershell
$apiKey = Read-Host 'UniFi API key' -AsSecureString
```

API keys are created in the UniFi Network Integrations settings. They are sent in the `X-API-Key` header to the official local integration API.

## Parameter changes

| 1.x | 2.0 |
| --- | --- |
| `Credential` | `ApiKey` |
| `Site`, usually `default` | `SiteId`, an official UUID |
| `MacAddress` | `ClientId`, an official connected-client UUID |
| `RetryCount` | `MaxAttempts` |
| Certificate validation always disabled | Validation enabled unless `SkipCertificateCheck` is supplied |

## Action changes

Removed actions:

- `Login`
- `Logout`
- `BlockClient`
- `UnblockClient`

API keys are stateless, so login and logout actions are not applicable. The current official client action API does not expose the legacy `block-sta` and `unblock-sta` commands.

Added actions:

- `AuthorizeGuest`
- `UnauthorizeGuest`

These are the client actions supported by the official API. They are not aliases for blocking and unblocking a normal client.

## Endpoint changes

| 1.x private endpoint | 2.0 official endpoint |
| --- | --- |
| `/api/self/sites` | `/proxy/network/integration/v1/sites` |
| `/api/s/{site}/stat/sta` | `/proxy/network/integration/v1/sites/{siteId}/clients` |
| `/api/s/{site}/stat/device` | `/proxy/network/integration/v1/sites/{siteId}/devices` |
| `/api/s/{site}/rest/wlanconf` | `/proxy/network/integration/v1/sites/{siteId}/wifi/broadcasts` |

List operations now follow `offset`, `limit`, and `totalCount` until all pages are collected.

## Output changes

Every action returns exactly one result object with `Success`, `Action`, `Data`, and `ItemCount`.

JSON exports always contain an array. Empty results create `[]`. One-item results remain arrays. Extension mismatches now terminate instead of producing a warning.
