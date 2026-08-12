$discoveryRepositoryRoot = Split-Path -Parent $PSScriptRoot
$discoveryModulePath = Join-Path $discoveryRepositoryRoot 'UnifiOps/UnifiOps.psd1'
Import-Module $discoveryModulePath -Force

BeforeAll {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
    $ModulePath = Join-Path $RepositoryRoot 'UnifiOps/UnifiOps.psd1'
    $ScriptPath = Join-Path $RepositoryRoot 'UnifiOps.ps1'
}

AfterAll {
    Remove-Module UnifiOps -Force -ErrorAction SilentlyContinue
}

Describe 'Module packaging' {
    It 'has a valid 2.0 manifest' {
        $manifest = Test-ModuleManifest -Path $ModulePath
        $manifest.Version.ToString() | Should -Be '2.0.0'
        $manifest.PowerShellVersion.ToString() | Should -Be '7.0'
    }

    It 'exports only the supported public commands' {
        $actual = @(Get-Command -Module UnifiOps | Sort-Object Name | Select-Object -ExpandProperty Name)
        $expected = @(
            'Connect-Unifi'
            'Export-UnifiData'
            'Get-UnifiClient'
            'Get-UnifiDevice'
            'Get-UnifiSite'
            'Get-UnifiWlan'
            'Invoke-UnifiGuestAccess'
            'Invoke-UnifiOperation'
        )
        $actual | Should -Be $expected
    }

    It 'provides help for every public command' {
        foreach ($command in Get-Command -Module UnifiOps) {
            $help = Get-Help $command.Name
            $help.Synopsis | Should -Not -BeNullOrEmpty
            @($help.Examples.Example).Count | Should -BeGreaterOrEqual 1
        }
    }
}

Describe 'Secure connection context' {
    InModuleScope UnifiOps {
        BeforeEach {
            $script:TestApiKey = ConvertTo-SecureString 'test-api-key' -AsPlainText -Force
            Mock Invoke-RestMethod {
                $script:CapturedApiKey = $Headers['X-API-Key']
                $script:CapturedTimeout = $ConnectionTimeoutSeconds
                [pscustomobject]@{
                    applicationVersion = '10.1.84'
                }
            }
        }

        It 'uses the official info endpoint and API key header' {
            $context = Connect-Unifi -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey

            $context.ApiRoot | Should -Be 'https://controller.test/proxy/network/integration'
            $context.ApplicationInfo.applicationVersion | Should -Be '10.1.84'
            $context.ApiKey | Should -BeOfType ([securestring])
            ($context | ConvertTo-Json -Depth 5) | Should -Not -Match 'test-api-key'
            $script:CapturedApiKey | Should -Be 'test-api-key'
            $script:CapturedTimeout | Should -Be 30
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Uri.AbsoluteUri -eq 'https://controller.test/proxy/network/integration/v1/info' -and
                $Method -eq 'GET' -and
                $UserAgent -eq 'UnifiOps/2.0.0' -and
                -not $SkipCertificateCheck
            }
        }

        It 'enables certificate bypass only when explicitly requested' {
            $null = Connect-Unifi -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -SkipCertificateCheck

            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $SkipCertificateCheck
            }
        }

        It 'rejects plaintext HTTP before making a request' {
            { Connect-Unifi -BaseUrl 'http://controller.test' -ApiKey $script:TestApiKey } |
                Should -Throw '*must use HTTPS*'
            Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        }

        It 'rejects a BaseUrl containing an API path' {
            { Connect-Unifi -BaseUrl 'https://controller.test/proxy/network' -ApiKey $script:TestApiKey } |
                Should -Throw '*console root*'
            Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        }

        It 'retries safe GET requests after transient network failures' {
            $script:attempt = 0
            Mock Invoke-RestMethod {
                $script:attempt++
                if ($script:attempt -lt 3) {
                    throw [System.Net.Http.HttpRequestException]::new('temporary network failure')
                }
                [pscustomobject]@{ applicationVersion = '10.1.84' }
            }
            Mock Start-Sleep

            $context = Connect-Unifi -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -MaxAttempts 3

            $context.ApplicationInfo.applicationVersion | Should -Be '10.1.84'
            Should -Invoke Invoke-RestMethod -Times 3 -Exactly
            Should -Invoke Start-Sleep -Times 2 -Exactly
        }

        It 'retries HTTP 429 responses for safe GET requests' {
            $script:attempt = 0
            Mock Invoke-RestMethod {
                $script:attempt++
                if ($script:attempt -eq 1) {
                    throw [System.Net.Http.HttpRequestException]::new(
                        'rate limited',
                        $null,
                        [System.Net.HttpStatusCode]::TooManyRequests
                    )
                }
                [pscustomobject]@{ applicationVersion = '10.1.84' }
            }
            Mock Start-Sleep

            $context = Connect-Unifi -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -MaxAttempts 2

            $context.ApplicationInfo.applicationVersion | Should -Be '10.1.84'
            Should -Invoke Invoke-RestMethod -Times 2 -Exactly
            Should -Invoke Start-Sleep -Times 1 -Exactly
        }

        It 'does not retry POST requests' {
            $context = Initialize-UnifiContext -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -MaxAttempts 3
            Mock Invoke-RestMethod { throw [System.Net.Http.HttpRequestException]::new('uncertain write result') }
            Mock Start-Sleep

            { Invoke-UnifiRequest -Context $context -RelativePath '/v1/sites/00000000-0000-0000-0000-000000000001/clients/00000000-0000-0000-0000-000000000002/actions' -Method POST -Body @{ action = 'UNAUTHORIZE_GUEST_ACCESS' } } |
                Should -Throw '*uncertain write result*'
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
            Should -Invoke Start-Sleep -Times 0 -Exactly
        }
    }
}

Describe 'Official API queries' {
    InModuleScope UnifiOps {
        BeforeEach {
            $apiKey = ConvertTo-SecureString 'test-api-key' -AsPlainText -Force
            $script:Context = Initialize-UnifiContext -BaseUrl 'https://controller.test' -ApiKey $apiKey -PageSize 2
            $script:SiteId = [guid]'00000000-0000-0000-0000-000000000001'
        }

        It 'follows pagination until totalCount is reached' {
            Mock Invoke-UnifiRequest {
                if ($RelativePath -match 'offset=0') {
                    return [pscustomobject]@{
                        offset = 0
                        limit = 2
                        count = 2
                        totalCount = 3
                        data = @([pscustomobject]@{ id = 1 }, [pscustomobject]@{ id = 2 })
                    }
                }
                [pscustomobject]@{
                    offset = 2
                    limit = 2
                    count = 1
                    totalCount = 3
                    data = @([pscustomobject]@{ id = 3 })
                }
            }

            $items = @(Get-UnifiSite -Context $script:Context)

            $items.Count | Should -Be 3
            $items.id | Should -Be 1, 2, 3
            Should -Invoke Invoke-UnifiRequest -Times 2 -Exactly
        }

        It 'URL encodes the official filter expression' {
            Mock Invoke-UnifiRequest {
                [pscustomobject]@{ offset = 0; limit = 2; count = 0; totalCount = 0; data = @() }
            }

            $null = @(Get-UnifiSite -Context $script:Context -Filter "name.like('Lab*')")

            Should -Invoke Invoke-UnifiRequest -Times 1 -Exactly -ParameterFilter {
                $RelativePath -match 'filter=name.like%28%27Lab%2A%27%29'
            }
        }

        It 'uses the official sites endpoint' {
            Mock Invoke-UnifiRequest {
                [pscustomobject]@{ offset = 0; limit = 2; count = 0; totalCount = 0; data = @() }
            }
            $null = @(Get-UnifiSite -Context $script:Context)
            Should -Invoke Invoke-UnifiRequest -ParameterFilter { $RelativePath -like '/v1/sites?*' }
        }

        It 'uses the official clients endpoint' {
            Mock Invoke-UnifiRequest {
                [pscustomobject]@{ offset = 0; limit = 2; count = 0; totalCount = 0; data = @() }
            }
            $null = @(Get-UnifiClient -Context $script:Context -SiteId $script:SiteId)
            Should -Invoke Invoke-UnifiRequest -ParameterFilter {
                $RelativePath -like "/v1/sites/$($script:SiteId.ToString('D'))/clients?*"
            }
        }

        It 'uses the official devices endpoint' {
            Mock Invoke-UnifiRequest {
                [pscustomobject]@{ offset = 0; limit = 2; count = 0; totalCount = 0; data = @() }
            }
            $null = @(Get-UnifiDevice -Context $script:Context -SiteId $script:SiteId)
            Should -Invoke Invoke-UnifiRequest -ParameterFilter {
                $RelativePath -like "/v1/sites/$($script:SiteId.ToString('D'))/devices?*"
            }
        }

        It 'uses the official WiFi broadcasts endpoint' {
            Mock Invoke-UnifiRequest {
                [pscustomobject]@{ offset = 0; limit = 2; count = 0; totalCount = 0; data = @() }
            }
            $null = @(Get-UnifiWlan -Context $script:Context -SiteId $script:SiteId)
            Should -Invoke Invoke-UnifiRequest -ParameterFilter {
                $RelativePath -like "/v1/sites/$($script:SiteId.ToString('D'))/wifi/broadcasts?*"
            }
        }

        It 'fails closed on a malformed pagination response' {
            Mock Invoke-UnifiRequest { [pscustomobject]@{ data = @() } }
            { Get-UnifiSite -Context $script:Context } | Should -Throw "*missing 'offset'*"
        }

        It 'fails instead of looping when pagination stops making progress' {
            Mock Invoke-UnifiRequest {
                [pscustomobject]@{ offset = 0; limit = 2; count = 0; totalCount = 1; data = @() }
            }
            { Get-UnifiSite -Context $script:Context } | Should -Throw '*pagination stopped*'
        }
    }
}

Describe 'Guest access actions' {
    InModuleScope UnifiOps {
        BeforeEach {
            $apiKey = ConvertTo-SecureString 'test-api-key' -AsPlainText -Force
            $script:Context = Initialize-UnifiContext -BaseUrl 'https://controller.test' -ApiKey $apiKey
            $script:SiteId = [guid]'00000000-0000-0000-0000-000000000001'
            $script:ClientId = [guid]'00000000-0000-0000-0000-000000000002'
            Mock Invoke-UnifiRequest { [pscustomobject]@{ action = $Body.action } }
        }

        It 'sends the supported authorize action and limits' {
            $result = Invoke-UnifiGuestAccess -Context $script:Context -SiteId $script:SiteId -ClientId $script:ClientId -Action Authorize -TimeLimitMinutes 120 -DataUsageLimitMBytes 500 -Confirm:$false

            $result.action | Should -Be 'AUTHORIZE_GUEST_ACCESS'
            Should -Invoke Invoke-UnifiRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and
                $RelativePath -eq "/v1/sites/$($script:SiteId.ToString('D'))/clients/$($script:ClientId.ToString('D'))/actions" -and
                $Body.action -eq 'AUTHORIZE_GUEST_ACCESS' -and
                $Body.timeLimitMinutes -eq 120 -and
                $Body.dataUsageLimitMBytes -eq 500
            }
        }

        It 'sends the supported unauthorize action' {
            $result = Invoke-UnifiGuestAccess -Context $script:Context -SiteId $script:SiteId -ClientId $script:ClientId -Action Unauthorize -Confirm:$false

            $result.action | Should -Be 'UNAUTHORIZE_GUEST_ACCESS'
            Should -Invoke Invoke-UnifiRequest -Times 1 -Exactly -ParameterFilter {
                $Body.action -eq 'UNAUTHORIZE_GUEST_ACCESS'
            }
        }

        It 'rejects authorization limits on unauthorize' {
            { Invoke-UnifiGuestAccess -Context $script:Context -SiteId $script:SiteId -ClientId $script:ClientId -Action Unauthorize -TimeLimitMinutes 10 -Confirm:$false } |
                Should -Throw '*only be used with the Authorize action*'
            Should -Invoke Invoke-UnifiRequest -Times 0 -Exactly
        }

        It 'honors WhatIf without making a request' {
            $null = Invoke-UnifiGuestAccess -Context $script:Context -SiteId $script:SiteId -ClientId $script:ClientId -Action Authorize -WhatIf
            Should -Invoke Invoke-UnifiRequest -Times 0 -Exactly
        }
    }
}

Describe 'Stable and atomic exports' {
    It 'creates an empty JSON array for an empty collection' {
        $path = Join-Path $TestDrive 'empty.json'
        $result = Export-UnifiData -Data @() -OutputPath $path -OutputFormat Json -Confirm:$false

        Test-Path -LiteralPath $path -PathType Leaf | Should -BeTrue
        (Get-Content -LiteralPath $path -Raw) | Should -Be '[]'
        $result.ItemCount | Should -Be 0
    }

    It 'keeps a one-item JSON export as an array' {
        $path = Join-Path $TestDrive 'one.json'
        $null = Export-UnifiData -Data @([pscustomobject]@{ id = 1 }) -OutputPath $path -OutputFormat Json -Confirm:$false

        $json = Get-Content -LiteralPath $path -Raw
        $json.TrimStart()[0] | Should -Be '['
        @(ConvertFrom-Json -InputObject $json).Count | Should -Be 1
    }

    It 'creates an empty CSV file for an empty collection' {
        $path = Join-Path $TestDrive 'empty.csv'
        $result = Export-UnifiData -Data @() -OutputPath $path -OutputFormat Csv -Confirm:$false

        Test-Path -LiteralPath $path -PathType Leaf | Should -BeTrue
        (Get-Item -LiteralPath $path).Length | Should -Be 0
        $result.ItemCount | Should -Be 0
    }

    It 'creates parent directories and exports populated CSV data' {
        $path = Join-Path $TestDrive 'nested/items.csv'
        $null = Export-UnifiData -Data @([pscustomobject]@{ id = 1; name = 'AP' }) -OutputPath $path -OutputFormat Csv -Confirm:$false

        Test-Path -LiteralPath $path -PathType Leaf | Should -BeTrue
        $rows = @(Import-Csv -LiteralPath $path)
        $rows.Count | Should -Be 1
        $rows[0].name | Should -Be 'AP'
    }

    It 'refuses to overwrite without Force' {
        $path = Join-Path $TestDrive 'existing.json'
        [IO.File]::WriteAllText($path, 'original')

        { Export-UnifiData -Data @() -OutputPath $path -OutputFormat Json -Confirm:$false } |
            Should -Throw '*already exists*'
        (Get-Content -LiteralPath $path -Raw) | Should -Be 'original'
    }

    It 'overwrites atomically with Force' {
        $path = Join-Path $TestDrive 'replace.json'
        [IO.File]::WriteAllText($path, 'original')

        $null = Export-UnifiData -Data @([pscustomobject]@{ id = 2 }) -OutputPath $path -OutputFormat Json -Force -Confirm:$false

        (Get-Content -LiteralPath $path -Raw) | Should -Match '"id": 2'
        @(Get-ChildItem -LiteralPath $TestDrive -Filter '.unifiops-*.tmp').Count | Should -Be 0
    }

    It 'rejects an extension that does not match the format' {
        $path = Join-Path $TestDrive 'wrong.csv'
        { Export-UnifiData -Data @() -OutputPath $path -OutputFormat Json -Confirm:$false } |
            Should -Throw "*'.json' extension*"
    }

    It 'uses literal paths containing wildcard characters' {
        $path = Join-Path $TestDrive 'clients[1].json'
        $null = Export-UnifiData -Data @() -OutputPath $path -OutputFormat Json -Confirm:$false
        Test-Path -LiteralPath $path -PathType Leaf | Should -BeTrue
    }
}

Describe 'Operation orchestration' {
    InModuleScope UnifiOps {
        BeforeEach {
            $script:TestApiKey = ConvertTo-SecureString 'test-api-key' -AsPlainText -Force
            $script:Context = [pscustomobject]@{
                PSTypeName = 'UnifiOps.Context'
                BaseUrl = 'https://controller.test'
                ApiRoot = 'https://controller.test/proxy/network/integration'
                ApiKey = $script:TestApiKey
                MaxAttempts = 3
                TimeoutSec = 30
                PageSize = 200
                SkipCertificateCheck = $false
                ApplicationInfo = [pscustomobject]@{ applicationVersion = '10.1.84' }
            }
            Mock Connect-Unifi { $script:Context }
        }

        It 'returns one consistent result object for collection actions' {
            Mock Get-UnifiSite { [pscustomobject]@{ id = 1 }; [pscustomobject]@{ id = 2 } }

            $result = @(Invoke-UnifiOperation -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -Action GetSites)

            $result.Count | Should -Be 1
            $result[0].Success | Should -BeTrue
            $result[0].Action | Should -Be 'GetSites'
            @($result[0].Data).Count | Should -Be 2
            $result[0].ItemCount | Should -Be 2
        }

        It 'returns sanitized connection information for Test' {
            $result = Invoke-UnifiOperation -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -Action Test

            $result.Success | Should -BeTrue
            $result.Action | Should -Be 'Test'
            $result.Data.BaseUrl | Should -Be 'https://controller.test'
            $result.Data.ApplicationInfo.applicationVersion | Should -Be '10.1.84'
            $result.ItemCount | Should -BeNullOrEmpty
        }

        It 'routes GetClients with the site UUID and filter' {
            $siteId = [guid]'00000000-0000-0000-0000-000000000001'
            Mock Get-UnifiClient { [pscustomobject]@{ id = 1 } }

            $result = Invoke-UnifiOperation -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -Action GetClients -SiteId $siteId -Filter "type.eq('WIRELESS')"

            $result.ItemCount | Should -Be 1
            Should -Invoke Get-UnifiClient -Times 1 -Exactly -ParameterFilter {
                $SiteId -eq [guid]'00000000-0000-0000-0000-000000000001' -and
                $Filter -eq "type.eq('WIRELESS')"
            }
        }

        It 'routes GetDevices with the site UUID' {
            $siteId = [guid]'00000000-0000-0000-0000-000000000001'
            Mock Get-UnifiDevice { [pscustomobject]@{ id = 1 } }

            $result = Invoke-UnifiOperation -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -Action GetDevices -SiteId $siteId

            $result.ItemCount | Should -Be 1
            Should -Invoke Get-UnifiDevice -Times 1 -Exactly
        }

        It 'routes GetWlans with the site UUID' {
            $siteId = [guid]'00000000-0000-0000-0000-000000000001'
            Mock Get-UnifiWlan { [pscustomobject]@{ id = 1 } }

            $result = Invoke-UnifiOperation -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -Action GetWlans -SiteId $siteId

            $result.ItemCount | Should -Be 1
            Should -Invoke Get-UnifiWlan -Times 1 -Exactly
        }

        It 'routes AuthorizeGuest with supported limits' {
            $siteId = [guid]'00000000-0000-0000-0000-000000000001'
            $clientId = [guid]'00000000-0000-0000-0000-000000000002'
            Mock Invoke-UnifiGuestAccess { [pscustomobject]@{ action = 'AUTHORIZE_GUEST_ACCESS' } }

            $result = Invoke-UnifiOperation -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -Action AuthorizeGuest -SiteId $siteId -ClientId $clientId -TimeLimitMinutes 60 -Confirm:$false

            $result.Data.action | Should -Be 'AUTHORIZE_GUEST_ACCESS'
            Should -Invoke Invoke-UnifiGuestAccess -Times 1 -Exactly -ParameterFilter {
                $Action -eq 'Authorize' -and $TimeLimitMinutes -eq 60
            }
        }

        It 'routes UnauthorizeGuest' {
            $siteId = [guid]'00000000-0000-0000-0000-000000000001'
            $clientId = [guid]'00000000-0000-0000-0000-000000000002'
            Mock Invoke-UnifiGuestAccess { [pscustomobject]@{ action = 'UNAUTHORIZE_GUEST_ACCESS' } }

            $result = Invoke-UnifiOperation -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -Action UnauthorizeGuest -SiteId $siteId -ClientId $clientId -Confirm:$false

            $result.Data.action | Should -Be 'UNAUTHORIZE_GUEST_ACCESS'
            Should -Invoke Invoke-UnifiGuestAccess -Times 1 -Exactly -ParameterFilter { $Action -eq 'Unauthorize' }
        }

        It 'returns export metadata in the standard result shape' {
            $path = Join-Path $TestDrive 'operation-sites.json'
            Mock Get-UnifiSite { [pscustomobject]@{ id = 1 } }
            Mock Export-UnifiData {
                [pscustomobject]@{ OutputPath = $OutputPath; OutputFormat = $OutputFormat; ItemCount = @($Data).Count }
            }

            $result = Invoke-UnifiOperation -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -Action ExportSites -OutputPath $path -Confirm:$false

            $result.Success | Should -BeTrue
            $result.Action | Should -Be 'ExportSites'
            $result.ItemCount | Should -Be 1
            $result.Data.OutputFormat | Should -Be 'Json'
            Should -Invoke Export-UnifiData -Times 1 -Exactly
        }

        It 'routes each site scoped export action' {
            $siteId = [guid]'00000000-0000-0000-0000-000000000001'
            Mock Get-UnifiClient { [pscustomobject]@{ id = 1 } }
            Mock Get-UnifiDevice { [pscustomobject]@{ id = 1 } }
            Mock Get-UnifiWlan { [pscustomobject]@{ id = 1 } }
            Mock Export-UnifiData {
                [pscustomobject]@{ OutputPath = $OutputPath; OutputFormat = $OutputFormat; ItemCount = @($Data).Count }
            }

            $clientResult = Invoke-UnifiOperation -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -Action ExportClients -SiteId $siteId -OutputPath (Join-Path $TestDrive 'clients.json') -Confirm:$false
            $deviceResult = Invoke-UnifiOperation -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -Action ExportDevices -SiteId $siteId -OutputPath (Join-Path $TestDrive 'devices.json') -Confirm:$false
            $wlanResult = Invoke-UnifiOperation -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -Action ExportWlans -SiteId $siteId -OutputPath (Join-Path $TestDrive 'wlans.json') -Confirm:$false

            $clientResult.Action | Should -Be 'ExportClients'
            $deviceResult.Action | Should -Be 'ExportDevices'
            $wlanResult.Action | Should -Be 'ExportWlans'
            Should -Invoke Export-UnifiData -Times 3 -Exactly
        }

        It 'validates SiteId before connecting' {
            { Invoke-UnifiOperation -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -Action GetClients } |
                Should -Throw '*SiteId is required*'
            Should -Invoke Connect-Unifi -Times 0 -Exactly
        }

        It 'validates ClientId before connecting' {
            $siteId = [guid]'00000000-0000-0000-0000-000000000001'
            { Invoke-UnifiOperation -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -Action AuthorizeGuest -SiteId $siteId -Confirm:$false } |
                Should -Throw '*ClientId is required*'
            Should -Invoke Connect-Unifi -Times 0 -Exactly
        }

        It 'rejects guest limits for UnauthorizeGuest before connecting' {
            $siteId = [guid]'00000000-0000-0000-0000-000000000001'
            $clientId = [guid]'00000000-0000-0000-0000-000000000002'
            { Invoke-UnifiOperation -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -Action UnauthorizeGuest -SiteId $siteId -ClientId $clientId -TimeLimitMinutes 10 -Confirm:$false } |
                Should -Throw '*only be used with AuthorizeGuest*'
            Should -Invoke Connect-Unifi -Times 0 -Exactly
        }

        It 'validates export paths before connecting' {
            { Invoke-UnifiOperation -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -Action ExportSites -OutputPath 'wrong.txt' -Confirm:$false } |
                Should -Throw "*'.json' extension*"
            Should -Invoke Connect-Unifi -Times 0 -Exactly
        }

        It 'honors WhatIf before connecting for guest actions' {
            $siteId = [guid]'00000000-0000-0000-0000-000000000001'
            $clientId = [guid]'00000000-0000-0000-0000-000000000002'

            $null = Invoke-UnifiOperation -BaseUrl 'https://controller.test' -ApiKey $script:TestApiKey -Action AuthorizeGuest -SiteId $siteId -ClientId $clientId -WhatIf

            Should -Invoke Connect-Unifi -Times 0 -Exactly
        }
    }
}

Describe 'Standalone script preflight' {
    It 'preserves the actual BaseUrl validation error in a clean invocation' {
        $apiKey = ConvertTo-SecureString 'test-api-key' -AsPlainText -Force
        { & $ScriptPath -BaseUrl 'http://controller.test' -ApiKey $apiKey -Action Test -Confirm:$false } |
            Should -Throw '*must use HTTPS*'
    }

    It 'validates export requirements before any connection attempt' {
        $apiKey = ConvertTo-SecureString 'test-api-key' -AsPlainText -Force
        { & $ScriptPath -BaseUrl 'https://controller.test' -ApiKey $apiKey -Action ExportSites -OutputPath 'wrong.txt' -Confirm:$false } |
            Should -Throw "*'.json' extension*"
    }
}
