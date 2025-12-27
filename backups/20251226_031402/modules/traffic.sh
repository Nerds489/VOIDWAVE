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
# Traffic module: packet capture, analysis, MITM tools
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_TRAFFIC_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_TRAFFIC_LOADED=1

# Source library files
source "${BASH_SOURCE%/*}/../lib/core.sh"
source "${BASH_SOURCE%/*}/../lib/ui.sh"
source "${BASH_SOURCE%/*}/../lib/utils.sh"
source "${BASH_SOURCE%/*}/../lib/detection.sh"

#═══════════════════════════════════════════════════════════════════════════════
# TCPDUMP FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run tcpdump packet capture
# Args: $1 = interface (optional)
run_tcpdump() {
    check_tool "tcpdump" || return 1

    local iface="$1"

    # Get interface if not provided
    if [[ -z "$iface" ]]; then
        iface=$(get_default_interface)
        if [[ -z "$iface" ]]; then
            get_target_input "Interface: " iface
        else
            echo -e "    ${C_SHADOW}Using interface: $iface${C_RESET}"
        fi
    fi

    if ! check_interface "$iface"; then
        log_error "Interface not found: $iface"
        return 1
    fi

    local outfile="${OUTPUT_DIR:-/tmp}/capture_$(timestamp_filename).pcap"

    operation_header "tcpdump" "$iface"
    local start_ms=$(date +%s)

    log_audit "TRAFFIC_CAPTURE" "tcpdump" "$iface"
    log_info "Starting tcpdump on $iface (Ctrl+C to stop)"
    echo -e "    ${C_SHADOW}Output: $outfile${C_RESET}"
    echo ""

    log_command_preview "tcpdump -i ${iface} -w ${outfile}"
    tcpdump -i "$iface" -w "$outfile"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Capture saved: $outfile"
    operation_summary "success" "tcpdump" "Duration: $duration"
}

# Run tcpdump with filter
# Args: $1 = interface, $2 = filter expression
run_tcpdump_filter() {
    check_tool "tcpdump" || return 1

    local iface="$1"
    local filter="$2"

    # Get interface if not provided
    if [[ -z "$iface" ]]; then
        iface=$(get_default_interface)
        get_target_input "Interface [$iface]: " iface_input
        iface="${iface_input:-$iface}"
    fi

    if ! check_interface "$iface"; then
        log_error "Interface not found: $iface"
        return 1
    fi

    # Get filter if not provided
    if [[ -z "$filter" ]]; then
        echo -e "\n    ${C_CYAN}Common filters:${C_RESET}"
        echo -e "    ${C_SHADOW}port 80           - HTTP traffic${C_RESET}"
        echo -e "    ${C_SHADOW}port 443          - HTTPS traffic${C_RESET}"
        echo -e "    ${C_SHADOW}host 192.168.1.1  - Traffic to/from host${C_RESET}"
        echo -e "    ${C_SHADOW}tcp               - TCP only${C_RESET}"
        echo -e "    ${C_SHADOW}udp               - UDP only${C_RESET}"
        echo -e "    ${C_SHADOW}icmp              - ICMP only${C_RESET}"
        echo ""
        get_target_input "Filter expression: " filter
    fi

    local outfile="${OUTPUT_DIR:-/tmp}/capture_filtered_$(timestamp_filename).pcap"

    operation_header "tcpdump (filtered)" "$iface"
    local start_ms=$(date +%s)

    log_audit "TRAFFIC_CAPTURE" "tcpdump_filter" "$iface ($filter)"
    log_info "Starting tcpdump on $iface with filter: $filter"
    echo -e "    ${C_SHADOW}Output: $outfile${C_RESET}"
    echo ""

    log_command_preview "tcpdump -i ${iface} -w ${outfile} ${filter}"
    tcpdump -i "$iface" -w "$outfile" $filter

    local duration=$(elapsed_time "$start_ms")
    log_loot "Capture saved: $outfile"
    operation_summary "success" "tcpdump" "Duration: $duration"
}

# Run tcpdump with verbose output (live view)
# Args: $1 = interface (optional)
run_tcpdump_live() {
    check_tool "tcpdump" || return 1

    local iface="$1"

    # Get interface if not provided
    if [[ -z "$iface" ]]; then
        iface=$(get_default_interface)
        get_target_input "Interface [$iface]: " iface_input
        iface="${iface_input:-$iface}"
    fi

    if ! check_interface "$iface"; then
        log_error "Interface not found: $iface"
        return 1
    fi

    operation_header "tcpdump (live)" "$iface"
    local start_ms=$(date +%s)

    log_audit "TRAFFIC_CAPTURE" "tcpdump_live" "$iface"
    log_info "Live capture on $iface (Ctrl+C to stop)"
    echo ""

    log_command_preview "tcpdump -i ${iface} -n -v"
    tcpdump -i "$iface" -n -v

    local duration=$(elapsed_time "$start_ms")
    operation_summary "success" "tcpdump live" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# WIRESHARK/TSHARK FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Launch Wireshark GUI
# Args: $1 = interface (optional)
run_wireshark() {
    check_tool "wireshark" || return 1

    local iface="$1"

    # Get interface if not provided
    if [[ -z "$iface" ]]; then
        iface=$(get_default_interface)
        get_target_input "Interface [$iface]: " iface_input
        iface="${iface_input:-$iface}"
    fi

    if ! check_interface "$iface"; then
        log_error "Interface not found: $iface"
        return 1
    fi

    operation_header "Wireshark" "$iface"
    local start_ms=$(date +%s)

    log_audit "TRAFFIC_CAPTURE" "wireshark" "$iface"
    log_info "Launching Wireshark on $iface"

    log_command_preview "wireshark -i ${iface} -k"
    wireshark -i "$iface" -k &

    operation_summary "success" "Wireshark" "Launched in background"
}

# Open capture file in Wireshark
# Args: $1 = capture file
run_wireshark_file() {
    check_tool "wireshark" || return 1

    local capfile="$1"

    if [[ -z "$capfile" ]]; then
        get_target_input "Capture file (.pcap/.pcapng): " capfile
    fi

    if [[ ! -f "$capfile" ]]; then
        log_error "File not found: $capfile"
        return 1
    fi

    operation_header "Wireshark" "$capfile"

    log_audit "TRAFFIC_ANALYSIS" "wireshark" "$capfile"
    log_info "Opening $capfile in Wireshark"

    log_command_preview "wireshark ${capfile}"
    wireshark "$capfile" &

    operation_summary "success" "Wireshark" "Opened file in background"
}

# Run tshark CLI capture
# Args: $1 = interface (optional)
run_tshark() {
    check_tool "tshark" || return 1

    local iface="$1"

    # Get interface if not provided
    if [[ -z "$iface" ]]; then
        iface=$(get_default_interface)
        get_target_input "Interface [$iface]: " iface_input
        iface="${iface_input:-$iface}"
    fi

    if ! check_interface "$iface"; then
        log_error "Interface not found: $iface"
        return 1
    fi

    local outfile="${OUTPUT_DIR:-/tmp}/tshark_$(timestamp_filename).pcapng"

    operation_header "tshark" "$iface"
    local start_ms=$(date +%s)

    log_audit "TRAFFIC_CAPTURE" "tshark" "$iface"
    log_info "Starting tshark on $iface (Ctrl+C to stop)"
    echo -e "    ${C_SHADOW}Output: $outfile${C_RESET}"
    echo ""

    log_command_preview "tshark -i ${iface} -w ${outfile}"
    tshark -i "$iface" -w "$outfile"

    local duration=$(elapsed_time "$start_ms")
    log_loot "Capture saved: $outfile"
    operation_summary "success" "tshark" "Duration: $duration"
}

# Run tshark with display filter
# Args: $1 = interface, $2 = display filter
run_tshark_filter() {
    check_tool "tshark" || return 1

    local iface="$1"
    local filter="$2"

    # Get interface if not provided
    if [[ -z "$iface" ]]; then
        iface=$(get_default_interface)
        get_target_input "Interface [$iface]: " iface_input
        iface="${iface_input:-$iface}"
    fi

    if ! check_interface "$iface"; then
        log_error "Interface not found: $iface"
        return 1
    fi

    # Get filter if not provided
    if [[ -z "$filter" ]]; then
        echo -e "\n    ${C_CYAN}Common display filters:${C_RESET}"
        echo -e "    ${C_SHADOW}http                   - HTTP traffic${C_RESET}"
        echo -e "    ${C_SHADOW}tcp.port == 443        - HTTPS traffic${C_RESET}"
        echo -e "    ${C_SHADOW}ip.addr == 192.168.1.1 - Traffic to/from host${C_RESET}"
        echo -e "    ${C_SHADOW}dns                    - DNS queries${C_RESET}"
        echo -e "    ${C_SHADOW}tcp.flags.syn == 1     - TCP SYN packets${C_RESET}"
        echo ""
        get_target_input "Display filter: " filter
    fi

    operation_header "tshark (filtered)" "$iface"
    local start_ms=$(date +%s)

    log_audit "TRAFFIC_CAPTURE" "tshark_filter" "$iface ($filter)"
    log_info "tshark on $iface with filter: $filter"
    echo ""

    log_command_preview "tshark -i ${iface} -Y \"${filter}\""
    tshark -i "$iface" -Y "$filter"

    local duration=$(elapsed_time "$start_ms")
    operation_summary "success" "tshark" "Duration: $duration"
}

# Analyze capture file with tshark
# Args: $1 = capture file
run_tshark_analyze() {
    check_tool "tshark" || return 1

    local capfile="$1"

    if [[ -z "$capfile" ]]; then
        get_target_input "Capture file (.pcap/.pcapng): " capfile
    fi

    if [[ ! -f "$capfile" ]]; then
        log_error "File not found: $capfile"
        return 1
    fi

    operation_header "tshark Analysis" "$capfile"
    local start_ms=$(date +%s)

    log_audit "TRAFFIC_ANALYSIS" "tshark" "$capfile"

    echo -e "\n    ${C_CYAN}=== Protocol Hierarchy ===${C_RESET}"
    log_command_preview "tshark -r ${capfile} -q -z io,phs"
    tshark -r "$capfile" -q -z io,phs

    echo -e "\n    ${C_CYAN}=== Conversations ===${C_RESET}"
    log_command_preview "tshark -r ${capfile} -q -z conv,ip"
    tshark -r "$capfile" -q -z conv,ip

    echo -e "\n    ${C_CYAN}=== Endpoints ===${C_RESET}"
    log_command_preview "tshark -r ${capfile} -q -z endpoints,ip"
    tshark -r "$capfile" -q -z endpoints,ip

    local duration=$(elapsed_time "$start_ms")
    operation_summary "success" "tshark Analysis" "Duration: $duration"
}

# Extract HTTP objects from capture
# Args: $1 = capture file
run_tshark_extract_http() {
    check_tool "tshark" || return 1

    local capfile="$1"

    if [[ -z "$capfile" ]]; then
        get_target_input "Capture file (.pcap/.pcapng): " capfile
    fi

    if [[ ! -f "$capfile" ]]; then
        log_error "File not found: $capfile"
        return 1
    fi

    local outdir="${LOOT_DIR:-/tmp}/http_objects_$(timestamp_filename)"
    mkdir -p "$outdir"

    operation_header "HTTP Object Export" "$capfile"
    local start_ms=$(date +%s)

    log_audit "TRAFFIC_ANALYSIS" "tshark_http" "$capfile"
    log_info "Extracting HTTP objects to $outdir"

    log_command_preview "tshark -r ${capfile} --export-objects http,${outdir}"
    tshark -r "$capfile" --export-objects "http,$outdir"

    local count=$(ls -1 "$outdir" 2>/dev/null | wc -l)
    local duration=$(elapsed_time "$start_ms")
    log_loot "Extracted $count files to: $outdir"
    operation_summary "success" "HTTP Extract" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# ETTERCAP FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run ettercap for MITM attacks
# Args: $1 = interface (optional)
run_ettercap() {
    check_tool "ettercap" || return 1

    local iface="$1"

    # Get interface if not provided
    if [[ -z "$iface" ]]; then
        iface=$(get_default_interface)
        get_target_input "Interface [$iface]: " iface_input
        iface="${iface_input:-$iface}"
    fi

    if ! check_interface "$iface"; then
        log_error "Interface not found: $iface"
        return 1
    fi

    echo -e "\n    ${C_CYAN}Ettercap modes:${C_RESET}"
    echo -e "    ${C_GHOST}[1]${C_RESET} Text mode (unified sniffing)"
    echo -e "    ${C_GHOST}[2]${C_RESET} GUI mode"
    echo -e "    ${C_GHOST}[3]${C_RESET} ARP poisoning"
    echo ""

    local choice
    get_target_input "Choice [1-3]: " choice

    operation_header "Ettercap" "$iface"
    local start_ms=$(date +%s)

    log_audit "TRAFFIC_MITM" "ettercap" "$iface"

    case "$choice" in
        1)
            log_info "Starting ettercap in unified sniffing mode"
            log_command_preview "ettercap -T -i ${iface}"
            ettercap -T -i "$iface"
            ;;
        2)
            log_info "Launching ettercap GUI"
            log_command_preview "ettercap -G -i ${iface}"
            ettercap -G -i "$iface" &
            ;;
        3)
            local target1 target2
            get_target_input "Target 1 (IP or //): " target1
            get_target_input "Target 2 (IP or //): " target2
            log_info "Starting ARP poisoning attack"
            log_command_preview "ettercap -T -i ${iface} -M arp:remote /${target1}// /${target2}//"
            ettercap -T -i "$iface" -M arp:remote "/${target1}//" "/${target2}//"
            ;;
        *)
            log_error "Invalid choice"
            return 1
            ;;
    esac

    local duration=$(elapsed_time "$start_ms")
    operation_summary "success" "Ettercap" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# BETTERCAP FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run bettercap for advanced MITM
# Args: $1 = interface (optional)
run_bettercap_traffic() {
    check_tool "bettercap" || return 1

    local iface="$1"

    # Get interface if not provided
    if [[ -z "$iface" ]]; then
        iface=$(get_default_interface)
        get_target_input "Interface [$iface]: " iface_input
        iface="${iface_input:-$iface}"
    fi

    if ! check_interface "$iface"; then
        log_error "Interface not found: $iface"
        return 1
    fi

    echo -e "\n    ${C_CYAN}Bettercap modes:${C_RESET}"
    echo -e "    ${C_GHOST}[1]${C_RESET} Interactive console"
    echo -e "    ${C_GHOST}[2]${C_RESET} Web UI"
    echo -e "    ${C_GHOST}[3]${C_RESET} Run caplet"
    echo ""

    local choice
    get_target_input "Choice [1-3]: " choice

    operation_header "Bettercap" "$iface"
    local start_ms=$(date +%s)

    log_audit "TRAFFIC_MITM" "bettercap" "$iface"

    case "$choice" in
        1)
            log_info "Starting bettercap interactive console"
            log_command_preview "bettercap -iface ${iface}"
            bettercap -iface "$iface"
            ;;
        2)
            local webport
            get_target_input "Web UI port [8080]: " webport
            webport="${webport:-8080}"
            log_info "Starting bettercap Web UI on port $webport"
            log_command_preview "bettercap -iface ${iface} -eval \"set http.server.port ${webport}; http.server on\""
            echo -e "    ${C_SHADOW}Access: http://localhost:${webport}${C_RESET}"
            bettercap -iface "$iface" -eval "set http.server.port $webport; http.server on"
            ;;
        3)
            local caplet
            get_target_input "Caplet file/name: " caplet
            log_info "Running bettercap caplet: $caplet"
            log_command_preview "bettercap -iface ${iface} -caplet ${caplet}"
            bettercap -iface "$iface" -caplet "$caplet"
            ;;
        *)
            log_error "Invalid choice"
            return 1
            ;;
    esac

    local duration=$(elapsed_time "$start_ms")
    operation_summary "success" "Bettercap" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# ARPSPOOF FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run arpspoof for ARP spoofing
# Args: $1 = interface, $2 = target, $3 = gateway
run_arpspoof() {
    check_tool "arpspoof" || return 1

    local iface="$1"
    local target="$2"
    local gateway="$3"

    # Get interface if not provided
    if [[ -z "$iface" ]]; then
        iface=$(get_default_interface)
        get_target_input "Interface [$iface]: " iface_input
        iface="${iface_input:-$iface}"
    fi

    if ! check_interface "$iface"; then
        log_error "Interface not found: $iface"
        return 1
    fi

    if [[ -z "$target" ]]; then
        get_target_input "Target IP: " target
    fi

    if [[ -z "$gateway" ]]; then
        get_target_input "Gateway IP: " gateway
    fi

    operation_header "ARP Spoof" "$target <-> $gateway"
    local start_ms=$(date +%s)

    log_audit "TRAFFIC_MITM" "arpspoof" "$target <-> $gateway"
    log_warning "Enabling IP forwarding..."
    echo 1 > /proc/sys/net/ipv4/ip_forward

    log_info "Starting ARP spoof (Ctrl+C to stop)"
    echo -e "    ${C_SHADOW}Spoofing $target <-> $gateway on $iface${C_RESET}"
    echo ""

    # Run in background and capture PID
    log_command_preview "arpspoof -i ${iface} -t ${target} ${gateway}"
    arpspoof -i "$iface" -t "$target" "$gateway" &
    local pid1=$!

    log_command_preview "arpspoof -i ${iface} -t ${gateway} ${target}"
    arpspoof -i "$iface" -t "$gateway" "$target" &
    local pid2=$!

    # Wait for interrupt
    trap "kill $pid1 $pid2 2>/dev/null; echo 0 > /proc/sys/net/ipv4/ip_forward" INT
    wait

    local duration=$(elapsed_time "$start_ms")
    log_warning "Disabling IP forwarding..."
    echo 0 > /proc/sys/net/ipv4/ip_forward
    operation_summary "success" "ARP Spoof" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# RESPONDER FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run Responder for LLMNR/NBT-NS poisoning
# Args: $1 = interface (optional)
run_responder() {
    check_tool "responder" || return 1

    local iface="$1"

    # Get interface if not provided
    if [[ -z "$iface" ]]; then
        iface=$(get_default_interface)
        get_target_input "Interface [$iface]: " iface_input
        iface="${iface_input:-$iface}"
    fi

    if ! check_interface "$iface"; then
        log_error "Interface not found: $iface"
        return 1
    fi

    echo -e "\n    ${C_CYAN}Responder options:${C_RESET}"
    echo -e "    ${C_GHOST}[1]${C_RESET} Default (all protocols)"
    echo -e "    ${C_GHOST}[2]${C_RESET} Analyze mode (passive)"
    echo -e "    ${C_GHOST}[3]${C_RESET} WPAD attack"
    echo ""

    local choice
    get_target_input "Choice [1-3]: " choice

    operation_header "Responder" "$iface"
    local start_ms=$(date +%s)

    log_audit "TRAFFIC_MITM" "responder" "$iface"

    case "$choice" in
        1)
            log_info "Starting Responder with all protocols"
            log_command_preview "responder -I ${iface}"
            responder -I "$iface"
            ;;
        2)
            log_info "Starting Responder in analyze mode"
            log_command_preview "responder -I ${iface} -A"
            responder -I "$iface" -A
            ;;
        3)
            log_info "Starting Responder with WPAD attack"
            log_command_preview "responder -I ${iface} -wFb"
            responder -I "$iface" -wFb
            ;;
        *)
            log_error "Invalid choice"
            return 1
            ;;
    esac

    local duration=$(elapsed_time "$start_ms")
    log_loot "Responder logs: /usr/share/responder/logs/"
    operation_summary "success" "Responder" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# MITMPROXY FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run mitmproxy for HTTP/HTTPS interception
# Args: none
run_mitmproxy() {
    check_tool "mitmproxy" || return 1

    echo -e "\n    ${C_CYAN}mitmproxy modes:${C_RESET}"
    echo -e "    ${C_GHOST}[1]${C_RESET} Interactive console (mitmproxy)"
    echo -e "    ${C_GHOST}[2]${C_RESET} Web interface (mitmweb)"
    echo -e "    ${C_GHOST}[3]${C_RESET} Dump mode (mitmdump)"
    echo ""

    local choice
    get_target_input "Choice [1-3]: " choice

    local port
    get_target_input "Proxy port [8080]: " port
    port="${port:-8080}"

    operation_header "mitmproxy" "port $port"
    local start_ms=$(date +%s)

    log_audit "TRAFFIC_MITM" "mitmproxy" "port $port"

    case "$choice" in
        1)
            log_info "Starting mitmproxy console on port $port"
            log_command_preview "mitmproxy -p ${port}"
            mitmproxy -p "$port"
            ;;
        2)
            log_info "Starting mitmweb on port $port"
            echo -e "    ${C_SHADOW}Web UI: http://localhost:8081${C_RESET}"
            log_command_preview "mitmweb -p ${port}"
            mitmweb -p "$port"
            ;;
        3)
            local outfile="${OUTPUT_DIR:-/tmp}/mitm_$(timestamp_filename).txt"
            log_info "Starting mitmdump on port $port"
            log_command_preview "mitmdump -p ${port} -w ${outfile}"
            mitmdump -p "$port" -w "$outfile"
            log_loot "Dump saved: $outfile"
            ;;
        *)
            log_error "Invalid choice"
            return 1
            ;;
    esac

    local duration=$(elapsed_time "$start_ms")
    operation_summary "success" "mitmproxy" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# PACKET ANALYSIS FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Read and display pcap file summary
# Args: $1 = capture file
analyze_pcap() {
    local capfile="$1"

    if [[ -z "$capfile" ]]; then
        get_target_input "Capture file (.pcap/.pcapng): " capfile
    fi

    if [[ ! -f "$capfile" ]]; then
        log_error "File not found: $capfile"
        return 1
    fi

    operation_header "PCAP Analysis" "$capfile"
    local start_ms=$(date +%s)

    log_audit "TRAFFIC_ANALYSIS" "pcap" "$capfile"

    # Use capinfos if available
    if command -v capinfos &>/dev/null; then
        echo -e "\n    ${C_CYAN}=== File Information ===${C_RESET}"
        log_command_preview "capinfos ${capfile}"
        capinfos "$capfile"
    fi

    # Use tcpdump for basic stats
    if command -v tcpdump &>/dev/null; then
        echo -e "\n    ${C_CYAN}=== First 20 Packets ===${C_RESET}"
        log_command_preview "tcpdump -r ${capfile} -c 20 -n"
        tcpdump -r "$capfile" -c 20 -n
    fi

    # Use tshark for deeper analysis
    if command -v tshark &>/dev/null; then
        echo -e "\n    ${C_CYAN}=== Protocol Statistics ===${C_RESET}"
        log_command_preview "tshark -r ${capfile} -q -z io,phs"
        tshark -r "$capfile" -q -z io,phs
    fi

    local duration=$(elapsed_time "$start_ms")
    operation_summary "success" "PCAP Analysis" "Duration: $duration"
}

# Extract credentials from pcap
# Args: $1 = capture file
extract_credentials() {
    local capfile="$1"

    if [[ -z "$capfile" ]]; then
        get_target_input "Capture file (.pcap/.pcapng): " capfile
    fi

    if [[ ! -f "$capfile" ]]; then
        log_error "File not found: $capfile"
        return 1
    fi

    operation_header "Credential Extraction" "$capfile"
    local start_ms=$(date +%s)

    log_audit "TRAFFIC_ANALYSIS" "cred_extract" "$capfile"

    local outfile="${LOOT_DIR:-/tmp}/creds_$(timestamp_filename).txt"

    echo -e "\n    ${C_CYAN}Searching for credentials...${C_RESET}\n" | tee "$outfile"

    # HTTP Basic Auth
    echo -e "    ${C_SHADOW}=== HTTP Basic Auth ===${C_RESET}" | tee -a "$outfile"
    if command -v tshark &>/dev/null; then
        tshark -r "$capfile" -Y "http.authorization" -T fields -e http.authorization 2>/dev/null | tee -a "$outfile"
    fi

    # HTTP POST data (login forms)
    echo -e "\n    ${C_SHADOW}=== HTTP POST Data ===${C_RESET}" | tee -a "$outfile"
    if command -v tshark &>/dev/null; then
        tshark -r "$capfile" -Y "http.request.method == POST" -T fields -e http.file_data 2>/dev/null | tee -a "$outfile"
    fi

    # FTP credentials
    echo -e "\n    ${C_SHADOW}=== FTP Credentials ===${C_RESET}" | tee -a "$outfile"
    if command -v tshark &>/dev/null; then
        tshark -r "$capfile" -Y "ftp.request.command == USER || ftp.request.command == PASS" -T fields -e ftp.request.command -e ftp.request.arg 2>/dev/null | tee -a "$outfile"
    fi

    # SMTP credentials
    echo -e "\n    ${C_SHADOW}=== SMTP Auth ===${C_RESET}" | tee -a "$outfile"
    if command -v tshark &>/dev/null; then
        tshark -r "$capfile" -Y "smtp.auth.username || smtp.auth.password" -T fields -e smtp.auth.username -e smtp.auth.password 2>/dev/null | tee -a "$outfile"
    fi

    local duration=$(elapsed_time "$start_ms")
    log_loot "Results saved: $outfile"
    operation_summary "success" "Credential Extract" "Duration: $duration"
}

#═══════════════════════════════════════════════════════════════════════════════
# TRAFFIC MENU
#═══════════════════════════════════════════════════════════════════════════════

# Main traffic menu
traffic_menu() {
    while true; do
        clear
        echo -e "\n"
        echo -e "    ${C_SKULL}╭──────────────────────────────────────────────────────────────────╮${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}                    ${C_FIRE}📊 TRAFFIC ANALYSIS${C_RESET}                        ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}╰──────────────────────────────────────────────────────────────────╯${C_RESET}"
        echo ""
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_CYAN}PACKET CAPTURE${C_RESET}                                                ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[1]${C_RESET} tcpdump                  ${C_SHADOW}CLI packet capture${C_RESET}              ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[2]${C_RESET} tcpdump (filtered)       ${C_SHADOW}Capture with BPF filter${C_RESET}         ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[3]${C_RESET} tcpdump (live)           ${C_SHADOW}Live verbose output${C_RESET}             ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[4]${C_RESET} Wireshark                ${C_SHADOW}GUI packet analyzer${C_RESET}             ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[5]${C_RESET} tshark                   ${C_SHADOW}CLI packet analyzer${C_RESET}             ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[6]${C_RESET} tshark (filtered)        ${C_SHADOW}Display filter capture${C_RESET}          ${C_SKULL}│${C_RESET}"
        echo ""
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_CYAN}ANALYSIS${C_RESET}                                                      ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[7]${C_RESET} Analyze PCAP             ${C_SHADOW}Basic pcap analysis${C_RESET}             ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[8]${C_RESET} tshark Analysis          ${C_SHADOW}Protocol statistics${C_RESET}             ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[9]${C_RESET} Extract HTTP Objects     ${C_SHADOW}Export files from capture${C_RESET}       ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[10]${C_RESET} Extract Credentials     ${C_SHADOW}Find creds in capture${C_RESET}           ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[11]${C_RESET} Open in Wireshark       ${C_SHADOW}View capture file${C_RESET}               ${C_SKULL}│${C_RESET}"
        echo ""
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_CYAN}MITM ATTACKS${C_RESET}                                                  ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[12]${C_RESET} Ettercap                ${C_SHADOW}ARP poisoning/sniffing${C_RESET}          ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[13]${C_RESET} Bettercap               ${C_SHADOW}Advanced MITM framework${C_RESET}         ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[14]${C_RESET} ARP Spoof               ${C_SHADOW}Simple ARP spoofing${C_RESET}             ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[15]${C_RESET} Responder               ${C_SHADOW}LLMNR/NBT-NS poisoning${C_RESET}          ${C_SKULL}│${C_RESET}"
        echo -e "    ${C_SKULL}│${C_RESET}  ${C_GHOST}[16]${C_RESET} mitmproxy               ${C_SHADOW}HTTP/HTTPS interception${C_RESET}         ${C_SKULL}│${C_RESET}"
        echo ""
        echo -e "    ${C_GHOST}[0]${C_RESET} Back"
        echo ""

        local choice
        get_target_input "Select option: " choice

        case "$choice" in
            1) run_tcpdump ;;
            2) run_tcpdump_filter ;;
            3) run_tcpdump_live ;;
            4) run_wireshark ;;
            5) run_tshark ;;
            6) run_tshark_filter ;;
            7) analyze_pcap ;;
            8) run_tshark_analyze ;;
            9) run_tshark_extract_http ;;
            10) extract_credentials ;;
            11) run_wireshark_file ;;
            12) run_ettercap ;;
            13) run_bettercap_traffic ;;
            14) run_arpspoof ;;
            15) run_responder ;;
            16) run_mitmproxy ;;
            0|q|Q|back|exit) return 0 ;;
            *) log_warning "Invalid option" ;;
        esac

        echo ""
        read -rp "    Press Enter to continue..."
    done
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORT FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# tcpdump functions
export -f run_tcpdump run_tcpdump_filter run_tcpdump_live

# Wireshark/tshark functions
export -f run_wireshark run_wireshark_file run_tshark run_tshark_filter
export -f run_tshark_analyze run_tshark_extract_http

# MITM functions
export -f run_ettercap run_bettercap_traffic run_arpspoof run_responder run_mitmproxy

# Analysis functions
export -f analyze_pcap extract_credentials

# Menu
export -f traffic_menu
