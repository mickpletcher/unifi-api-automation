# UnifiOps

[![CI](https://github.com/mickpletcher/unifi-api-automation/actions/workflows/ci.yml/badge.svg)](https://github.com/mickpletcher/unifi-api-automation/actions/workflows/ci.yml)

PowerShell 7 module and script for the official local UniFi Network API.

UnifiOps uses API key authentication, follows API pagination automatically, validates inputs before network calls, and produces stable objects and exports.

## Requirements

- PowerShell 7.0 or later
- UniFi Network with the official local API available under Network > Control Plane > Integrations
- A UniFi Network API key
- HTTPS access to the UniFi console

The implementation targets the [official UniFi Network API](https://developer.ui.com/network/v10.1.84/openapi.json) at `https://<console>/proxy/network/integration/v1`, documented for UniFi Network 10.1.84.

## Quick start

```powershell
$apiKey = Read-Host 'UniFi API key' -AsSecureString

.\UnifiOps.ps1 `
    -BaseUrl 'https://192.168.1.1' `
    -ApiKey $apiKey `
    -Action Test
```

For a console using a self-signed certificate, add `-SkipCertificateCheck`. This is an explicit exception and should only be used on a trusted network.

## Actions

| Action | Required inputs | Result |
| --- | --- | --- |
| `Test` | None beyond connection inputs | Application information |
| `GetSites` | None | All local sites |
| `GetClients` | `SiteId` | Connected clients |
| `GetDevices` | `SiteId` | Adopted devices |
| `GetWlans` | `SiteId` | WiFi broadcasts |
| `AuthorizeGuest` | `SiteId`, `ClientId` | Guest authorization response |
| `UnauthorizeGuest` | `SiteId`, `ClientId` | Guest unauthorization response |
| `ExportSites` | `OutputPath` | JSON or CSV export metadata |
| `ExportClients` | `SiteId`, `OutputPath` | JSON or CSV export metadata |
| `ExportDevices` | `SiteId`, `OutputPath` | JSON or CSV export metadata |
| `ExportWlans` | `SiteId`, `OutputPath` | JSON or CSV export metadata |

`SiteId` and `ClientId` are official UUID values. Run `GetSites` and `GetClients` to discover them.

## Query examples

```powershell
$sites = .\UnifiOps.ps1 `
    -BaseUrl 'https://192.168.1.1' `
    -ApiKey $apiKey `
    -Action GetSites

$siteId = [guid]$sites.Data[0].id

$clients = .\UnifiOps.ps1 `
    -BaseUrl 'https://192.168.1.1' `
    -ApiKey $apiKey `
    -Action GetClients `
    -SiteId $siteId

$clients.Data | Select-Object name, type, macAddress, ipAddress
```

Official filter expressions are passed with `-Filter` and URL encoded by the module.

```powershell
.\UnifiOps.ps1 `
    -BaseUrl 'https://192.168.1.1' `
    -ApiKey $apiKey `
    -Action GetDevices `
    -SiteId $siteId `
    -Filter "state.eq('ONLINE')"
```

## Exports

Export validation runs before any API request. JSON exports are always arrays, including zero and one item results. Files are written through a temporary file and moved into place only after serialization succeeds.

```powershell
.\UnifiOps.ps1 `
    -BaseUrl 'https://192.168.1.1' `
    -ApiKey $apiKey `
    -Action ExportDevices `
    -SiteId $siteId `
    -OutputPath '.\reports\devices.json'
```

Use `-Force` to replace an existing file. The extension must be `.json` for JSON or `.csv` for CSV.

## Guest access

The official API supports guest authorization and unauthorization. These actions require the connected client UUID, not a MAC address.

```powershell
.\UnifiOps.ps1 `
    -BaseUrl 'https://192.168.1.1' `
    -ApiKey $apiKey `
    -Action AuthorizeGuest `
    -SiteId $siteId `
    -ClientId $clientId `
    -TimeLimitMinutes 120 `
    -DataUsageLimitMBytes 500 `
    -Confirm
```

`-WhatIf` is supported. POST requests are never retried because their result may be uncertain after a transport failure.

## Module usage

```powershell
Import-Module .\UnifiOps\UnifiOps.psd1 -Force

$context = Connect-Unifi `
    -BaseUrl 'https://192.168.1.1' `
    -ApiKey $apiKey

$devices = @(Get-UnifiDevice -Context $context -SiteId $siteId)
```

`Invoke-UnifiOperation` provides the same standardized interface as the standalone script.

## Result contract

Every successful operation returns one object:

```text
Success   Boolean
Action    String
Data      Payload or export metadata
ItemCount Integer for collection and export actions, otherwise null
```

Failures are terminating errors. UnifiOps does not replace controller or PowerShell exceptions with generic success objects.

## Reliability controls

- `MaxAttempts`: 1 through 10. Default 3.
- `TimeoutSec`: 1 through 300. Default 30.
- `PageSize`: 1 through 200. Default 200.
- GET requests retry network failures and HTTP 408, 425, 429, 500, 502, 503, and 504.
- Retry delay uses bounded exponential backoff with jitter and honors `Retry-After` when available.
- Write requests are not retried.

## Validation

```powershell
Install-Module Pester -RequiredVersion 6.0.1 -Scope CurrentUser
Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser
./Invoke-Validation.ps1
```

CI runs the same command on Windows and Ubuntu. It requires zero analyzer findings, all tests passing, and at least 80 percent command coverage.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development instructions and [MIGRATION.md](docs/MIGRATION.md) for the 1.x breaking changes.
