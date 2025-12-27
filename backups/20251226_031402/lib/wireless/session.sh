#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# Wireless Session: extends core session system with wireless-specific state
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_WIRELESS_SESSION_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_WIRELESS_SESSION_LOADED=1

# Source core session if not loaded
if ! declare -F session_start &>/dev/null; then
    source "${BASH_SOURCE%/*}/../sessions.sh"
fi

#═══════════════════════════════════════════════════════════════════════════════
# WIRELESS SESSION STATE
#═══════════════════════════════════════════════════════════════════════════════

# Current wireless attack state
declare -gA WIRELESS_STATE=(
    [interface]=""
    [monitor_interface]=""
    [original_mac]=""
    [current_mac]=""
    [target_bssid]=""
    [target_essid]=""
    [target_channel]=""
    [target_encryption]=""
    [attack_type]=""
    [attack_status]=""
    [attack_progress]="0"
    [attack_total]="0"
    [handshake_captured]="false"
    [pmkid_captured]="false"
    [wps_pin]=""
    [cracked_password]=""
)

# Attack history for current session
declare -ga WIRELESS_ATTACK_HISTORY=()

#═══════════════════════════════════════════════════════════════════════════════
# SESSION LIFECYCLE
#═══════════════════════════════════════════════════════════════════════════════

# Start a new wireless session
# Returns: session ID
wireless_session_start() {
    local name="${1:-wireless}"

    # Start core session
    local session_id
    session_id=$(session_start "$name")

    # Initialize wireless state
    WIRELESS_STATE=(
        [interface]=""
        [monitor_interface]=""
        [original_mac]=""
        [current_mac]=""
        [target_bssid]=""
        [target_essid]=""
        [target_channel]=""
        [target_encryption]=""
        [attack_type]=""
        [attack_status]="initialized"
        [attack_progress]="0"
        [attack_total]="0"
        [handshake_captured]="false"
        [pmkid_captured]="false"
        [wps_pin]=""
        [cracked_password]=""
    )

    WIRELESS_ATTACK_HISTORY=()

    # Save initial wireless state
    wireless_session_save

    log_debug "Wireless session started: $session_id"
    echo "$session_id"
}

# Save wireless session state
wireless_session_save() {
    # Save to core session
    for key in "${!WIRELESS_STATE[@]}"; do
        session_set "wireless.$key" "${WIRELESS_STATE[$key]}"
    done

    # Save attack history
    local history_str
    history_str=$(printf '%s|' "${WIRELESS_ATTACK_HISTORY[@]}")
    session_set "wireless.attack_history" "$history_str"
}

# Load wireless session state
wireless_session_load() {
    # Load from core session
    for key in "${!WIRELESS_STATE[@]}"; do
        local value
        value=$(session_get "wireless.$key")
        [[ -n "$value" ]] && WIRELESS_STATE[$key]="$value"
    done

    # Load attack history
    local history_str
    history_str=$(session_get "wireless.attack_history")
    if [[ -n "$history_str" ]]; then
        IFS='|' read -ra WIRELESS_ATTACK_HISTORY <<< "$history_str"
    fi
}

# Resume wireless session
# Args: $1 = session ID
wireless_session_resume() {
    local session_id="$1"

    if ! session_resume "$session_id"; then
        return 1
    fi

    # Load wireless state
    wireless_session_load

    log_info "Wireless session resumed"
    log_info "  Interface: ${WIRELESS_STATE[interface]:-none}"
    log_info "  Target: ${WIRELESS_STATE[target_essid]:-none} (${WIRELESS_STATE[target_bssid]:-none})"
    log_info "  Attack: ${WIRELESS_STATE[attack_type]:-none} - ${WIRELESS_STATE[attack_status]:-unknown}"

    return 0
}

# End wireless session
wireless_session_end() {
    wireless_session_save
    session_end

    # Clear state
    WIRELESS_STATE=()
    WIRELESS_ATTACK_HISTORY=()

    log_debug "Wireless session ended"
}

#═══════════════════════════════════════════════════════════════════════════════
# STATE MANAGEMENT
#═══════════════════════════════════════════════════════════════════════════════

# Set wireless state value
# Args: $1 = key, $2 = value
wireless_state_set() {
    local key="$1"
    local value="$2"

    WIRELESS_STATE[$key]="$value"
    session_set "wireless.$key" "$value"
}

# Get wireless state value
# Args: $1 = key
# Returns: value
wireless_state_get() {
    local key="$1"
    echo "${WIRELESS_STATE[$key]:-}"
}

# Set current interface
# Args: $1 = interface name
wireless_session_set_interface() {
    local iface="$1"
    wireless_state_set "interface" "$iface"
}

# Set monitor interface
# Args: $1 = monitor interface name
wireless_session_set_monitor() {
    local iface="$1"
    wireless_state_set "monitor_interface" "$iface"
}

# Set current target
# Args: $1 = bssid, $2 = essid, $3 = channel, $4 = encryption (optional)
wireless_session_set_target() {
    local bssid="$1"
    local essid="$2"
    local channel="$3"
    local encryption="${4:-WPA2}"

    wireless_state_set "target_bssid" "$bssid"
    wireless_state_set "target_essid" "$essid"
    wireless_state_set "target_channel" "$channel"
    wireless_state_set "target_encryption" "$encryption"

    log_info "Target set: $essid ($bssid) on channel $channel"
}

# Clear current target
wireless_session_clear_target() {
    wireless_state_set "target_bssid" ""
    wireless_state_set "target_essid" ""
    wireless_state_set "target_channel" ""
    wireless_state_set "target_encryption" ""
}

#═══════════════════════════════════════════════════════════════════════════════
# ATTACK TRACKING
#═══════════════════════════════════════════════════════════════════════════════

# Start tracking an attack
# Args: $1 = attack type, $2 = total steps (optional)
wireless_attack_start() {
    local attack_type="$1"
    local total="${2:-0}"

    wireless_state_set "attack_type" "$attack_type"
    wireless_state_set "attack_status" "running"
    wireless_state_set "attack_progress" "0"
    wireless_state_set "attack_total" "$total"

    # Add to history
    WIRELESS_ATTACK_HISTORY+=("$(date -Iseconds):$attack_type:started")
    wireless_session_save

    log_audit "WIRELESS_ATTACK" "$attack_type" "started"
}

# Update attack progress
# Args: $1 = current progress, $2 = status message (optional)
wireless_attack_progress() {
    local progress="$1"
    local status_msg="${2:-}"

    wireless_state_set "attack_progress" "$progress"

    if [[ -n "$status_msg" ]]; then
        wireless_state_set "attack_status" "$status_msg"
    fi

    wireless_session_save
}

# Mark attack as successful
# Args: $1 = result message (optional)
wireless_attack_success() {
    local result="${1:-success}"
    local attack_type="${WIRELESS_STATE[attack_type]}"

    wireless_state_set "attack_status" "success"

    WIRELESS_ATTACK_HISTORY+=("$(date -Iseconds):$attack_type:success:$result")
    wireless_session_save

    log_success "Attack completed: $attack_type - $result"
    log_audit "WIRELESS_ATTACK" "$attack_type" "success:$result"
}

# Mark attack as failed
# Args: $1 = reason
wireless_attack_fail() {
    local reason="${1:-unknown}"
    local attack_type="${WIRELESS_STATE[attack_type]}"

    wireless_state_set "attack_status" "failed"

    WIRELESS_ATTACK_HISTORY+=("$(date -Iseconds):$attack_type:failed:$reason")
    wireless_session_save

    log_error "Attack failed: $attack_type - $reason"
    log_audit "WIRELESS_ATTACK" "$attack_type" "failed:$reason"
}

# Mark handshake as captured
wireless_attack_handshake_captured() {
    wireless_state_set "handshake_captured" "true"
    WIRELESS_ATTACK_HISTORY+=("$(date -Iseconds):handshake:captured")
    wireless_session_save
    log_success "Handshake captured!"
}

# Mark PMKID as captured
wireless_attack_pmkid_captured() {
    wireless_state_set "pmkid_captured" "true"
    WIRELESS_ATTACK_HISTORY+=("$(date -Iseconds):pmkid:captured")
    wireless_session_save
    log_success "PMKID captured!"
}

# Save WPS PIN
wireless_attack_wps_pin_found() {
    local pin="$1"
    wireless_state_set "wps_pin" "$pin"
    WIRELESS_ATTACK_HISTORY+=("$(date -Iseconds):wps:pin_found:$pin")
    wireless_session_save
    log_success "WPS PIN found: $pin"
}

# Save cracked password
wireless_attack_password_cracked() {
    local password="$1"
    wireless_state_set "cracked_password" "$password"
    WIRELESS_ATTACK_HISTORY+=("$(date -Iseconds):crack:success")
    wireless_session_save
    log_success "Password cracked!"
}

#═══════════════════════════════════════════════════════════════════════════════
# SESSION INFO
#═══════════════════════════════════════════════════════════════════════════════

# Show wireless session status
wireless_session_status() {
    echo ""
    echo -e "    ${C_CYAN}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "    ${C_CYAN}║${C_RESET}                   ${C_BOLD}WIRELESS SESSION STATUS${C_RESET}                         ${C_CYAN}║${C_RESET}"
    echo -e "    ${C_CYAN}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""

    # Session info
    printf "    ${C_GHOST}%-18s${C_RESET} %s\n" "Session ID:" "${SESSION_ID:-none}"

    # Interface info
    echo ""
    echo -e "    ${C_SHADOW}──── Interface ────${C_RESET}"
    printf "    ${C_GHOST}%-18s${C_RESET} %s\n" "Interface:" "${WIRELESS_STATE[interface]:-none}"
    printf "    ${C_GHOST}%-18s${C_RESET} %s\n" "Monitor:" "${WIRELESS_STATE[monitor_interface]:-none}"

    if [[ -n "${WIRELESS_STATE[original_mac]}" ]]; then
        printf "    ${C_GHOST}%-18s${C_RESET} %s\n" "Original MAC:" "${WIRELESS_STATE[original_mac]}"
        printf "    ${C_GHOST}%-18s${C_RESET} %s\n" "Current MAC:" "${WIRELESS_STATE[current_mac]}"
    fi

    # Target info
    if [[ -n "${WIRELESS_STATE[target_bssid]}" ]]; then
        echo ""
        echo -e "    ${C_SHADOW}──── Target ────${C_RESET}"
        printf "    ${C_GHOST}%-18s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "ESSID:" "${WIRELESS_STATE[target_essid]:-unknown}"
        printf "    ${C_GHOST}%-18s${C_RESET} %s\n" "BSSID:" "${WIRELESS_STATE[target_bssid]}"
        printf "    ${C_GHOST}%-18s${C_RESET} %s\n" "Channel:" "${WIRELESS_STATE[target_channel]:-?}"
        printf "    ${C_GHOST}%-18s${C_RESET} %s\n" "Encryption:" "${WIRELESS_STATE[target_encryption]:-?}"
    fi

    # Attack status
    if [[ -n "${WIRELESS_STATE[attack_type]}" ]]; then
        echo ""
        echo -e "    ${C_SHADOW}──── Attack ────${C_RESET}"
        printf "    ${C_GHOST}%-18s${C_RESET} %s\n" "Type:" "${WIRELESS_STATE[attack_type]}"

        local status_color
        case "${WIRELESS_STATE[attack_status]}" in
            running)   status_color="${C_YELLOW}" ;;
            success)   status_color="${C_GREEN}" ;;
            failed)    status_color="${C_RED}" ;;
            *)         status_color="${C_GRAY}" ;;
        esac
        printf "    ${C_GHOST}%-18s${C_RESET} ${status_color}%s${C_RESET}\n" "Status:" "${WIRELESS_STATE[attack_status]}"

        if [[ "${WIRELESS_STATE[attack_total]}" != "0" ]]; then
            printf "    ${C_GHOST}%-18s${C_RESET} %s/%s\n" "Progress:" \
                "${WIRELESS_STATE[attack_progress]}" "${WIRELESS_STATE[attack_total]}"
        fi
    fi

    # Captures
    echo ""
    echo -e "    ${C_SHADOW}──── Captures ────${C_RESET}"

    local hs_color pk_color
    [[ "${WIRELESS_STATE[handshake_captured]}" == "true" ]] && hs_color="${C_GREEN}" || hs_color="${C_GRAY}"
    [[ "${WIRELESS_STATE[pmkid_captured]}" == "true" ]] && pk_color="${C_GREEN}" || pk_color="${C_GRAY}"

    printf "    ${C_GHOST}%-18s${C_RESET} ${hs_color}%s${C_RESET}\n" "Handshake:" "${WIRELESS_STATE[handshake_captured]}"
    printf "    ${C_GHOST}%-18s${C_RESET} ${pk_color}%s${C_RESET}\n" "PMKID:" "${WIRELESS_STATE[pmkid_captured]}"

    if [[ -n "${WIRELESS_STATE[wps_pin]}" ]]; then
        printf "    ${C_GHOST}%-18s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "WPS PIN:" "${WIRELESS_STATE[wps_pin]}"
    fi

    if [[ -n "${WIRELESS_STATE[cracked_password]}" ]]; then
        printf "    ${C_GHOST}%-18s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "Password:" "${WIRELESS_STATE[cracked_password]}"
    fi

    echo ""
}

# Show attack history
wireless_session_history() {
    echo ""
    echo -e "    ${C_CYAN}Attack History${C_RESET}"
    echo -e "    ${C_SHADOW}$(printf '─%.0s' {1..60})${C_RESET}"

    if [[ ${#WIRELESS_ATTACK_HISTORY[@]} -eq 0 ]]; then
        echo -e "    ${C_SHADOW}No attacks recorded${C_RESET}"
    else
        for entry in "${WIRELESS_ATTACK_HISTORY[@]}"; do
            IFS=':' read -r timestamp attack status extra <<< "$entry"
            local status_color
            case "$status" in
                started)   status_color="${C_CYAN}" ;;
                success|captured|pin_found) status_color="${C_GREEN}" ;;
                failed)    status_color="${C_RED}" ;;
                *)         status_color="${C_GRAY}" ;;
            esac
            printf "    ${C_SHADOW}%s${C_RESET} %-15s ${status_color}%s${C_RESET}" \
                "${timestamp:11:8}" "$attack" "$status"
            [[ -n "$extra" ]] && printf " ${C_SHADOW}%s${C_RESET}" "$extra"
            echo ""
        done
    fi

    echo ""
}

# List resumable wireless sessions
wireless_session_list() {
    echo ""
    echo -e "    ${C_CYAN}Wireless Sessions${C_RESET}"
    echo -e "    ${C_SHADOW}$(printf '─%.0s' {1..70})${C_RESET}"
    echo ""

    local count=0
    for f in "${VOIDWAVE_SESSION_DIR}"/*.session; do
        [[ -f "$f" ]] || continue

        # Check if it's a wireless session
        grep -q "^name=wireless" "$f" 2>/dev/null || continue

        local id status target
        id=$(grep "^id=" "$f" | cut -d= -f2)
        status=$(grep "^status=" "$f" | cut -d= -f2)
        target=$(grep "^wireless.target_essid=" "$f" | cut -d= -f2)

        # Status color
        local status_color
        case "$status" in
            active|resumed) status_color="${C_GREEN}" ;;
            completed)      status_color="${C_CYAN}" ;;
            failed)         status_color="${C_RED}" ;;
            *)              status_color="${C_GRAY}" ;;
        esac

        printf "    ${C_GREEN}%-40s${C_RESET} ${status_color}%-10s${C_RESET} %s\n" \
            "${id:0:40}" "$status" "${target:-no target}"

        ((count++)) || true
    done

    if [[ $count -eq 0 ]]; then
        echo -e "    ${C_SHADOW}No wireless sessions found${C_RESET}"
    else
        echo ""
        echo -e "    ${C_SHADOW}Total: $count session(s)${C_RESET}"
    fi

    echo ""
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
#═══════════════════════════════════════════════════════════════════════════════

export -f wireless_session_start wireless_session_save wireless_session_load
export -f wireless_session_resume wireless_session_end
export -f wireless_state_set wireless_state_get
export -f wireless_session_set_interface wireless_session_set_monitor
export -f wireless_session_set_target wireless_session_clear_target
export -f wireless_attack_start wireless_attack_progress
export -f wireless_attack_success wireless_attack_fail
export -f wireless_attack_handshake_captured wireless_attack_pmkid_captured
export -f wireless_attack_wps_pin_found wireless_attack_password_cracked
export -f wireless_session_status wireless_session_history wireless_session_list
