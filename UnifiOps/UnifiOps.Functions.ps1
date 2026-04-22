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
            Success  = $true
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
            Error   = $_
        }
    }
}

function Connect-Unifi {
    <#
    .SYNOPSIS
    Authenticates to a UniFi controller and returns a session context.

    .EXAMPLE
    $ctx = Connect-Unifi -BaseUrl 'https://192.168.1.1' -Credential (Get-Credential)
    #>
    param(
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][PSCredential]$Credential
    )

    $context = New-UnifiContext -BaseUrl $BaseUrl

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
        $result = Test-UnifiLoginPath -Context $context -Path $path -Body $loginBody
        if ($result.Success) {
            $context.LoginPath = $path
            break
        }
    }

    if (-not $context.LoginPath) {
        throw "Unable to authenticate to UniFi. Checked /api/auth/login and /api/login."
    }

    $networkPrefixes = @(
        '/proxy/network'
        ''
    )

    foreach ($prefix in $networkPrefixes) {
        try {
            $testUri = '{0}{1}/api/self/sites' -f $context.BaseUrl, $prefix
            $null = Invoke-UnifiRequest -Context $context -Uri $testUri -Method GET
            $context.NetworkPrefix = $prefix
            break
        }
        catch {
            Write-Verbose "API prefix candidate [$prefix] did not respond to /api/self/sites."
        }
    }

    if ($null -eq $context.NetworkPrefix) {
        throw "Authenticated successfully, but could not determine the UniFi Network API prefix."
    }

    return $context
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
    <#
    .SYNOPSIS
    Returns all sites on the controller.

    .EXAMPLE
    $sites = Get-UnifiSite -Context $ctx
    #>
    param([Parameter(Mandatory)]$Context)

    $uri = Get-UnifiApiUri -Context $Context -RelativePath '/api/self/sites'
    Invoke-UnifiRequest -Context $Context -Uri $uri -Method GET
}

function Get-UnifiClient {
    <#
    .SYNOPSIS
    Returns connected clients for a site.

    .EXAMPLE
    $clients = Get-UnifiClient -Context $ctx -Site 'default'
    #>
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Site
    )

    $uri = Get-UnifiApiUri -Context $Context -RelativePath "/api/s/$Site/stat/sta"
    Invoke-UnifiRequest -Context $Context -Uri $uri -Method GET
}

function Get-UnifiDevice {
    <#
    .SYNOPSIS
    Returns network devices for a site.

    .EXAMPLE
    $devices = Get-UnifiDevice -Context $ctx -Site 'default'
    #>
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Site
    )

    $uri = Get-UnifiApiUri -Context $Context -RelativePath "/api/s/$Site/stat/device"
    Invoke-UnifiRequest -Context $Context -Uri $uri -Method GET
}

function Get-UnifiWlan {
    <#
    .SYNOPSIS
    Returns WLAN configurations for a site.

    .EXAMPLE
    $wlans = Get-UnifiWlan -Context $ctx -Site 'default'
    #>
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Site
    )

    $uri = Get-UnifiApiUri -Context $Context -RelativePath "/api/s/$Site/rest/wlanconf"
    Invoke-UnifiRequest -Context $Context -Uri $uri -Method GET
}

function Invoke-UnifiClientAction {
    <#
    .SYNOPSIS
    Blocks or unblocks a client by MAC address.

    .EXAMPLE
    Invoke-UnifiClientAction -Context $ctx -Site 'default' -Command 'block-sta' -MacAddress 'aa:bb:cc:dd:ee:ff'
    #>
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

function Export-UnifiData {
    <#
    .SYNOPSIS
    Writes data to a JSON or CSV file at the specified output path.

    .EXAMPLE
    Export-UnifiData -Data $clients -OutputPath '.\clients.json' -OutputFormat 'Json'
    #>
    param(
        [Parameter(Mandatory)]$Data,
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][string]$OutputFormat
    )

    $dir = Split-Path -Path $OutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -Path $dir)) {
        $null = New-Item -ItemType Directory -Path $dir -Force
    }

    if ($OutputFormat -eq 'Csv') {
        $Data | Export-Csv -Path $OutputPath -NoTypeInformation -Force
    }
    else {
        $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Force
    }
}

function Assert-ExportParameter {
    param(
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][string]$OutputFormat,
        [string]$OutputPath
    )

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        throw "-OutputPath is required for $Action."
    }

    # GetInvalidPathChars() returns only control chars and pipe on Windows.
    # Combining with GetInvalidFileNameChars() and removing valid path separators covers the full set.
    $validInPath = [char[]]@('\', '/', ':')
    $invalidChars = ([System.IO.Path]::GetInvalidFileNameChars() + [System.IO.Path]::GetInvalidPathChars()) |
        Select-Object -Unique |
        Where-Object { $validInPath -notcontains $_ }
    $foundInvalid = $invalidChars | Where-Object { $OutputPath.Contains([string]$_) }
    if ($foundInvalid) {
        $charList = ($foundInvalid | ForEach-Object { "[$_]" }) -join ' '
        throw "OutputPath '$OutputPath': contains invalid characters $charList."
    }

    $qualifier = Split-Path -Path $OutputPath -Qualifier -ErrorAction SilentlyContinue
    if (-not [string]::IsNullOrWhiteSpace($qualifier) -and -not (Test-Path -Path $qualifier)) {
        throw "OutputPath '$OutputPath': drive '$qualifier' is not available."
    }

    if (Test-Path -Path $OutputPath -PathType Container) {
        throw "OutputPath '$OutputPath': must target a file, not a directory."
    }

    $ext = [System.IO.Path]::GetExtension($OutputPath).ToLower()
    $expectedExt = if ($OutputFormat -eq 'Json') { '.json' } else { '.csv' }
    if ($ext -ne $expectedExt) {
        Write-Warning "OutputPath '$OutputPath': extension '$ext' does not match OutputFormat '$OutputFormat'. Expected '$expectedExt'."
    }
}

function Disconnect-Unifi {
    <#
    .SYNOPSIS
    Logs out of a UniFi session and closes the web session.

    .EXAMPLE
    Disconnect-Unifi -Context $ctx
    #>
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
