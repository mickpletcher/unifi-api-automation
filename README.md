# UnifiOps

UnifiOps is a modular automation and API toolkit for UniFi networks, built with PowerShell and designed for AI-driven workflows. It enables secure authentication, inventory, monitoring, and control with seamless integration into MCP servers and automation pipelines.

## Quick Action Index

| Action | Example |
| --- | --- |
| Test | [Run](#run) |
| GetClients | [Get Clients](#get-clients) |
| BlockClient | [Block Client](#block-client) |
| UnblockClient | [Unblock Client](#unblock-client) |

## Run

Use `Get-Credential` for secure username and password input.

```powershell
$credential = Get-Credential -Message "Enter UniFi credentials"

.\UnifiOps.ps1 `
  -BaseUrl "https://unifi.example.com" `
  -Credential $credential `
  -Action Test
```

## More Examples

### Get Clients

```powershell
$credential = Get-Credential -Message "Enter UniFi credentials"

.\UnifiOps.ps1 `
  -BaseUrl "https://unifi.example.com" `
  -Credential $credential `
  -Action GetClients `
  -Site "default"
```

### Machine List Examples

Get all machines with a smaller set of useful fields.

```powershell
$credential = Get-Credential -Message "Enter UniFi credentials"

(.\UnifiOps.ps1 `
  -BaseUrl "https://unifi.example.com" `
  -Credential $credential `
  -Action GetClients `
  -Site "default").data |
Select-Object name, hostname, ip, mac, oui, network, is_wired |
Format-Table -AutoSize
```

Get only active machines.

```powershell
$credential = Get-Credential -Message "Enter UniFi credentials"

(.\UnifiOps.ps1 `
  -BaseUrl "https://unifi.example.com" `
  -Credential $credential `
  -Action GetClients `
  -Site "default").data |
Where-Object { $_.last_seen -gt [DateTimeOffset]::UtcNow.AddMinutes(-15).ToUnixTimeSeconds() } |
Select-Object name, hostname, ip, mac, last_seen |
Format-Table -AutoSize
```

Find machines by name, hostname, or vendor text.

```powershell
$credential = Get-Credential -Message "Enter UniFi credentials"

(.\UnifiOps.ps1 `
  -BaseUrl "https://unifi.example.com" `
  -Credential $credential `
  -Action GetClients `
  -Site "default").data |
Where-Object {
  $_.name -match "meross" -or
  $_.hostname -match "meross" -or
  $_.oui -match "meross"
} |
Select-Object name, hostname, ip, mac, oui |
ConvertTo-Json -Depth 10
```

### Block Client

```powershell
$credential = Get-Credential -Message "Enter UniFi credentials"

.\UnifiOps.ps1 `
  -BaseUrl "https://unifi.example.com" `
  -Credential $credential `
  -Action BlockClient `
  -Site "default" `
  -MacAddress "aa:bb:cc:dd:ee:ff"
```

### Unblock Client

```powershell
$credential = Get-Credential -Message "Enter UniFi credentials"

.\UnifiOps.ps1 `
  -BaseUrl "https://unifi.example.com" `
  -Credential $credential `
  -Action UnblockClient `
  -Site "default" `
  -MacAddress "aa:bb:cc:dd:ee:ff"
```
