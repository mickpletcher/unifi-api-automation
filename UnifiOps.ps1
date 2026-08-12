<#
.SYNOPSIS
Runs supported operations against the official local UniFi Network API.

.DESCRIPTION
Uses API key authentication and the official /proxy/network/integration/v1 API. All list actions follow pagination automatically. Export validation runs before any network request.

.PARAMETER BaseUrl
HTTPS URL for the UniFi console root, such as https://192.168.1.1.

.PARAMETER ApiKey
UniFi Network API key stored as a SecureString.

.PARAMETER Action
Operation to run. Test is the default.

.PARAMETER SiteId
Official UniFi site UUID. Required for site-scoped actions.

.PARAMETER ClientId
Official connected client UUID. Required for guest access actions.

.PARAMETER Filter
Optional official UniFi API filter expression for list and export actions.

.PARAMETER OutputPath
Destination file for export actions.

.PARAMETER OutputFormat
Json or Csv. The filename extension must match.

.PARAMETER Force
Allows an export to replace an existing file.

.PARAMETER MaxAttempts
Maximum attempts for safe GET requests after transient network, HTTP 408, 425, 429, or 5xx failures.

.PARAMETER TimeoutSec
Timeout for each API request.

.PARAMETER PageSize
Number of records requested per page. The official maximum is 200.

.PARAMETER SkipCertificateCheck
Explicitly allows a self-signed or otherwise untrusted console certificate. Use only on a trusted network.

.EXAMPLE
$apiKey = Read-Host 'UniFi API key' -AsSecureString
.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -ApiKey $apiKey -Action Test

.EXAMPLE
.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -ApiKey $apiKey -Action GetSites

.EXAMPLE
.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -ApiKey $apiKey -Action GetClients -SiteId $siteId

.EXAMPLE
.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -ApiKey $apiKey -Action ExportDevices -SiteId $siteId -OutputPath '.\devices.json'

.EXAMPLE
.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -ApiKey $apiKey -Action AuthorizeGuest -SiteId $siteId -ClientId $clientId -TimeLimitMinutes 120 -Confirm
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [uri]$BaseUrl,

    [Parameter(Mandatory)]
    [securestring]$ApiKey,

    [ValidateSet(
        'Test',
        'GetSites',
        'GetClients',
        'GetDevices',
        'GetWlans',
        'AuthorizeGuest',
        'UnauthorizeGuest',
        'ExportSites',
        'ExportClients',
        'ExportDevices',
        'ExportWlans'
    )]
    [string]$Action = 'Test',

    [guid]$SiteId = [guid]::Empty,

    [guid]$ClientId = [guid]::Empty,

    [string]$Filter,

    [string]$OutputPath,

    [ValidateSet('Json', 'Csv')]
    [string]$OutputFormat = 'Json',

    [switch]$Force,

    [ValidateRange(1, 10)]
    [int]$MaxAttempts = 3,

    [ValidateRange(1, 300)]
    [int]$TimeoutSec = 30,

    [ValidateRange(1, 200)]
    [int]$PageSize = 200,

    [switch]$SkipCertificateCheck,

    [ValidateRange(1, 1000000)]
    [long]$TimeLimitMinutes,

    [ValidateRange(1, 1048576)]
    [long]$DataUsageLimitMBytes,

    [ValidateRange(2, 100000)]
    [long]$RxRateLimitKbps,

    [ValidateRange(2, 100000)]
    [long]$TxRateLimitKbps
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'UnifiOps\UnifiOps.Functions.ps1')

Invoke-UnifiOperation @PSBoundParameters
