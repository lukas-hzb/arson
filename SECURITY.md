# Security Policy

## Supported Versions

Only the most recent release receives security fixes. Preview and pre-release builds may be replaced without backports.

## Report a Vulnerability

Do not disclose vulnerabilities, exploit details, private signing information, or sensitive logs in a public issue.

1. Use GitHub's [private vulnerability report](https://github.com/lukas-hzb/arson/security/advisories/new).
2. If GitHub cannot create the report, contact the maintainer through the [GitHub profile](https://github.com/lukas-hzb) before sending technical details so a private channel can be arranged.
3. Include the affected version, impact, reproduction requirements, and a minimal proof of concept where safe.

Reports will be acknowledged as availability permits. Please allow time for investigation and a coordinated release before public disclosure.

## Scope

Security-sensitive areas include:

- Sparkle feed and archive verification
- Release signing and notarization
- Accessibility permission handling
- Global keyboard shortcut registration
- Preset persistence and local file handling

The repository never needs the private Sparkle key, Developer ID certificates, or notarization credentials. Any appearance of those secrets should be reported immediately.
