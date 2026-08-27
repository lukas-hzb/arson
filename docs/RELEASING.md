# Release Guide

Arson is distributed outside the Mac App Store through GitHub Releases. Public releases should be signed with a Developer ID certificate, notarized by Apple, and accompanied by a signed Sparkle appcast.

## Release Types

- **Preview / pre-release** — Intended for trusted testers. An unsigned or ad-hoc-signed build may be used only when it is clearly labelled and users are warned about Gatekeeper.
- **Public release** — A universal, Developer ID-signed, notarized build published as a normal GitHub release with its Sparkle feed.

The existing unsigned `v1.0.0` preview predates the updater. Users of that build must install the first updater-enabled release manually once.

## Prerequisites

- An active Apple Developer Program membership
- A valid **Developer ID Application** certificate
- Notarization credentials stored outside the repository
- The Arson Sparkle EdDSA private key available under account `de.lukasharzbecker.arson` in the login Keychain
- A clean, reviewed commit and a passing CI run
- Node.js 20 or later (24 LTS recommended), npm, and Xcode command-line tools for DMG packaging

Install the pinned [create-dmg](https://github.com/sindresorhus/create-dmg) tooling once after checkout, and again when its lockfile changes:

```bash
npm ci --prefix Scripts/dmg
```

These dependencies are only used for packaging, not by Arson itself. The native dependencies need a working Xcode toolchain; if compilation cannot find the C++ headers, run the command with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

The Sparkle private key is as sensitive as a signing password. Back it up before the first public updater-enabled release:

```bash
generate_keys --account de.lukasharzbecker.arson -x <secure-path>
```

Move the exported secret to protected credential storage and remove the temporary file. Never commit it. Losing both the Keychain item and the backup can prevent existing installations from accepting future updates.

## Versioning

Before building a release, update both values in the Arson target:

- `MARKETING_VERSION` — the user-visible semantic version, such as `1.1.0`
- `CURRENT_PROJECT_VERSION` — a monotonically increasing integer used by Sparkle, such as `2`

Use a matching Git tag prefixed with `v`, for example `v1.1.0`.

## Build, Sign, and Notarize

1. Archive a generic macOS Release build in Xcode so both Apple Silicon and Intel slices are included.
2. Sign the complete bundle with the **Developer ID Application** identity and a secure timestamp.
3. Submit the application or distribution archive to Apple's notary service.
4. Wait for acceptance and staple the resulting ticket.
5. Verify the final application before packaging:

```bash
codesign --verify --deep --strict --verbose=2 Arson.app
spctl --assess --type execute --verbose=2 Arson.app
xcrun stapler validate Arson.app
lipo Arson.app/Contents/MacOS/Arson -verify_arch arm64
lipo Arson.app/Contents/MacOS/Arson -verify_arch x86_64
```

Create the installer DMG:

```bash
./Scripts/create-dmg.sh Arson.app .artifacts/updates/Arson-1.1.0.dmg
```

The DMG uses a fixed 660 × 400 Finder window, large app and `Applications` icons, a drag-and-drop arrow, and a volume icon derived from Arson's app icon. It opens directly without a license dialog. Xcode includes the repository's `LICENSE` as `Arson.app/Contents/Resources/LICENSE` before signing; rebuild older apps to include this resource. The packaging script does not modify the supplied app bundle, and an existing output is only replaced after the new image passes `hdiutil verify`.

The packaging script deliberately does not sign the DMG or select a Keychain identity. For public releases, sign and notarize the final DMG, then staple its ticket **before** generating the Sparkle appcast. Review the mounted Finder window and test dragging the app into `Applications` before publishing.

Never advertise an unsigned or ad-hoc-signed build in a production appcast.

## Generate the Sparkle Appcast

Place the final archive and an optional same-named Markdown release-notes file in a dedicated directory:

```text
.artifacts/updates/
├── Arson-1.1.0.dmg
└── Arson-1.1.0.md
```

Generate and sign the feed using the exact release tag:

```bash
./Scripts/generate-appcast.sh .artifacts/updates v1.1.0
```

The script resolves the pinned Sparkle tools, signs the update archive and feed with the Keychain key, embeds release notes, and writes `.artifacts/updates/appcast.xml`.

## Publish on GitHub

1. Create the tag and GitHub release using the exact version passed to the appcast script.
2. Attach the signed/notarized update archive and `appcast.xml`.
3. Include concise user-facing release notes and upgrade caveats.
4. Publish a production update as a normal release, not only as a pre-release.
5. Confirm that the latest feed resolves at:
   `https://github.com/lukas-hzb/arson/releases/latest/download/appcast.xml`

The archive URLs embedded in the appcast point to the exact versioned GitHub release, while installed applications discover the feed through the latest normal release.

## Post-Release Checks

- Install the release on a Mac without a previous Arson development build.
- Confirm Gatekeeper assessment succeeds without manual override.
- Grant the system permission and apply at least one preset to another app.
- Check for updates from both **Arson → Check for Updates…** and the menu bar item.
- Confirm the GitHub release contains the archive, appcast, release notes, and correct tag.
- Update [CHANGELOG.md](../CHANGELOG.md) and compare its links.

Apple notarization guidance: <https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution>

Sparkle publishing guidance: <https://sparkle-project.org/documentation/publishing/>
