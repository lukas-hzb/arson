# Changelog

All notable changes to Arson are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-08-27

This release is ad-hoc signed and not notarized by Apple. The update archive and feed are authenticated separately with Arson's Sparkle EdDSA key.

### Added

- An App Window menu bar icon option alongside Flame and Windows.

### Changed

- Refreshed the app icon and replaced README placeholders with actual screenshots.
- Improved the DMG installer with a fixed Finder layout, large icons, a drag-and-drop arrow, and an Arson volume icon.
- Included the project license inside the app bundle without a license dialog before installation.
- Moved the warning for presets without an effect to the General section of the editor.
- Added reproducible DMG packaging and installer checks to CI.

## [1.1.0] - 2026-08-26

### Added

- Sparkle-based update checks with signed appcast and archive verification.
- A localized **Check for Updates…** command in the app and menu bar menus.
- Release tooling and documentation for signed GitHub updates.
- Automated tests for updater configuration and full-screen window behavior.

### Changed

- The flame is now the default menu bar symbol for new installations.
- Global preset shortcuts are suspended silently while the focused application is in full screen.
- Repository documentation and GitHub contribution structure have been reorganized.

## [1.0.0]

### Added

- Initial unsigned preview with reusable window presets, independent sizing rules, positioning, offsets, global shortcuts, onboarding, menu bar control, and login-item support.

[Unreleased]: https://github.com/lukas-hzb/arson/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/lukas-hzb/arson/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/lukas-hzb/arson/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/lukas-hzb/arson/releases/tag/v1.0.0
