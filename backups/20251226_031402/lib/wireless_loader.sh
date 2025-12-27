#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# Wireless Module Loader: Loads all wireless attack modules
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_WIRELESS_LOADER_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_WIRELESS_LOADER_LOADED=1

# Get script directory
_WIRELESS_LIB_DIR="${BASH_SOURCE%/*}"

# Source core if not loaded
if ! declare -F log_info &>/dev/null; then
    source "${_WIRELESS_LIB_DIR}/core.sh"
fi

#═══════════════════════════════════════════════════════════════════════════════
# MODULE LOADING
#═══════════════════════════════════════════════════════════════════════════════

# Core wireless infrastructure
_wireless_core_modules=(
    "intelligence/help.sh"
    "intelligence/preflight.sh"
    "intelligence/targeting.sh"
    "intelligence/wireless_menu_smart.sh"
    "wireless/config.sh"
    "wireless/adapter.sh"
    "wireless/deps.sh"
    "wireless/loot.sh"
    "wireless/session.sh"
    "wireless/mac.sh"
)

# Attack modules
_wireless_attack_modules=(
    "attacks/wps.sh"
    "attacks/handshake.sh"
    "attacks/pmkid.sh"
    "attacks/dos.sh"
    "attacks/eviltwin.sh"
    "attacks/wep.sh"
    "attacks/enterprise.sh"
    "attacks/advanced.sh"
)

# Automation and cracking
_wireless_extra_modules=(
    "automation/engine.sh"
    "cracking/cracker.sh"
)

# Load module with error handling
_load_module() {
    local module="$1"
    local path="${_WIRELESS_LIB_DIR}/${module}"

    if [[ -f "$path" ]]; then
        # shellcheck source=/dev/null
        source "$path" 2>/dev/null && return 0
    fi
    return 1
}

# Load all wireless modules
wireless_load_all() {
    local loaded=0
    local failed=0

    log_info "Loading wireless modules..."

    # Load core modules first
    for module in "${_wireless_core_modules[@]}"; do
        if _load_module "$module"; then
            ((loaded++)) || true
        else
            ((failed++)) || true
            log_debug "Could not load: $module"
        fi
    done

    # Load attack modules
    for module in "${_wireless_attack_modules[@]}"; do
        if _load_module "$module"; then
            ((loaded++)) || true
        else
            ((failed++)) || true
            log_debug "Could not load: $module"
        fi
    done

    # Load extra modules
    for module in "${_wireless_extra_modules[@]}"; do
        if _load_module "$module"; then
            ((loaded++)) || true
        else
            ((failed++)) || true
            log_debug "Could not load: $module"
        fi
    done

    log_success "Loaded $loaded wireless modules"
    [[ $failed -gt 0 ]] && log_warning "$failed modules not found"

    return 0
}

# Load only essential modules (faster startup)
wireless_load_essential() {
    log_info "Loading essential wireless modules..."

    for module in "${_wireless_core_modules[@]}"; do
        _load_module "$module"
    done
}

# Load specific attack module
# Args: $1 = attack type (wps, handshake, pmkid, dos, eviltwin, wep, enterprise)
wireless_load_attack() {
    local attack_type="$1"

    case "$attack_type" in
        wps|handshake|pmkid|dos|eviltwin|wep|enterprise|advanced)
            _load_module "attacks/${attack_type}.sh"
            ;;
        automation)
            _load_module "automation/engine.sh"
            ;;
        cracking)
            _load_module "cracking/cracker.sh"
            ;;
        *)
            log_error "Unknown attack type: $attack_type"
            return 1
            ;;
    esac
}

#═══════════════════════════════════════════════════════════════════════════════
# MODULE STATUS
#═══════════════════════════════════════════════════════════════════════════════

# Show loaded modules
wireless_show_modules() {
    echo ""
    echo -e "    ${C_CYAN}Wireless Module Status${C_RESET}"
    echo -e "    ${C_SHADOW}$(printf '─%.0s' {1..50})${C_RESET}"

    echo -e "    ${C_WHITE}Core Infrastructure:${C_RESET}"
    for module in "${_wireless_core_modules[@]}"; do
        local name="${module##*/}"
        name="${name%.sh}"
        local var="_VOIDWAVE_${name^^}_LOADED"
        var="${var//-/_}"

        if [[ -n "${!var:-}" ]]; then
            echo -e "      ${C_GREEN}✓${C_RESET} $name"
        else
            echo -e "      ${C_RED}✗${C_RESET} $name"
        fi
    done

    echo ""
    echo -e "    ${C_WHITE}Attack Modules:${C_RESET}"
    for module in "${_wireless_attack_modules[@]}"; do
        local name="${module##*/}"
        name="${name%.sh}"
        local var="_VOIDWAVE_${name^^}_LOADED"

        if [[ -n "${!var:-}" ]]; then
            echo -e "      ${C_GREEN}✓${C_RESET} $name"
        else
            echo -e "      ${C_RED}✗${C_RESET} $name"
        fi
    done

    echo ""
    echo -e "    ${C_WHITE}Extra Modules:${C_RESET}"
    for module in "${_wireless_extra_modules[@]}"; do
        local name="${module##*/}"
        name="${name%.sh}"
        local var="_VOIDWAVE_${name^^}_LOADED"
        var="${var//-/_}"

        if [[ -n "${!var:-}" ]]; then
            echo -e "      ${C_GREEN}✓${C_RESET} $name"
        else
            echo -e "      ${C_RED}✗${C_RESET} $name"
        fi
    done

    echo ""
}

#═══════════════════════════════════════════════════════════════════════════════
# QUICK ACCESS FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Quick WPS attack
wireless_attack_wps() {
    wireless_load_attack "wps"
    declare -F wps_pixie_auto &>/dev/null && wps_pixie_auto "$@"
}

# Quick handshake capture
wireless_attack_handshake() {
    wireless_load_attack "handshake"
    declare -F handshake_capture_full &>/dev/null && handshake_capture_full "$@"
}

# Quick PMKID capture
wireless_attack_pmkid() {
    wireless_load_attack "pmkid"
    declare -F pmkid_capture_target &>/dev/null && pmkid_capture_target "$@"
}

# Quick deauth attack
wireless_attack_deauth() {
    wireless_load_attack "dos"
    declare -F dos_deauth &>/dev/null && dos_deauth "$@"
}

# Quick evil twin
wireless_attack_eviltwin() {
    wireless_load_attack "eviltwin"
    declare -F et_attack_full &>/dev/null && et_attack_full "$@"
}

# Auto crack
wireless_crack() {
    wireless_load_attack "cracking"
    declare -F crack_auto &>/dev/null && crack_auto "$@"
}

# Pillage mode
wireless_pillage() {
    wireless_load_attack "automation"
    declare -F auto_pillage &>/dev/null && auto_pillage "$@"
}

#═══════════════════════════════════════════════════════════════════════════════
# AUTO-LOAD (DISABLED FOR PERFORMANCE)
#═══════════════════════════════════════════════════════════════════════════════

# NOTE: Auto-loading disabled for performance optimization.
# Loading 16 modules on every startup adds ~200ms overhead even when wireless
# features are not used. Modules are now loaded on-demand via:
#   - wireless_load_all()       - Load all modules when entering WiFi menu
#   - wireless_load_essential() - Load only core infrastructure
#   - wireless_load_attack()    - Load specific attack module when needed
#
# To restore auto-loading, uncomment the line below:
# wireless_load_all

#═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
#═══════════════════════════════════════════════════════════════════════════════

export -f wireless_load_all wireless_load_essential wireless_load_attack
export -f wireless_show_modules
export -f wireless_attack_wps wireless_attack_handshake wireless_attack_pmkid
export -f wireless_attack_deauth wireless_attack_eviltwin
export -f wireless_crack wireless_pillage
