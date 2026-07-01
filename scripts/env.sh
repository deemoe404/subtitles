#!/usr/bin/env bash

load_subtitles_env() {
    local root_dir="$1"
    local env_file="$root_dir/.env.local"
    local preserved_vars=(
        DEVELOPER_DIR
        SUBTITLES_BUNDLE_IDENTIFIER
        SUBTITLES_BUNDLE_SHORT_VERSION
        SUBTITLES_BUNDLE_VERSION
        SUBTITLES_MINIMUM_SYSTEM_VERSION
        SUBTITLES_CODESIGN_IDENTITY
        SUBTITLES_CODESIGN_HARDENED_RUNTIME
        SUBTITLES_CODESIGN_ENTITLEMENTS
        SUBTITLES_APP_NAME
        SUBTITLES_APP_BUNDLE_NAME
        SUBTITLES_APP_EXECUTABLE_NAME
        SUBTITLES_STATUS_ITEM_TITLE
        SUBTITLES_SPARKLE_VERSION
        SUBTITLES_SPARKLE_URL
        SUBTITLES_SPARKLE_ZIP_CHECKSUM
        SUBTITLES_SPARKLE_FEED_URL
        SUBTITLES_SPARKLE_PUBLIC_ED_KEY
        SUBTITLES_SPARKLE_PRIVATE_KEY
        SUBTITLES_SPARKLE_PRIVATE_KEY_FILE
        SUBTITLES_SPARKLE_KEY_ACCOUNT
        SUBTITLES_SPARKLE_APPCAST_DIR
        SUBTITLES_SPARKLE_APPCAST_PATH
        SUBTITLES_SPARKLE_DOWNLOAD_URL_PREFIX
        SUBTITLES_SPARKLE_FULL_RELEASE_NOTES_URL
    )
    local var
    local had_var
    local value

    if [[ -f "$env_file" ]]; then
        for var in "${preserved_vars[@]}"; do
            if [[ -n "${!var+x}" ]]; then
                printf -v "subtitles_env_had_$var" '%s' 1
                printf -v "subtitles_env_value_$var" '%s' "${!var}"
            else
                printf -v "subtitles_env_had_$var" '%s' 0
            fi
        done

        set -a
        # shellcheck source=/dev/null
        source "$env_file"
        set +a

        for var in "${preserved_vars[@]}"; do
            had_var="subtitles_env_had_$var"
            value="subtitles_env_value_$var"
            if [[ "${!had_var}" == "1" ]]; then
                export "$var=${!value}"
            fi
            unset "$had_var" "$value"
        done
    fi

    if [[ -z "${DEVELOPER_DIR:-}" ]]; then
        local xcode_beta="$HOME/Applications/Xcode-beta.app/Contents/Developer"
        if [[ -d "$xcode_beta" ]]; then
            export DEVELOPER_DIR="$xcode_beta"
        fi
    fi
}
