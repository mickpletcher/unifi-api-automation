<#
.SYNOPSIS
Automates UniFi network operations via the REST API.

.DESCRIPTION
Single-script interface for authenticating, querying, controlling, and exporting UniFi network data.
Handles API version detection automatically. Use -Action to select the operation.

.PARAMETER BaseUrl
URL of the UniFi controller, e.g. https://192.168.1.1.

.PARAMETER Credential
PSCredential containing the UniFi username and password. Use Get-Credential to build this securely.

.PARAMETER Action
Operation to run. Valid values: Test, Login, GetSites, GetClients, GetDevices, GetWlans,
BlockClient, UnblockClient, ExportSites, ExportClients, ExportDevices, ExportWlans, Logout.
Default is Test.

.PARAMETER Site
UniFi site identifier. Default is 'default'.

.PARAMETER MacAddress
Client MAC address. Required for BlockClient and UnblockClient.

.PARAMETER OutputPath
File path for export output. Required for export actions. Parent directory is created if missing.

.PARAMETER OutputFormat
Output format for export actions. Valid values: Json, Csv. Default is Json.

.PARAMETER Force
Allows export actions to overwrite an existing file. Without this switch, exporting to an existing file path throws an error.

.PARAMETER RetryCount
Number of attempts for each API request. Applies to transient failures such as HTTP 5xx responses and network errors. HTTP 4xx errors fail immediately regardless of this setting. Default is 3.

.EXAMPLE
.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -Credential (Get-Credential) -Action Test
Verifies the connection and returns the site count.

.EXAMPLE
.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -Credential (Get-Credential) -Action Login
Authenticates and returns the detected login path and network prefix.

.EXAMPLE
.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -Credential (Get-Credential) -Action GetSites
Returns all sites on the controller.

.EXAMPLE
.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -Credential (Get-Credential) -Action GetClients -Site 'default'
Returns all connected clients for the default site.

.EXAMPLE
.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -Credential (Get-Credential) -Action GetDevices -Site 'default'
Returns all network devices for the default site.

.EXAMPLE
.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -Credential (Get-Credential) -Action GetWlans -Site 'default'
Returns all WLAN configurations for the default site.

.EXAMPLE
.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -Credential (Get-Credential) -Action BlockClient -MacAddress 'aa:bb:cc:dd:ee:ff'
Blocks the client with the specified MAC address on the default site.

.EXAMPLE
.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -Credential (Get-Credential) -Action UnblockClient -MacAddress 'aa:bb:cc:dd:ee:ff'
Unblocks the client with the specified MAC address on the default site.

.EXAMPLE
.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -Credential (Get-Credential) -Action ExportSites -OutputPath '.\sites.json'
Exports all sites to a JSON file.

.EXAMPLE
.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -Credential (Get-Credential) -Action ExportClients -OutputPath '.\clients.json'
Exports all clients for the default site to a JSON file.

.EXAMPLE
.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -Credential (Get-Credential) -Action ExportDevices -OutputPath '.\devices.csv' -OutputFormat Csv
Exports all devices for the default site to a CSV file.

.EXAMPLE
.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -Credential (Get-Credential) -Action ExportWlans -OutputPath '.\wlans.json'
Exports all WLAN configurations for the default site to a JSON file.

.EXAMPLE
.\UnifiOps.ps1 -BaseUrl 'https://192.168.1.1' -Credential (Get-Credential) -Action Logout
Logs out of the current session.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$BaseUrl,

    [Parameter(Mandatory)]
    [PSCredential]$Credential,

    [ValidateSet('Login','GetSites','GetClients','GetDevices','GetWlans','BlockClient','UnblockClient','Logout','Test',
                 'ExportSites','ExportClients','ExportDevices','ExportWlans')]
    [string]$Action = 'Test',

    [string]$Site = 'default',

    [string]$MacAddress,

    [string]$OutputPath,

    [ValidateSet('Json','Csv')]
    [string]$OutputFormat = 'Json',

    [switch]$Force,

    [int]$RetryCount = 3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'UnifiOps\UnifiOps.Functions.ps1')

try {
    $context = Connect-Unifi -BaseUrl $BaseUrl -Credential $Credential -RetryCount $RetryCount

    switch ($Action) {
        'Login' {
            [pscustomobject]@{
                Success       = $true
                BaseUrl       = $context.BaseUrl
                LoginPath     = $context.LoginPath
                NetworkPrefix = $context.NetworkPrefix
            }
        }

        'GetSites' {
            Get-UnifiSite -Context $context
        }

        'GetClients' {
            Get-UnifiClient -Context $context -Site $Site
        }

        'GetDevices' {
            Get-UnifiDevice -Context $context -Site $Site
        }

        'GetWlans' {
            Get-UnifiWlan -Context $context -Site $Site
        }

        'BlockClient' {
            if ([string]::IsNullOrWhiteSpace($MacAddress)) {
                throw "MacAddress is required for BlockClient."
            }

            Invoke-UnifiClientAction -Context $context -Site $Site -Command 'block-sta' -MacAddress $MacAddress
        }

        'UnblockClient' {
            if ([string]::IsNullOrWhiteSpace($MacAddress)) {
                throw "MacAddress is required for UnblockClient."
            }

            Invoke-UnifiClientAction -Context $context -Site $Site -Command 'unblock-sta' -MacAddress $MacAddress
        }

        'ExportSites' {
            Assert-ExportParameter -Action $Action -OutputPath $OutputPath -OutputFormat $OutputFormat -Force:$Force
            $items = @((Get-UnifiSite -Context $context).data)
            Export-UnifiData -Data $items -OutputPath $OutputPath -OutputFormat $OutputFormat -Force:$Force
            [pscustomobject]@{
                Success      = $true
                Action       = $Action
                OutputPath   = $OutputPath
                OutputFormat = $OutputFormat
                ItemCount    = $items.Count
            }
        }

        'ExportClients' {
            Assert-ExportParameter -Action $Action -OutputPath $OutputPath -OutputFormat $OutputFormat -Force:$Force
            $items = @((Get-UnifiClient -Context $context -Site $Site).data)
            Export-UnifiData -Data $items -OutputPath $OutputPath -OutputFormat $OutputFormat -Force:$Force
            [pscustomobject]@{
                Success      = $true
                Action       = $Action
                OutputPath   = $OutputPath
                OutputFormat = $OutputFormat
                ItemCount    = $items.Count
            }
        }

        'ExportDevices' {
            Assert-ExportParameter -Action $Action -OutputPath $OutputPath -OutputFormat $OutputFormat -Force:$Force
            $items = @((Get-UnifiDevice -Context $context -Site $Site).data)
            Export-UnifiData -Data $items -OutputPath $OutputPath -OutputFormat $OutputFormat -Force:$Force
            [pscustomobject]@{
                Success      = $true
                Action       = $Action
                OutputPath   = $OutputPath
                OutputFormat = $OutputFormat
                ItemCount    = $items.Count
            }
        }

        'ExportWlans' {
            Assert-ExportParameter -Action $Action -OutputPath $OutputPath -OutputFormat $OutputFormat -Force:$Force
            $items = @((Get-UnifiWlan -Context $context -Site $Site).data)
            Export-UnifiData -Data $items -OutputPath $OutputPath -OutputFormat $OutputFormat -Force:$Force
            [pscustomobject]@{
                Success      = $true
                Action       = $Action
                OutputPath   = $OutputPath
                OutputFormat = $OutputFormat
                ItemCount    = $items.Count
            }
        }

        'Logout' {
            Disconnect-Unifi -Context $context
            [pscustomobject]@{
                Success = $true
                Message = 'Logged out.'
            }
        }

        'Test' {
            $sites = Get-UnifiSite -Context $context
            [pscustomobject]@{
                Success       = $true
                BaseUrl       = $context.BaseUrl
                LoginPath     = $context.LoginPath
                NetworkPrefix = $context.NetworkPrefix
                SitesFound    = @($sites.data).Count
            }
        }
    }
}
finally {
    if ($null -ne $context -and $Action -ne 'Logout') {
        Disconnect-Unifi -Context $context
    }
}
