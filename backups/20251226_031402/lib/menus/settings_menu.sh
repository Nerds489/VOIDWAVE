#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# See LICENSE and NOTICE files in the project root for full details.
# ═══════════════════════════════════════════════════════════════════════════════
#
# Settings Menu: configuration, API keys, paths, logging
# ═══════════════════════════════════════════════════════════════════════════════

[[ -n "${_VOIDWAVE_SETTINGS_MENU_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_SETTINGS_MENU_LOADED=1

show_settings_menu() {
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] && return 1

    while true; do
        clear_screen 2>/dev/null || clear
        show_banner "${VERSION:-}"

        echo -e "    ${C_BOLD:-}Settings${C_RESET:-}"
        echo ""
        echo "    1) View Current Settings"
        echo "    2) Configure Logging"
        echo "    3) Configure API Keys"
        echo "    4) Configure Paths"
        echo "    5) Export Configuration"
        echo "    6) Import Configuration"
        echo "    7) Reset to Defaults"
        echo "    0) Back"
        echo ""

        local choice
        echo -en "    ${C_PURPLE:-}▶${C_RESET:-} Select [0-7]: "
        read -r choice
        choice="${choice//[[:space:]]/}"

        case "$choice" in
            1) _settings_view ;;
            2) _settings_logging ;;
            3) _settings_apikeys ;;
            4) _settings_paths ;;
            5) _settings_export ;;
            6) _settings_import ;;
            7) _settings_reset ;;
            0) return 0 ;;
            "") continue ;;
            *) echo -e "    ${C_RED:-}[!] Invalid option: '$choice'${C_RESET:-}"; sleep 1 ;;
        esac
    done
}

_settings_view() {
    echo ""
    echo -e "    ${C_CYAN:-}═══════════════════════════════════════════${C_RESET:-}"
    echo -e "    ${C_BOLD:-}VOIDWAVE Configuration${C_RESET:-}"
    echo -e "    ${C_CYAN:-}═══════════════════════════════════════════${C_RESET:-}"
    echo ""

    echo -e "    ${C_BOLD:-}Version${C_RESET:-}"
    echo "      Version: ${VERSION:-unknown}"
    echo "      Root: ${VOIDWAVE_ROOT:-unknown}"
    echo ""

    echo -e "    ${C_BOLD:-}Paths${C_RESET:-}"
    echo "      Home: ${VOIDWAVE_HOME:-$HOME/.voidwave}"
    echo "      Config: ${VOIDWAVE_CONFIG_DIR:-$HOME/.voidwave/config}"
    echo "      Logs: ${VOIDWAVE_LOG_DIR:-$HOME/.voidwave/logs}"
    echo "      Output: ${VOIDWAVE_OUTPUT_DIR:-$HOME/.voidwave/output}"
    echo ""

    echo -e "    ${C_BOLD:-}Environment${C_RESET:-}"
    echo "      Log Level: ${VOIDWAVE_LOG_LEVEL:-1}"
    echo "      Non-Interactive: ${VW_NON_INTERACTIVE:-0}"
    echo "      Unsafe Mode: ${VW_UNSAFE_MODE:-0}"
    echo "      Dry Run: ${DRY_RUN:-0}"
    echo ""

    echo -e "    ${C_BOLD:-}API Keys${C_RESET:-}"
    echo "      Shodan: $(mask_string "${SHODAN_API_KEY:-not set}")"
    echo "      VirusTotal: $(mask_string "${VT_API_KEY:-not set}")"
    echo "      Censys: $(mask_string "${CENSYS_API_KEY:-not set}")"
    echo "      Hunter: $(mask_string "${HUNTER_API_KEY:-not set}")"
    echo ""

    wait_for_keypress
}

_settings_logging() {
    echo ""
    echo -e "    ${C_BOLD:-}Logging Configuration${C_RESET:-}"
    echo ""
    echo "    Current level: ${VOIDWAVE_LOG_LEVEL:-1}"
    echo ""
    echo "    0) DEBUG (verbose)"
    echo "    1) INFO (default)"
    echo "    2) SUCCESS"
    echo "    3) WARNING"
    echo "    4) ERROR"
    echo "    5) FATAL (quiet)"
    echo ""

    local level
    read -rp "    Select level [0-5]: " level

    if [[ "$level" =~ ^[0-5]$ ]]; then
        _save_setting "VOIDWAVE_LOG_LEVEL" "$level"
        export VOIDWAVE_LOG_LEVEL="$level"
        echo -e "    ${C_GREEN:-}Log level set to $level${C_RESET:-}"
    fi

    echo ""
    echo "    File logging: ${VOIDWAVE_FILE_LOGGING:-1}"
    echo ""
    echo "    1) Enable"
    echo "    2) Disable"
    echo ""

    local file_log
    read -rp "    Select [1-2]: " file_log

    case "$file_log" in
        1)
            _save_setting "VOIDWAVE_FILE_LOGGING" "1"
            export VOIDWAVE_FILE_LOGGING="1"
            echo -e "    ${C_GREEN:-}File logging enabled${C_RESET:-}"
            ;;
        2)
            _save_setting "VOIDWAVE_FILE_LOGGING" "0"
            export VOIDWAVE_FILE_LOGGING="0"
            echo -e "    ${C_GREEN:-}File logging disabled${C_RESET:-}"
            ;;
    esac

    wait_for_keypress
}

_settings_apikeys() {
    echo ""
    echo -e "    ${C_BOLD:-}API Key Configuration${C_RESET:-}"
    echo ""
    echo "    1) Shodan"
    echo "    2) VirusTotal"
    echo "    3) Censys"
    echo "    4) Hunter.io"
    echo "    5) View all (masked)"
    echo "    0) Back"
    echo ""

    local choice
    read -rp "    Select [0-5]: " choice

    case "$choice" in
        1) _configure_api_key "SHODAN_API_KEY" "Shodan" ;;
        2) _configure_api_key "VT_API_KEY" "VirusTotal" ;;
        3) _configure_api_key "CENSYS_API_KEY" "Censys" ;;
        4) _configure_api_key "HUNTER_API_KEY" "Hunter.io" ;;
        5)
            echo ""
            echo "    Shodan: $(mask_string "${SHODAN_API_KEY:-not set}")"
            echo "    VirusTotal: $(mask_string "${VT_API_KEY:-not set}")"
            echo "    Censys: $(mask_string "${CENSYS_API_KEY:-not set}")"
            echo "    Hunter: $(mask_string "${HUNTER_API_KEY:-not set}")"
            wait_for_keypress
            ;;
        0) return ;;
    esac
}

_configure_api_key() {
    local var_name="$1"
    local display_name="$2"

    local current
    eval "current=\${$var_name:-}"

    echo ""
    if [[ -n "$current" ]]; then
        echo "    Current: $(mask_string "$current")"
        echo ""
        echo "    1) Update key"
        echo "    2) Remove key"
        echo "    0) Cancel"
        echo ""

        local action
        read -rp "    Select [0-2]: " action

        case "$action" in
            1)
                read -rsp "    Enter new $display_name API key: " new_key
                echo ""
                if [[ -n "$new_key" ]]; then
                    _save_setting "$var_name" "$new_key"
                    export "$var_name"="$new_key"
                    echo -e "    ${C_GREEN:-}$display_name API key updated${C_RESET:-}"
                fi
                ;;
            2)
                _remove_setting "$var_name"
                unset "$var_name"
                echo -e "    ${C_GREEN:-}$display_name API key removed${C_RESET:-}"
                ;;
        esac
    else
        read -rsp "    Enter $display_name API key: " new_key
        echo ""
        if [[ -n "$new_key" ]]; then
            _save_setting "$var_name" "$new_key"
            export "$var_name"="$new_key"
            echo -e "    ${C_GREEN:-}$display_name API key saved${C_RESET:-}"
        fi
    fi

    wait_for_keypress
}

_settings_paths() {
    echo ""
    echo -e "    ${C_BOLD:-}Path Configuration${C_RESET:-}"
    echo ""
    echo "    Current paths:"
    echo "      Output: ${VOIDWAVE_OUTPUT_DIR:-$HOME/.voidwave/output}"
    echo "      Logs: ${VOIDWAVE_LOG_DIR:-$HOME/.voidwave/logs}"
    echo ""
    echo "    1) Change output directory"
    echo "    2) Change logs directory"
    echo "    3) Reset to defaults"
    echo "    0) Back"
    echo ""

    local choice
    read -rp "    Select [0-3]: " choice

    case "$choice" in
        1)
            local new_path
            read -rp "    New output path: " new_path
            if [[ -n "$new_path" ]]; then
                mkdir -p "$new_path" 2>/dev/null
                if [[ -d "$new_path" ]]; then
                    _save_setting "VOIDWAVE_OUTPUT_DIR" "$new_path"
                    export VOIDWAVE_OUTPUT_DIR="$new_path"
                    echo -e "    ${C_GREEN:-}Output directory updated${C_RESET:-}"
                else
                    echo -e "    ${C_RED:-}Cannot create directory${C_RESET:-}"
                fi
            fi
            ;;
        2)
            local new_path
            read -rp "    New logs path: " new_path
            if [[ -n "$new_path" ]]; then
                mkdir -p "$new_path" 2>/dev/null
                if [[ -d "$new_path" ]]; then
                    _save_setting "VOIDWAVE_LOG_DIR" "$new_path"
                    export VOIDWAVE_LOG_DIR="$new_path"
                    echo -e "    ${C_GREEN:-}Logs directory updated${C_RESET:-}"
                else
                    echo -e "    ${C_RED:-}Cannot create directory${C_RESET:-}"
                fi
            fi
            ;;
        3)
            _remove_setting "VOIDWAVE_OUTPUT_DIR"
            _remove_setting "VOIDWAVE_LOG_DIR"
            echo -e "    ${C_GREEN:-}Paths reset to defaults${C_RESET:-}"
            ;;
    esac

    wait_for_keypress
}

_settings_export() {
    echo ""

    local config_dir="${VOIDWAVE_CONFIG_DIR:-$HOME/.voidwave/config}"
    local settings_file="$config_dir/settings.conf"

    local export_path
    read -rp "    Export path [~/voidwave_config_backup.conf]: " export_path
    export_path="${export_path:-$HOME/voidwave_config_backup.conf}"

    if [[ -f "$settings_file" ]]; then
        cp "$settings_file" "$export_path"
        echo -e "    ${C_GREEN:-}Configuration exported to: $export_path${C_RESET:-}"
    else
        echo -e "    ${C_YELLOW:-}No configuration file to export${C_RESET:-}"
    fi

    wait_for_keypress
}

_settings_import() {
    echo ""

    local import_path
    read -rp "    Import from path: " import_path

    if [[ ! -f "$import_path" ]]; then
        echo -e "    ${C_RED:-}File not found${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    local config_dir="${VOIDWAVE_CONFIG_DIR:-$HOME/.voidwave/config}"
    mkdir -p "$config_dir"

    # Parse config file safely line-by-line instead of sourcing
    # This prevents arbitrary code execution from malicious config files
    local line key value
    local tmp_file
    tmp_file=$(mktemp) || { echo -e "    ${C_RED:-}Failed to create temp file${C_RESET:-}"; return 1; }

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" == \#* ]] && continue

        # Only process valid key=value lines
        if [[ "$line" =~ ^[a-zA-Z_][a-zA-Z0-9_]*= ]]; then
            key="${line%%=*}"
            value="${line#*=}"
            # Remove surrounding quotes if present
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"
            echo "${key}=${value}" >> "$tmp_file"
        fi
    done < "$import_path"

    # Atomic move to config location
    mv "$tmp_file" "$config_dir/settings.conf" 2>/dev/null || {
        cp "$tmp_file" "$config_dir/settings.conf"
        rm -f "$tmp_file"
    }

    echo -e "    ${C_GREEN:-}Configuration imported${C_RESET:-}"

    wait_for_keypress
}

_settings_reset() {
    echo ""
    echo -e "    ${C_RED:-}This will reset ALL settings to defaults${C_RESET:-}"
    echo ""

    confirm "Reset all settings?" || return

    local config_dir="${VOIDWAVE_CONFIG_DIR:-$HOME/.voidwave/config}"

    rm -f "$config_dir/settings.conf"
    rm -f "$config_dir/api_keys.conf"

    # Unset env vars
    unset VOIDWAVE_LOG_LEVEL
    unset VOIDWAVE_FILE_LOGGING
    unset VOIDWAVE_OUTPUT_DIR
    unset VOIDWAVE_LOG_DIR
    unset SHODAN_API_KEY
    unset VT_API_KEY
    unset CENSYS_API_KEY
    unset HUNTER_API_KEY

    echo -e "    ${C_GREEN:-}All settings reset to defaults${C_RESET:-}"

    wait_for_keypress
}

# Helper: Save setting to config file
_save_setting() {
    local key="$1"
    local value="$2"

    local config_dir="${VOIDWAVE_CONFIG_DIR:-$HOME/.voidwave/config}"
    local settings_file="$config_dir/settings.conf"

    mkdir -p "$config_dir"

    # Remove existing line
    if [[ -f "$settings_file" ]]; then
        grep -v "^${key}=" "$settings_file" > "$settings_file.tmp" 2>/dev/null || true
        mv "$settings_file.tmp" "$settings_file"
    fi

    # Append new value
    echo "${key}=\"${value}\"" >> "$settings_file"
    chmod 600 "$settings_file"
}

# Helper: Remove setting from config file
_remove_setting() {
    local key="$1"

    local config_dir="${VOIDWAVE_CONFIG_DIR:-$HOME/.voidwave/config}"
    local settings_file="$config_dir/settings.conf"

    if [[ -f "$settings_file" ]]; then
        grep -v "^${key}=" "$settings_file" > "$settings_file.tmp" 2>/dev/null || true
        mv "$settings_file.tmp" "$settings_file"
    fi
}

# Load settings on source
_load_settings() {
    local config_dir="${VOIDWAVE_CONFIG_DIR:-$HOME/.voidwave/config}"
    local settings_file="$config_dir/settings.conf"

    if [[ -f "$settings_file" ]]; then
        source "$settings_file" 2>/dev/null || true
    fi
    return 0
}

_load_settings || true

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export -f show_settings_menu
export -f _settings_view _settings_logging _settings_apikeys _settings_paths
export -f _settings_export _settings_import _settings_reset
export -f _configure_api_key _save_setting _remove_setting _load_settings
