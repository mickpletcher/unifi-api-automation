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
    [string]$OutputFormat = 'Json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'UnifiOps\UnifiOps.Functions.ps1')

try {
    $context = Connect-Unifi -BaseUrl $BaseUrl -Credential $Credential

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
            Assert-ExportParameter -Action $Action -OutputPath $OutputPath -OutputFormat $OutputFormat
            $items = @((Get-UnifiSite -Context $context).data)
            Export-UnifiData -Data $items -OutputPath $OutputPath -OutputFormat $OutputFormat
            [pscustomobject]@{
                Success      = $true
                Action       = $Action
                OutputPath   = $OutputPath
                OutputFormat = $OutputFormat
                ItemCount    = $items.Count
            }
        }

        'ExportClients' {
            Assert-ExportParameter -Action $Action -OutputPath $OutputPath -OutputFormat $OutputFormat
            $items = @((Get-UnifiClient -Context $context -Site $Site).data)
            Export-UnifiData -Data $items -OutputPath $OutputPath -OutputFormat $OutputFormat
            [pscustomobject]@{
                Success      = $true
                Action       = $Action
                OutputPath   = $OutputPath
                OutputFormat = $OutputFormat
                ItemCount    = $items.Count
            }
        }

        'ExportDevices' {
            Assert-ExportParameter -Action $Action -OutputPath $OutputPath -OutputFormat $OutputFormat
            $items = @((Get-UnifiDevice -Context $context -Site $Site).data)
            Export-UnifiData -Data $items -OutputPath $OutputPath -OutputFormat $OutputFormat
            [pscustomobject]@{
                Success      = $true
                Action       = $Action
                OutputPath   = $OutputPath
                OutputFormat = $OutputFormat
                ItemCount    = $items.Count
            }
        }

        'ExportWlans' {
            Assert-ExportParameter -Action $Action -OutputPath $OutputPath -OutputFormat $OutputFormat
            $items = @((Get-UnifiWlan -Context $context -Site $Site).data)
            Export-UnifiData -Data $items -OutputPath $OutputPath -OutputFormat $OutputFormat
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
