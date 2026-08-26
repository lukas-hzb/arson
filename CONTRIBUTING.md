# Contributing to Arson

Bug reports and focused feature proposals are welcome. Because Arson is proprietary source-available software, code contributions require prior written authorization from the maintainer before creating a public fork or submitting a pull request.

## Documentation and Commands

Keep `README.md` focused on installing and using Arson. Local development, testing, troubleshooting, and repository commands belong in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md). Signing, packaging, appcast, and publication commands belong in [docs/RELEASING.md](docs/RELEASING.md).

When adding a new contributor or maintainer workflow, extend the most relevant guide and link to it instead of duplicating command sequences in the README or this file.

## Report a Bug

Use the repository's bug report form and include:

- Arson version and build number
- macOS version and Mac architecture
- The affected application and whether its window was full screen
- Reproduction steps, expected behavior, and actual behavior
- Relevant logs with private information removed

Security vulnerabilities must follow [SECURITY.md](SECURITY.md) and must not be disclosed in a public issue.

## Propose a Feature

Open a feature request describing the user problem, the expected workflow, and any alternatives considered. Keep proposals focused on window management and Arson's native macOS scope.

## Submit an Authorized Change

1. Obtain written authorization from the maintainer for the proposed contribution and fork.
2. Create a focused branch from the latest `main`.
3. Follow [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for setup and tests.
4. Add or update tests for behavioral changes.
5. Use English Conventional Commits, for example `fix: ignore shortcuts in full screen`.
6. Open a pull request using the repository template.

Do not commit generated build products, credentials, signing material, exported Sparkle keys, or user-specific Xcode data.

## Contribution Terms

By submitting a contribution, you agree to section 5 of [LICENSE](LICENSE), including its contributor grant and representations. Third-party material must be clearly identified and compatible with Arson's distribution model.
