#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# Wireless MAC: MAC address management, spoofing, and randomization
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_WIRELESS_MAC_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_WIRELESS_MAC_LOADED=1

# Source core if not loaded
if ! declare -F log_info &>/dev/null; then
    source "${BASH_SOURCE%/*}/../core.sh"
fi

#═══════════════════════════════════════════════════════════════════════════════
# MAC ADDRESS STORAGE
#═══════════════════════════════════════════════════════════════════════════════

# Store original MAC addresses for restoration
declare -gA _MAC_ORIGINAL=()

# Common vendor OUIs for MAC randomization
declare -ga MAC_VENDOR_OUIS=(
    "00:0C:29"   # VMware
    "00:50:56"   # VMware
    "00:1A:2B"   # Generic
    "00:1E:58"   # D-Link
    "00:1F:33"   # Netgear
    "00:21:5D"   # Cisco
    "00:23:69"   # Cisco
    "00:24:D7"   # Intel
    "00:26:C7"   # Intel
    "00:0A:F7"   # Broadcom
    "DC:A6:32"   # Raspberry Pi
    "B8:27:EB"   # Raspberry Pi
    "00:E0:4C"   # Realtek
    "AC:DE:48"   # Private
)

#═══════════════════════════════════════════════════════════════════════════════
# MAC ADDRESS FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Get current MAC address
# Args: $1 = interface name
# Returns: MAC address or empty
mac_get_current() {
    local iface="$1"

    if [[ -f "/sys/class/net/$iface/address" ]]; then
        cat "/sys/class/net/$iface/address"
    elif command -v ip &>/dev/null; then
        ip link show "$iface" 2>/dev/null | awk '/ether/{print $2}'
    elif command -v ifconfig &>/dev/null; then
        ifconfig "$iface" 2>/dev/null | awk '/ether/{print $2}'
    fi
}

# Get permanent/original MAC address
# Args: $1 = interface name
# Returns: original MAC address
mac_get_original() {
    local iface="$1"

    # Check stored original
    if [[ -n "${_MAC_ORIGINAL[$iface]}" ]]; then
        echo "${_MAC_ORIGINAL[$iface]}"
        return 0
    fi

    # Try to get permanent MAC from ethtool
    if command -v ethtool &>/dev/null; then
        local perm
        perm=$(ethtool -P "$iface" 2>/dev/null | awk '{print $3}')
        if [[ -n "$perm" && "$perm" != "00:00:00:00:00:00" ]]; then
            echo "$perm"
            return 0
        fi
    fi

    # Fall back to current MAC
    mac_get_current "$iface"
}

# Store original MAC for later restoration
# Args: $1 = interface name
mac_store_original() {
    local iface="$1"

    if [[ -z "${_MAC_ORIGINAL[$iface]}" ]]; then
        _MAC_ORIGINAL[$iface]=$(mac_get_original "$iface")
        log_debug "Stored original MAC for $iface: ${_MAC_ORIGINAL[$iface]}"
    fi
}

# Generate random MAC address
# Args: $1 = vendor OUI (optional, uses random if not specified)
# Returns: random MAC address
mac_generate_random() {
    local oui="${1:-}"

    # Use random vendor OUI if not specified
    if [[ -z "$oui" ]]; then
        local idx=$((RANDOM % ${#MAC_VENDOR_OUIS[@]}))
        oui="${MAC_VENDOR_OUIS[$idx]}"
    fi

    # Generate random NIC portion
    local nic
    nic=$(printf '%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))

    echo "${oui}:${nic}"
}

# Validate MAC address format
# Args: $1 = MAC address
# Returns: 0 if valid, 1 if invalid
mac_validate() {
    local mac="$1"
    [[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]
}

#═══════════════════════════════════════════════════════════════════════════════
# MAC ADDRESS MODIFICATION
#═══════════════════════════════════════════════════════════════════════════════

# Set MAC address (requires root)
# Args: $1 = interface, $2 = new MAC address
# Returns: 0 on success, 1 on failure
mac_set() {
    local iface="$1"
    local new_mac="$2"

    # Validate MAC
    if ! mac_validate "$new_mac"; then
        log_error "Invalid MAC address format: $new_mac"
        return 1
    fi

    # Check root
    if [[ $EUID -ne 0 ]]; then
        log_error "Root required to change MAC address"
        return 1
    fi

    # Store original if not already stored
    mac_store_original "$iface"

    log_info "Changing MAC on $iface to $new_mac"

    # Bring interface down
    ip link set "$iface" down 2>/dev/null || ifconfig "$iface" down 2>/dev/null

    # Change MAC using ip or macchanger
    if command -v macchanger &>/dev/null; then
        macchanger -m "$new_mac" "$iface" &>/dev/null
    elif command -v ip &>/dev/null; then
        ip link set "$iface" address "$new_mac" 2>/dev/null
    else
        ifconfig "$iface" hw ether "$new_mac" 2>/dev/null
    fi

    local result=$?

    # Bring interface back up
    ip link set "$iface" up 2>/dev/null || ifconfig "$iface" up 2>/dev/null

    # Verify change
    local current
    current=$(mac_get_current "$iface")

    if [[ "${current,,}" == "${new_mac,,}" ]]; then
        log_success "MAC changed to $new_mac"
        log_audit "MAC_CHANGE" "$iface" "old=${_MAC_ORIGINAL[$iface]} new=$new_mac"
        return 0
    else
        log_error "Failed to change MAC (current: $current)"
        return 1
    fi
}

# Randomize MAC address
# Args: $1 = interface, $2 = vendor OUI (optional)
mac_randomize() {
    local iface="$1"
    local oui="${2:-}"

    local new_mac
    new_mac=$(mac_generate_random "$oui")

    mac_set "$iface" "$new_mac"
}

# Restore original MAC address
# Args: $1 = interface
mac_restore() {
    local iface="$1"

    local original="${_MAC_ORIGINAL[$iface]}"

    if [[ -z "$original" ]]; then
        log_warning "No original MAC stored for $iface"
        return 1
    fi

    log_info "Restoring original MAC on $iface"

    if mac_set "$iface" "$original"; then
        log_success "MAC restored to $original"
        unset "_MAC_ORIGINAL[$iface]"
        return 0
    else
        log_error "Failed to restore original MAC"
        return 1
    fi
}

# Spoof MAC to match a specific vendor
# Args: $1 = interface, $2 = vendor name (intel, cisco, etc)
mac_spoof_vendor() {
    local iface="$1"
    local vendor="$2"

    local oui=""
    case "${vendor,,}" in
        intel)
            oui="00:24:D7"
            ;;
        cisco)
            oui="00:21:5D"
            ;;
        dlink|d-link)
            oui="00:1E:58"
            ;;
        netgear)
            oui="00:1F:33"
            ;;
        broadcom)
            oui="00:0A:F7"
            ;;
        realtek)
            oui="00:E0:4C"
            ;;
        vmware)
            oui="00:0C:29"
            ;;
        raspberry|rpi)
            oui="DC:A6:32"
            ;;
        *)
            log_warning "Unknown vendor: $vendor, using random"
            oui=""
            ;;
    esac

    mac_randomize "$iface" "$oui"
}

# Clone MAC from another device (for impersonation)
# Args: $1 = interface, $2 = MAC to clone
mac_clone() {
    local iface="$1"
    local target_mac="$2"

    if ! mac_validate "$target_mac"; then
        log_error "Invalid target MAC: $target_mac"
        return 1
    fi

    log_info "Cloning MAC $target_mac to $iface"
    mac_set "$iface" "$target_mac"
}

#═══════════════════════════════════════════════════════════════════════════════
# MAC UTILITIES
#═══════════════════════════════════════════════════════════════════════════════

# Show MAC address info
# Args: $1 = interface
mac_show_info() {
    local iface="$1"

    local current original vendor
    current=$(mac_get_current "$iface")
    original="${_MAC_ORIGINAL[$iface]:-$current}"

    # Try to get vendor from OUI
    vendor="Unknown"
    if command -v macchanger &>/dev/null; then
        vendor=$(macchanger -l 2>/dev/null | grep -i "${current:0:8}" | head -1 | cut -d'-' -f2- | xargs)
    fi

    echo ""
    echo -e "    ${C_CYAN}MAC Address Info: $iface${C_RESET}"
    echo -e "    ${C_SHADOW}$(printf '─%.0s' {1..40})${C_RESET}"
    printf "    ${C_GHOST}%-15s${C_RESET} %s\n" "Current:" "$current"
    printf "    ${C_GHOST}%-15s${C_RESET} %s\n" "Original:" "$original"
    printf "    ${C_GHOST}%-15s${C_RESET} %s\n" "Vendor:" "${vendor:-Unknown}"

    if [[ "$current" != "$original" ]]; then
        echo -e "    ${C_YELLOW}MAC is currently spoofed${C_RESET}"
    fi

    echo ""
}

# Check if MAC is spoofed
# Args: $1 = interface
# Returns: 0 if spoofed, 1 if original
mac_is_spoofed() {
    local iface="$1"

    local current original
    current=$(mac_get_current "$iface")
    original="${_MAC_ORIGINAL[$iface]:-}"

    # If no original stored, check permanent
    if [[ -z "$original" ]]; then
        original=$(mac_get_original "$iface")
    fi

    [[ "${current,,}" != "${original,,}" ]]
}

# Restore all spoofed MACs
mac_restore_all() {
    log_info "Restoring all spoofed MACs..."

    for iface in "${!_MAC_ORIGINAL[@]}"; do
        mac_restore "$iface"
    done

    log_success "All MACs restored"
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
#═══════════════════════════════════════════════════════════════════════════════

export -f mac_get_current mac_get_original mac_store_original
export -f mac_generate_random mac_validate
export -f mac_set mac_randomize mac_restore
export -f mac_spoof_vendor mac_clone
export -f mac_show_info mac_is_spoofed mac_restore_all
