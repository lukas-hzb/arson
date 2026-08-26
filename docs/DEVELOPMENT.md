# Development Guide

This guide covers local setup, project conventions, testing, and the behavior that is easiest to misunderstand when working on Arson.

## Requirements

- macOS 26 or later
- Xcode 26.5 or later
- Git
- Accessibility permission when manually testing control of third-party windows

## Recommended Local Workflow

Use the local installer for normal testing instead of opening an application inside `DerivedData`:

```bash
./Scripts/install-local.sh
```

It builds the current checkout, quits running Arson processes, replaces the canonical copy at `/Applications/Arson.app`, unregisters generated app and UI-test-runner bundles, refreshes Launchpad, and opens the installed application. macOS may request an administrator password when replacing an application in `/Applications`.

Useful variants:

```bash
# Install without launching
./Scripts/install-local.sh --no-open

# Reopen the introduction without resetting the local build
./Scripts/install-local.sh --show-onboarding

# Install a fresh build and reset the introduction
./Scripts/install-local.sh --reset-onboarding
```

Always launch `/Applications/Arson.app` for manual testing. Multiple registered copies can cause macOS privacy permissions and Launch Services to target the wrong bundle.

## Run from Xcode

1. Open `Arson.xcodeproj`.
2. Select the shared `Arson` scheme and the local Mac destination.
3. Build and run with `⌘R`.
4. Complete the introduction and grant the requested system permission.
5. After Xcode development, run `./Scripts/install-local.sh` before normal testing so that only the canonical application remains registered.

The project uses automatic signing for local development. App Sandbox is deliberately disabled because Arson controls windows owned by other processes. Hardened Runtime remains enabled. Debug/local builds use a narrowly scoped entitlement so the ad-hoc-signed Sparkle framework can be loaded; production Release builds do not include that exception.

## Permissions

Arson needs access under **System Settings → Privacy & Security → Device Control & Data Access**. On older macOS versions, the setting is named **Accessibility**.

Because local builds are ad-hoc signed, macOS can require a rebuilt version to be removed and added again in that system setting. The introduction explains this recovery path.

## Project Layout

```text
Arson/
├── App/          Application lifecycle and shared state
├── Models/       Preset and menu bar value types
├── Services/     Window control, persistence, hot keys, updates, and system APIs
├── Views/        SwiftUI and AppKit presentation
└── Resources/    Assets, localization, entitlements, and third-party notices
```

The target uses Xcode's file-system-synchronized groups. Swift files added below `Arson`, `ArsonTests`, or `ArsonUITests` are normally discovered automatically; special resources such as the production `Info.plist` may require a build-file exception in the project.

## Preset Semantics

Each preset changes width and height independently:

- **Unchanged** keeps the current dimension.
- **Points** uses a fixed logical point size, limited to the selected display's visible work area.
- **Percent** accepts a value greater than 0 and up to 100 percent of the visible work area.

The display with the greatest overlap with the focused window is used. The visible work area excludes the menu bar and Dock. Arson keeps the current origin where possible, but moves a resized window just far enough to fit. A preset may instead center the window or align it with the left or right edge while retaining its vertical position where possible.

The point offset is applied last. Positive X moves right and positive Y moves down. Offsets are intentionally not constrained to screen bounds.

## Shortcut Rules

Global shortcuts require Command, Control, or Option and one non-modifier key. Shift may be added. Escape cancels recording, and unmodified Delete removes a shortcut; modified Delete can be recorded. Conflicting, reserved, and unavailable shortcuts are shown inline.

When the focused app is in full screen, Arson suspends its global handlers so the app can receive matching shortcuts itself. No warning is shown for that case.

## Tests

Run all unit and UI targets in Xcode with `⌘U`, or run the complete suite from the command line:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test \
  -project Arson.xcodeproj \
  -scheme Arson \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/ArsonDerivedData
```

Unit tests cover geometry, animation, display coordinates, persistence, validation, seed data, shortcut conflicts, full-screen error handling, and updater configuration. UI tests cover onboarding, preset creation, and Apple's accessibility audit.

Accessibility control of third-party windows still requires manual testing because behavior depends on system permission and the target application. After tests, run `./Scripts/install-local.sh --no-open` to remove generated runner bundles and restore the canonical application registration.

## Continuous Integration

GitHub Actions builds with warnings treated as errors, runs unit and UI/accessibility tests, builds the Release configuration, and verifies both `arm64` and `x86_64` slices. Pull requests and pushes to `main` run the same workflow.

## Code and Commit Style

- Treat compiler warnings as errors.
- Prefer focused types and test pure geometry or validation logic independently from macOS APIs.
- Keep user-facing text in `Localizable.xcstrings`.
- Use English [Conventional Commits](https://www.conventionalcommits.org/) messages.
- Never commit signing credentials, notarization credentials, Sparkle private keys, or exported archives.

For the publication workflow, continue with [RELEASING.md](RELEASING.md).
