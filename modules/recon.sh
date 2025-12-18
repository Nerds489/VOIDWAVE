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
# Recon module: port scanning, network discovery, DNS enumeration, SSL analysis
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_RECON_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_RECON_LOADED=1

# Source library files
source "${BASH_SOURCE%/*}/../lib/core.sh"
source "${BASH_SOURCE%/*}/../lib/ui.sh"
source "${BASH_SOURCE%/*}/../lib/safety.sh"
source "${BASH_SOURCE%/*}/../lib/detection.sh"
source "${BASH_SOURCE%/*}/../lib/utils.sh"

#═══════════════════════════════════════════════════════════════════════════════
# MODULE VARIABLES
#═══════════════════════════════════════════════════════════════════════════════

# Current target for recon operations
declare -g RECON_TARGET=""

#═══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Get target from user if not set
_recon_get_target() {
    local prompt="${1:-Enter target (IP/hostname/CIDR)}"

    if [[ -n "$RECON_TARGET" ]]; then
        echo "$RECON_TARGET"
        return 0
    fi

    local target
    target=$(get_target_input "$prompt")

    if [[ -z "$target" ]]; then
        log_error "No target specified"
        return 1
    fi

    # Validate target
    if ! validate_target "$target"; then
        return 1
    fi

    RECON_TARGET="$target"
    echo "$target"
}

# Generate output filename for recon operations
_recon_output_file() {
    local prefix="${1:-scan}"
    local extension="${2:-txt}"
    local target="${RECON_TARGET:-unknown}"

    # Sanitize target for filename
    local safe_target
    safe_target=$(echo "$target" | tr -cd '[:alnum:]._-' | cut -c1-50)

    local filename="${prefix}_${safe_target}_$(timestamp_filename).${extension}"
    echo "${OUTPUT_DIR}/${filename}"
}

#═══════════════════════════════════════════════════════════════════════════════
# NMAP SCANNING FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Quick nmap scan (-T4 -F)
run_nmap_quick() {
    local target="${1:-$RECON_TARGET}"

    # Check tool
    if ! check_tool "nmap"; then
        log_error "nmap is not installed"
        log_info "Install: sudo apt install nmap"
        return 1
    fi

    # Get target if not provided
    if [[ -z "$target" ]]; then
        target=$(_recon_get_target) || return 1
    fi

    # Validate target
    validate_target "$target" || return 1

    local outfile
    outfile=$(_recon_output_file "nmap_quick" "txt")

    operation_header "Quick Port Scan" "$target"
    log_command_preview "nmap -T4 -F -oN \"$outfile\" \"$target\""
    log_info "Scanning common ports..."

    # Run scan
    nmap -T4 -F -oN "$outfile" "$target"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        operation_summary "success" "Quick scan complete" "Output: $outfile"
        log_audit "NMAP_QUICK" "$target" "success"
    else
        operation_summary "failed" "Scan failed with exit code $exit_code"
        log_audit "NMAP_QUICK" "$target" "failed"
    fi

    return $exit_code
}

# Full nmap scan (-sS -sV -sC -A -p-)
run_nmap_full() {
    local target="${1:-$RECON_TARGET}"

    if ! check_tool "nmap"; then
        log_error "nmap is not installed"
        return 1
    fi

    # Full scan requires root
    if ! check_root; then
        log_warning "Full scan requires root for SYN scan"
        return 1
    fi

    if [[ -z "$target" ]]; then
        target=$(_recon_get_target) || return 1
    fi

    validate_target "$target" || return 1

    local outfile
    outfile=$(_recon_output_file "nmap_full" "txt")

    operation_header "Full Port Scan" "$target"
    log_command_preview "nmap -sS -sV -sC -A -p- -oN \"$outfile\" \"$target\""
    log_info "Scanning all 65535 ports with service detection..."
    log_warning "This may take a long time"

    nmap -sS -sV -sC -A -p- -oN "$outfile" "$target"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        operation_summary "success" "Full scan complete" "Output: $outfile"
        log_audit "NMAP_FULL" "$target" "success"
    else
        operation_summary "failed" "Scan failed"
        log_audit "NMAP_FULL" "$target" "failed"
    fi

    return $exit_code
}

# Stealth nmap scan (-sS -T2 -f)
run_nmap_stealth() {
    local target="${1:-$RECON_TARGET}"

    if ! check_tool "nmap"; then
        log_error "nmap is not installed"
        return 1
    fi

    if ! check_root; then
        log_warning "Stealth scan requires root"
        return 1
    fi

    if [[ -z "$target" ]]; then
        target=$(_recon_get_target) || return 1
    fi

    validate_target "$target" || return 1

    local outfile
    outfile=$(_recon_output_file "nmap_stealth" "txt")

    operation_header "Stealth Port Scan" "$target"
    log_command_preview "nmap -sS -T2 -f --data-length 24 -oN \"$outfile\" \"$target\""
    log_info "Scanning with fragmentation and slow timing..."

    nmap -sS -T2 -f --data-length 24 -oN "$outfile" "$target"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        operation_summary "success" "Stealth scan complete" "Output: $outfile"
        log_audit "NMAP_STEALTH" "$target" "success"
    else
        operation_summary "failed" "Scan failed"
        log_audit "NMAP_STEALTH" "$target" "failed"
    fi

    return $exit_code
}

# UDP nmap scan (-sU --top-ports 100)
run_nmap_udp() {
    local target="${1:-$RECON_TARGET}"

    if ! check_tool "nmap"; then
        log_error "nmap is not installed"
        return 1
    fi

    if ! check_root; then
        log_warning "UDP scan requires root"
        return 1
    fi

    if [[ -z "$target" ]]; then
        target=$(_recon_get_target) || return 1
    fi

    validate_target "$target" || return 1

    local outfile
    outfile=$(_recon_output_file "nmap_udp" "txt")

    operation_header "UDP Port Scan" "$target"
    log_command_preview "nmap -sU --top-ports 100 -oN \"$outfile\" \"$target\""
    log_info "Scanning top 100 UDP ports..."

    nmap -sU --top-ports 100 -oN "$outfile" "$target"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        operation_summary "success" "UDP scan complete" "Output: $outfile"
        log_audit "NMAP_UDP" "$target" "success"
    else
        operation_summary "failed" "Scan failed"
        log_audit "NMAP_UDP" "$target" "failed"
    fi

    return $exit_code
}

# Vulnerability nmap scan (--script vuln)
run_nmap_vuln() {
    local target="${1:-$RECON_TARGET}"

    if ! check_tool "nmap"; then
        log_error "nmap is not installed"
        return 1
    fi

    if [[ -z "$target" ]]; then
        target=$(_recon_get_target) || return 1
    fi

    validate_target "$target" || return 1

    local outfile
    outfile=$(_recon_output_file "nmap_vuln" "txt")

    operation_header "Vulnerability Scan" "$target"
    log_command_preview "nmap --script vuln -oN \"$outfile\" \"$target\""
    log_info "Running vulnerability scripts..."

    nmap --script vuln -oN "$outfile" "$target"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        operation_summary "success" "Vulnerability scan complete" "Output: $outfile"
        log_audit "NMAP_VULN" "$target" "success"
    else
        operation_summary "failed" "Scan failed"
        log_audit "NMAP_VULN" "$target" "failed"
    fi

    return $exit_code
}

# Service detection nmap scan (-sV)
run_nmap_service() {
    local target="${1:-$RECON_TARGET}"

    if ! check_tool "nmap"; then
        log_error "nmap is not installed"
        return 1
    fi

    if [[ -z "$target" ]]; then
        target=$(_recon_get_target) || return 1
    fi

    validate_target "$target" || return 1

    local outfile
    outfile=$(_recon_output_file "nmap_services" "txt")

    operation_header "Service Detection" "$target"
    log_command_preview "nmap -sV --version-intensity 5 -oN \"$outfile\" \"$target\""
    log_info "Detecting service versions..."

    nmap -sV --version-intensity 5 -oN "$outfile" "$target"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        operation_summary "success" "Service detection complete" "Output: $outfile"
        log_audit "NMAP_SERVICE" "$target" "success"
    else
        operation_summary "failed" "Scan failed"
        log_audit "NMAP_SERVICE" "$target" "failed"
    fi

    return $exit_code
}

#═══════════════════════════════════════════════════════════════════════════════
# ALTERNATIVE SCANNERS
#═══════════════════════════════════════════════════════════════════════════════

# Masscan - high-speed port scanner
run_masscan() {
    local target="${1:-$RECON_TARGET}"
    local rate="${2:-10000}"

    if ! check_tool "masscan"; then
        log_error "masscan is not installed"
        log_info "Install: sudo apt install masscan"
        return 1
    fi

    if ! check_root; then
        log_warning "masscan requires root"
        return 1
    fi

    if [[ -z "$target" ]]; then
        target=$(_recon_get_target) || return 1
    fi

    validate_target "$target" || return 1

    # Get rate if interactive
    if [[ -z "$2" ]]; then
        rate=$(get_input "Scan rate (packets/sec)" "10000")
    fi

    local outfile
    outfile=$(_recon_output_file "masscan" "txt")

    operation_header "Masscan" "$target"
    log_command_preview "masscan -p1-65535 --rate=$rate -oL \"$outfile\" \"$target\""
    log_info "Scanning all ports at rate $rate..."

    masscan -p1-65535 --rate="$rate" -oL "$outfile" "$target"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        operation_summary "success" "Masscan complete" "Output: $outfile"
        log_audit "MASSCAN" "$target" "success"
    else
        operation_summary "failed" "Scan failed"
        log_audit "MASSCAN" "$target" "failed"
    fi

    return $exit_code
}

# Rustscan - fast port scanner with nmap integration
run_rustscan() {
    local target="${1:-$RECON_TARGET}"

    if ! check_tool "rustscan"; then
        log_error "rustscan is not installed"
        log_info "Install from: https://github.com/RustScan/RustScan"
        return 1
    fi

    if [[ -z "$target" ]]; then
        target=$(_recon_get_target) || return 1
    fi

    validate_target "$target" || return 1

    local outfile
    outfile=$(_recon_output_file "rustscan" "txt")

    operation_header "Rustscan" "$target"
    log_command_preview "rustscan -a \"$target\" --ulimit 5000 -- -sV -oN \"$outfile\""
    log_info "Fast scanning with rustscan..."

    rustscan -a "$target" --ulimit 5000 -- -sV -oN "$outfile"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        operation_summary "success" "Rustscan complete" "Output: $outfile"
        log_audit "RUSTSCAN" "$target" "success"
    else
        operation_summary "failed" "Scan failed"
        log_audit "RUSTSCAN" "$target" "failed"
    fi

    return $exit_code
}

#═══════════════════════════════════════════════════════════════════════════════
# NETWORK DISCOVERY
#═══════════════════════════════════════════════════════════════════════════════

# Netdiscover - ARP reconnaissance
run_netdiscover() {
    local target="${1:-$RECON_TARGET}"

    if ! check_tool "netdiscover"; then
        log_error "netdiscover is not installed"
        log_info "Install: sudo apt install netdiscover"
        return 1
    fi

    if ! check_root; then
        log_warning "netdiscover requires root"
        return 1
    fi

    if [[ -z "$target" ]]; then
        target=$(_recon_get_target "Enter IP range (CIDR, e.g., 192.168.1.0/24)") || return 1
    fi

    validate_target "$target" || return 1

    operation_header "Network Discovery" "$target"
    log_command_preview "netdiscover -r $target -P -N"
    log_info "Scanning network for hosts..."

    timeout 60 netdiscover -r "$target" -P -N
    local exit_code=$?

    if [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 124 ]]; then
        operation_summary "success" "Discovery complete"
        log_audit "NETDISCOVER" "$target" "success"
    else
        operation_summary "failed" "Discovery failed"
        log_audit "NETDISCOVER" "$target" "failed"
    fi

    return 0
}

# ARP scan
run_arp_scan() {
    if ! check_tool "arp-scan"; then
        log_error "arp-scan is not installed"
        log_info "Install: sudo apt install arp-scan"
        return 1
    fi

    if ! check_root; then
        log_warning "arp-scan requires root"
        return 1
    fi

    operation_header "ARP Scan" "local network"
    log_command_preview "arp-scan -l"
    log_info "Scanning local network..."

    arp-scan -l
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        operation_summary "success" "ARP scan complete"
        log_audit "ARP_SCAN" "local" "success"
    else
        operation_summary "failed" "Scan failed"
        log_audit "ARP_SCAN" "local" "failed"
    fi

    return $exit_code
}

# Ping sweep
run_ping_sweep() {
    local target="${1:-$RECON_TARGET}"

    if ! check_tool "nmap"; then
        log_error "nmap is not installed"
        return 1
    fi

    if [[ -z "$target" ]]; then
        target=$(_recon_get_target "Enter IP range (CIDR)") || return 1
    fi

    validate_target "$target" || return 1

    operation_header "Ping Sweep" "$target"
    log_command_preview "nmap -sn \"$target\""
    log_info "Discovering live hosts..."

    nmap -sn "$target"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        operation_summary "success" "Ping sweep complete"
        log_audit "PING_SWEEP" "$target" "success"
    else
        operation_summary "failed" "Sweep failed"
        log_audit "PING_SWEEP" "$target" "failed"
    fi

    return $exit_code
}

#═══════════════════════════════════════════════════════════════════════════════
# DNS ENUMERATION
#═══════════════════════════════════════════════════════════════════════════════

# DNS enumeration with dnsenum
run_dnsenum() {
    local target="${1:-$RECON_TARGET}"

    if ! check_tool "dnsenum"; then
        log_error "dnsenum is not installed"
        log_info "Install: sudo apt install dnsenum"
        return 1
    fi

    if [[ -z "$target" ]]; then
        target=$(_recon_get_target "Enter domain") || return 1
    fi

    local outfile
    outfile=$(_recon_output_file "dnsenum" "txt")

    operation_header "DNS Enumeration" "$target"
    log_command_preview "dnsenum \"$target\""
    log_info "Enumerating DNS records..."

    dnsenum "$target" | tee "$outfile"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        operation_summary "success" "DNS enumeration complete" "Output: $outfile"
        log_audit "DNSENUM" "$target" "success"
    else
        operation_summary "failed" "Enumeration failed"
        log_audit "DNSENUM" "$target" "failed"
    fi

    return $exit_code
}

# DNS recon
run_dnsrecon() {
    local target="${1:-$RECON_TARGET}"

    if ! check_tool "dnsrecon"; then
        log_error "dnsrecon is not installed"
        log_info "Install: sudo apt install dnsrecon"
        return 1
    fi

    if [[ -z "$target" ]]; then
        target=$(_recon_get_target "Enter domain") || return 1
    fi

    local outfile
    outfile=$(_recon_output_file "dnsrecon" "txt")

    operation_header "DNS Recon" "$target"
    log_command_preview "dnsrecon -d \"$target\""
    log_info "Running DNS reconnaissance..."

    dnsrecon -d "$target" | tee "$outfile"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        operation_summary "success" "DNS recon complete" "Output: $outfile"
        log_audit "DNSRECON" "$target" "success"
    else
        operation_summary "failed" "Recon failed"
        log_audit "DNSRECON" "$target" "failed"
    fi

    return $exit_code
}

#═══════════════════════════════════════════════════════════════════════════════
# SSL/TLS ANALYSIS
#═══════════════════════════════════════════════════════════════════════════════

# SSL scan
run_sslscan() {
    local target="${1:-$RECON_TARGET}"

    if ! check_tool "sslscan"; then
        log_error "sslscan is not installed"
        log_info "Install: sudo apt install sslscan"
        return 1
    fi

    if [[ -z "$target" ]]; then
        target=$(_recon_get_target "Enter host:port (default port 443)") || return 1
    fi

    local outfile
    outfile=$(_recon_output_file "sslscan" "txt")

    operation_header "SSL Scan" "$target"
    log_command_preview "sslscan \"$target\""
    log_info "Analyzing SSL/TLS configuration..."

    sslscan "$target" | tee "$outfile"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        operation_summary "success" "SSL scan complete" "Output: $outfile"
        log_audit "SSLSCAN" "$target" "success"
    else
        operation_summary "failed" "Scan failed"
        log_audit "SSLSCAN" "$target" "failed"
    fi

    return $exit_code
}

# SSLyze
run_sslyze() {
    local target="${1:-$RECON_TARGET}"

    if ! check_tool "sslyze"; then
        log_error "sslyze is not installed"
        log_info "Install: pip install sslyze"
        return 1
    fi

    if [[ -z "$target" ]]; then
        target=$(_recon_get_target "Enter host:port") || return 1
    fi

    local outfile
    outfile=$(_recon_output_file "sslyze" "txt")

    operation_header "SSLyze Analysis" "$target"
    log_command_preview "sslyze --regular \"$target\""
    log_info "Running SSLyze analysis..."

    sslyze --regular "$target" | tee "$outfile"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        operation_summary "success" "SSLyze complete" "Output: $outfile"
        log_audit "SSLYZE" "$target" "success"
    else
        operation_summary "failed" "Analysis failed"
        log_audit "SSLYZE" "$target" "failed"
    fi

    return $exit_code
}

#═══════════════════════════════════════════════════════════════════════════════
# SNMP & SMB ENUMERATION
#═══════════════════════════════════════════════════════════════════════════════

# SNMP sweep with onesixtyone
run_snmp_sweep() {
    local target="${1:-$RECON_TARGET}"

    if ! check_tool "onesixtyone"; then
        log_error "onesixtyone is not installed"
        log_info "Install: sudo apt install onesixtyone"
        return 1
    fi

    if [[ -z "$target" ]]; then
        target=$(_recon_get_target) || return 1
    fi

    validate_target "$target" || return 1

    operation_header "SNMP Sweep" "$target"
    log_command_preview "onesixtyone \"$target\" public private"
    log_info "Testing SNMP community strings..."

    onesixtyone "$target" public private
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        operation_summary "success" "SNMP sweep complete"
        log_audit "SNMP_SWEEP" "$target" "success"
    else
        operation_summary "failed" "Sweep failed"
        log_audit "SNMP_SWEEP" "$target" "failed"
    fi

    return $exit_code
}

# SMB enumeration
run_smb_enum() {
    local target="${1:-$RECON_TARGET}"

    if [[ -z "$target" ]]; then
        target=$(_recon_get_target) || return 1
    fi

    validate_target "$target" || return 1

    local outfile
    outfile=$(_recon_output_file "smb_enum" "txt")

    operation_header "SMB Enumeration" "$target"

    # Try enum4linux first
    if check_tool "enum4linux"; then
        log_command_preview "enum4linux -a \"$target\""
        log_info "Running enum4linux..."
        enum4linux -a "$target" | tee "$outfile"
    elif check_tool "smbclient"; then
        log_command_preview "smbclient -L \"//$target\" -N"
        log_info "Listing SMB shares..."
        smbclient -L "//$target" -N | tee "$outfile"
    else
        log_error "No SMB enumeration tools found"
        log_info "Install: sudo apt install enum4linux smbclient"
        return 1
    fi

    operation_summary "success" "SMB enumeration complete" "Output: $outfile"
    log_audit "SMB_ENUM" "$target" "success"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# RECON MENU
#═══════════════════════════════════════════════════════════════════════════════

recon_menu() {
    while true; do
        clear
        echo -e "${C_CYAN}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}                    ${C_FIRE}⚔ RECON ARSENAL ⚔${C_RESET}                           ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}╠═══════════════════════════════════════════════════════════════════╣${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}                                                                   ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_SHADOW}──── Port Scanning ────${C_RESET}                                       ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_GHOST}[1]${C_RESET} Quick Scan             ${C_SHADOW}nmap -T4 -F${C_RESET}                     ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_GHOST}[2]${C_RESET} Full Scan              ${C_SHADOW}nmap -sS -sV -sC -A -p-${C_RESET}         ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_GHOST}[3]${C_RESET} Stealth Scan           ${C_SHADOW}nmap -sS -T2 -f${C_RESET}                  ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_GHOST}[4]${C_RESET} UDP Scan               ${C_SHADOW}nmap -sU --top-ports 100${C_RESET}         ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_GHOST}[5]${C_RESET} Vulnerability Scan     ${C_SHADOW}nmap --script vuln${C_RESET}               ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_GHOST}[6]${C_RESET} Service Detection      ${C_SHADOW}nmap -sV${C_RESET}                         ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_GHOST}[7]${C_RESET} Masscan                ${C_SHADOW}masscan --rate 10000${C_RESET}             ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_GHOST}[8]${C_RESET} Rustscan               ${C_SHADOW}rustscan + nmap${C_RESET}                  ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}                                                                   ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_SHADOW}──── Network Discovery ────${C_RESET}                                   ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_GHOST}[9]${C_RESET} Netdiscover            ${C_SHADOW}ARP reconnaissance${C_RESET}               ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_GHOST}[10]${C_RESET} ARP Scan              ${C_SHADOW}arp-scan -l${C_RESET}                      ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_GHOST}[11]${C_RESET} Ping Sweep            ${C_SHADOW}nmap -sn${C_RESET}                         ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}                                                                   ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_SHADOW}──── Enumeration ────${C_RESET}                                         ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_GHOST}[12]${C_RESET} DNS Enumeration       ${C_SHADOW}dnsenum${C_RESET}                          ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_GHOST}[13]${C_RESET} DNS Recon             ${C_SHADOW}dnsrecon${C_RESET}                         ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_GHOST}[14]${C_RESET} SSL/TLS Scan          ${C_SHADOW}sslscan${C_RESET}                          ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_GHOST}[15]${C_RESET} SSLyze                ${C_SHADOW}sslyze --regular${C_RESET}                 ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_GHOST}[16]${C_RESET} SNMP Sweep            ${C_SHADOW}onesixtyone${C_RESET}                      ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}   ${C_GHOST}[17]${C_RESET} SMB Enumeration       ${C_SHADOW}enum4linux${C_RESET}                       ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}                                                                   ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}║${C_RESET}                      ${C_BLOOD}[B] ← Back${C_RESET}                                 ${C_CYAN}║${C_RESET}"
        echo -e "${C_CYAN}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
        echo

        # Show current target if set
        if [[ -n "$RECON_TARGET" ]]; then
            echo -e "    ${C_SHADOW}Current target: ${C_GREEN}$RECON_TARGET${C_RESET}"
            echo
        fi

        echo -ne "    ${C_CYAN}▶${C_RESET} "
        read -r choice

        case "$choice" in
            1)  RECON_TARGET=$(_recon_get_target) && run_nmap_quick ;;
            2)  RECON_TARGET=$(_recon_get_target) && run_nmap_full ;;
            3)  RECON_TARGET=$(_recon_get_target) && run_nmap_stealth ;;
            4)  RECON_TARGET=$(_recon_get_target) && run_nmap_udp ;;
            5)  RECON_TARGET=$(_recon_get_target) && run_nmap_vuln ;;
            6)  RECON_TARGET=$(_recon_get_target) && run_nmap_service ;;
            7)  RECON_TARGET=$(_recon_get_target) && run_masscan ;;
            8)  RECON_TARGET=$(_recon_get_target) && run_rustscan ;;
            9)  run_netdiscover ;;
            10) run_arp_scan ;;
            11) run_ping_sweep ;;
            12) RECON_TARGET=$(_recon_get_target "Enter domain") && run_dnsenum ;;
            13) RECON_TARGET=$(_recon_get_target "Enter domain") && run_dnsrecon ;;
            14) RECON_TARGET=$(_recon_get_target "Enter host:port") && run_sslscan ;;
            15) RECON_TARGET=$(_recon_get_target "Enter host:port") && run_sslyze ;;
            16) RECON_TARGET=$(_recon_get_target) && run_snmp_sweep ;;
            17) RECON_TARGET=$(_recon_get_target) && run_smb_enum ;;
            t|T)
                RECON_TARGET=$(get_target_input "Set target")
                log_info "Target set to: $RECON_TARGET"
                ;;
            c|C)
                RECON_TARGET=""
                log_info "Target cleared"
                ;;
            b|B|back|0)
                RECON_TARGET=""
                return
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac

        echo
        pause
    done
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORT FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Menu
export -f recon_menu

# Nmap functions
export -f run_nmap_quick run_nmap_full run_nmap_stealth run_nmap_udp
export -f run_nmap_vuln run_nmap_service

# Alternative scanners
export -f run_masscan run_rustscan

# Network discovery
export -f run_netdiscover run_arp_scan run_ping_sweep

# Enumeration
export -f run_dnsenum run_dnsrecon
export -f run_sslscan run_sslyze
export -f run_snmp_sweep run_smb_enum
