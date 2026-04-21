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
