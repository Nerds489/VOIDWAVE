#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE Intelligent Auto-Detection System
# ═══════════════════════════════════════════════════════════════════════════════
# Automatic detection and selection of:
# - Wireless interfaces (with capability checking)
# - Monitor mode (auto-enable)
# - Targets (auto-scan, smart selection)
# - Clients (auto-detect for targeted attacks)
# - Network info (IP, gateway, subnet)
# ═══════════════════════════════════════════════════════════════════════════════

[[ -n "${_VOIDWAVE_AUTO_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_AUTO_LOADED=1

# Source dependencies
source "${BASH_SOURCE%/*}/targeting.sh" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════════
# GLOBAL STATE
# ═══════════════════════════════════════════════════════════════════════════════

declare -g _CURRENT_IFACE=""         # Selected wireless interface
declare -g _MONITOR_IFACE=""         # Monitor mode interface
declare -g AUTO_SILENT=0             # Suppress output when 1
declare -g AUTO_LAST_ERROR=""        # Last error message

# Network detection cache
declare -g _LOCAL_IP=""
declare -g _GATEWAY_IP=""
declare -g _SUBNET=""
declare -g _DEFAULT_IFACE=""

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY
# ═══════════════════════════════════════════════════════════════════════════════

_auto_log() {
    [[ $AUTO_SILENT -eq 1 ]] && return
    echo -e "    ${C_CYAN:-}⟳${C_RESET:-} $*"
}

_auto_ok() {
    [[ $AUTO_SILENT -eq 1 ]] && return
    echo -e "    ${C_GREEN:-}✓${C_RESET:-} $*"
}

_auto_warn() {
    [[ $AUTO_SILENT -eq 1 ]] && return
    echo -e "    ${C_YELLOW:-}!${C_RESET:-} $*" >&2
}

_auto_fail() {
    AUTO_LAST_ERROR="$1"
    [[ $AUTO_SILENT -eq 1 ]] && return 1
    echo -e "    ${C_RED:-}✗${C_RESET:-} $*" >&2
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# WIRELESS INTERFACE AUTO-DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

# Get all wireless interfaces
get_wireless_interfaces() {
    iw dev 2>/dev/null | awk '/Interface/{print $2}'
}

# Get interfaces that support monitor mode
get_monitor_capable_interfaces() {
    local -a capable=()

    while IFS= read -r iface; do
        [[ -z "$iface" ]] && continue
        local phy
        phy=$(iw dev "$iface" info 2>/dev/null | awk '/wiphy/{print $2}')
        [[ -z "$phy" ]] && continue

        # Check if phy supports monitor mode
        if iw phy "phy${phy}" info 2>/dev/null | grep -q "monitor"; then
            capable+=("$iface")
        fi
    done < <(get_wireless_interfaces)

    printf '%s\n' "${capable[@]}"
}

# Get interface info (driver, chipset, mode)
get_interface_info() {
    local iface="$1"
    local driver chipset mode phy

    driver=$(ethtool -i "$iface" 2>/dev/null | awk '/driver:/{print $2}')
    mode=$(iw dev "$iface" info 2>/dev/null | awk '/type/{print $2}')
    phy=$(iw dev "$iface" info 2>/dev/null | awk '/wiphy/{print $2}')

    # Try to get chipset from modalias
    if [[ -n "$phy" ]] && [[ -f "/sys/class/ieee80211/phy${phy}/device/modalias" ]]; then
        chipset=$(cat "/sys/class/ieee80211/phy${phy}/device/modalias" 2>/dev/null | cut -c1-20)
    fi

    echo "${driver:-unknown}|${mode:-managed}|${chipset:-unknown}"
}

# Score interface for attack suitability (higher = better)
score_interface() {
    local iface="$1"
    local score=0
    local info driver mode

    info=$(get_interface_info "$iface")
    IFS='|' read -r driver mode _ <<< "$info"

    # Already in monitor mode = best
    [[ "$mode" == "monitor" ]] && ((score += 100))

    # Preferred drivers (known good for packet injection)
    case "$driver" in
        ath9k_htc|ath9k|rt2800usb|rtl8187|rt2500usb|carl9170) ((score += 50)) ;;
        rtl88*|rtl8*|mt76*|mt7921*) ((score += 30)) ;;
        iwlwifi) ((score += 10)) ;; # Intel - limited injection support
    esac

    # USB adapters often better for pentest
    [[ -e "/sys/class/net/${iface}/device/driver" ]] && \
        readlink "/sys/class/net/${iface}/device/driver" 2>/dev/null | grep -q "usb" && \
        ((score += 20))

    echo "$score"
}

# Auto-select best wireless interface
# Sets: _CURRENT_IFACE
auto_interface() {
    # Already have one?
    if [[ -n "$_CURRENT_IFACE" ]] && ip link show "$_CURRENT_IFACE" &>/dev/null; then
        return 0
    fi

    _auto_log "Detecting wireless interfaces..."

    local -a ifaces=()
    local -a scores=()
    local best_iface="" best_score=-1

    # Get monitor-capable interfaces
    while IFS= read -r iface; do
        [[ -z "$iface" ]] && continue
        ifaces+=("$iface")
        local score
        score=$(score_interface "$iface")
        scores+=("$score")

        if [[ $score -gt $best_score ]]; then
            best_score=$score
            best_iface="$iface"
        fi
    done < <(get_monitor_capable_interfaces)

    if [[ -z "$best_iface" ]]; then
        # Fallback to any wireless interface
        best_iface=$(get_wireless_interfaces | head -1)
    fi

    if [[ -z "$best_iface" ]]; then
        _auto_fail "No wireless interfaces found"
        return 1
    fi

    _CURRENT_IFACE="$best_iface"
    local info
    info=$(get_interface_info "$best_iface")
    IFS='|' read -r driver mode _ <<< "$info"

    _auto_ok "Selected interface: $_CURRENT_IFACE (${driver}, ${mode})"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# MONITOR MODE AUTO-ENABLE
# ═══════════════════════════════════════════════════════════════════════════════

# Check if interface is in monitor mode
is_monitor_mode() {
    local iface="${1:-$_CURRENT_IFACE}"
    [[ -z "$iface" ]] && return 1
    iw dev "$iface" info 2>/dev/null | grep -q "type monitor"
}

# Auto-enable monitor mode
# Sets: _MONITOR_IFACE
auto_monitor() {
    # Already have monitor?
    if [[ -n "$_MONITOR_IFACE" ]] && is_monitor_mode "$_MONITOR_IFACE"; then
        return 0
    fi

    # Need an interface first
    auto_interface || return 1

    # Already in monitor?
    if is_monitor_mode "$_CURRENT_IFACE"; then
        _MONITOR_IFACE="$_CURRENT_IFACE"
        _auto_ok "Interface already in monitor mode: $_MONITOR_IFACE"
        return 0
    fi

    _auto_log "Enabling monitor mode on $_CURRENT_IFACE..."

    # Kill interfering processes
    airmon-ng check kill &>/dev/null

    # Enable monitor mode
    if ! airmon-ng start "$_CURRENT_IFACE" &>/dev/null; then
        # Try alternative method
        ip link set "$_CURRENT_IFACE" down 2>/dev/null
        iw dev "$_CURRENT_IFACE" set type monitor 2>/dev/null
        ip link set "$_CURRENT_IFACE" up 2>/dev/null
    fi

    sleep 1

    # Find the monitor interface
    _MONITOR_IFACE=$(ls /sys/class/net/ 2>/dev/null | grep -E "${_CURRENT_IFACE}mon|mon[0-9]" | head -1)
    [[ -z "$_MONITOR_IFACE" ]] && _MONITOR_IFACE="$_CURRENT_IFACE"

    if is_monitor_mode "$_MONITOR_IFACE"; then
        _auto_ok "Monitor mode enabled: $_MONITOR_IFACE"
        return 0
    else
        _auto_fail "Failed to enable monitor mode"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# TARGET AUTO-DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

# Score a network for attack priority
# Higher score = better target
score_target() {
    local bssid="$1"
    local channel="$2"
    local essid="$3"
    local enc="$4"
    local power="$5"
    local score=0

    # Power-based score (stronger = easier)
    if [[ "$power" =~ ^-?[0-9]+$ ]]; then
        # Convert dBm to positive score (closer to 0 = stronger = better)
        local abs_power=${power#-}
        if [[ $abs_power -lt 50 ]]; then
            ((score += 50))
        elif [[ $abs_power -lt 70 ]]; then
            ((score += 30))
        elif [[ $abs_power -lt 85 ]]; then
            ((score += 10))
        fi
    fi

    # Encryption-based score
    case "$enc" in
        *OPN*|*OPEN*) ((score += 100)) ;;  # Open = easiest
        *WEP*) ((score += 80)) ;;           # WEP = very easy
        *WPA*WPA2*) ((score += 20)) ;;      # Mixed mode
        *WPA2*) ((score += 15)) ;;
        *WPA3*) ((score += 5)) ;;           # Hardest
        *WPA*) ((score += 25)) ;;
    esac

    # Has clients = can capture handshake
    local clients=0
    for client in "${SCAN_CLIENTS[@]:-}"; do
        [[ "$client" == *"$bssid"* ]] && ((clients++))
    done
    ((score += clients * 10))

    # Non-hidden ESSID preferred
    [[ "$essid" != "<hidden>" && -n "$essid" ]] && ((score += 10))

    echo "$score"
}

# Auto-select best target from scan results
# Args: $1 = selection mode (best/wps/open/clients)
# Sets: TARGET_BSSID, TARGET_CHANNEL, TARGET_ESSID, TARGET_ENC
auto_select_target() {
    local mode="${1:-best}"

    if [[ ${#SCAN_RESULTS[@]} -eq 0 ]]; then
        return 1
    fi

    local best_score=-1
    local best_idx=-1
    local idx=0

    for entry in "${SCAN_RESULTS[@]}"; do
        local bssid channel essid enc power
        IFS='|' read -r bssid channel essid enc power <<< "$entry"

        local score

        case "$mode" in
            wps)
                # Prefer WPS-enabled (check SCAN_WPS)
                for wps in "${SCAN_WPS[@]:-}"; do
                    if [[ "$wps" == "$bssid|"* ]]; then
                        local locked
                        locked=$(echo "$wps" | cut -d'|' -f4)
                        [[ "$locked" != "Yes" ]] && ((score += 100))
                    fi
                done
                ;;
            open)
                # Only consider open networks
                [[ "$enc" != *"OPN"* && "$enc" != *"OPEN"* ]] && { ((idx++)); continue; }
                score=100
                ;;
            clients)
                # Only consider networks with clients
                local clients=0
                for client in "${SCAN_CLIENTS[@]:-}"; do
                    [[ "$client" == *"$bssid"* ]] && ((clients++))
                done
                [[ $clients -eq 0 ]] && { ((idx++)); continue; }
                score=$((clients * 50))
                ;;
            *)
                score=$(score_target "$bssid" "$channel" "$essid" "$enc" "$power")
                ;;
        esac

        if [[ $score -gt $best_score ]]; then
            best_score=$score
            best_idx=$idx
        fi

        ((idx++))
    done

    if [[ $best_idx -ge 0 ]]; then
        local entry="${SCAN_RESULTS[$best_idx]}"
        IFS='|' read -r TARGET_BSSID TARGET_CHANNEL TARGET_ESSID TARGET_ENC _ <<< "$entry"
        return 0
    fi

    return 1
}

# Full auto-target: scan if needed, then select best
# Args: $1 = interface, $2 = mode (best/wps/open/clients), $3 = scan_duration
auto_target() {
    local iface="${1:-$_MONITOR_IFACE}"
    local mode="${2:-best}"
    local duration="${3:-15}"

    [[ -z "$iface" ]] && { _auto_fail "No interface for scanning"; return 1; }

    # Already have a valid target?
    if has_target 2>/dev/null; then
        _auto_ok "Using existing target: $(get_target_string 2>/dev/null)"
        return 0
    fi

    # Need to scan
    if [[ ${#SCAN_RESULTS[@]} -eq 0 ]]; then
        _auto_log "Scanning for networks (${duration}s)..."

        if [[ "$mode" == "wps" ]]; then
            scan_wps "$iface" "$duration" 2>/dev/null
        else
            scan_networks "$iface" "$duration" 2>/dev/null
        fi
    fi

    if [[ ${#SCAN_RESULTS[@]} -eq 0 && ${#SCAN_WPS[@]} -eq 0 ]]; then
        _auto_fail "No networks found"
        return 1
    fi

    # Auto-select best target
    _auto_log "Selecting best target (mode: $mode)..."

    if auto_select_target "$mode"; then
        _auto_ok "Target: ${TARGET_ESSID:-$TARGET_BSSID} (CH:$TARGET_CHANNEL)"
        return 0
    else
        _auto_fail "No suitable target found"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLIENT AUTO-DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

# Auto-select client for target
# Sets: TARGET_CLIENT
auto_client() {
    [[ -z "$TARGET_BSSID" ]] && { _auto_fail "No target selected"; return 1; }

    # Find clients for this BSSID
    local -a target_clients=()
    local -a client_powers=()

    for client in "${SCAN_CLIENTS[@]:-}"; do
        if [[ "$client" == *"$TARGET_BSSID"* ]]; then
            local mac power
            IFS='|' read -r mac _ power <<< "$client"
            target_clients+=("$mac")
            client_powers+=("$power")
        fi
    done

    if [[ ${#target_clients[@]} -eq 0 ]]; then
        _auto_warn "No clients detected - using broadcast"
        TARGET_CLIENT=""
        return 0
    fi

    # Select strongest client
    local best_idx=0
    local best_power=-100

    for i in "${!client_powers[@]}"; do
        local p="${client_powers[$i]}"
        [[ "$p" =~ ^-?[0-9]+$ ]] && [[ $p -gt $best_power ]] && {
            best_power=$p
            best_idx=$i
        }
    done

    TARGET_CLIENT="${target_clients[$best_idx]}"
    _auto_ok "Selected client: $TARGET_CLIENT (${best_power}dBm)"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# NETWORK INFO AUTO-DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

# Auto-detect local network info
# Sets: _LOCAL_IP, _GATEWAY_IP, _SUBNET, _DEFAULT_IFACE
auto_network() {
    # Get default interface
    _DEFAULT_IFACE=$(ip route 2>/dev/null | awk '/default/{print $5; exit}')

    if [[ -z "$_DEFAULT_IFACE" ]]; then
        # Fallback: first interface with IP
        _DEFAULT_IFACE=$(ip -4 addr 2>/dev/null | awk '/inet.*scope global/{gsub(/.*\s/, ""); print; exit}')
    fi

    [[ -z "$_DEFAULT_IFACE" ]] && { _auto_fail "No network interface found"; return 1; }

    # Get local IP
    _LOCAL_IP=$(ip -4 addr show "$_DEFAULT_IFACE" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -1)

    # Get subnet in CIDR
    _SUBNET=$(ip -4 addr show "$_DEFAULT_IFACE" 2>/dev/null | awk '/inet /{print $2}' | head -1)

    # Get gateway
    _GATEWAY_IP=$(ip route 2>/dev/null | awk '/default.*'"$_DEFAULT_IFACE"'/{print $3; exit}')
    [[ -z "$_GATEWAY_IP" ]] && _GATEWAY_IP=$(ip route 2>/dev/null | awk '/default/{print $3; exit}')

    if [[ -n "$_LOCAL_IP" ]]; then
        _auto_ok "Network: $_LOCAL_IP via $_GATEWAY_IP ($_DEFAULT_IFACE)"
        return 0
    else
        _auto_fail "Could not detect network info"
        return 1
    fi
}

# Get local IP (with caching)
get_local_ip() {
    [[ -z "$_LOCAL_IP" ]] && auto_network >/dev/null 2>&1
    echo "$_LOCAL_IP"
}

# Get gateway IP (with caching)
get_gateway_ip() {
    [[ -z "$_GATEWAY_IP" ]] && auto_network >/dev/null 2>&1
    echo "$_GATEWAY_IP"
}

# Get subnet (with caching)
get_subnet() {
    [[ -z "$_SUBNET" ]] && auto_network >/dev/null 2>&1
    echo "$_SUBNET"
}

# Get default interface
get_default_interface() {
    [[ -z "$_DEFAULT_IFACE" ]] && auto_network >/dev/null 2>&1
    echo "$_DEFAULT_IFACE"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ONE-SHOT PREPARATION
# ═══════════════════════════════════════════════════════════════════════════════

# Prepare everything needed for an attack type
# Args: $1 = attack type (wireless/wps/scan/network)
# Returns 0 if ready, 1 if failed
auto_prepare() {
    local attack_type="${1:-wireless}"

    case "$attack_type" in
        wireless|wpa|handshake|pmkid)
            auto_interface || return 1
            auto_monitor || return 1
            auto_target "$_MONITOR_IFACE" "clients" || return 1
            ;;
        wps|pixie)
            auto_interface || return 1
            auto_monitor || return 1
            auto_target "$_MONITOR_IFACE" "wps" || return 1
            ;;
        deauth|dos)
            auto_interface || return 1
            auto_monitor || return 1
            auto_target "$_MONITOR_IFACE" "best" || return 1
            auto_client
            ;;
        scan|recon)
            auto_interface || return 1
            auto_monitor
            ;;
        network|nmap|exploit)
            auto_network || return 1
            ;;
        full)
            auto_interface
            auto_monitor
            auto_network
            ;;
        *)
            # Unknown type - try network detection at minimum
            auto_network
            ;;
    esac

    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export -f get_wireless_interfaces get_monitor_capable_interfaces get_interface_info score_interface
export -f auto_interface auto_monitor is_monitor_mode
export -f score_target auto_select_target auto_target
export -f auto_client
export -f auto_network get_local_ip get_gateway_ip get_subnet get_default_interface
export -f auto_prepare
