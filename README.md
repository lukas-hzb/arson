# Arson

Arson is a native macOS utility for resizing and positioning the focused window with reusable presets and global keyboard shortcuts. It is built entirely with Swift 6, SwiftUI, AppKit, Accessibility, Carbon hot keys, and Service Management—without third-party dependencies or network access.

The app icon uses the native Icon Composer source in the project.

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

The display with the greatest overlap with the focused window is used. The visible work area excludes the menu bar and Dock. Arson keeps the current origin where possible, but moves it just far enough to fit a resized window into that work area; alternatively, it centers the window or aligns it with the left or right edge while retaining its vertical position where possible. The point offset is applied last. Positive X moves right; positive Y moves down. Offsets are intentionally not constrained to screen bounds.

Global shortcuts require Command, Control, or Option and one non-modifier key. Shift may be added. Escape cancels recording and unmodified Delete removes a shortcut; modified Delete can be recorded as part of a shortcut. Conflicting, reserved, or unavailable shortcuts are shown inline.

Fresh configurations start with Compact (`⌃⌘↩`), Left Half (`⌃⌘←`), Right Half (`⌃⌘→`), and Down and Right (`⌃⌘⌫`). Existing stored presets are left unchanged.

Closing all Arson windows keeps the app and shortcuts running and removes the Dock icon. The Settings window lets you choose the menu bar symbol or hide it entirely. When hidden, Arson and its global shortcuts keep running in the background; open Arson again from Applications or Launchpad to restore the main window. `⌘Q` quits the app.

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

## Distributing releases

Local and CI builds are not signed with an Apple Developer ID and are not notarized. Publish those builds only as clearly labeled pre-releases for trusted testers: Gatekeeper blocks their normal first launch, so testers must explicitly approve opening them in Finder or System Settings.

For a normal public release outside the Mac App Store, archive a universal Release build, sign it with a **Developer ID Application** certificate and a secure timestamp, submit it to Apple's notary service, staple the resulting ticket, and verify the final artifact with `codesign`, `spctl`, and `stapler` before uploading it. Keep signing certificates and notarization credentials in protected CI secrets, never in the repository. See Apple's [notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Known limits

Version 1 has no app-specific rules, tiling layouts, absolute screen coordinates, post-offset edge correction, cloud sync, preset import/export, automatic updates, or notarized releases. Full-screen, non-resizable, and Arson-owned windows are left unchanged.
