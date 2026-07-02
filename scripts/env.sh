#!/usr/bin/env bash

load_onemorecap_env() {
    local root_dir="$1"
    local env_file="$root_dir/.env.local"
    local preserved_vars=(
        DEVELOPER_DIR
        ONEMORECAP_BUNDLE_IDENTIFIER
        ONEMORECAP_BUNDLE_SHORT_VERSION
        ONEMORECAP_BUNDLE_VERSION
        ONEMORECAP_MINIMUM_SYSTEM_VERSION
        ONEMORECAP_DISTRIBUTION_CHANNEL
        ONEMORECAP_CODESIGN_IDENTITY
        ONEMORECAP_CODESIGN_HARDENED_RUNTIME
        ONEMORECAP_CODESIGN_ENTITLEMENTS
        ONEMORECAP_APP_NAME
        ONEMORECAP_APP_BUNDLE_NAME
        ONEMORECAP_APP_EXECUTABLE_NAME
        ONEMORECAP_STATUS_ITEM_TITLE
        ONEMORECAP_APP_ICON_SOURCE
        ONEMORECAP_MENU_BAR_ICON_SOURCE_DIR
        ONEMORECAP_SPARKLE_VERSION
        ONEMORECAP_SPARKLE_URL
        ONEMORECAP_SPARKLE_ZIP_CHECKSUM
        ONEMORECAP_SPARKLE_FEED_URL
        ONEMORECAP_SPARKLE_PUBLIC_ED_KEY
        ONEMORECAP_SPARKLE_PRIVATE_KEY
        ONEMORECAP_SPARKLE_PRIVATE_KEY_FILE
        ONEMORECAP_SPARKLE_KEY_ACCOUNT
        ONEMORECAP_SPARKLE_APPCAST_DIR
        ONEMORECAP_SPARKLE_APPCAST_PATH
        ONEMORECAP_SPARKLE_DOWNLOAD_URL_PREFIX
        ONEMORECAP_SPARKLE_FULL_RELEASE_NOTES_URL
    )
    local var
    local had_var
    local value

    if [[ -f "$env_file" ]]; then
        for var in "${preserved_vars[@]}"; do
            if [[ -n "${!var+x}" ]]; then
                printf -v "onemorecap_env_had_$var" '%s' 1
                printf -v "onemorecap_env_value_$var" '%s' "${!var}"
            else
                printf -v "onemorecap_env_had_$var" '%s' 0
            fi
        done

        set -a
        # shellcheck source=/dev/null
        source "$env_file"
        set +a

        for var in "${preserved_vars[@]}"; do
            had_var="onemorecap_env_had_$var"
            value="onemorecap_env_value_$var"
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
