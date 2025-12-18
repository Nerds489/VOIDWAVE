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
# Stress module: bandwidth testing, load testing, network impairment
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_STRESS_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_STRESS_LOADED=1

# Source library files
source "${BASH_SOURCE%/*}/../lib/core.sh"
source "${BASH_SOURCE%/*}/../lib/ui.sh"
source "${BASH_SOURCE%/*}/../lib/safety.sh"
source "${BASH_SOURCE%/*}/../lib/detection.sh"
source "${BASH_SOURCE%/*}/../lib/utils.sh"

#═══════════════════════════════════════════════════════════════════════════════
# STRESS PRE-SCAN / VALIDATION
#═══════════════════════════════════════════════════════════════════════════════

# Validate target and get confirmation before stress testing
# Args: $1 = target (IP or hostname)
# Returns: 0 if confirmed, 1 if denied or invalid
stress_prescan() {
    local target="$1"

    # Validate target
    if ! validate_target "$target"; then
        return 1
    fi

    # Ping test to check if host is responding
    log_info "Testing connectivity to $target..."
    if ping -c 3 -W 2 "$target" &>/dev/null; then
        log_success "Host responding to ICMP"
    else
        log_warning "Host not responding to ICMP (may be blocked or offline)"
    fi

    # Legal warning
    echo ""
    echo -e "    ${C_RED}╔════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "    ${C_RED}║${C_RESET}  ${C_YELLOW}⚠  WARNING: STRESS TESTING CAN DISRUPT SERVICES${C_RESET}             ${C_RED}║${C_RESET}"
    echo -e "    ${C_RED}║${C_RESET}                                                                ${C_RED}║${C_RESET}"
    echo -e "    ${C_RED}║${C_RESET}  Only test systems you ${C_GREEN}OWN${C_RESET} or have explicit ${C_GREEN}PERMISSION${C_RESET}      ${C_RED}║${C_RESET}"
    echo -e "    ${C_RED}║${C_RESET}  Unauthorized stress testing is ${C_RED}ILLEGAL${C_RESET} in most places      ${C_RED}║${C_RESET}"
    echo -e "    ${C_RED}╚════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""

    # Require explicit confirmation
    if ! confirm_dangerous "Proceed with stress testing $target?"; then
        log_info "Stress test cancelled by user"
        return 1
    fi

    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# HPING3 STRESS TESTING
#═══════════════════════════════════════════════════════════════════════════════

# Run hping3 packet flood attack
# Args: $1 = target, $2 = port (default: 80), $3 = type (syn/udp/icmp, default: syn)
#       $4 = duration in seconds (default: 30), $5 = rate in pps (default: 1000)
# Returns: 0 on success, 1 on failure
run_hping_attack() {
    local target="$1"
    local port="${2:-80}"
    local attack_type="${3:-syn}"
    local duration="${4:-30}"
    local rate="${5:-1000}"

    # Validate target is provided
    if [[ -z "$target" ]]; then
        log_error "No target specified"
        return 1
    fi

    # Require hping3
    require_tools hping3 || return 1

    # Run prescan (validates target and gets confirmation)
    stress_prescan "$target" || return 1

    # Build hping3 flags based on attack type
    local type_flags=""
    case "${attack_type,,}" in
        syn)
            type_flags="-S -p $port"
            ;;
        udp)
            type_flags="--udp -p $port"
            ;;
        icmp)
            type_flags="--icmp"
            ;;
        *)
            log_error "Unknown attack type: $attack_type (use: syn, udp, icmp)"
            return 1
            ;;
    esac

    # Calculate interval and count
    # interval in microseconds = 1,000,000 / rate
    local interval=$((1000000 / rate))
    local count=$((rate * duration))

    # Build command
    local cmd="hping3 $type_flags -i u${interval} -c $count $target"

    # Log the operation
    log_info "hping3: $target:$port ($attack_type, ${duration}s, ${rate}pps)"

    # Audit logging
    if declare -f log_audit &>/dev/null; then
        log_audit "STRESS" "hping3 $attack_type $target:$port"
    fi

    # Dry-run support
    if [[ "${VW_DRY_RUN:-0}" == "1" ]] || [[ "${DRY_RUN:-0}" == "1" ]]; then
        echo -e "    ${C_YELLOW}[DRY-RUN]${C_RESET} sudo $cmd"
        return 0
    fi

    # Execute with sudo
    log_info "Starting stress test (${duration}s)..."
    if run_with_sudo $cmd; then
        log_success "Stress test completed"
        return 0
    else
        log_error "Stress test failed"
        return 1
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# NETWORK EMULATION / IMPAIRMENT
#═══════════════════════════════════════════════════════════════════════════════

# Apply network impairment using tc/netem
# Args: $1 = interface, $2 = impairment type (delay/loss/corrupt, default: delay)
#       $3 = value (e.g., 100ms, 10%, default: 100ms), $4 = duration in seconds (default: 60)
# Returns: 0 on success, 1 on failure
run_netem() {
    local iface="$1"
    local impairment="${2:-delay}"
    local value="${3:-100ms}"
    local duration="${4:-60}"

    # Validate interface is provided
    if [[ -z "$iface" ]]; then
        log_error "No interface specified"
        return 1
    fi

    # Require tc
    require_tools tc || return 1

    # Validate interface exists
    if [[ ! -d "/sys/class/net/$iface" ]]; then
        log_error "Interface does not exist: $iface"
        return 1
    fi

    # Validate impairment type
    case "${impairment,,}" in
        delay|loss|corrupt|duplicate|reorder)
            ;;
        *)
            log_error "Unknown impairment type: $impairment (use: delay, loss, corrupt, duplicate, reorder)"
            return 1
            ;;
    esac

    # Require confirmation
    if ! confirm_dangerous "Apply $impairment ($value) to $iface for ${duration}s?"; then
        log_info "Network impairment cancelled by user"
        return 1
    fi

    # Build command
    local cmd="tc qdisc add dev $iface root netem $impairment $value"

    # Audit logging
    if declare -f log_audit &>/dev/null; then
        log_audit "NETEM" "$impairment $value on $iface"
    fi

    # Dry-run support
    if [[ "${VW_DRY_RUN:-0}" == "1" ]] || [[ "${DRY_RUN:-0}" == "1" ]]; then
        echo -e "    ${C_YELLOW}[DRY-RUN]${C_RESET} sudo $cmd"
        echo -e "    ${C_YELLOW}[DRY-RUN]${C_RESET} sleep $duration"
        echo -e "    ${C_YELLOW}[DRY-RUN]${C_RESET} sudo tc qdisc del dev $iface root"
        return 0
    fi

    # Apply impairment
    log_info "Applying $impairment ($value) to $iface..."
    if ! run_with_sudo tc qdisc add dev "$iface" root netem "$impairment" "$value"; then
        log_error "Failed to apply network impairment"
        return 1
    fi

    log_success "Impairment applied"
    log_info "Waiting ${duration}s..."

    # Wait for duration
    sleep "$duration"

    # Cleanup - always attempt to remove impairment
    log_info "Removing impairment..."
    run_with_sudo tc qdisc del dev "$iface" root 2>/dev/null || true

    log_success "Impairment removed"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# CLI USAGE
#═══════════════════════════════════════════════════════════════════════════════

# Show stress module usage
stress_usage() {
    cat << 'EOF'
VOIDWAVE Stress Testing Commands

Usage: voidwave stress <command> [options]

Commands:
  hping <target> [port] [type] [duration] [rate]
      Run hping3 packet flood
      port:     Target port (default: 80)
      type:     syn, udp, or icmp (default: syn)
      duration: Test duration in seconds (default: 30)
      rate:     Packets per second (default: 1000)

  netem <iface> [impairment] [value] [duration]
      Apply network impairment using tc/netem
      impairment: delay, loss, corrupt, duplicate, reorder (default: delay)
      value:      Impairment value e.g., 100ms, 10% (default: 100ms)
      duration:   Duration in seconds (default: 60)

Examples:
  voidwave stress hping 192.168.1.1 80 syn 30 1000
  voidwave stress hping 10.0.0.1 53 udp 10 500
  voidwave stress netem eth0 delay 100ms 30
  voidwave stress netem wlan0 loss 10% 60

WARNING: Stress testing can disrupt services.
         Only test systems you own or have permission to test.
EOF
}

#═══════════════════════════════════════════════════════════════════════════════
# LEGACY MENU (PLACEHOLDER)
#═══════════════════════════════════════════════════════════════════════════════

menu_stress() {
    log_info "Use CLI commands for stress testing:"
    echo ""
    stress_usage
    echo ""
    pause
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORT FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

export -f stress_prescan
export -f run_hping_attack
export -f run_netem
export -f stress_usage
export -f menu_stress
