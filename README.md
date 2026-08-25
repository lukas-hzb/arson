# Arson

Arson is a native macOS utility for resizing and positioning the focused window with reusable presets and global keyboard shortcuts. It is built entirely with Swift 6, SwiftUI, AppKit, Accessibility, Carbon hot keys, and Service Management—without third-party dependencies or network access.

> The current app icon is intentionally a neutral placeholder. The final icon will be supplied separately.

## Requirements

- macOS 26 or later
- Xcode 26.5 or later
- Accessibility permission for controlling windows of other apps

## Install and keep one local copy

Use the local installer for normal testing instead of opening an app inside `DerivedData`. It builds the current checkout, quits every running Arson process, replaces the single canonical copy at `/Applications/Arson.app`, unregisters and deletes generated app and UI-test-runner bundles, refreshes Launchpad, and opens the installed app:

```sh
./Scripts/install-local.sh
```

Run the same command after every code change to update the installed copy. macOS may ask for an administrator password when replacing the app in `/Applications`.

To test onboarding again without rebuilding or changing the current app signature and permission, use:

```sh
./Scripts/install-local.sh --show-onboarding
```

To install a fresh build and show onboarding immediately, use:

```sh
./Scripts/install-local.sh --reset-onboarding
```

The introduction replaces the main window's content without opening a sheet or changing the window frame. It can be opened again at any time from **Help → Show Introduction**.

To update the installed app without launching it, use `./Scripts/install-local.sh --no-open`. Always launch `/Applications/Arson.app`; do not launch copies from `DerivedData`. Because local builds are ad-hoc signed, macOS can require the newly built version to be removed and added again under **System Settings → Privacy & Security → Device Control & Data Access**. The onboarding explains this recovery path. On older macOS versions, that setting is named **Accessibility**.

## Run from Xcode

1. Open `Arson.xcodeproj`.
2. Select the shared `Arson` scheme and the local Mac destination.
3. Build and run with `⌘R`.
4. After Xcode development, run `./Scripts/install-local.sh` before normal testing so only `/Applications/Arson.app` remains registered.
5. In the introduction, choose **Get Started**, then **Continue**, and approve Arson under **System Settings → Privacy & Security → Device Control & Data Access**. On older macOS versions, the setting is named **Accessibility**.

The project uses automatic signing for local development. App Sandbox is deliberately disabled because Arson must control windows belonging to other processes. Hardened Runtime remains enabled.

## Preset semantics

Each preset can change width and height independently:

- **Unchanged** keeps the current dimension.
- **Points** uses a fixed logical point size, limited to the selected display's visible work area.
- **Percent** uses a value greater than 0 and up to 100 percent of the visible work area.

The display with the greatest overlap with the focused window is used. The visible work area excludes the menu bar and Dock. Arson first applies the size, reads back the actual size accepted by the target app, then keeps the current origin or centers the window, and finally applies the point offset. Positive X moves right; positive Y moves down. Offsets are intentionally not constrained to screen bounds.

Global shortcuts require Command, Control, or Option and one non-modifier key. Shift may be added. Escape cancels recording and Delete removes a shortcut. Conflicting, reserved, or unavailable shortcuts are shown inline.

Closing all Arson windows keeps the app and shortcuts running and removes the Dock icon. Use the menu bar item or open Arson again to restore the main window. `⌘Q` quits the app.

## Tests

Run the unit and UI test targets from Xcode with `⌘U`, or use:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test \
  -project Arson.xcodeproj \
  -scheme Arson \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/ArsonDerivedData
```

Unit tests cover geometry, window animation, display coordinate conversion, persistence, validation, seed data, and shortcut conflicts. UI tests cover onboarding, preset creation, and Apple's accessibility audit. Accessibility control of third-party windows still requires manual testing because it depends on system permission and target-app behavior.

Xcode temporarily creates and registers test app bundles. After command-line or Xcode tests, run `./Scripts/install-local.sh --no-open` to remove those bundles and restore `/Applications/Arson.app` as the only registered copy.

## Known limits

Version 1 has no app-specific rules, tiling layouts, absolute screen coordinates, post-offset edge correction, cloud sync, preset import/export, automatic updates, or notarized releases. Full-screen, non-resizable, and Arson-owned windows are left unchanged.
