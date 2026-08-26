#!/bin/zsh

set -euo pipefail

readonly SCRIPT_DIRECTORY="${0:A:h}"
readonly REPOSITORY_ROOT="${SCRIPT_DIRECTORY:h}"
readonly ARSON_XCODE_APP="${ARSON_XCODE_APP:-/Applications/Xcode.app}"
readonly SOURCE_PACKAGES_DIRECTORY="${ARSON_SOURCE_PACKAGES_DIRECTORY:-${REPOSITORY_ROOT}/DerivedData/SparkleSourcePackages}"
readonly SPARKLE_ACCOUNT="de.lukasharzbecker.arson"

usage() {
    print -- "Usage: ./Scripts/generate-appcast.sh <updates-directory> <release-tag>"
    print -- "Example: ./Scripts/generate-appcast.sh .artifacts/updates v1.1.0"
}

if [[ $# -ne 2 ]]; then
    usage >&2
    exit 2
fi

updates_directory="${1:A}"
release_tag="$2"

if [[ ! -d "$updates_directory" ]]; then
    print -u2 -- "Updates directory does not exist: ${updates_directory}"
    exit 2
fi

if [[ ! "$release_tag" =~ '^v[0-9A-Za-z][0-9A-Za-z._-]*$' ]]; then
    print -u2 -- "Release tag must start with v and contain only letters, digits, dots, underscores, or hyphens."
    exit 2
fi

xcodebuild_path="${ARSON_XCODE_APP}/Contents/Developer/usr/bin/xcodebuild"
if [[ ! -x "$xcodebuild_path" ]]; then
    print -u2 -- "Xcode was not found at ${ARSON_XCODE_APP}."
    exit 1
fi

DEVELOPER_DIR="${ARSON_XCODE_APP}/Contents/Developer" \
    "$xcodebuild_path" \
    -resolvePackageDependencies \
    -project "${REPOSITORY_ROOT}/Arson.xcodeproj" \
    -scheme Arson \
    -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIRECTORY"

generate_appcast="${SOURCE_PACKAGES_DIRECTORY}/artifacts/sparkle/Sparkle/bin/generate_appcast"
if [[ ! -x "$generate_appcast" ]]; then
    print -u2 -- "Sparkle's generate_appcast tool was not found at ${generate_appcast}."
    exit 1
fi

"$generate_appcast" \
    --account "$SPARKLE_ACCOUNT" \
    --download-url-prefix "https://github.com/lukas-hzb/arson/releases/download/${release_tag}/" \
    --link "https://github.com/lukas-hzb/arson" \
    --maximum-versions 1 \
    --maximum-deltas 0 \
    --embed-release-notes \
    -o "${updates_directory}/appcast.xml" \
    "$updates_directory"

print -- "Signed appcast created at ${updates_directory}/appcast.xml"
