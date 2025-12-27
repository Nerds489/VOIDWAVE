#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# Wireless library: interface detection, monitor mode management, validation
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_WIRELESS_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_WIRELESS_LOADED=1

# Source core library for logging, colors, and sudo helpers
source "${BASH_SOURCE%/*}/core.sh"

#
# NOTE:
# - is_wireless_interface() lives in lib/detection.sh as the single source of truth.
# - This file intentionally does NOT duplicate that function.
#

# Safety: if someone sources lib/wireless.sh directly without detection.sh
if ! declare -F is_wireless_interface >/dev/null 2>&1; then
    # shellcheck disable=SC1091
    source "${VOIDWAVE_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}/lib/detection.sh" 2>/dev/null || true
fi

#═══════════════════════════════════════════════════════════════════════════════
# WIRELESS INTERFACE DETECTION
#═══════════════════════════════════════════════════════════════════════════════

# is_wireless_interface() is defined in lib/detection.sh (single source of truth)
# The safety source above ensures it's available.

# List all wireless interfaces
# Returns: one interface per line
# Exit: 0 if found, 1 if none
get_wireless_interfaces() {
    local interfaces=()
    local iface

    for iface_path in /sys/class/net/*; do
        iface=$(basename "$iface_path")
        if is_wireless_interface "$iface"; then
            interfaces+=("$iface")
        fi
    done

    if [[ ${#interfaces[@]} -eq 0 ]]; then
        log_warning "No wireless interfaces found"
        return 1
    fi

    printf '%s\n' "${interfaces[@]}"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# INTERFACE VALIDATION
#═══════════════════════════════════════════════════════════════════════════════

# Validate that an interface exists and is wireless
# Args: $1 = interface name
# Returns: 0 if valid wireless interface, 1 otherwise
validate_wireless_interface() {
    local iface="$1"

    # Check for empty argument
    if [[ -z "$iface" ]]; then
        log_error "No interface specified"
        return 1
    fi

    # Check interface exists
    if [[ ! -d "/sys/class/net/$iface" ]]; then
        log_error "Interface '$iface' does not exist"
        return 1
    fi

    # Check if wireless
    if ! is_wireless_interface "$iface"; then
        log_error "'$iface' is not a wireless interface"
        return 1
    fi

    log_success "Interface $iface validated"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# MONITOR MODE DETECTION
#═══════════════════════════════════════════════════════════════════════════════

# Check if interface is in monitor mode
# Args: $1 = interface name
# Returns: 0 if monitor mode, 1 if managed/other
# Outputs: colored status line
check_monitor_mode() {
    local iface="$1"
    local mode=""

    # Validate input
    if [[ -z "$iface" ]]; then
        return 1
    fi

    # Check interface exists
    if [[ ! -d "/sys/class/net/$iface" ]]; then
        return 1
    fi

    # Method 1: Try iwconfig (legacy but widely supported)
    if command -v iwconfig &>/dev/null; then
        mode=$(iwconfig "$iface" 2>/dev/null | sed -n 's/.*Mode:\([A-Za-z]*\).*/\1/p' || true)
    fi

    # Method 2: Try iw (modern)
    if [[ -z "$mode" ]] && command -v iw &>/dev/null; then
        mode=$(iw dev "$iface" info 2>/dev/null | awk '/type/ {print $2}' || true)
    fi

    # Evaluate mode
    if [[ "${mode,,}" == "monitor" ]]; then
        echo -e "    ${C_GREEN}[✓]${C_RESET} $iface: ${C_GREEN}MONITOR${C_RESET}"
        return 0
    else
        echo -e "    ${C_YELLOW}[!]${C_RESET} $iface: ${C_YELLOW}MANAGED${C_RESET}"
        return 1
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# MONITOR MODE MANAGEMENT
#═══════════════════════════════════════════════════════════════════════════════

# Enable monitor mode on interface
# Args: $1 = interface name
# Returns: 0 on success, 1 on failure
# Outputs: resulting interface name (may be iface or ifacemon)
enable_monitor_mode() {
    local iface="$1"

    # Validate interface
    if ! validate_wireless_interface "$iface"; then
        return 1
    fi

    # Check if already in monitor mode
    if check_monitor_mode "$iface" &>/dev/null; then
        echo "$iface"
        return 0
    fi

    log_info "Enabling monitor mode on $iface..."

    # Method 1: Try airmon-ng (preferred - handles interfering processes)
    if command -v airmon-ng &>/dev/null; then
        # Kill interfering processes
        run_with_sudo airmon-ng check kill &>/dev/null || true

        # Start monitor mode
        run_with_sudo airmon-ng start "$iface" &>/dev/null || true

        # Check for renamed interface (e.g., wlan0mon)
        if [[ -d "/sys/class/net/${iface}mon" ]]; then
            if check_monitor_mode "${iface}mon" &>/dev/null; then
                echo "${iface}mon"
                return 0
            fi
        fi

        # Check if original interface is now in monitor mode
        if check_monitor_mode "$iface" &>/dev/null; then
            echo "$iface"
            return 0
        fi
    fi

    # Method 2: Manual fallback using ip/iw
    run_with_sudo ip link set "$iface" down 2>/dev/null || true
    run_with_sudo iw dev "$iface" set type monitor 2>/dev/null || true
    run_with_sudo ip link set "$iface" up 2>/dev/null || true

    # Verify monitor mode enabled
    if check_monitor_mode "$iface" &>/dev/null; then
        echo "$iface"
        return 0
    fi

    log_error "Failed to enable monitor mode on $iface"
    return 1
}

# Disable monitor mode on interface
# Args: $1 = interface name (could be iface or ifacemon)
# Returns: 0 on success (always succeeds with best effort)
disable_monitor_mode() {
    local iface="$1"

    if [[ -z "$iface" ]]; then
        log_error "No interface specified"
        return 1
    fi

    log_info "Disabling monitor mode on $iface..."

    # Method 1: Try airmon-ng (handles renamed interfaces)
    if command -v airmon-ng &>/dev/null; then
        run_with_sudo airmon-ng stop "$iface" &>/dev/null || true
    fi

    # Method 2: Manual fallback - always attempt
    run_with_sudo ip link set "$iface" down 2>/dev/null || true
    run_with_sudo iw dev "$iface" set type managed 2>/dev/null || true
    run_with_sudo ip link set "$iface" up 2>/dev/null || true

    # Restart NetworkManager if running (best effort)
    if command -v systemctl &>/dev/null; then
        if systemctl is-active --quiet NetworkManager 2>/dev/null; then
            run_with_sudo systemctl restart NetworkManager &>/dev/null || true
        fi
    fi

    log_success "Monitor mode disabled"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
#═══════════════════════════════════════════════════════════════════════════════

export -f is_wireless_interface
export -f get_wireless_interfaces
export -f validate_wireless_interface
export -f check_monitor_mode
export -f enable_monitor_mode
export -f disable_monitor_mode
