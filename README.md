# UnifiOps

PowerShell script for automating UniFi network operations via the UniFi REST API. Handles authentication, inventory queries, client control, and file exports.

## Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| `-BaseUrl` | Always | UniFi controller URL, e.g. `https://192.168.1.1` |
| `-Credential` | Always | PSCredential for UniFi login |
| `-Action` | No | Action to run. Default is `Test` |
| `-Site` | No | Site identifier. Default is `default` |
| `-MacAddress` | For client actions | Client MAC address |
| `-OutputPath` | For export actions | File path for export output |
| `-OutputFormat` | For export actions | `Json` or `Csv`. Default is `Json` |

## Action Index

| Action | Description |
| --- | --- |
| `Test` | Verify connection and return site count |
| `Login` | Authenticate and return connection info |
| `GetSites` | List all sites |
| `GetClients` | List connected clients for a site |
| `GetDevices` | List network devices for a site |
| `GetWlans` | List WLAN configurations for a site |
| `BlockClient` | Block a client by MAC address |
| `UnblockClient` | Unblock a client by MAC address |
| `ExportSites` | Export sites to JSON or CSV |
| `ExportClients` | Export clients to JSON or CSV |
| `ExportDevices` | Export devices to JSON or CSV |
| `ExportWlans` | Export WLANs to JSON or CSV |
| `Logout` | Log out of the current session |

## Examples

### Test Connection

```powershell
$credential = Get-Credential

.\UnifiOps.ps1 `
  -BaseUrl "https://192.168.1.1" `
  -Credential $credential `
  -Action Test
```

### Get Clients

```powershell
$credential = Get-Credential

.\UnifiOps.ps1 `
  -BaseUrl "https://192.168.1.1" `
  -Credential $credential `
  -Action GetClients `
  -Site "default"
```

### Get Clients as Readable JSON

```powershell
$credential = Get-Credential

(.\UnifiOps.ps1 `
  -BaseUrl "https://192.168.1.1" `
  -Credential $credential `
  -Action GetClients).Data | ConvertTo-Json -Depth 10
```

### Get Clients with Selected Fields

```powershell
$credential = Get-Credential

(.\UnifiOps.ps1 `
  -BaseUrl "https://192.168.1.1" `
  -Credential $credential `
  -Action GetClients).Data |
Select-Object name, hostname, ip, mac, oui, network, is_wired |
Format-Table -AutoSize
```

### Get Active Clients

Clients seen within the last 15 minutes.

```powershell
$credential = Get-Credential

(.\UnifiOps.ps1 `
  -BaseUrl "https://192.168.1.1" `
  -Credential $credential `
  -Action GetClients).Data |
Where-Object { $_.last_seen -gt [DateTimeOffset]::UtcNow.AddMinutes(-15).ToUnixTimeSeconds() } |
Select-Object name, hostname, ip, mac, last_seen |
Format-Table -AutoSize
```

### Search Clients by Name or Vendor

```powershell
$credential = Get-Credential

(.\UnifiOps.ps1 `
  -BaseUrl "https://192.168.1.1" `
  -Credential $credential `
  -Action GetClients).Data |
Where-Object {
  $_.name -match "apple" -or
  $_.hostname -match "apple" -or
  $_.oui -match "apple"
} |
Select-Object name, hostname, ip, mac, oui |
Format-Table -AutoSize
```

### Export Clients to JSON

```powershell
$credential = Get-Credential

.\UnifiOps.ps1 `
  -BaseUrl "https://192.168.1.1" `
  -Credential $credential `
  -Action ExportClients `
  -OutputPath ".\clients.json"
```

### Export Clients to CSV

```powershell
$credential = Get-Credential

.\UnifiOps.ps1 `
  -BaseUrl "https://192.168.1.1" `
  -Credential $credential `
  -Action ExportClients `
  -OutputFormat Csv `
  -OutputPath ".\clients.csv"
```

### Export Devices to JSON

```powershell
$credential = Get-Credential

.\UnifiOps.ps1 `
  -BaseUrl "https://192.168.1.1" `
  -Credential $credential `
  -Action ExportDevices `
  -OutputPath "C:\Reports\devices.json"
```

### Block a Client

```powershell
$credential = Get-Credential

.\UnifiOps.ps1 `
  -BaseUrl "https://192.168.1.1" `
  -Credential $credential `
  -Action BlockClient `
  -MacAddress "aa:bb:cc:dd:ee:ff"
```

### Unblock a Client

```powershell
$credential = Get-Credential

.\UnifiOps.ps1 `
  -BaseUrl "https://192.168.1.1" `
  -Credential $credential `
  -Action UnblockClient `
  -MacAddress "aa:bb:cc:dd:ee:ff"
```

## Output Path Validation

Export actions validate `-OutputPath` before making any API call.

| Condition | Behavior |
| --- | --- |
| `-OutputPath` not provided | Terminates with error |
| Path contains invalid characters | Terminates with error naming the characters |
| Path points to an existing directory | Terminates with error |
| Drive or root does not exist | Terminates with error |
| File extension does not match `-OutputFormat` | Writes a warning and continues |

Parent directories are created automatically if they do not exist.
