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
# Wireless Menu: WiFi attacks, monitor mode, handshake capture
# ═══════════════════════════════════════════════════════════════════════════════

[[ -n "${_VOIDWAVE_WIRELESS_MENU_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_WIRELESS_MENU_LOADED=1

declare -g _WIRELESS_IFACE=""
declare -g _WIRELESS_MONITOR_IFACE=""

show_wireless_menu() {
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] && return 1

    # Root check
    if [[ $EUID -ne 0 ]]; then
        echo -e "    ${C_RED:-}Wireless attacks require root${C_RESET:-}"
        echo "    Run: sudo voidwave"
        wait_for_keypress
        return 1
    fi

    # Check for aircrack-ng
    if ! command -v airmon-ng &>/dev/null; then
        echo -e "    ${C_RED:-}aircrack-ng suite not found${C_RESET:-}"
        echo "    Install: apt install aircrack-ng"
        wait_for_keypress
        return 1
    fi

    while true; do
        clear_screen 2>/dev/null || clear
        show_banner "${VERSION:-}"

        echo -e "    ${C_BOLD:-}Wireless Attacks${C_RESET:-}"
        echo ""
        _show_interface_status
        echo ""
        echo "    1) Select Interface"
        echo "    2) Enable Monitor Mode"
        echo "    3) Disable Monitor Mode"
        echo "    4) Scan Networks"
        echo "    5) Capture Handshake"
        echo "    6) Deauthentication Attack"
        echo "    7) WPS Attack"
        echo "    8) Automated Audit (wifite)"
        echo "    0) Back"
        echo ""

        local choice
        echo -en "    ${C_PURPLE:-}▶${C_RESET:-} Select [0-8]: "
        read -r choice
        choice="${choice//[[:space:]]/}"

        case "$choice" in
            1) _wireless_select_interface ;;
            2) _wireless_enable_monitor ;;
            3) _wireless_disable_monitor ;;
            4) _wireless_scan ;;
            5) _wireless_capture ;;
            6) _wireless_deauth ;;
            7) _wireless_wps ;;
            8) _wireless_wifite ;;
            0) return 0 ;;
            "") continue ;;
            *) echo -e "    ${C_RED:-}[!] Invalid option: '$choice'${C_RESET:-}"; sleep 1 ;;
        esac
    done
}

_show_interface_status() {
    echo -e "    ${C_GRAY:-}Interface: ${_WIRELESS_IFACE:-none}${C_RESET:-}"
    if [[ -n "$_WIRELESS_MONITOR_IFACE" ]]; then
        echo -e "    ${C_GREEN:-}Monitor Mode: $_WIRELESS_MONITOR_IFACE${C_RESET:-}"
    else
        echo -e "    ${C_GRAY:-}Monitor Mode: disabled${C_RESET:-}"
    fi
}

_wireless_select_interface() {
    local -a ifaces=()
    while IFS= read -r iface; do
        [[ -n "$iface" ]] && ifaces+=("$iface")
    done < <(iw dev 2>/dev/null | awk '/Interface/{print $2}')

    if [[ ${#ifaces[@]} -eq 0 ]]; then
        echo -e "    ${C_RED:-}No wireless interfaces found${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    # Loop until valid selection
    while true; do
        echo ""
        echo -e "    ${C_CYAN:-}Available interfaces:${C_RESET:-}"
        echo ""
        for i in "${!ifaces[@]}"; do
            local mode
            mode=$(iw dev "${ifaces[$i]}" info 2>/dev/null | awk '/type/{print $2}')
            echo -e "    ${C_CYAN:-}[$((i+1))]${C_RESET:-} ${ifaces[$i]} ${C_SHADOW:-}($mode)${C_RESET:-}"
        done
        echo ""
        echo -e "    ${C_SHADOW:-}[0] Cancel${C_RESET:-}"
        echo ""

        local choice
        echo -en "    Select [1-${#ifaces[@]}]: "
        read -r choice
        choice="${choice//[[:space:]]/}"

        # Handle cancel
        if [[ "$choice" == "0" || "$choice" == "q" ]]; then
            return 0
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#ifaces[@]} )); then
            _WIRELESS_IFACE="${ifaces[$((choice-1))]}"
            echo -e "    ${C_GREEN:-}Selected: $_WIRELESS_IFACE${C_RESET:-}"
            wait_for_keypress
            return 0
        fi

        echo -e "    ${C_RED:-}[!] Invalid selection: '$choice'. Please enter 1-${#ifaces[@]} or 0 to cancel.${C_RESET:-}"
        sleep 1
    done
}

_wireless_enable_monitor() {
    echo ""

    if [[ -z "$_WIRELESS_IFACE" ]]; then
        echo -e "    ${C_RED:-}Select interface first${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    echo -e "    ${C_CYAN:-}Enabling monitor mode on $_WIRELESS_IFACE${C_RESET:-}"
    echo ""

    # Kill interfering processes
    airmon-ng check kill 2>&1 | sed 's/^/    /'

    # Enable monitor mode
    if airmon-ng start "$_WIRELESS_IFACE" 2>&1 | sed 's/^/    /'; then
        # Check for new interface
        local new_iface="${_WIRELESS_IFACE}mon"
        if iw dev "$new_iface" info &>/dev/null; then
            _WIRELESS_MONITOR_IFACE="$new_iface"
        elif iw dev "${_WIRELESS_IFACE}" info 2>/dev/null | grep -q "monitor"; then
            _WIRELESS_MONITOR_IFACE="$_WIRELESS_IFACE"
        fi

        if [[ -n "$_WIRELESS_MONITOR_IFACE" ]]; then
            echo ""
            echo -e "    ${C_GREEN:-}Monitor mode enabled: $_WIRELESS_MONITOR_IFACE${C_RESET:-}"
        fi
    else
        echo -e "    ${C_RED:-}Failed to enable monitor mode${C_RESET:-}"
    fi

    wait_for_keypress
}

_wireless_disable_monitor() {
    echo ""

    if [[ -z "$_WIRELESS_MONITOR_IFACE" ]]; then
        echo -e "    ${C_YELLOW:-}Monitor mode not active${C_RESET:-}"
        wait_for_keypress
        return
    fi

    echo -e "    ${C_CYAN:-}Disabling monitor mode${C_RESET:-}"
    echo ""

    airmon-ng stop "$_WIRELESS_MONITOR_IFACE" 2>&1 | sed 's/^/    /'

    # Restart networking
    systemctl restart NetworkManager &>/dev/null || service network-manager restart &>/dev/null

    _WIRELESS_MONITOR_IFACE=""
    echo ""
    echo -e "    ${C_GREEN:-}Monitor mode disabled${C_RESET:-}"

    wait_for_keypress
}

_wireless_scan() {
    echo ""

    local iface="${_WIRELESS_MONITOR_IFACE:-$_WIRELESS_IFACE}"
    if [[ -z "$iface" ]]; then
        echo -e "    ${C_RED:-}Select interface first${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    echo -e "    ${C_CYAN:-}Scanning networks on $iface${C_RESET:-}"
    echo -e "    ${C_YELLOW:-}Press Ctrl+C to stop${C_RESET:-}"
    echo ""

    local duration
    read -rp "    Duration in seconds [30]: " duration
    duration="${duration:-30}"

    timeout "$duration" airodump-ng "$iface" 2>/dev/null || true

    wait_for_keypress
}

_wireless_capture() {
    echo ""

    if [[ -z "$_WIRELESS_MONITOR_IFACE" ]]; then
        echo -e "    ${C_RED:-}Enable monitor mode first${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    local bssid channel
    read -rp "    Target BSSID (AA:BB:CC:DD:EE:FF): " bssid
    [[ -z "$bssid" ]] && return

    read -rp "    Channel [1-14]: " channel
    [[ -z "$channel" ]] && return

    local outdir="${VOIDWAVE_OUTPUT_DIR:-$HOME/.voidwave/output}/captures"
    local outfile="$outdir/capture_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$outdir"

    echo ""
    echo -e "    ${C_CYAN:-}Capturing on channel $channel${C_RESET:-}"
    echo -e "    ${C_GRAY:-}Target: $bssid${C_RESET:-}"
    echo -e "    ${C_GRAY:-}Output: $outfile${C_RESET:-}"
    echo -e "    ${C_YELLOW:-}Press Ctrl+C when handshake captured${C_RESET:-}"
    echo ""

    airodump-ng -c "$channel" --bssid "$bssid" -w "$outfile" "$_WIRELESS_MONITOR_IFACE" 2>/dev/null || true

    [[ -f "${outfile}-01.cap" ]] && echo -e "    ${C_GREEN:-}Capture saved: ${outfile}-01.cap${C_RESET:-}"

    wait_for_keypress
}

_wireless_deauth() {
    echo ""

    if [[ -z "$_WIRELESS_MONITOR_IFACE" ]]; then
        echo -e "    ${C_RED:-}Enable monitor mode first${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    echo -e "    ${C_YELLOW:-}Warning: Only use on authorized networks${C_RESET:-}"
    echo ""

    confirm "Continue?" || return

    local bssid client count
    read -rp "    Target BSSID: " bssid
    [[ -z "$bssid" ]] && return

    read -rp "    Client MAC (blank for broadcast): " client

    read -rp "    Packet count [10]: " count
    count="${count:-10}"

    echo ""
    echo -e "    ${C_CYAN:-}Sending $count deauth packets${C_RESET:-}"

    if [[ -n "$client" ]]; then
        aireplay-ng -0 "$count" -a "$bssid" -c "$client" "$_WIRELESS_MONITOR_IFACE" 2>&1 | sed 's/^/    /'
    else
        aireplay-ng -0 "$count" -a "$bssid" "$_WIRELESS_MONITOR_IFACE" 2>&1 | sed 's/^/    /'
    fi

    wait_for_keypress
}

_wireless_wps() {
    echo ""

    if [[ -z "$_WIRELESS_MONITOR_IFACE" ]]; then
        echo -e "    ${C_RED:-}Enable monitor mode first${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    if ! command -v reaver &>/dev/null; then
        echo -e "    ${C_RED:-}reaver not found${C_RESET:-}"
        echo "    Install: apt install reaver"
        wait_for_keypress
        return 1
    fi

    local bssid channel
    read -rp "    Target BSSID: " bssid
    [[ -z "$bssid" ]] && return

    read -rp "    Channel: " channel
    [[ -z "$channel" ]] && return

    echo ""
    echo -e "    ${C_CYAN:-}Starting WPS attack${C_RESET:-}"
    echo -e "    ${C_YELLOW:-}This may take hours. Press Ctrl+C to stop${C_RESET:-}"
    echo ""

    reaver -i "$_WIRELESS_MONITOR_IFACE" -b "$bssid" -c "$channel" -vv 2>&1 | sed 's/^/    /' || true

    wait_for_keypress
}

_wireless_wifite() {
    echo ""

    if ! command -v wifite &>/dev/null; then
        echo -e "    ${C_RED:-}wifite not found${C_RESET:-}"
        echo "    Install: apt install wifite"
        wait_for_keypress
        return 1
    fi

    echo -e "    ${C_CYAN:-}Launching wifite${C_RESET:-}"
    echo -e "    ${C_YELLOW:-}wifite will manage its own interface${C_RESET:-}"
    echo ""

    wifite 2>&1 || true

    wait_for_keypress
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export -f show_wireless_menu _show_interface_status
export -f _wireless_select_interface _wireless_enable_monitor _wireless_disable_monitor
export -f _wireless_scan _wireless_capture _wireless_deauth _wireless_wps _wireless_wifite
