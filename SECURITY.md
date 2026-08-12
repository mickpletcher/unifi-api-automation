# Security Policy

## Supported version

Only the latest major version is supported with security fixes.

| Version | Supported |
| --- | --- |
| 2.x | Yes |
| 1.x | No |

## Reporting

Report security issues through a private GitHub Security Advisory for this repository. Do not open a public issue containing credentials, controller addresses, exported inventory, or exploit details.

## Credential handling

- Pass API keys as SecureString values.
- Do not place API keys directly in scripts, command history, configuration files, test fixtures, or GitHub Actions logs.
- Prefer a secret manager for scheduled automation.
- Rotate an API key immediately if it may have been exposed.

## TLS

Certificate validation is enabled by default. `SkipCertificateCheck` is intended only for a trusted local network with a known self-signed console certificate.
