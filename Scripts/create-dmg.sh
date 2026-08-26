#!/bin/zsh

set -euo pipefail

readonly SCRIPT_DIRECTORY="${0:A:h}"
readonly REPOSITORY_ROOT="${SCRIPT_DIRECTORY:h}"

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
arson_dmg_staging="$(/usr/bin/mktemp -d /tmp/arson-dmg.XXXXXX)"

cleanup() {
    if [[ "$arson_dmg_staging" == /tmp/arson-dmg.* ]]; then
        /bin/rm -rf -- "$arson_dmg_staging"
    fi
}
trap cleanup EXIT

/bin/mkdir -p "${output_path:h}"
/usr/bin/ditto "$app_path" "${arson_dmg_staging}/Arson.app"
/bin/ln -s /Applications "${arson_dmg_staging}/Applications"

if [[ -f "${REPOSITORY_ROOT}/LICENSE" ]]; then
    /usr/bin/ditto "${REPOSITORY_ROOT}/LICENSE" "${arson_dmg_staging}/LICENSE.txt"
fi

if [[ -e "$output_path" ]]; then
    /bin/rm -f -- "$output_path"
fi

/usr/sbin/diskutil image create from \
    --format UDZO \
    --volumeName "Arson ${version}" \
    "$arson_dmg_staging" \
    "$output_path"

/usr/bin/hdiutil verify "$output_path"
print -- "Created ${output_path}"
