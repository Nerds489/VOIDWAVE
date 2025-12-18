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
# Scanning Menu: port scanning, service detection, OS fingerprinting
# ═══════════════════════════════════════════════════════════════════════════════

[[ -n "${_VOIDWAVE_SCAN_MENU_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_SCAN_MENU_LOADED=1

show_scan_menu() {
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] && return 1

    while true; do
        clear_screen 2>/dev/null || clear
        show_banner "${VERSION:-}"

        echo -e "    ${C_BOLD:-}Scanning${C_RESET:-}"
        echo ""
        echo "    1) Quick Scan (Top 100 ports)"
        echo "    2) Full Port Scan (1-65535)"
        echo "    3) Service Version Detection"
        echo "    4) OS Detection"
        echo "    5) Vulnerability Scan"
        echo "    6) Stealth Scan"
        echo "    7) UDP Scan"
        echo "    8) Custom Scan"
        echo "    0) Back"
        echo ""

        local choice
        read -rp "    Select [0-8]: " choice

        case "$choice" in
            1) _scan_quick ;;
            2) _scan_full ;;
            3) _scan_version ;;
            4) _scan_os ;;
            5) _scan_vuln ;;
            6) _scan_stealth ;;
            7) _scan_udp ;;
            8) _scan_custom ;;
            0) return 0 ;;
            *) echo -e "    ${C_RED:-}Invalid option${C_RESET:-}"; sleep 1 ;;
        esac
    done
}

_get_scan_target() {
    local target

    # Use memory system if available
    if type -t get_resource_with_memory &>/dev/null; then
        target=$(get_resource_with_memory "network" "Select scan target (IP/CIDR/hostname)" "_scan_local_networks" "validate_target")
        [[ -z "$target" ]] && return 1
    else
        # Fallback to simple prompt
        read -rp "    Target (IP/CIDR/hostname): " target
        [[ -z "$target" ]] && return 1
    fi

    # Basic validation
    if type -t validate_target &>/dev/null; then
        validate_target "$target" || return 1
    fi

    # Warn on public IPs
    if [[ "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        if ! [[ "$target" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.) ]]; then
            echo -e "    ${C_YELLOW:-}Warning: Public IP detected${C_RESET:-}"
            confirm "Continue with public target?" || return 1
        fi
    fi

    # Save to memory for future use
    if type -t memory_add &>/dev/null; then
        memory_add "network" "$target"
    fi

    echo "$target"
}

_run_nmap() {
    local opts="$1" target="$2" desc="$3"

    if ! command -v nmap &>/dev/null; then
        echo -e "    ${C_RED:-}nmap not found${C_RESET:-}"
        return 1
    fi

    local outdir="${VOIDWAVE_OUTPUT_DIR:-$HOME/.voidwave/output}"
    local outfile="$outdir/scan_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$outdir"

    echo ""
    echo -e "    ${C_CYAN:-}$desc${C_RESET:-}"
    echo -e "    ${C_GRAY:-}nmap $opts $target${C_RESET:-}"
    echo ""

    if [[ $EUID -ne 0 ]] && [[ "$opts" =~ -s[STUA] || "$opts" =~ -O ]]; then
        echo -e "    ${C_YELLOW:-}Some options require root${C_RESET:-}"
    fi

    # shellcheck disable=SC2086
    nmap $opts -oA "$outfile" "$target" 2>&1 | sed 's/^/    /'

    echo ""
    echo -e "    ${C_GREEN:-}Results: ${outfile}.*${C_RESET:-}"
    wait_for_keypress
}

_scan_quick() {
    echo ""
    local target
    target=$(_get_scan_target) || { wait_for_keypress; return; }
    _run_nmap "-T4 -F" "$target" "Quick Scan (Top 100 ports)"
}

_scan_full() {
    echo ""
    local target
    target=$(_get_scan_target) || { wait_for_keypress; return; }

    echo -e "    ${C_YELLOW:-}Full port scan may take 10-30 minutes${C_RESET:-}"
    confirm "Continue?" || return

    _run_nmap "-T3 -p-" "$target" "Full Port Scan (1-65535)"
}

_scan_version() {
    echo ""
    local target
    target=$(_get_scan_target) || { wait_for_keypress; return; }
    _run_nmap "-sV -T4" "$target" "Service Version Detection"
}

_scan_os() {
    echo ""

    if [[ $EUID -ne 0 ]]; then
        echo -e "    ${C_RED:-}OS detection requires root${C_RESET:-}"
        wait_for_keypress
        return
    fi

    local target
    target=$(_get_scan_target) || { wait_for_keypress; return; }
    _run_nmap "-O -T4" "$target" "OS Detection"
}

_scan_vuln() {
    echo ""
    local target
    target=$(_get_scan_target) || { wait_for_keypress; return; }

    echo -e "    ${C_YELLOW:-}Vulnerability scan uses NSE scripts${C_RESET:-}"
    confirm "Continue?" || return

    _run_nmap "-sV --script=vuln -T4" "$target" "Vulnerability Scan"
}

_scan_stealth() {
    echo ""

    if [[ $EUID -ne 0 ]]; then
        echo -e "    ${C_RED:-}Stealth scan requires root${C_RESET:-}"
        wait_for_keypress
        return
    fi

    local target
    target=$(_get_scan_target) || { wait_for_keypress; return; }
    _run_nmap "-sS -T2 -f --data-length 24" "$target" "Stealth Scan"
}

_scan_udp() {
    echo ""

    if [[ $EUID -ne 0 ]]; then
        echo -e "    ${C_RED:-}UDP scan requires root${C_RESET:-}"
        wait_for_keypress
        return
    fi

    local target
    target=$(_get_scan_target) || { wait_for_keypress; return; }

    echo -e "    ${C_YELLOW:-}UDP scans are slow${C_RESET:-}"
    confirm "Continue?" || return

    _run_nmap "-sU --top-ports 100 -T4" "$target" "UDP Scan (Top 100)"
}

_scan_custom() {
    echo ""
    local target
    target=$(_get_scan_target) || { wait_for_keypress; return; }

    local ports timing scripts

    read -rp "    Ports (e.g., 22,80,443 or 1-1000) [1-1000]: " ports
    ports="${ports:-1-1000}"

    echo ""
    echo "    Timing: 1=Paranoid 2=Sneaky 3=Normal 4=Aggressive 5=Insane"
    read -rp "    Select [1-5] [3]: " timing
    timing="${timing:-3}"

    echo ""
    read -rp "    NSE scripts (comma-sep or blank): " scripts

    local opts="-p$ports -T$timing"
    [[ -n "$scripts" ]] && opts="$opts --script=$scripts"

    _run_nmap "$opts" "$target" "Custom Scan"
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export -f show_scan_menu
export -f _get_scan_target _run_nmap
export -f _scan_quick _scan_full _scan_version _scan_os
export -f _scan_vuln _scan_stealth _scan_udp _scan_custom
