#!/bin/zsh

set -euo pipefail

readonly SCRIPT_DIRECTORY="${0:A:h}"
readonly REPOSITORY_ROOT="${SCRIPT_DIRECTORY:h}"
readonly INSTALL_APP="/Applications/Arson.app"
readonly BUNDLE_IDENTIFIER="de.lukasharzbecker.arson"
readonly UI_TEST_RUNNER_BUNDLE_IDENTIFIER="de.lukasharzbecker.arson.uitests.xctrunner"
readonly ONBOARDING_KEY="completedOnboardingVersion"
readonly LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
readonly ARSON_XCODE_APP="${ARSON_XCODE_APP:-/Applications/Xcode.app}"
readonly ARSON_DERIVED_DATA="${REPOSITORY_ROOT}/DerivedData/LocalInstall"
readonly BUILT_APP="${ARSON_DERIVED_DATA}/Build/Products/Release/Arson.app"
readonly USER_XCODE_DERIVED_DATA="${HOME}/Library/Developer/Xcode/DerivedData"

reset_onboarding=false
show_onboarding_only=false
open_after_install=true
ARSON_STAGING_DIRECTORY=""

usage() {
    print -- "Usage: ./Scripts/install-local.sh [--reset-onboarding | --show-onboarding] [--no-open]"
    print -- ""
    print -- "  --reset-onboarding  Build and install, then show onboarding on launch."
    print -- "  --show-onboarding   Reopen the installed app with onboarding, without rebuilding."
    print -- "  --no-open           Build and install without launching Arson."
}

for argument in "$@"; do
    case "$argument" in
        --reset-onboarding)
            reset_onboarding=true
            ;;
        --show-onboarding)
            show_onboarding_only=true
            reset_onboarding=true
            ;;
        --no-open)
            open_after_install=false
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            print -u2 -- "Unknown option: $argument"
            usage >&2
            exit 2
            ;;
    esac
done

if $show_onboarding_only && ! $open_after_install; then
    print -u2 -- "--show-onboarding and --no-open cannot be used together."
    exit 2
fi

quit_all_arson_processes() {
    if ! /usr/bin/pgrep -x Arson >/dev/null 2>&1; then
        return
    fi

    /usr/bin/pkill -TERM -x Arson
    for _ in {1..30}; do
        if ! /usr/bin/pgrep -x Arson >/dev/null 2>&1; then
            return
        fi
        /bin/sleep 0.1
    done

    print -u2 -- "Arson did not quit. Quit it manually with Command-Q, then run this command again."
    exit 1
}

unregister_app() {
    local app_path="$1"
    [[ -n "$app_path" ]] || return
    "$LSREGISTER" -u "$app_path" >/dev/null 2>&1 || true
}

registered_arson_app_paths() {
    "$LSREGISTER" -dump 2>/dev/null | /usr/bin/awk \
        -v app_identifier="$BUNDLE_IDENTIFIER" \
        -v runner_identifier="$UI_TEST_RUNNER_BUNDLE_IDENTIFIER" '
        function emit() {
            if ((identifier == app_identifier || identifier == runner_identifier) && path != "") {
                print path
            }
            path = ""
            identifier = ""
        }
        /^-{20,}$/ {
            emit()
            next
        }
        /^path:/ {
            path = $0
            sub(/^[^:]*:[[:space:]]*/, "", path)
            sub(/[[:space:]]+\(0x[[:xdigit:]]+\)$/, "", path)
            next
        }
        /^identifier:/ {
            identifier = $0
            sub(/^[^:]*:[[:space:]]*/, "", identifier)
            next
        }
        END {
            emit()
        }
    '
}

unregister_build_copies() {
    local candidate

    while IFS= read -r candidate; do
        if [[ -n "$candidate" && "$candidate" != "$INSTALL_APP" ]]; then
            unregister_app "$candidate"
        fi
    done < <(registered_arson_app_paths)

    if [[ -d "${REPOSITORY_ROOT}/DerivedData" ]]; then
        while IFS= read -r candidate; do
            unregister_app "$candidate"
        done < <(/usr/bin/find "${REPOSITORY_ROOT}/DerivedData" -type d \( -name Arson.app -o -name ArsonUITests-Runner.app \) -prune -print)
    fi

    while IFS= read -r candidate; do
        if [[ -n "$candidate" && "$candidate" != "$INSTALL_APP" ]]; then
            unregister_app "$candidate"
        fi
    done < <(/usr/bin/mdfind "kMDItemCFBundleIdentifier == '${BUNDLE_IDENTIFIER}'" 2>/dev/null || true)

    while IFS= read -r candidate; do
        if [[ -n "$candidate" ]]; then
            unregister_app "$candidate"
        fi
    done < <(/usr/bin/mdfind "kMDItemCFBundleIdentifier == '${UI_TEST_RUNNER_BUNDLE_IDENTIFIER}'" 2>/dev/null || true)
}

remove_generated_build_copies() {
    local candidate
    local bundle_identifier
    local derived_data_root

    for derived_data_root in "${REPOSITORY_ROOT}/DerivedData" "$USER_XCODE_DERIVED_DATA"; do
        [[ -d "$derived_data_root" ]] || continue

        while IFS= read -r candidate; do
            case "$candidate" in
                "${derived_data_root}"/*/Build/Products/*/Arson.app|\
                "${derived_data_root}"/*/Build/Products/*/ArsonUITests-Runner.app)
                    ;;
                *)
                    print -u2 -- "Refusing to remove unexpected build path: ${candidate}"
                    exit 1
                    ;;
            esac

            bundle_identifier="$(
                /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" \
                    "${candidate}/Contents/Info.plist" 2>/dev/null || true
            )"
            case "$bundle_identifier" in
                "$BUNDLE_IDENTIFIER"|"$UI_TEST_RUNNER_BUNDLE_IDENTIFIER")
                    unregister_app "$candidate"
                    /bin/rm -rf -- "$candidate"
                    ;;
                *)
                    print -u2 -- "Refusing to remove app with unexpected identifier at ${candidate}"
                    exit 1
                    ;;
            esac
        done < <(
            /usr/bin/find "$derived_data_root" -type d \
                \( -name Arson.app -o -name ArsonUITests-Runner.app \) \
                -prune -print
        )
    done
}

run_for_applications_directory() {
    if [[ -w /Applications ]]; then
        "$@"
    else
        /usr/bin/sudo "$@"
    fi
}

cleanup_staging_directory() {
    if [[ "$ARSON_STAGING_DIRECTORY" == /tmp/arson-install.* ]]; then
        /bin/rm -rf -- "$ARSON_STAGING_DIRECTORY"
    fi
}

install_current_build() {
    local xcodebuild_path="${ARSON_XCODE_APP}/Contents/Developer/usr/bin/xcodebuild"
    if [[ ! -x "$xcodebuild_path" ]]; then
        print -u2 -- "Xcode was not found at ${ARSON_XCODE_APP}."
        print -u2 -- "Set ARSON_XCODE_APP to the correct Xcode.app path and try again."
        exit 1
    fi

    /bin/mkdir -p "${REPOSITORY_ROOT}/DerivedData"
    /usr/bin/touch "${REPOSITORY_ROOT}/DerivedData/.metadata_never_index"

    print -- "Building the current Arson checkout…"
    DEVELOPER_DIR="${ARSON_XCODE_APP}/Contents/Developer" \
        "$xcodebuild_path" \
        -project "${REPOSITORY_ROOT}/Arson.xcodeproj" \
        -scheme Arson \
        -configuration Release \
        -destination "platform=macOS" \
        -derivedDataPath "$ARSON_DERIVED_DATA" \
        CODE_SIGNING_ALLOWED=YES \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY=- \
        build

    if [[ ! -d "$BUILT_APP" ]]; then
        print -u2 -- "The build succeeded but Arson.app was not found at ${BUILT_APP}."
        exit 1
    fi

    ARSON_STAGING_DIRECTORY="$(/usr/bin/mktemp -d /tmp/arson-install.XXXXXX)"
    local staging_app="${ARSON_STAGING_DIRECTORY}/Arson.app"
    local previous_app="${ARSON_STAGING_DIRECTORY}/Previous-Arson.app"

    trap cleanup_staging_directory EXIT

    /usr/bin/ditto "$BUILT_APP" "$staging_app"

    unregister_app "$INSTALL_APP"
    if [[ -d "$INSTALL_APP" ]]; then
        /usr/bin/ditto "$INSTALL_APP" "$previous_app"
    fi

    run_for_applications_directory /bin/rm -rf -- "$INSTALL_APP"
    if ! run_for_applications_directory /usr/bin/ditto "$staging_app" "$INSTALL_APP"; then
        print -u2 -- "Installation failed. Restoring the previous Arson.app…"
        if [[ -d "$previous_app" ]]; then
            run_for_applications_directory /usr/bin/ditto "$previous_app" "$INSTALL_APP"
        fi
        exit 1
    fi

    trap - EXIT
    cleanup_staging_directory
}

if $show_onboarding_only && [[ ! -d "$INSTALL_APP" ]]; then
    print -u2 -- "${INSTALL_APP} is not installed yet. Run ./Scripts/install-local.sh first."
    exit 1
fi

quit_all_arson_processes

if ! $show_onboarding_only; then
    install_current_build
fi

unregister_build_copies
remove_generated_build_copies
"$LSREGISTER" -gc >/dev/null 2>&1 || true
"$LSREGISTER" -f "$INSTALL_APP" >/dev/null

if $reset_onboarding; then
    /usr/bin/defaults delete "$BUNDLE_IDENTIFIER" "$ONBOARDING_KEY" >/dev/null 2>&1 || true
fi

# Launchpad is part of the Dock process. Restarting it makes stale registrations disappear immediately.
/usr/bin/killall Dock >/dev/null 2>&1 || true

if $open_after_install; then
    if $reset_onboarding; then
        /usr/bin/open "$INSTALL_APP" --args -show-onboarding
    else
        /usr/bin/open "$INSTALL_APP"
    fi
fi

print -- "Installed the current build at ${INSTALL_APP}."
if $reset_onboarding; then
    print -- "Onboarding was reset for this launch."
fi
