@{
    RootModule        = 'UnifiOps.psm1'
    ModuleVersion     = '2.0.0'
    GUID              = '3ebba5f3-0d78-4835-bb60-2307ebbaf174'
    Author            = 'Mick Pletcher'
    CompanyName       = 'Mick Pletcher'
    Copyright         = '(c) Mick Pletcher. Licensed under the MIT License.'
    Description       = 'PowerShell module for the official local UniFi Network API.'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport = @(
        'Connect-Unifi'
        'Get-UnifiSite'
        'Get-UnifiClient'
        'Get-UnifiDevice'
        'Get-UnifiWlan'
        'Invoke-UnifiGuestAccess'
        'Invoke-UnifiOperation'
        'Export-UnifiData'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('UniFi', 'Network', 'Automation', 'API')
            LicenseUri   = 'https://github.com/mickpletcher/unifi-api-automation/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/mickpletcher/unifi-api-automation'
            ReleaseNotes = 'Migrated to the official API-key-authenticated UniFi Network integration API.'
        }
    }
}
