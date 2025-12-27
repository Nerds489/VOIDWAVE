#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# Wireless Configuration: extends core config with wireless-specific settings
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_WIRELESS_CONFIG_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_WIRELESS_CONFIG_LOADED=1

# Source core config if not loaded
if ! declare -F config_get &>/dev/null; then
    source "${BASH_SOURCE%/*}/../config.sh"
fi

#═══════════════════════════════════════════════════════════════════════════════
# WIRELESS CONFIGURATION DEFAULTS
#═══════════════════════════════════════════════════════════════════════════════

# Default wireless configuration values
# These extend the core DEFAULT_CONFIG array
declare -gA WIRELESS_DEFAULT_CONFIG=(
    # General wireless settings
    [wireless.auto_monitor]="true"
    [wireless.5ghz_enabled]="true"
    [wireless.print_hints]="true"
    [wireless.force_nm_kill]="true"
    [wireless.window_manager]="xterm"

    # Attack timeouts (seconds)
    [wireless.deauth_count]="10"
    [wireless.handshake_timeout]="300"
    [wireless.pmkid_timeout]="30"
    [wireless.wps_timeout]="660"
    [wireless.wps_fail_limit]="100"
    [wireless.wep_timeout]="600"
    [wireless.wep_pps]="600"
    [wireless.wep_ivs_threshold]="10000"

    # Tool preferences
    [wireless.preferred_wps_tool]="reaver"
    [wireless.preferred_cracker]="hashcat"
    [wireless.preferred_dos_tool]="mdk4"
    [wireless.preferred_deauth]="aireplay"

    # Cracking settings
    [wireless.default_wordlist]="/usr/share/wordlists/rockyou.txt"
    [wireless.hashcat_rules_dir]="/usr/share/hashcat/rules"
    [wireless.use_gpu]="auto"
    [wireless.hashcat_workload]="3"

    # Evil Twin settings
    [wireless.portal_language]="en"
    [wireless.portal_template]="generic"
    [wireless.dhcp_range_start]="192.168.1.100"
    [wireless.dhcp_range_end]="192.168.1.250"
    [wireless.dhcp_gateway]="192.168.1.1"
    [wireless.dhcp_subnet]="255.255.255.0"

    # Safety settings
    [wireless.confirm_attacks]="true"
    [wireless.audit_logging]="true"
    [wireless.mac_randomization]="false"
    [wireless.warn_public_networks]="true"

    # Output settings
    [wireless.auto_save_captures]="true"
    [wireless.auto_convert_hashcat]="true"
    [wireless.verbose_attacks]="false"
)

# Ordered list for consistent output
declare -ga WIRELESS_CONFIG_KEYS=(
    "wireless.auto_monitor"
    "wireless.5ghz_enabled"
    "wireless.print_hints"
    "wireless.force_nm_kill"
    "wireless.window_manager"
    "wireless.deauth_count"
    "wireless.handshake_timeout"
    "wireless.pmkid_timeout"
    "wireless.wps_timeout"
    "wireless.wps_fail_limit"
    "wireless.wep_timeout"
    "wireless.wep_pps"
    "wireless.wep_ivs_threshold"
    "wireless.preferred_wps_tool"
    "wireless.preferred_cracker"
    "wireless.preferred_dos_tool"
    "wireless.preferred_deauth"
    "wireless.default_wordlist"
    "wireless.hashcat_rules_dir"
    "wireless.use_gpu"
    "wireless.hashcat_workload"
    "wireless.portal_language"
    "wireless.portal_template"
    "wireless.dhcp_range_start"
    "wireless.dhcp_range_end"
    "wireless.dhcp_gateway"
    "wireless.dhcp_subnet"
    "wireless.confirm_attacks"
    "wireless.audit_logging"
    "wireless.mac_randomization"
    "wireless.warn_public_networks"
    "wireless.auto_save_captures"
    "wireless.auto_convert_hashcat"
    "wireless.verbose_attacks"
)

#═══════════════════════════════════════════════════════════════════════════════
# WIRELESS CONFIG FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Initialize wireless configuration
# Merges wireless defaults into core config
wireless_config_init() {
    local key

    # Merge wireless defaults into core CONFIG if not already present
    for key in "${!WIRELESS_DEFAULT_CONFIG[@]}"; do
        if [[ -z "${CONFIG[$key]+isset}" ]]; then
            CONFIG["$key"]="${WIRELESS_DEFAULT_CONFIG[$key]}"
        fi
    done

    log_debug "Wireless configuration initialized"
}

# Get wireless config value with fallback to default
# Args: $1 = key (with or without wireless. prefix)
# Returns: value
wireless_config_get() {
    local key="$1"

    # Add prefix if not present
    [[ "$key" != wireless.* ]] && key="wireless.$key"

    # Try core config first
    local value
    value=$(config_get "$key" 2>/dev/null)

    if [[ -n "$value" ]]; then
        echo "$value"
        return 0
    fi

    # Fall back to wireless defaults
    if [[ -n "${WIRELESS_DEFAULT_CONFIG[$key]+isset}" ]]; then
        echo "${WIRELESS_DEFAULT_CONFIG[$key]}"
        return 0
    fi

    return 1
}

# Set wireless config value
# Args: $1 = key, $2 = value
wireless_config_set() {
    local key="$1"
    local value="$2"

    # Add prefix if not present
    [[ "$key" != wireless.* ]] && key="wireless.$key"

    # Use core config_set
    config_set "$key" "$value"
}

# Check if wireless config value is true
# Args: $1 = key
# Returns: 0 if true, 1 if false
wireless_config_is_true() {
    local value
    value=$(wireless_config_get "$1")
    config_is_true "$value"
}

# Display wireless configuration
wireless_config_show() {
    local key value default_value is_default

    echo ""
    echo -e "    ${C_CYAN}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "    ${C_CYAN}║${C_RESET}               ${C_BOLD}WIRELESS CONFIGURATION${C_RESET}                            ${C_CYAN}║${C_RESET}"
    echo -e "    ${C_CYAN}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""

    local current_section=""

    for key in "${WIRELESS_CONFIG_KEYS[@]}"; do
        value=$(wireless_config_get "$key")
        default_value="${WIRELESS_DEFAULT_CONFIG[$key]:-}"

        # Determine section from key
        local section="${key#wireless.}"
        section="${section%%.*}"
        section="${section%%_*}"

        # Print section header if changed
        if [[ "$section" != "$current_section" ]]; then
            current_section="$section"
            echo -e "    ${C_SHADOW}──── ${section^^} ────${C_RESET}"
        fi

        # Check if modified
        if [[ "$value" == "$default_value" ]]; then
            is_default="${C_SHADOW}(default)${C_RESET}"
        else
            is_default="${C_YELLOW}(modified)${C_RESET}"
        fi

        # Display key with short name
        local short_key="${key#wireless.}"
        printf "    ${C_GHOST}%-28s${C_RESET} = ${C_GREEN}%-20s${C_RESET} %s\n" \
            "$short_key" "$value" "$is_default"
    done

    echo ""
}

# Reset wireless configuration to defaults
wireless_config_reset() {
    local key

    log_info "Resetting wireless configuration to defaults..."

    for key in "${!WIRELESS_DEFAULT_CONFIG[@]}"; do
        CONFIG["$key"]="${WIRELESS_DEFAULT_CONFIG[$key]}"
    done

    # Persist to file
    _config_write_file

    log_success "Wireless configuration reset"
}

# Get preferred tool based on config
# Args: $1 = tool type (wps, cracker, dos, deauth)
# Returns: tool name
wireless_get_preferred_tool() {
    local tool_type="$1"

    case "$tool_type" in
        wps)
            wireless_config_get "preferred_wps_tool"
            ;;
        cracker|crack)
            wireless_config_get "preferred_cracker"
            ;;
        dos)
            wireless_config_get "preferred_dos_tool"
            ;;
        deauth)
            wireless_config_get "preferred_deauth"
            ;;
        *)
            return 1
            ;;
    esac
}

# Validate wireless configuration values
wireless_config_validate() {
    local errors=0
    local value

    # Validate numeric values
    for key in deauth_count handshake_timeout pmkid_timeout wps_timeout \
               wps_fail_limit wep_timeout wep_pps wep_ivs_threshold hashcat_workload; do
        value=$(wireless_config_get "$key")
        if [[ ! "$value" =~ ^[0-9]+$ ]]; then
            log_warning "Invalid numeric value for wireless.$key: $value"
            ((errors++)) || true
        fi
    done

    # Validate tool preferences
    value=$(wireless_config_get "preferred_wps_tool")
    if [[ "$value" != "reaver" && "$value" != "bully" ]]; then
        log_warning "Invalid WPS tool: $value (expected: reaver or bully)"
        ((errors++)) || true
    fi

    value=$(wireless_config_get "preferred_cracker")
    if [[ "$value" != "hashcat" && "$value" != "aircrack" && "$value" != "john" ]]; then
        log_warning "Invalid cracker: $value (expected: hashcat, aircrack, or john)"
        ((errors++)) || true
    fi

    value=$(wireless_config_get "preferred_dos_tool")
    if [[ "$value" != "mdk3" && "$value" != "mdk4" && "$value" != "aireplay" ]]; then
        log_warning "Invalid DoS tool: $value (expected: mdk3, mdk4, or aireplay)"
        ((errors++)) || true
    fi

    # Validate window manager
    value=$(wireless_config_get "window_manager")
    if [[ "$value" != "xterm" && "$value" != "tmux" && "$value" != "screen" ]]; then
        log_warning "Invalid window manager: $value (expected: xterm, tmux, or screen)"
        ((errors++)) || true
    fi

    # Validate GPU setting
    value=$(wireless_config_get "use_gpu")
    if [[ "$value" != "auto" && "$value" != "true" && "$value" != "false" ]]; then
        log_warning "Invalid GPU setting: $value (expected: auto, true, or false)"
        ((errors++)) || true
    fi

    if [[ $errors -eq 0 ]]; then
        log_success "Wireless configuration validated"
        return 0
    else
        log_error "Configuration has $errors error(s)"
        return 1
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
#═══════════════════════════════════════════════════════════════════════════════

export -f wireless_config_init wireless_config_get wireless_config_set
export -f wireless_config_is_true wireless_config_show wireless_config_reset
export -f wireless_get_preferred_tool wireless_config_validate
