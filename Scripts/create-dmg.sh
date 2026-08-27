#!/bin/zsh

set -euo pipefail

readonly SCRIPT_DIRECTORY="${0:A:h}"
readonly DMG_TOOLS_DIRECTORY="${SCRIPT_DIRECTORY}/dmg"
readonly CREATE_DMG="${DMG_TOOLS_DIRECTORY}/node_modules/create-dmg/cli.js"

usage() {
    print -- "Usage: ./Scripts/create-dmg.sh <app-path> <output-dmg>"
    print -- "Example: ./Scripts/create-dmg.sh Arson.app .artifacts/updates/Arson-1.1.0.dmg"
}

if [[ $# -ne 2 ]]; then
    usage >&2
    exit 2
fi

app_path="${1:A}"
output_path="${2:A}"

if [[ "${output_path:e:l}" != "dmg" ]]; then
    print -u2 -- "Output path must use the .dmg extension: ${output_path}"
    exit 2
fi

if [[ ! -d "$app_path" || "${app_path:e}" != "app" ]]; then
    print -u2 -- "Application bundle does not exist: ${app_path}"
    exit 2
fi

info_plist="${app_path}/Contents/Info.plist"
if [[ ! -f "$info_plist" ]]; then
    print -u2 -- "Application Info.plist does not exist: ${info_plist}"
    exit 2
fi

bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_plist")"
if [[ "$bundle_identifier" != "de.lukasharzbecker.arson" ]]; then
    print -u2 -- "Refusing to package unexpected bundle identifier: ${bundle_identifier}"
    exit 2
fi

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist")"

if ! command -v node >/dev/null 2>&1 || ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 20 ? 0 : 1)'; then
    print -u2 -- "DMG packaging requires Node.js 20 or later (Node.js 24 LTS recommended)."
    exit 1
fi

if [[ ! -f "$CREATE_DMG" ]]; then
    print -u2 -- "Install the pinned DMG tools first: npm ci --prefix \"${DMG_TOOLS_DIRECTORY}\""
    exit 1
fi

if [[ -e "$output_path" && ! -f "$output_path" ]]; then
    print -u2 -- "Output path is not a regular file: ${output_path}"
    exit 2
fi

# Build next to the destination so the verified image can replace it atomically.
/bin/mkdir -p "${output_path:h}"
arson_dmg_staging="$(/usr/bin/mktemp -d "${output_path:h}/.arson-dmg.XXXXXX")"

cleanup() {
    if [[ -n "$arson_dmg_staging" && "${arson_dmg_staging:t}" == .arson-dmg.* ]]; then
        /bin/rm -rf -- "$arson_dmg_staging"
    fi
}
trap cleanup EXIT

/usr/bin/ditto "$app_path" "${arson_dmg_staging}/Arson.app"

# An empty working directory prevents create-dmg from picking up license.txt
# or license.rtf and adding a blocking license dialog. Xcode bundles LICENSE
# as an app resource before signing instead. Keep DMG signing explicit.
(
    cd "$arson_dmg_staging"
    node "$CREATE_DMG" \
        --no-code-sign \
        --no-version-in-filename \
        --dmg-title="Arson ${version}" \
        "${arson_dmg_staging}/Arson.app" \
        "$arson_dmg_staging"
)

generated_images=("${arson_dmg_staging}"/*.dmg(N))
if [[ ${#generated_images} -ne 1 ]]; then
    print -u2 -- "Expected exactly one generated DMG in ${arson_dmg_staging}."
    exit 1
fi

/usr/bin/hdiutil verify "$generated_images[1]"
/bin/mv -f -- "$generated_images[1]" "$output_path"
print -- "Created ${output_path}"
