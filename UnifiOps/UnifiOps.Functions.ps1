$script:UnifiOpsVersion = '2.0.0'

function Initialize-UnifiContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$BaseUrl,

        [Parameter(Mandatory)]
        [securestring]$ApiKey,

        [ValidateRange(1, 10)]
        [int]$MaxAttempts = 3,

        [ValidateRange(1, 300)]
        [int]$TimeoutSec = 30,

        [ValidateRange(1, 200)]
        [int]$PageSize = 200,

        [switch]$SkipCertificateCheck
    )

    if (-not $BaseUrl.IsAbsoluteUri) {
        throw 'BaseUrl must be an absolute HTTPS URI.'
    }

    if ($BaseUrl.Scheme -ne 'https') {
        throw "BaseUrl must use HTTPS. Received '$($BaseUrl.Scheme)'."
    }

    if (-not [string]::IsNullOrEmpty($BaseUrl.UserInfo) -or
        -not [string]::IsNullOrEmpty($BaseUrl.Query) -or
        -not [string]::IsNullOrEmpty($BaseUrl.Fragment)) {
        throw 'BaseUrl cannot contain user information, a query string, or a fragment.'
    }

    if ($BaseUrl.AbsolutePath.Trim('/') -ne '') {
        throw 'BaseUrl must be the UniFi console root without an API path.'
    }

    $normalizedBaseUrl = $BaseUrl.GetLeftPart([System.UriPartial]::Authority)

    [pscustomobject]@{
        PSTypeName           = 'UnifiOps.Context'
        BaseUrl              = $normalizedBaseUrl
        ApiRoot              = "$normalizedBaseUrl/proxy/network/integration"
        ApiKey               = $ApiKey
        MaxAttempts          = $MaxAttempts
        TimeoutSec           = $TimeoutSec
        PageSize             = $PageSize
        SkipCertificateCheck = [bool]$SkipCertificateCheck
        ApplicationInfo      = $null
    }
}

function Assert-UnifiContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Context
    )

    if ($Context.PSObject.TypeNames -notcontains 'UnifiOps.Context') {
        throw 'Context must be created by Connect-Unifi.'
    }

    foreach ($propertyName in 'ApiRoot', 'ApiKey', 'MaxAttempts', 'TimeoutSec', 'PageSize', 'SkipCertificateCheck') {
        if ($null -eq $Context.PSObject.Properties[$propertyName]) {
            throw "Context is missing required property '$propertyName'."
        }
    }
}

function Get-UnifiStatusCode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $statusProperty = $ErrorRecord.Exception.PSObject.Properties['StatusCode']
    if ($null -ne $statusProperty -and $null -ne $statusProperty.Value) {
        return [int]$statusProperty.Value
    }

    $responseProperty = $ErrorRecord.Exception.PSObject.Properties['Response']
    if ($null -ne $responseProperty -and $null -ne $responseProperty.Value) {
        $responseStatusProperty = $responseProperty.Value.PSObject.Properties['StatusCode']
        if ($null -ne $responseStatusProperty -and $null -ne $responseStatusProperty.Value) {
            return [int]$responseStatusProperty.Value
        }
    }

    0
}

function Get-UnifiRetryDelay {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter(Mandatory)]
        [ValidateRange(1, 10)]
        [int]$Attempt
    )

    $responseProperty = $ErrorRecord.Exception.PSObject.Properties['Response']
    if ($null -ne $responseProperty -and $null -ne $responseProperty.Value) {
        $headersProperty = $responseProperty.Value.PSObject.Properties['Headers']
        if ($null -ne $headersProperty -and $null -ne $headersProperty.Value) {
            $retryAfterProperty = $headersProperty.Value.PSObject.Properties['RetryAfter']
            if ($null -ne $retryAfterProperty -and $null -ne $retryAfterProperty.Value) {
                $deltaProperty = $retryAfterProperty.Value.PSObject.Properties['Delta']
                if ($null -ne $deltaProperty -and $null -ne $deltaProperty.Value) {
                    return [Math]::Min(60, [Math]::Max(0, $deltaProperty.Value.TotalSeconds))
                }
            }
        }
    }

    $baseDelay = [Math]::Min(30, [Math]::Pow(2, $Attempt - 1))
    $baseDelay + [Math]::Round([System.Random]::Shared.NextDouble(), 3)
}

function Invoke-UnifiRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Context,

        [Parameter(Mandatory)]
        [ValidatePattern('^/v1(?:/|$)')]
        [string]$RelativePath,

        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')]
        [string]$Method = 'GET',

        [object]$Body
    )

    Assert-UnifiContext -Context $Context

    $uri = [uri]("$($Context.ApiRoot)$RelativePath")
    $bstr = [IntPtr]::Zero
    $plainApiKey = $null
    $headers = $null

    try {
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Context.ApiKey)
        $plainApiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        $headers = @{
            Accept      = 'application/json'
            'X-API-Key' = $plainApiKey
        }

        $invokeParameters = @{
            Uri         = $uri
            Method      = $Method
            Headers     = $headers
            TimeoutSec  = $Context.TimeoutSec
            UserAgent   = "UnifiOps/$script:UnifiOpsVersion"
            ErrorAction = 'Stop'
        }

        if ($Context.SkipCertificateCheck) {
            $invokeParameters['SkipCertificateCheck'] = $true
        }

        if ($null -ne $Body) {
            $invokeParameters['ContentType'] = 'application/json'
            $invokeParameters['Body'] = ConvertTo-Json -InputObject $Body -Depth 20 -Compress
        }

        for ($attempt = 1; $attempt -le $Context.MaxAttempts; $attempt++) {
            try {
                return Invoke-RestMethod @invokeParameters
            }
            catch {
                $statusCode = Get-UnifiStatusCode -ErrorRecord $_
                $isTransientStatus = $statusCode -in 408, 425, 429, 500, 502, 503, 504
                $isNetworkFailure = $statusCode -eq 0
                $canRetry = $Method -eq 'GET' -and
                    ($isTransientStatus -or $isNetworkFailure) -and
                    $attempt -lt $Context.MaxAttempts

                if (-not $canRetry) {
                    throw
                }

                $delaySeconds = Get-UnifiRetryDelay -ErrorRecord $_ -Attempt $attempt
                Write-Warning "UniFi API request failed on attempt $attempt of $($Context.MaxAttempts). Retrying in $delaySeconds seconds."
                Start-Sleep -Milliseconds ([int]($delaySeconds * 1000))
            }
        }
    }
    finally {
        if ($null -ne $headers) {
            $headers['X-API-Key'] = ''
        }
        $plainApiKey = $null
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}

function Get-UnifiPagedData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Context,

        [Parameter(Mandatory)]
        [ValidatePattern('^/v1(?:/|$)')]
        [string]$RelativePath,

        [string]$Filter
    )

    Assert-UnifiContext -Context $Context

    $items = [System.Collections.Generic.List[object]]::new()
    [long]$offset = 0

    do {
        $query = "offset=$offset&limit=$($Context.PageSize)"
        if (-not [string]::IsNullOrWhiteSpace($Filter)) {
            $query += '&filter=' + [uri]::EscapeDataString($Filter)
        }

        $separator = if ($RelativePath.Contains('?')) { '&' } else { '?' }
        $response = Invoke-UnifiRequest -Context $Context -RelativePath "$RelativePath$separator$query"

        foreach ($propertyName in 'offset', 'limit', 'count', 'totalCount', 'data') {
            if ($null -eq $response.PSObject.Properties[$propertyName]) {
                throw "UniFi API pagination response is missing '$propertyName'."
            }
        }

        $pageItems = @()
        if ($null -ne $response.data) {
            $pageItems = @($response.data)
        }
        foreach ($item in $pageItems) {
            $items.Add($item)
        }

        [long]$totalCount = $response.totalCount
        if ($items.Count -ge $totalCount) {
            break
        }

        if ($pageItems.Count -eq 0) {
            throw "UniFi API pagination stopped at offset $offset before totalCount $totalCount was reached."
        }

        $offset += $pageItems.Count
    } while ($true)

    $items.ToArray()
}

function Connect-Unifi {
    <#
    .SYNOPSIS
    Creates a secure UniFi API context and validates it against the official application information endpoint.

    .EXAMPLE
    $apiKey = Read-Host 'UniFi API key' -AsSecureString
    $context = Connect-Unifi -BaseUrl 'https://192.168.1.1' -ApiKey $apiKey
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$BaseUrl,

        [Parameter(Mandatory)]
        [securestring]$ApiKey,

        [ValidateRange(1, 10)]
        [int]$MaxAttempts = 3,

        [ValidateRange(1, 300)]
        [int]$TimeoutSec = 30,

        [ValidateRange(1, 200)]
        [int]$PageSize = 200,

        [switch]$SkipCertificateCheck
    )

    $context = Initialize-UnifiContext @PSBoundParameters
    $context.ApplicationInfo = Invoke-UnifiRequest -Context $context -RelativePath '/v1/info'
    $context
}

function Get-UnifiSite {
    <#
    .SYNOPSIS
    Returns all local UniFi sites available to the API key.

    .EXAMPLE
    $sites = @(Get-UnifiSite -Context $context)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Context,

        [string]$Filter
    )

    Get-UnifiPagedData -Context $Context -RelativePath '/v1/sites' -Filter $Filter
}

function Get-UnifiClient {
    <#
    .SYNOPSIS
    Returns all connected clients for a UniFi site.

    .EXAMPLE
    $clients = @(Get-UnifiClient -Context $context -SiteId '00000000-0000-0000-0000-000000000001')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Context,

        [Parameter(Mandatory)]
        [guid]$SiteId,

        [string]$Filter
    )

    Get-UnifiPagedData -Context $Context -RelativePath "/v1/sites/$($SiteId.ToString('D'))/clients" -Filter $Filter
}

function Get-UnifiDevice {
    <#
    .SYNOPSIS
    Returns all adopted devices for a UniFi site.

    .EXAMPLE
    $devices = @(Get-UnifiDevice -Context $context -SiteId '00000000-0000-0000-0000-000000000001')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Context,

        [Parameter(Mandatory)]
        [guid]$SiteId,

        [string]$Filter
    )

    Get-UnifiPagedData -Context $Context -RelativePath "/v1/sites/$($SiteId.ToString('D'))/devices" -Filter $Filter
}

function Get-UnifiWlan {
    <#
    .SYNOPSIS
    Returns all WiFi broadcasts for a UniFi site.

    .EXAMPLE
    $wlans = @(Get-UnifiWlan -Context $context -SiteId '00000000-0000-0000-0000-000000000001')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Context,

        [Parameter(Mandatory)]
        [guid]$SiteId,

        [string]$Filter
    )

    Get-UnifiPagedData -Context $Context -RelativePath "/v1/sites/$($SiteId.ToString('D'))/wifi/broadcasts" -Filter $Filter
}

function Invoke-UnifiGuestAccess {
    <#
    .SYNOPSIS
    Authorizes or unauthorizes guest access for a connected client.

    .EXAMPLE
    Invoke-UnifiGuestAccess -Context $context -SiteId $siteId -ClientId $clientId -Action Authorize -TimeLimitMinutes 120
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [psobject]$Context,

        [Parameter(Mandatory)]
        [guid]$SiteId,

        [Parameter(Mandatory)]
        [guid]$ClientId,

        [Parameter(Mandatory)]
        [ValidateSet('Authorize', 'Unauthorize')]
        [string]$Action,

        [ValidateRange(1, 1000000)]
        [long]$TimeLimitMinutes,

        [ValidateRange(1, 1048576)]
        [long]$DataUsageLimitMBytes,

        [ValidateRange(2, 100000)]
        [long]$RxRateLimitKbps,

        [ValidateRange(2, 100000)]
        [long]$TxRateLimitKbps
    )

    Assert-UnifiContext -Context $Context

    $limitParameters = 'TimeLimitMinutes', 'DataUsageLimitMBytes', 'RxRateLimitKbps', 'TxRateLimitKbps'
    if ($Action -eq 'Unauthorize' -and ($limitParameters | Where-Object { $PSBoundParameters.ContainsKey($_) })) {
        throw 'Guest access limits can only be used with the Authorize action.'
    }

    $body = [ordered]@{
        action = if ($Action -eq 'Authorize') { 'AUTHORIZE_GUEST_ACCESS' } else { 'UNAUTHORIZE_GUEST_ACCESS' }
    }

    if ($Action -eq 'Authorize') {
        foreach ($parameterName in $limitParameters) {
            if ($PSBoundParameters.ContainsKey($parameterName)) {
                $body[$parameterName.Substring(0, 1).ToLowerInvariant() + $parameterName.Substring(1)] = $PSBoundParameters[$parameterName]
            }
        }
    }

    $target = "$($SiteId.ToString('D'))/$($ClientId.ToString('D'))"
    if ($PSCmdlet.ShouldProcess($target, "$Action UniFi guest access")) {
        $relativePath = "/v1/sites/$($SiteId.ToString('D'))/clients/$($ClientId.ToString('D'))/actions"
        Invoke-UnifiRequest -Context $Context -RelativePath $relativePath -Method POST -Body $body
    }
}

function Resolve-UnifiOutputPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [ValidateSet('Json', 'Csv')]
        [string]$OutputFormat,

        [switch]$Force
    )

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        throw 'OutputPath cannot be empty.'
    }

    $expectedExtension = if ($OutputFormat -eq 'Json') { '.json' } else { '.csv' }
    $actualExtension = [IO.Path]::GetExtension($OutputPath)
    if ($actualExtension -ne $expectedExtension) {
        throw "OutputPath must use the '$expectedExtension' extension for $OutputFormat output."
    }

    $provider = $null
    $drive = $null
    try {
        $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
            $OutputPath,
            [ref]$provider,
            [ref]$drive
        )
    }
    catch {
        throw "OutputPath '$OutputPath' is invalid: $($_.Exception.Message)"
    }

    if ($provider.Name -ne 'FileSystem') {
        throw "OutputPath '$OutputPath' must use the FileSystem provider."
    }

    $root = [IO.Path]::GetPathRoot($fullPath)
    if ([string]::IsNullOrWhiteSpace($root) -or -not [IO.Directory]::Exists($root)) {
        throw "OutputPath '$OutputPath' has an unavailable filesystem root."
    }

    $relativeToRoot = $fullPath.Substring($root.Length)
    $segments = $relativeToRoot.Split([IO.Path]::DirectorySeparatorChar, [System.StringSplitOptions]::RemoveEmptyEntries)
    $invalidNameCharacters = [IO.Path]::GetInvalidFileNameChars()
    foreach ($segment in $segments) {
        if ($segment.IndexOfAny($invalidNameCharacters) -ge 0) {
            throw "OutputPath '$OutputPath' contains invalid filename characters."
        }
    }

    if (Test-Path -LiteralPath $fullPath -PathType Container) {
        throw "OutputPath '$OutputPath' must target a file, not a directory."
    }

    if ((Test-Path -LiteralPath $fullPath -PathType Leaf) -and -not $Force) {
        throw "OutputPath '$OutputPath' already exists. Use -Force to overwrite it."
    }

    $fullPath
}

function Export-UnifiData {
    <#
    .SYNOPSIS
    Atomically writes UniFi data as a stable JSON array or CSV file.

    .EXAMPLE
    Export-UnifiData -Data $clients -OutputPath '.\clients.json' -OutputFormat Json
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Data,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [ValidateSet('Json', 'Csv')]
        [string]$OutputFormat,

        [switch]$Force
    )

    $fullPath = Resolve-UnifiOutputPath -OutputPath $OutputPath -OutputFormat $OutputFormat -Force:$Force
    if (-not $PSCmdlet.ShouldProcess($fullPath, "Export $($Data.Count) UniFi items as $OutputFormat")) {
        return
    }

    $directory = [IO.Path]::GetDirectoryName($fullPath)
    if (-not [IO.Directory]::Exists($directory)) {
        $null = [IO.Directory]::CreateDirectory($directory)
    }

    $temporaryPath = [IO.Path]::Combine($directory, ".unifiops-$([guid]::NewGuid().ToString('N')).tmp")
    $utf8NoBom = [Text.UTF8Encoding]::new($false)

    try {
        if ($OutputFormat -eq 'Json') {
            $json = ConvertTo-Json -InputObject $Data -Depth 20
            [IO.File]::WriteAllText($temporaryPath, $json, $utf8NoBom)
        }
        elseif ($Data.Count -eq 0) {
            [IO.File]::WriteAllText($temporaryPath, '', $utf8NoBom)
        }
        else {
            $Data | Export-Csv -LiteralPath $temporaryPath -NoTypeInformation -Encoding utf8
        }

        if ([IO.File]::Exists($fullPath)) {
            if (-not $Force) {
                throw "OutputPath '$OutputPath' was created by another process. Use -Force to overwrite it."
            }
            [IO.File]::Move($temporaryPath, $fullPath, $true)
        }
        else {
            [IO.File]::Move($temporaryPath, $fullPath)
        }
    }
    finally {
        if ([IO.File]::Exists($temporaryPath)) {
            [IO.File]::Delete($temporaryPath)
        }
    }

    [pscustomobject]@{
        OutputPath   = $fullPath
        OutputFormat = $OutputFormat
        ItemCount    = $Data.Count
    }
}

function Write-UnifiResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [AllowNull()]
        [object]$Data,

        [AllowNull()]
        [Nullable[int]]$ItemCount
    )

    [pscustomobject]@{
        Success   = $true
        Action    = $Action
        Data      = $Data
        ItemCount = $ItemCount
    }
}

function Invoke-UnifiOperation {
    <#
    .SYNOPSIS
    Runs a supported UniFi query, guest access action, or export with a consistent result object.

    .EXAMPLE
    Invoke-UnifiOperation -BaseUrl 'https://192.168.1.1' -ApiKey $apiKey -Action GetSites
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

    $siteActions = 'GetClients', 'GetDevices', 'GetWlans', 'AuthorizeGuest', 'UnauthorizeGuest',
        'ExportClients', 'ExportDevices', 'ExportWlans'
    $clientActions = 'AuthorizeGuest', 'UnauthorizeGuest'
    $exportActions = 'ExportSites', 'ExportClients', 'ExportDevices', 'ExportWlans'
    $guestLimitParameters = 'TimeLimitMinutes', 'DataUsageLimitMBytes', 'RxRateLimitKbps', 'TxRateLimitKbps'

    if ($Action -in $siteActions -and $SiteId -eq [guid]::Empty) {
        throw "SiteId is required for $Action. Run GetSites to obtain the official site UUID."
    }

    if ($Action -in $clientActions -and $ClientId -eq [guid]::Empty) {
        throw "ClientId is required for $Action. Run GetClients to obtain the official client UUID."
    }

    if ($Action -eq 'UnauthorizeGuest' -and ($guestLimitParameters | Where-Object { $PSBoundParameters.ContainsKey($_) })) {
        throw 'Guest access limits can only be used with AuthorizeGuest.'
    }

    $validatedOutputPath = $null
    if ($Action -in $exportActions) {
        $validatedOutputPath = Resolve-UnifiOutputPath -OutputPath $OutputPath -OutputFormat $OutputFormat -Force:$Force
        if (-not $PSCmdlet.ShouldProcess($validatedOutputPath, "Run $Action")) {
            return
        }
    }

    if ($Action -in $clientActions) {
        $guestTarget = "$($SiteId.ToString('D'))/$($ClientId.ToString('D'))"
        if (-not $PSCmdlet.ShouldProcess($guestTarget, "Run $Action")) {
            return
        }
    }

    $connectParameters = @{
        BaseUrl              = $BaseUrl
        ApiKey               = $ApiKey
        MaxAttempts          = $MaxAttempts
        TimeoutSec           = $TimeoutSec
        PageSize             = $PageSize
        SkipCertificateCheck = $SkipCertificateCheck
    }
    $context = Connect-Unifi @connectParameters

    switch ($Action) {
        'Test' {
            $data = [pscustomobject]@{
                BaseUrl         = $context.BaseUrl
                ApiRoot         = $context.ApiRoot
                ApplicationInfo = $context.ApplicationInfo
            }
            Write-UnifiResult -Action $Action -Data $data -ItemCount $null
        }

        'GetSites' {
            $items = @(Get-UnifiSite -Context $context -Filter $Filter)
            Write-UnifiResult -Action $Action -Data ([object[]]$items) -ItemCount $items.Count
        }

        'GetClients' {
            $items = @(Get-UnifiClient -Context $context -SiteId $SiteId -Filter $Filter)
            Write-UnifiResult -Action $Action -Data ([object[]]$items) -ItemCount $items.Count
        }

        'GetDevices' {
            $items = @(Get-UnifiDevice -Context $context -SiteId $SiteId -Filter $Filter)
            Write-UnifiResult -Action $Action -Data ([object[]]$items) -ItemCount $items.Count
        }

        'GetWlans' {
            $items = @(Get-UnifiWlan -Context $context -SiteId $SiteId -Filter $Filter)
            Write-UnifiResult -Action $Action -Data ([object[]]$items) -ItemCount $items.Count
        }

        'AuthorizeGuest' {
            $guestParameters = @{
                Context  = $context
                SiteId   = $SiteId
                ClientId = $ClientId
                Action   = 'Authorize'
                Confirm  = $false
            }
            foreach ($parameterName in $guestLimitParameters) {
                if ($PSBoundParameters.ContainsKey($parameterName)) {
                    $guestParameters[$parameterName] = $PSBoundParameters[$parameterName]
                }
            }
            $response = Invoke-UnifiGuestAccess @guestParameters
            Write-UnifiResult -Action $Action -Data $response -ItemCount $null
        }

        'UnauthorizeGuest' {
            $response = Invoke-UnifiGuestAccess -Context $context -SiteId $SiteId -ClientId $ClientId -Action Unauthorize -Confirm:$false
            Write-UnifiResult -Action $Action -Data $response -ItemCount $null
        }

        'ExportSites' {
            $items = @(Get-UnifiSite -Context $context -Filter $Filter)
            $export = Export-UnifiData -Data $items -OutputPath $validatedOutputPath -OutputFormat $OutputFormat -Force:$Force -Confirm:$false
            Write-UnifiResult -Action $Action -Data $export -ItemCount $items.Count
        }

        'ExportClients' {
            $items = @(Get-UnifiClient -Context $context -SiteId $SiteId -Filter $Filter)
            $export = Export-UnifiData -Data $items -OutputPath $validatedOutputPath -OutputFormat $OutputFormat -Force:$Force -Confirm:$false
            Write-UnifiResult -Action $Action -Data $export -ItemCount $items.Count
        }

        'ExportDevices' {
            $items = @(Get-UnifiDevice -Context $context -SiteId $SiteId -Filter $Filter)
            $export = Export-UnifiData -Data $items -OutputPath $validatedOutputPath -OutputFormat $OutputFormat -Force:$Force -Confirm:$false
            Write-UnifiResult -Action $Action -Data $export -ItemCount $items.Count
        }

        'ExportWlans' {
            $items = @(Get-UnifiWlan -Context $context -SiteId $SiteId -Filter $Filter)
            $export = Export-UnifiData -Data $items -OutputPath $validatedOutputPath -OutputFormat $OutputFormat -Force:$Force -Confirm:$false
            Write-UnifiResult -Action $Action -Data $export -ItemCount $items.Count
        }
    }
}
