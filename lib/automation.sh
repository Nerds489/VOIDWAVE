#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Automation Library
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# Smart automation: auto-detect, auto-fix, auto-acquire missing requirements
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_AUTOMATION_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_AUTOMATION_LOADED=1

# ═══════════════════════════════════════════════════════════════════════════════
# AUTO-INTERFACE: Select wireless interface automatically
# ═══════════════════════════════════════════════════════════════════════════════

# Auto-select a wireless interface
# If only one exists, use it. If multiple, pick first or prompt.
# Returns: interface name on stdout, 0 on success
auto_select_interface() {
    local interfaces=()
    local iface

    # Get all wireless interfaces
    for iface_path in /sys/class/net/*; do
        iface=$(basename "$iface_path")
        if is_wireless_interface "$iface" 2>/dev/null; then
            interfaces+=("$iface")
        fi
    done

    if [[ ${#interfaces[@]} -eq 0 ]]; then
        log_error "No wireless interfaces found"
        return 1
    fi

    if [[ ${#interfaces[@]} -eq 1 ]]; then
        log_info "Auto-selected interface: ${interfaces[0]}"
        echo "${interfaces[0]}"
        return 0
    fi

    # Multiple interfaces - prefer monitor mode ones first
    for iface in "${interfaces[@]}"; do
        if check_monitor_mode "$iface" &>/dev/null; then
            log_info "Auto-selected monitor interface: $iface"
            echo "$iface"
            return 0
        fi
    done

    # No monitor interface, use first one
    log_info "Auto-selected interface: ${interfaces[0]}"
    echo "${interfaces[0]}"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# AUTO-MONITOR: Ensure interface is in monitor mode
# ═══════════════════════════════════════════════════════════════════════════════

# Ensure interface is in monitor mode, enable if not
# Args: $1 = interface (optional - auto-selects if empty)
# Returns: monitor interface name on stdout
auto_ensure_monitor() {
    local iface="${1:-}"

    # Auto-select if not provided
    if [[ -z "$iface" ]]; then
        iface=$(auto_select_interface) || return 1
    fi

    # Check if already in monitor mode
    if check_monitor_mode "$iface" &>/dev/null; then
        echo "$iface"
        return 0
    fi

    # Not in monitor mode - enable it
    log_warning "$iface not in monitor mode, enabling..."
    local mon_iface
    mon_iface=$(enable_monitor_mode "$iface") || {
        log_error "Failed to enable monitor mode on $iface"
        return 1
    }

    log_success "Monitor mode enabled: $mon_iface"
    echo "$mon_iface"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# AUTO-TARGET: Discover targets when none specified
# ═══════════════════════════════════════════════════════════════════════════════

# Get local network CIDR for scanning
# Returns: CIDR notation (e.g., 192.168.1.0/24)
auto_get_local_network() {
    local gateway iface cidr

    # Get default gateway and interface
    read -r gateway iface <<< "$(ip route | awk '/default/ {print $3, $5; exit}')"

    if [[ -z "$gateway" ]]; then
        log_error "No default gateway found"
        return 1
    fi

    # Get CIDR from interface
    cidr=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2; exit}')

    if [[ -z "$cidr" ]]; then
        # Fallback: guess /24 from gateway
        cidr="${gateway%.*}.0/24"
    else
        # Convert host CIDR to network CIDR
        local ip="${cidr%/*}"
        local mask="${cidr#*/}"
        cidr="${ip%.*}.0/${mask}"
    fi

    log_info "Detected local network: $cidr"
    echo "$cidr"
    return 0
}

# Quick network scan to find live hosts
# Args: $1 = CIDR (optional, auto-detects)
# Returns: list of live IPs
auto_discover_hosts() {
    local cidr="${1:-}"

    # Auto-detect network if not provided
    if [[ -z "$cidr" ]]; then
        cidr=$(auto_get_local_network) || return 1
    fi

    log_info "Scanning for live hosts on $cidr..."

    # Use nmap ping scan (fast)
    if command -v nmap &>/dev/null; then
        run_with_sudo nmap -sn -n "$cidr" 2>/dev/null | \
            awk '/Nmap scan report/ {print $5}' | \
            grep -v "$(hostname -I 2>/dev/null | awk '{print $1}')" || true
        return 0
    fi

    # Fallback: arp-scan
    if command -v arp-scan &>/dev/null; then
        run_with_sudo arp-scan -l 2>/dev/null | \
            awk '/^[0-9]+\./ {print $1}' || true
        return 0
    fi

    log_error "No scanning tool available (need nmap or arp-scan)"
    return 1
}

# Auto-select a target from discovered hosts
# Returns: selected IP on stdout
auto_select_target() {
    local hosts
    hosts=$(auto_discover_hosts) || return 1

    local host_array=()
    while IFS= read -r host; do
        [[ -n "$host" ]] && host_array+=("$host")
    done <<< "$hosts"

    if [[ ${#host_array[@]} -eq 0 ]]; then
        log_error "No live hosts found on network"
        return 1
    fi

    if [[ ${#host_array[@]} -eq 1 ]]; then
        log_info "Auto-selected target: ${host_array[0]}"
        echo "${host_array[0]}"
        return 0
    fi

    # Multiple hosts - show selection menu
    echo -e "\n    ${C_BOLD}${C_CYAN}Discovered Hosts:${C_RESET}" >&2
    local i=1
    for host in "${host_array[@]}"; do
        echo -e "    ${C_WHITE}[$i]${C_RESET} $host" >&2
        ((i++))
    done

    echo -ne "\n    Select target [1-${#host_array[@]}]: " >&2
    local choice
    read -r choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#host_array[@]} )); then
        local selected="${host_array[$((choice-1))]}"
        log_info "Selected target: $selected"
        echo "$selected"
        return 0
    fi

    # Invalid choice - use first
    log_warning "Invalid selection, using first host: ${host_array[0]}"
    echo "${host_array[0]}"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# AUTO-CLIENT: Discover WiFi clients for deauth attacks
# ═══════════════════════════════════════════════════════════════════════════════

# Scan for access points
# Args: $1 = monitor interface
# Returns: list of APs (BSSID CHANNEL ESSID)
auto_scan_aps() {
    local iface="${1:-}"

    # Auto-get monitor interface
    if [[ -z "$iface" ]]; then
        iface=$(auto_ensure_monitor) || return 1
    fi

    log_info "Scanning for access points on $iface..."

    if ! command -v airodump-ng &>/dev/null; then
        log_error "airodump-ng not installed"
        return 1
    fi

    # Run quick scan (5 seconds)
    local tmpfile="/tmp/voidwave_apscan_$$"
    timeout 6 run_with_sudo airodump-ng --write-interval 1 -w "$tmpfile" --output-format csv "$iface" &>/dev/null || true

    # Parse results
    if [[ -f "${tmpfile}-01.csv" ]]; then
        # Extract BSSID, Channel, ESSID from CSV
        awk -F',' '
            NR>2 && $1 ~ /^[0-9A-Fa-f:]+$/ && length($1)==17 {
                gsub(/^ +| +$/, "", $1)  # BSSID
                gsub(/^ +| +$/, "", $4)  # Channel
                gsub(/^ +| +$/, "", $14) # ESSID
                if ($4 != "" && $4 > 0) print $1, $4, $14
            }
        ' "${tmpfile}-01.csv" 2>/dev/null | head -20
        rm -f "${tmpfile}"* 2>/dev/null
        return 0
    fi

    rm -f "${tmpfile}"* 2>/dev/null
    log_warning "No access points found"
    return 1
}

# Scan for clients connected to an AP
# Args: $1 = BSSID, $2 = channel, $3 = interface
# Returns: list of client MACs
auto_scan_clients() {
    local bssid="$1"
    local channel="${2:-}"
    local iface="${3:-}"

    if [[ -z "$bssid" ]]; then
        log_error "BSSID required"
        return 1
    fi

    # Auto-get monitor interface
    if [[ -z "$iface" ]]; then
        iface=$(auto_ensure_monitor) || return 1
    fi

    # Set channel if provided
    if [[ -n "$channel" ]]; then
        run_with_sudo iw dev "$iface" set channel "$channel" 2>/dev/null || true
    fi

    log_info "Scanning for clients on $bssid..."

    # Run targeted scan (8 seconds)
    local tmpfile="/tmp/voidwave_clscan_$$"
    timeout 9 run_with_sudo airodump-ng --bssid "$bssid" --write-interval 1 -w "$tmpfile" --output-format csv "$iface" &>/dev/null || true

    # Parse client MACs from CSV
    if [[ -f "${tmpfile}-01.csv" ]]; then
        awk -F',' '
            /Station MAC/ {capture=1; next}
            capture && $1 ~ /^[0-9A-Fa-f:]+$/ && length($1)==17 {
                gsub(/^ +| +$/, "", $1)
                print $1
            }
        ' "${tmpfile}-01.csv" 2>/dev/null | head -20
        rm -f "${tmpfile}"* 2>/dev/null
        return 0
    fi

    rm -f "${tmpfile}"* 2>/dev/null
    log_warning "No clients found on $bssid"
    return 1
}

# Interactive AP + client selection
# Returns: sets AP_BSSID, AP_CHANNEL, AP_ESSID, CLIENT_MAC globals
auto_select_ap_and_client() {
    local iface="${1:-}"

    # Ensure monitor mode
    iface=$(auto_ensure_monitor "$iface") || return 1

    # Scan for APs
    local aps
    aps=$(auto_scan_aps "$iface") || return 1

    local ap_array=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && ap_array+=("$line")
    done <<< "$aps"

    if [[ ${#ap_array[@]} -eq 0 ]]; then
        log_error "No access points found"
        return 1
    fi

    # Show AP selection
    echo -e "\n    ${C_BOLD}${C_CYAN}Access Points:${C_RESET}" >&2
    local i=1
    for ap in "${ap_array[@]}"; do
        local bssid chan essid
        read -r bssid chan essid <<< "$ap"
        printf "    ${C_WHITE}[%d]${C_RESET} %-17s  CH:%-2s  %s\n" "$i" "$bssid" "$chan" "${essid:-<hidden>}" >&2
        ((i++))
    done

    echo -ne "\n    Select AP [1-${#ap_array[@]}]: " >&2
    local choice
    read -r choice

    local selected_ap
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#ap_array[@]} )); then
        selected_ap="${ap_array[$((choice-1))]}"
    else
        selected_ap="${ap_array[0]}"
    fi

    read -r AP_BSSID AP_CHANNEL AP_ESSID <<< "$selected_ap"
    export AP_BSSID AP_CHANNEL AP_ESSID

    log_info "Selected AP: $AP_BSSID (${AP_ESSID:-hidden}) on channel $AP_CHANNEL"

    # Scan for clients on this AP
    local clients
    clients=$(auto_scan_clients "$AP_BSSID" "$AP_CHANNEL" "$iface") || {
        log_warning "No clients found, will broadcast deauth"
        CLIENT_MAC="FF:FF:FF:FF:FF:FF"
        export CLIENT_MAC
        return 0
    }

    local client_array=()
    while IFS= read -r mac; do
        [[ -n "$mac" ]] && client_array+=("$mac")
    done <<< "$clients"

    if [[ ${#client_array[@]} -eq 0 ]]; then
        log_warning "No clients found, will broadcast deauth"
        CLIENT_MAC="FF:FF:FF:FF:FF:FF"
        export CLIENT_MAC
        return 0
    fi

    # Show client selection
    echo -e "\n    ${C_BOLD}${C_CYAN}Connected Clients:${C_RESET}" >&2
    echo -e "    ${C_WHITE}[0]${C_RESET} FF:FF:FF:FF:FF:FF  (Broadcast - all clients)" >&2
    i=1
    for mac in "${client_array[@]}"; do
        printf "    ${C_WHITE}[%d]${C_RESET} %s\n" "$i" "$mac" >&2
        ((i++))
    done

    echo -ne "\n    Select client [0-${#client_array[@]}]: " >&2
    read -r choice

    if [[ "$choice" == "0" ]]; then
        CLIENT_MAC="FF:FF:FF:FF:FF:FF"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#client_array[@]} )); then
        CLIENT_MAC="${client_array[$((choice-1))]}"
    else
        CLIENT_MAC="FF:FF:FF:FF:FF:FF"
    fi
    export CLIENT_MAC

    log_info "Selected client: $CLIENT_MAC"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# AUTO-INSTALL: Install missing tools
# ═══════════════════════════════════════════════════════════════════════════════

# Check and install a tool if missing
# Args: $1 = tool name, $2 = package name (optional, defaults to tool name)
auto_install_tool() {
    local tool="$1"
    local pkg="${2:-$tool}"

    if command -v "$tool" &>/dev/null; then
        return 0
    fi

    log_warning "$tool not found, attempting to install..."

    # Detect package manager and install
    if command -v apt-get &>/dev/null; then
        run_with_sudo apt-get update -qq && run_with_sudo apt-get install -y -qq "$pkg"
    elif command -v dnf &>/dev/null; then
        run_with_sudo dnf install -y -q "$pkg"
    elif command -v pacman &>/dev/null; then
        run_with_sudo pacman -S --noconfirm "$pkg"
    elif command -v zypper &>/dev/null; then
        run_with_sudo zypper install -y "$pkg"
    else
        log_error "Unknown package manager, cannot auto-install $tool"
        return 1
    fi

    # Verify installation
    if command -v "$tool" &>/dev/null; then
        log_success "$tool installed successfully"
        return 0
    fi

    log_error "Failed to install $tool"
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# PREFLIGHT CHECK: All-in-one requirement checker
# ═══════════════════════════════════════════════════════════════════════════════

# Run preflight checks for an operation
# Args: $1 = operation type (scan, wifi, deauth, capture, etc.)
# Sets globals and returns 0 if ready, 1 if cannot proceed
auto_preflight() {
    local operation="${1:-}"

    case "$operation" in
        scan)
            # Need: nmap or masscan, target
            auto_install_tool nmap || auto_install_tool masscan || return 1
            if [[ -z "${TARGET:-}" ]]; then
                TARGET=$(auto_select_target) || return 1
                export TARGET
            fi
            ;;

        wifi|monitor)
            # Need: wireless interface in monitor mode
            MONITOR_IFACE=$(auto_ensure_monitor "${IFACE:-}") || return 1
            export MONITOR_IFACE
            ;;

        deauth)
            # Need: aircrack-ng suite, monitor mode, AP, client
            auto_install_tool aireplay-ng aircrack-ng || return 1
            auto_select_ap_and_client "${IFACE:-}" || return 1
            MONITOR_IFACE=$(auto_ensure_monitor "${IFACE:-}") || return 1
            export MONITOR_IFACE
            ;;

        capture)
            # Need: airodump-ng, monitor mode
            auto_install_tool airodump-ng aircrack-ng || return 1
            MONITOR_IFACE=$(auto_ensure_monitor "${IFACE:-}") || return 1
            export MONITOR_IFACE
            ;;

        crack)
            # Need: aircrack-ng or hashcat, capture file
            auto_install_tool aircrack-ng || auto_install_tool hashcat || return 1
            ;;

        *)
            log_debug "No preflight for operation: $operation"
            ;;
    esac

    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export -f auto_select_interface
export -f auto_ensure_monitor
export -f auto_get_local_network
export -f auto_discover_hosts
export -f auto_select_target
export -f auto_scan_aps
export -f auto_scan_clients
export -f auto_select_ap_and_client
export -f auto_install_tool
export -f auto_preflight
