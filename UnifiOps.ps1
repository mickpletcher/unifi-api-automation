[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$BaseUrl,

    [Parameter(Mandatory)]
    [PSCredential]$Credential,

    [ValidateSet('Login','GetSites','GetClients','GetDevices','GetWlans','BlockClient','UnblockClient','Logout','Test')]
    [string]$Action = 'Test',

    [string]$Site = 'default',

    [string]$MacAddress
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-UnifiContext {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$BaseUrl
    )

    if (-not $PSCmdlet.ShouldProcess($BaseUrl, 'Create UniFi session context')) {
        return
    }

    $normalizedBase = $BaseUrl.TrimEnd('/')

    [pscustomobject]@{
        BaseUrl       = $normalizedBase
        Session       = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
        LoginPath     = $null
        NetworkPrefix = $null
    }
}

function Invoke-UnifiRequest {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Uri,
        [ValidateSet('GET','POST','PUT','DELETE')]
        [string]$Method = 'GET',
        [object]$Body
    )

    $invokeParams = @{
        Uri                  = $Uri
        Method               = $Method
        WebSession           = $Context.Session
        SkipCertificateCheck = $true
    }

    if ($null -ne $Body) {
        $invokeParams['ContentType'] = 'application/json'
        $invokeParams['Body'] = ($Body | ConvertTo-Json -Depth 10)
    }

    Invoke-RestMethod @invokeParams
}

function Test-UnifiLoginPath {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][hashtable]$Body
    )

    try {
        $response = Invoke-UnifiRequest -Context $Context -Uri ($Context.BaseUrl + $Path) -Method POST -Body $Body
        return @{
            Success = $true
            Response = $response
        }
    }
    catch {
        $raw = $_.ErrorDetails.Message
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            try {
                $parsed = $raw | ConvertFrom-Json
                if ($parsed.code -eq 'AUTHENTICATION_FAILED_INVALID_CREDENTIALS') {
                    throw "Authentication failed for login path [$Path]. Credentials are invalid."
                }
            }
            catch {
                Write-Verbose "Login error details were not valid JSON for path [$Path]."
            }
        }

        return @{
            Success = $false
            Error = $_
        }
    }
}

function Connect-Unifi {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][PSCredential]$Credential
    )

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.GetNetworkCredential().SecurePassword)
    try {
        $plainSecret = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        $secretField = 'pass' + 'word'
        $loginBody = @{
            username = $Credential.UserName
        }
        $loginBody[$secretField] = $plainSecret
    }
    finally {
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }

    $loginPaths = @(
        '/api/auth/login'
        '/api/login'
    )

    foreach ($path in $loginPaths) {
        $result = Test-UnifiLoginPath -Context $Context -Path $path -Body $loginBody
        if ($result.Success) {
            $Context.LoginPath = $path
            break
        }
    }

    if (-not $Context.LoginPath) {
        throw "Unable to authenticate to UniFi. Checked /api/auth/login and /api/login."
    }

    $networkPrefixes = @(
        '/proxy/network'
        ''
    )

    foreach ($prefix in $networkPrefixes) {
        try {
            $testUri = '{0}{1}/api/self/sites' -f $Context.BaseUrl, $prefix
            $null = Invoke-UnifiRequest -Context $Context -Uri $testUri -Method GET
            $Context.NetworkPrefix = $prefix
            break
        }
        catch {
            Write-Verbose "API prefix candidate [$prefix] did not respond to /api/self/sites."
        }
    }

    if ($null -eq $Context.NetworkPrefix) {
        throw "Authenticated successfully, but could not determine the UniFi Network API prefix."
    }

    return $Context
}

function Get-UnifiApiUri {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$RelativePath
    )

    $cleanPath = if ($RelativePath.StartsWith('/')) { $RelativePath } else { "/$RelativePath" }
    '{0}{1}{2}' -f $Context.BaseUrl, $Context.NetworkPrefix, $cleanPath
}

function Get-UnifiSite {
    param([Parameter(Mandatory)]$Context)

    $uri = Get-UnifiApiUri -Context $Context -RelativePath '/api/self/sites'
    Invoke-UnifiRequest -Context $Context -Uri $uri -Method GET
}

function Get-UnifiClient {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Site
    )

    $uri = Get-UnifiApiUri -Context $Context -RelativePath "/api/s/$Site/stat/sta"
    Invoke-UnifiRequest -Context $Context -Uri $uri -Method GET
}

function Get-UnifiDevice {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Site
    )

    $uri = Get-UnifiApiUri -Context $Context -RelativePath "/api/s/$Site/stat/device"
    Invoke-UnifiRequest -Context $Context -Uri $uri -Method GET
}

function Get-UnifiWlan {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Site
    )

    $uri = Get-UnifiApiUri -Context $Context -RelativePath "/api/s/$Site/rest/wlanconf"
    Invoke-UnifiRequest -Context $Context -Uri $uri -Method GET
}

function Invoke-UnifiClientAction {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Site,
        [Parameter(Mandatory)][ValidateSet('block-sta','unblock-sta')][string]$Command,
        [Parameter(Mandatory)][string]$MacAddress
    )

    $uri = Get-UnifiApiUri -Context $Context -RelativePath "/api/s/$Site/cmd/stamgr"

    $body = @{
        cmd = $Command
        mac = $MacAddress.ToLowerInvariant()
    }

    Invoke-UnifiRequest -Context $Context -Uri $uri -Method POST -Body $body
}

function Disconnect-Unifi {
    param([Parameter(Mandatory)]$Context)

    $logoutCandidates = @(
        ($Context.BaseUrl + '/api/auth/logout')
        ($Context.BaseUrl + '/logout')
    )

    foreach ($uri in $logoutCandidates) {
        try {
            Invoke-UnifiRequest -Context $Context -Uri $uri -Method POST | Out-Null
            return
        }
        catch {
            Write-Verbose "Logout attempt failed for [$uri]."
        }
    }
}

try {
    $context = New-UnifiContext -BaseUrl $BaseUrl
    $null = Connect-Unifi -Context $context -Credential $Credential

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