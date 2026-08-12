Describe 'Live UniFi read-only integration' -Tag Integration {
    BeforeAll {
        if ([string]::IsNullOrWhiteSpace($env:UNIFIOPS_BASE_URL)) {
            throw 'UNIFIOPS_BASE_URL is required for integration tests.'
        }
        if ([string]::IsNullOrWhiteSpace($env:UNIFIOPS_API_KEY)) {
            throw 'UNIFIOPS_API_KEY is required for integration tests.'
        }

        $repositoryRoot = Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $repositoryRoot 'UnifiOps/UnifiOps.psd1') -Force
        $apiKey = ConvertTo-SecureString $env:UNIFIOPS_API_KEY -AsPlainText -Force
        $connectionParameters = @{
            BaseUrl = [uri]$env:UNIFIOPS_BASE_URL
            ApiKey = $apiKey
            MaxAttempts = 2
            TimeoutSec = 30
            PageSize = 200
        }
        if ($env:UNIFIOPS_SKIP_CERTIFICATE_CHECK -eq 'true') {
            $connectionParameters['SkipCertificateCheck'] = $true
        }
    }

    It 'connects and reads every supported inventory endpoint' {
        $context = Connect-Unifi @connectionParameters
        $context.ApplicationInfo | Should -Not -BeNullOrEmpty

        $sites = @(Get-UnifiSite -Context $context)
        $sites.Count | Should -BeGreaterOrEqual 1

        $siteId = [guid]$sites[0].id
        { @(Get-UnifiClient -Context $context -SiteId $siteId) } | Should -Not -Throw
        { @(Get-UnifiDevice -Context $context -SiteId $siteId) } | Should -Not -Throw
        { @(Get-UnifiWlan -Context $context -SiteId $siteId) } | Should -Not -Throw
    }
}
