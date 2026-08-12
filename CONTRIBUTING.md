# Contributing

## Requirements

- PowerShell 7.0 or later
- Pester 6.0.1
- PSScriptAnalyzer 1.25.0

Install the pinned validation dependencies:

```powershell
Install-Module Pester -RequiredVersion 6.0.1 -Scope CurrentUser
Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser
```

## Validation

Run the full local gate before opening a pull request:

```powershell
./Invoke-Validation.ps1
```

The gate requires:

- Zero PSScriptAnalyzer errors or warnings
- All Pester tests passing
- At least 80 percent command coverage
- A valid module manifest

CI runs the same gate on Windows and Ubuntu.

## Live read-only validation

Live integration tests never perform guest access writes. Set the values only in the current process and run:

```powershell
$env:UNIFIOPS_BASE_URL = 'https://192.168.1.1'
$env:UNIFIOPS_API_KEY = '<temporary API key value>'
$env:UNIFIOPS_SKIP_CERTIFICATE_CHECK = 'true'

./Invoke-Validation.ps1 -Integration

Remove-Item Env:UNIFIOPS_API_KEY
```

Do not place controller addresses or API keys in tracked files, test output, issues, or pull requests.

## Pull requests

- Keep changes scoped.
- Update tests and documentation with behavior changes.
- Do not add private or undocumented UniFi endpoints.
- Use the official version-specific OpenAPI document as the source of truth.
- Update `CHANGELOG.md` for user-visible changes.
