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
# Stress Testing Menu: DoS simulation with strong safety controls
# ═══════════════════════════════════════════════════════════════════════════════

[[ -n "${_VOIDWAVE_STRESS_MENU_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_STRESS_MENU_LOADED=1

# Safety limits (hardcoded, non-configurable)
declare -r _STRESS_MAX_DURATION=300
declare -r _STRESS_MAX_CONNECTIONS=10000
declare -r _STRESS_MAX_RATE=100000

# ═══════════════════════════════════════════════════════════════════════════════
# SMART STRESS MENU
# ═══════════════════════════════════════════════════════════════════════════════

show_stress_menu_smart() {
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] && return 1

    # Entry warning every time
    clear_screen 2>/dev/null || clear
    echo ""
    echo -e "    ${C_RED:-}╔══════════════════════════════════════════════════════╗${C_RESET:-}"
    echo -e "    ${C_RED:-}║  STRESS TESTING / DoS SIMULATION                     ║${C_RESET:-}"
    echo -e "    ${C_RED:-}║                                                       ║${C_RESET:-}"
    echo -e "    ${C_RED:-}║  These tools can cause service disruption.           ║${C_RESET:-}"
    echo -e "    ${C_RED:-}║  Only use against systems you OWN or have            ║${C_RESET:-}"
    echo -e "    ${C_RED:-}║  WRITTEN AUTHORIZATION to test.                      ║${C_RESET:-}"
    echo -e "    ${C_RED:-}║                                                       ║${C_RESET:-}"
    echo -e "    ${C_RED:-}║  Unauthorized use is a FEDERAL CRIME.                ║${C_RESET:-}"
    echo -e "    ${C_RED:-}╚══════════════════════════════════════════════════════╝${C_RESET:-}"
    echo ""

    confirm "I understand and have authorization" || return 1

    while true; do
        clear_screen 2>/dev/null || clear
        show_banner "${VERSION:-}"

        echo -e "    ${C_BOLD:-}${C_RED:-}Stress Testing${C_RESET:-}"
        echo ""
        echo "    1) HTTP Flood (slowloris)"
        echo "    2) SYN Flood"
        echo "    3) UDP Flood"
        echo "    4) ICMP Flood"
        echo "    5) Connection Test"
        echo "    6) Bandwidth Test"
        echo ""
        echo "    0) Back"
        echo -e "    ${C_SHADOW:-}?) Help${C_RESET:-}"
        echo ""

        local choice
        echo -en "    ${C_PURPLE:-}▶${C_RESET:-} Select: "
        read -r choice
        choice="${choice//[[:space:]]/}"

        # Handle help
        if type -t handle_help_input &>/dev/null; then
            handle_help_input "$choice" "stress" && continue
        fi

        case "$choice" in
            1)
                if type -t preflight &>/dev/null; then
                    preflight "stress_http" || { wait_for_keypress; continue; }
                fi
                _stress_http
                ;;
            2)
                if type -t preflight &>/dev/null; then
                    preflight "stress_syn" || { wait_for_keypress; continue; }
                fi
                _stress_syn
                ;;
            3)
                if type -t preflight &>/dev/null; then
                    preflight "stress_udp" || { wait_for_keypress; continue; }
                fi
                _stress_udp
                ;;
            4)
                if type -t preflight &>/dev/null; then
                    preflight "stress_icmp" || { wait_for_keypress; continue; }
                fi
                _stress_icmp
                ;;
            5) _stress_conn ;;
            6)
                if type -t preflight &>/dev/null; then
                    preflight "stress_bandwidth" || { wait_for_keypress; continue; }
                fi
                _stress_bandwidth
                ;;
            0) return 0 ;;
            "") continue ;;
            *) echo -e "    ${C_RED:-}[!] Invalid option: '$choice'${C_RESET:-}"; sleep 1 ;;
        esac
    done
}

# Legacy function for backwards compatibility
show_stress_menu() {
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] && return 1

    # Entry warning every time
    clear_screen 2>/dev/null || clear
    echo ""
    echo -e "    ${C_RED:-}╔══════════════════════════════════════════════════════╗${C_RESET:-}"
    echo -e "    ${C_RED:-}║  ⚠️  STRESS TESTING / DoS SIMULATION                  ║${C_RESET:-}"
    echo -e "    ${C_RED:-}║                                                       ║${C_RESET:-}"
    echo -e "    ${C_RED:-}║  These tools can cause service disruption.           ║${C_RESET:-}"
    echo -e "    ${C_RED:-}║  Only use against systems you OWN or have            ║${C_RESET:-}"
    echo -e "    ${C_RED:-}║  WRITTEN AUTHORIZATION to test.                      ║${C_RESET:-}"
    echo -e "    ${C_RED:-}║                                                       ║${C_RESET:-}"
    echo -e "    ${C_RED:-}║  Unauthorized use is a FEDERAL CRIME.                ║${C_RESET:-}"
    echo -e "    ${C_RED:-}╚══════════════════════════════════════════════════════╝${C_RESET:-}"
    echo ""

    confirm "I understand and have authorization" || return 1

    while true; do
        clear_screen 2>/dev/null || clear
        show_banner "${VERSION:-}"

        echo -e "    ${C_BOLD:-}${C_RED:-}Stress Testing${C_RESET:-}"
        echo ""
        echo "    1) HTTP Flood (slowloris)"
        echo "    2) SYN Flood"
        echo "    3) UDP Flood"
        echo "    4) ICMP Flood"
        echo "    5) Connection Test"
        echo "    6) Bandwidth Test"
        echo "    0) Back"
        echo ""

        local choice
        echo -en "    ${C_PURPLE:-}▶${C_RESET:-} Select [0-6]: "
        read -r choice
        choice="${choice//[[:space:]]/}"

        case "$choice" in
            1) _stress_http ;;
            2) _stress_syn ;;
            3) _stress_udp ;;
            4) _stress_icmp ;;
            5) _stress_conn ;;
            6) _stress_bandwidth ;;
            0) return 0 ;;
            "") continue ;;
            *) echo -e "    ${C_RED:-}[!] Invalid option: '$choice'${C_RESET:-}"; sleep 1 ;;
        esac
    done
}

_is_private_ip() {
    local ip="$1"
    [[ "$ip" =~ ^10\. ]] && return 0
    [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[01])\. ]] && return 0
    [[ "$ip" =~ ^192\.168\. ]] && return 0
    [[ "$ip" =~ ^127\. ]] && return 0
    return 1
}

_validate_stress_target() {
    local target="$1"

    # Resolve hostname to IP
    local ip="$target"
    if [[ ! "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        ip=$(dig +short A "$target" 2>/dev/null | head -1)
    fi

    if [[ -z "$ip" ]]; then
        echo -e "    ${C_RED:-}Cannot resolve target${C_RESET:-}"
        return 1
    fi

    # Block public IPs unless unsafe mode
    if ! _is_private_ip "$ip"; then
        if [[ "${VW_UNSAFE_MODE:-0}" != "1" ]]; then
            echo -e "    ${C_RED:-}Public IP stress testing blocked${C_RESET:-}"
            echo -e "    ${C_RED:-}Only private/internal targets allowed${C_RESET:-}"
            return 1
        fi
        echo -e "    ${C_YELLOW:-}Warning: Public IP - unsafe mode active${C_RESET:-}"
    fi

    return 0
}

_stress_http() {
    echo ""

    if [[ $EUID -ne 0 ]]; then
        echo -e "    ${C_RED:-}Stress testing requires root${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    local target connections duration

    read -rp "    Target URL (http://...): " target
    [[ -z "$target" ]] && return

    # Extract host
    local host
    host=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)

    _validate_stress_target "$host" || { wait_for_keypress; return 1; }

    read -rp "    Concurrent connections [500]: " connections
    connections="${connections:-500}"
    [[ $connections -gt $_STRESS_MAX_CONNECTIONS ]] && connections=$_STRESS_MAX_CONNECTIONS

    read -rp "    Duration seconds [60]: " duration
    duration="${duration:-60}"
    [[ $duration -gt $_STRESS_MAX_DURATION ]] && duration=$_STRESS_MAX_DURATION

    confirm "Start HTTP flood against $host?" || return

    echo ""
    echo -e "    ${C_CYAN:-}HTTP Flood: $host${C_RESET:-}"
    echo -e "    ${C_GRAY:-}Connections: $connections, Duration: ${duration}s${C_RESET:-}"
    echo -e "    ${C_YELLOW:-}Press Ctrl+C to stop${C_RESET:-}"
    echo ""

    # Use hping3 or slowloris if available
    if command -v slowloris &>/dev/null; then
        timeout "$duration" slowloris "$host" -s "$connections" 2>&1 | sed 's/^/    /' || true
    elif command -v hping3 &>/dev/null; then
        local port=80
        [[ "$target" =~ ^https ]] && port=443
        timeout "$duration" hping3 -S --flood -p "$port" "$host" 2>&1 | sed 's/^/    /' || true
    else
        # Fallback: parallel curl
        echo -e "    ${C_YELLOW:-}Using curl fallback (limited)${C_RESET:-}"
        local end=$((SECONDS + duration))
        while [[ $SECONDS -lt $end ]]; do
            for ((i=0; i<10; i++)); do
                curl -s -o /dev/null "$target" &
            done
            wait
        done
    fi

    echo ""
    echo -e "    ${C_GREEN:-}Test complete${C_RESET:-}"

    wait_for_keypress
}

_stress_syn() {
    echo ""

    if [[ $EUID -ne 0 ]]; then
        echo -e "    ${C_RED:-}SYN flood requires root${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    if ! command -v hping3 &>/dev/null; then
        echo -e "    ${C_RED:-}hping3 not found${C_RESET:-}"
        echo "    Install: apt install hping3"
        wait_for_keypress
        return 1
    fi

    local target port rate duration

    read -rp "    Target IP: " target
    [[ -z "$target" ]] && return

    _validate_stress_target "$target" || { wait_for_keypress; return 1; }

    read -rp "    Port [80]: " port
    port="${port:-80}"

    read -rp "    Duration seconds [30]: " duration
    duration="${duration:-30}"
    [[ $duration -gt $_STRESS_MAX_DURATION ]] && duration=$_STRESS_MAX_DURATION

    confirm "Start SYN flood against $target:$port?" || return

    echo ""
    echo -e "    ${C_CYAN:-}SYN Flood: $target:$port${C_RESET:-}"
    echo -e "    ${C_YELLOW:-}Press Ctrl+C to stop${C_RESET:-}"
    echo ""

    timeout "$duration" hping3 -S --flood -p "$port" "$target" 2>&1 | sed 's/^/    /' || true

    echo ""
    echo -e "    ${C_GREEN:-}Test complete${C_RESET:-}"

    wait_for_keypress
}

_stress_udp() {
    echo ""

    if [[ $EUID -ne 0 ]]; then
        echo -e "    ${C_RED:-}UDP flood requires root${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    if ! command -v hping3 &>/dev/null; then
        echo -e "    ${C_RED:-}hping3 not found${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    local target port duration

    read -rp "    Target IP: " target
    [[ -z "$target" ]] && return

    _validate_stress_target "$target" || { wait_for_keypress; return 1; }

    read -rp "    Port [53]: " port
    port="${port:-53}"

    read -rp "    Duration seconds [30]: " duration
    duration="${duration:-30}"
    [[ $duration -gt $_STRESS_MAX_DURATION ]] && duration=$_STRESS_MAX_DURATION

    confirm "Start UDP flood against $target:$port?" || return

    echo ""
    echo -e "    ${C_CYAN:-}UDP Flood: $target:$port${C_RESET:-}"
    echo ""

    timeout "$duration" hping3 --udp --flood -p "$port" "$target" 2>&1 | sed 's/^/    /' || true

    echo ""
    echo -e "    ${C_GREEN:-}Test complete${C_RESET:-}"

    wait_for_keypress
}

_stress_icmp() {
    echo ""

    if [[ $EUID -ne 0 ]]; then
        echo -e "    ${C_RED:-}ICMP flood requires root${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    local target duration

    read -rp "    Target IP: " target
    [[ -z "$target" ]] && return

    _validate_stress_target "$target" || { wait_for_keypress; return 1; }

    read -rp "    Duration seconds [30]: " duration
    duration="${duration:-30}"
    [[ $duration -gt $_STRESS_MAX_DURATION ]] && duration=$_STRESS_MAX_DURATION

    confirm "Start ICMP flood against $target?" || return

    echo ""
    echo -e "    ${C_CYAN:-}ICMP Flood: $target${C_RESET:-}"
    echo ""

    if command -v hping3 &>/dev/null; then
        timeout "$duration" hping3 --icmp --flood "$target" 2>&1 | sed 's/^/    /' || true
    else
        timeout "$duration" ping -f "$target" 2>&1 | sed 's/^/    /' || true
    fi

    echo ""
    echo -e "    ${C_GREEN:-}Test complete${C_RESET:-}"

    wait_for_keypress
}

_stress_conn() {
    echo ""

    local target port connections

    read -rp "    Target IP: " target
    [[ -z "$target" ]] && return

    _validate_stress_target "$target" || { wait_for_keypress; return 1; }

    read -rp "    Port [80]: " port
    port="${port:-80}"

    read -rp "    Connections to test [100]: " connections
    connections="${connections:-100}"
    [[ $connections -gt 1000 ]] && connections=1000

    echo ""
    echo -e "    ${C_CYAN:-}Connection Test: $target:$port${C_RESET:-}"
    echo ""

    local success=0 fail=0

    for ((i=1; i<=connections; i++)); do
        if timeout 2 bash -c "echo >/dev/tcp/$target/$port" 2>/dev/null; then
            ((success++)) || true
        else
            ((fail++)) || true
        fi

        if ((i % 10 == 0)); then
            printf "\r    Progress: %d/%d (Success: %d, Fail: %d)" "$i" "$connections" "$success" "$fail"
        fi
    done

    echo ""
    echo ""
    echo -e "    ${C_GREEN:-}Success: $success${C_RESET:-}"
    echo -e "    ${C_RED:-}Failed: $fail${C_RESET:-}"

    wait_for_keypress
}

_stress_bandwidth() {
    echo ""

    if ! command -v iperf3 &>/dev/null; then
        echo -e "    ${C_RED:-}iperf3 not found${C_RESET:-}"
        echo "    Install: apt install iperf3"
        wait_for_keypress
        return 1
    fi

    local target duration

    read -rp "    Target (iperf3 server IP): " target
    [[ -z "$target" ]] && return

    _validate_stress_target "$target" || { wait_for_keypress; return 1; }

    read -rp "    Duration seconds [10]: " duration
    duration="${duration:-10}"
    [[ $duration -gt 60 ]] && duration=60

    echo ""
    echo -e "    ${C_CYAN:-}Bandwidth Test: $target${C_RESET:-}"
    echo ""

    iperf3 -c "$target" -t "$duration" 2>&1 | sed 's/^/    /' || true

    wait_for_keypress
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export -f show_stress_menu show_stress_menu_smart _is_private_ip _validate_stress_target
export -f _stress_http _stress_syn _stress_udp _stress_icmp
export -f _stress_conn _stress_bandwidth
