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
# Scanning module: port scanning, service enumeration, network discovery
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_SCANNING_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_SCANNING_LOADED=1

# Source library files
source "${BASH_SOURCE%/*}/../lib/core.sh"
source "${BASH_SOURCE%/*}/../lib/ui.sh"
source "${BASH_SOURCE%/*}/../lib/safety.sh"
source "${BASH_SOURCE%/*}/../lib/detection.sh"
source "${BASH_SOURCE%/*}/../lib/utils.sh"

#═══════════════════════════════════════════════════════════════════════════════
# NMAP FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run a basic nmap scan with require_tools dependency gate
# This is an example function demonstrating the require_tools and timed_run patterns
# Args: $1 = target (IP, hostname, or CIDR)
# Returns: 0 on success, 1 on failure
run_nmap_scan() {
    local target="${1:-}"

    # Validate target using safety.sh
    if ! validate_target "$target" "nmap_scan"; then
        log_error "Invalid target: $target"
        return 1
    fi

    # Check required tools with auto-install support (interactive only)
    if ! require_tools nmap; then
        log_error "Required tool 'nmap' is not available"
        return 1
    fi

    log_audit "SCAN" "nmap_scan" "$target"

    # Run nmap with timed_run for elapsed-time logging
    timed_run "Nmap scan against $target" run_with_sudo nmap -sS -sV -T4 "$target"
}

# Run quick nmap scan
# Args: $1 = target
run_nmap_quick() {
    local target="$1"
    check_tool "nmap" || return 1
    validate_target "$target" || return 1

    operation_header "Nmap Quick Scan" "$target"
    local start_time
    start_time=$(date +%s)
    local outfile
    outfile=$(generate_target_filename "$target" "nmap_quick" "xml")

    log_command_preview "nmap -T4 -F -oX $outfile $target"
    log_audit "SCAN" "nmap_quick" "$target"

    nmap -T4 -F -oX "$outfile" "$target"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Nmap Quick" "Output: $outfile\nDuration: $duration"
    log_loot "Nmap results: $outfile"
}

# Run full nmap scan
# Args: $1 = target
run_nmap_full() {
    local target="$1"
    check_tool "nmap" || return 1
    validate_target "$target" || return 1

    require_root || return 1

    operation_header "Nmap Full Scan" "$target"
    local start_time
    start_time=$(date +%s)
    local outfile
    outfile=$(generate_target_filename "$target" "nmap_full" "xml")

    log_command_preview "nmap -sS -sV -sC -A -p- -oX $outfile $target"
    log_audit "SCAN" "nmap_full" "$target"

    nmap -sS -sV -sC -A -p- -oX "$outfile" "$target"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Nmap Full" "Output: $outfile\nDuration: $duration"
    log_loot "Nmap results: $outfile"
}

# Run stealth nmap scan
# Args: $1 = target
run_nmap_stealth() {
    local target="$1"
    check_tool "nmap" || return 1
    validate_target "$target" || return 1

    require_root || return 1

    operation_header "Nmap Stealth Scan" "$target"
    local start_time
    start_time=$(date +%s)
    local outfile
    outfile=$(generate_target_filename "$target" "nmap_stealth" "xml")

    log_command_preview "nmap -sS -T2 -f -D RND:5 -oX $outfile $target"
    log_audit "SCAN" "nmap_stealth" "$target"

    nmap -sS -T2 -f -D RND:5 -oX "$outfile" "$target"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Nmap Stealth" "Output: $outfile\nDuration: $duration"
    log_loot "Nmap results: $outfile"
}

# Run UDP nmap scan
# Args: $1 = target
run_nmap_udp() {
    local target="$1"
    check_tool "nmap" || return 1
    validate_target "$target" || return 1

    require_root || return 1

    operation_header "Nmap UDP Scan" "$target"
    local start_time
    start_time=$(date +%s)
    local outfile
    outfile=$(generate_target_filename "$target" "nmap_udp" "xml")

    log_command_preview "nmap -sU --top-ports 100 -oX $outfile $target"
    log_audit "SCAN" "nmap_udp" "$target"

    nmap -sU --top-ports 100 -oX "$outfile" "$target"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Nmap UDP" "Output: $outfile\nDuration: $duration"
    log_loot "Nmap results: $outfile"
}

# Run nmap vulnerability scan
# Args: $1 = target
run_nmap_vuln() {
    local target="$1"
    check_tool "nmap" || return 1
    validate_target "$target" || return 1

    operation_header "Nmap Vuln Scan" "$target"
    local start_time
    start_time=$(date +%s)
    local outfile
    outfile=$(generate_target_filename "$target" "nmap_vuln" "xml")

    log_command_preview "nmap --script vuln -oX $outfile $target"
    log_audit "SCAN" "nmap_vuln" "$target"

    nmap --script vuln -oX "$outfile" "$target"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Nmap Vuln" "Output: $outfile\nDuration: $duration"
    log_loot "Nmap results: $outfile"
}

# Run nmap service detection
# Args: $1 = target
run_nmap_service() {
    local target="$1"
    check_tool "nmap" || return 1
    validate_target "$target" || return 1

    operation_header "Nmap Service Detection" "$target"
    local start_time
    start_time=$(date +%s)
    local outfile
    outfile=$(generate_target_filename "$target" "nmap_service" "xml")

    log_command_preview "nmap -sV --version-intensity 5 -oX $outfile $target"
    log_audit "SCAN" "nmap_service" "$target"

    nmap -sV --version-intensity 5 -oX "$outfile" "$target"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Nmap Service" "Output: $outfile\nDuration: $duration"
    log_loot "Nmap results: $outfile"
}

# Run nmap OS detection
# Args: $1 = target
run_nmap_os() {
    local target="$1"
    check_tool "nmap" || return 1
    validate_target "$target" || return 1

    require_root || return 1

    operation_header "Nmap OS Detection" "$target"
    local start_time
    start_time=$(date +%s)
    local outfile
    outfile=$(generate_target_filename "$target" "nmap_os" "xml")

    log_command_preview "nmap -O -oX $outfile $target"
    log_audit "SCAN" "nmap_os" "$target"

    nmap -O -oX "$outfile" "$target"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Nmap OS" "Output: $outfile\nDuration: $duration"
    log_loot "Nmap results: $outfile"
}

# Run nmap custom scan
# Args: $1 = target, $2 = nmap options
run_nmap_custom() {
    local target="$1"
    local options="${2:--sV}"
    check_tool "nmap" || return 1
    validate_target "$target" || return 1

    operation_header "Nmap Custom" "$target"
    local start_time
    start_time=$(date +%s)
    local outfile
    outfile=$(generate_target_filename "$target" "nmap_custom" "xml")

    log_command_preview "nmap $options -oX $outfile $target"
    log_audit "SCAN" "nmap_custom" "$target"

    nmap $options -oX "$outfile" "$target"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Nmap Custom" "Output: $outfile\nDuration: $duration"
    log_loot "Nmap results: $outfile"
}

#═══════════════════════════════════════════════════════════════════════════════
# MASSCAN FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run masscan fast port scan
# Args: $1 = target, $2 = ports (optional), $3 = rate (optional)
run_masscan() {
    local target="$1"
    local ports="${2:-1-65535}"
    local rate="${3:-10000}"

    check_tool "masscan" || return 1
    validate_target "$target" || return 1
    require_root || return 1

    operation_header "Masscan" "$target"
    local start_time
    start_time=$(date +%s)
    local outfile
    outfile=$(generate_target_filename "$target" "masscan" "xml")

    log_command_preview "masscan -p$ports --rate=$rate -oX $outfile $target"
    log_audit "SCAN" "masscan" "$target"

    masscan -p"$ports" --rate="$rate" -oX "$outfile" "$target"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Masscan" "Output: $outfile\nDuration: $duration"
    log_loot "Masscan results: $outfile"
}

#═══════════════════════════════════════════════════════════════════════════════
# RUSTSCAN FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run rustscan (fast scanner with nmap integration)
# Args: $1 = target
run_rustscan() {
    local target="$1"
    check_tool "rustscan" || return 1
    validate_target "$target" || return 1

    operation_header "Rustscan" "$target"
    local start_time
    start_time=$(date +%s)
    local outfile
    outfile=$(generate_target_filename "$target" "rustscan" "txt")

    log_command_preview "rustscan -a $target -- -sV -sC"
    log_audit "SCAN" "rustscan" "$target"

    rustscan -a "$target" -- -sV -sC | tee "$outfile"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Rustscan" "Output: $outfile\nDuration: $duration"
    log_loot "Rustscan results: $outfile"
}

#═══════════════════════════════════════════════════════════════════════════════
# UNICORNSCAN FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run unicornscan (async scanner)
# Args: $1 = target
run_unicornscan() {
    local target="$1"
    check_tool "unicornscan" || return 1
    validate_target "$target" || return 1
    require_root || return 1

    operation_header "Unicornscan" "$target"
    local start_time
    start_time=$(date +%s)
    local outfile
    outfile=$(generate_target_filename "$target" "unicornscan" "txt")

    log_command_preview "unicornscan -mT -I $target:a"
    log_audit "SCAN" "unicornscan" "$target"

    unicornscan -mT -I "$target:a" | tee "$outfile"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Unicornscan" "Output: $outfile\nDuration: $duration"
    log_loot "Unicornscan results: $outfile"
}

#═══════════════════════════════════════════════════════════════════════════════
# ZMAP FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Run zmap (fast internet-wide scanner)
# Args: $1 = target/subnet, $2 = port
run_zmap() {
    local target="$1"
    local port="${2:-80}"

    check_tool "zmap" || return 1
    validate_target "$target" || return 1
    require_root || return 1

    operation_header "Zmap" "$target"
    local start_time
    start_time=$(date +%s)
    local outfile
    outfile=$(generate_target_filename "$target" "zmap" "txt")

    log_command_preview "zmap -p $port $target -o $outfile"
    log_audit "SCAN" "zmap" "$target"

    zmap -p "$port" "$target" -o "$outfile"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "Zmap" "Output: $outfile\nDuration: $duration"
    log_loot "Zmap results: $outfile"
}

#═══════════════════════════════════════════════════════════════════════════════
# SERVICE ENUMERATION
#═══════════════════════════════════════════════════════════════════════════════

# Enumerate SMB shares
# Args: $1 = target
run_smb_enum() {
    local target="$1"
    validate_target "$target" || return 1

    operation_header "SMB Enumeration" "$target"
    local start_time
    start_time=$(date +%s)
    local outfile
    outfile=$(generate_target_filename "$target" "smb_enum" "txt")

    log_audit "ENUM" "smb" "$target"

    {
        if check_tool "enum4linux-ng"; then
            log_command_preview "enum4linux-ng -A $target"
            enum4linux-ng -A "$target"
        elif check_tool "enum4linux"; then
            log_command_preview "enum4linux -a $target"
            enum4linux -a "$target"
        elif check_tool "smbclient"; then
            log_command_preview "smbclient -L //$target -N"
            smbclient -L "//$target" -N
        else
            log_error "No SMB enumeration tool found"
            return 1
        fi
    } | tee "$outfile"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "SMB Enum" "Output: $outfile\nDuration: $duration"
    log_loot "SMB results: $outfile"
}

# Enumerate SNMP
# Args: $1 = target
run_snmp_enum() {
    local target="$1"
    validate_target "$target" || return 1

    operation_header "SNMP Enumeration" "$target"
    local start_time
    start_time=$(date +%s)
    local outfile
    outfile=$(generate_target_filename "$target" "snmp_enum" "txt")

    log_audit "ENUM" "snmp" "$target"

    {
        if check_tool "snmp-check"; then
            log_command_preview "snmp-check $target"
            snmp-check "$target"
        elif check_tool "snmpwalk"; then
            log_command_preview "snmpwalk -v2c -c public $target"
            snmpwalk -v2c -c public "$target"
        else
            log_error "No SNMP enumeration tool found"
            return 1
        fi
    } | tee "$outfile"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "SNMP Enum" "Output: $outfile\nDuration: $duration"
    log_loot "SNMP results: $outfile"
}

# Enumerate LDAP
# Args: $1 = target
run_ldap_enum() {
    local target="$1"
    validate_target "$target" || return 1

    check_tool "ldapsearch" || return 1

    operation_header "LDAP Enumeration" "$target"
    local start_time
    start_time=$(date +%s)
    local outfile
    outfile=$(generate_target_filename "$target" "ldap_enum" "txt")

    log_command_preview "ldapsearch -x -H ldap://$target -s base"
    log_audit "ENUM" "ldap" "$target"

    ldapsearch -x -H "ldap://$target" -s base | tee "$outfile"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "LDAP Enum" "Output: $outfile\nDuration: $duration"
    log_loot "LDAP results: $outfile"
}

# Enumerate NFS
# Args: $1 = target
run_nfs_enum() {
    local target="$1"
    validate_target "$target" || return 1

    check_tool "showmount" || return 1

    operation_header "NFS Enumeration" "$target"
    local start_time
    start_time=$(date +%s)
    local outfile
    outfile=$(generate_target_filename "$target" "nfs_enum" "txt")

    log_command_preview "showmount -e $target"
    log_audit "ENUM" "nfs" "$target"

    showmount -e "$target" | tee "$outfile"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "NFS Enum" "Output: $outfile\nDuration: $duration"
    log_loot "NFS results: $outfile"
}

# Enumerate RPC
# Args: $1 = target
run_rpc_enum() {
    local target="$1"
    validate_target "$target" || return 1

    check_tool "rpcclient" || return 1

    operation_header "RPC Enumeration" "$target"
    local start_time
    start_time=$(date +%s)
    local outfile
    outfile=$(generate_target_filename "$target" "rpc_enum" "txt")

    log_command_preview "rpcclient -U '' -N $target"
    log_audit "ENUM" "rpc" "$target"

    rpcclient -U '' -N "$target" -c "srvinfo;enumdomusers;enumdomgroups" 2>/dev/null | tee "$outfile"

    local duration
    duration=$(elapsed_time "$start_time")
    operation_summary "success" "RPC Enum" "Output: $outfile\nDuration: $duration"
    log_loot "RPC results: $outfile"
}

#═══════════════════════════════════════════════════════════════════════════════
# SCANNING MENU
#═══════════════════════════════════════════════════════════════════════════════

# Interactive scanning menu
scanning_menu() {
    local target=""

    while true; do
        clear
        echo -e "    ${C_CYAN}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}                     ${C_CYAN}🔍 SCANNING ARSENAL${C_RESET}                          ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}╠═══════════════════════════════════════════════════════════════════╣${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}                                                                   ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}   ${C_SHADOW}──── Port Scanning ────${C_RESET}                                       ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}   ${C_GHOST}[1]${C_RESET} Quick Scan              ${C_SHADOW}nmap -T4 -F${C_RESET}                     ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}   ${C_GHOST}[2]${C_RESET} Full Scan               ${C_SHADOW}nmap -sS -sV -sC -A -p-${C_RESET}         ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}   ${C_GHOST}[3]${C_RESET} Stealth Scan            ${C_SHADOW}nmap -sS -T2 -f${C_RESET}                 ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}   ${C_GHOST}[4]${C_RESET} UDP Scan                ${C_SHADOW}nmap -sU --top-ports${C_RESET}            ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}   ${C_GHOST}[5]${C_RESET} Vuln Scan               ${C_SHADOW}nmap --script vuln${C_RESET}              ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}   ${C_GHOST}[6]${C_RESET} Masscan                 ${C_SHADOW}masscan --rate 10000${C_RESET}            ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}   ${C_GHOST}[7]${C_RESET} Rustscan                ${C_SHADOW}fast + nmap${C_RESET}                     ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}                                                                   ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}   ${C_SHADOW}──── Service Enumeration ────${C_RESET}                                 ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}   ${C_GHOST}[8]${C_RESET} Service Detection       ${C_SHADOW}nmap -sV${C_RESET}                        ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}   ${C_GHOST}[9]${C_RESET} OS Detection            ${C_SHADOW}nmap -O${C_RESET}                         ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}   ${C_GHOST}[10]${C_RESET} SMB Enumeration        ${C_SHADOW}enum4linux${C_RESET}                      ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}   ${C_GHOST}[11]${C_RESET} SNMP Enumeration       ${C_SHADOW}snmp-check${C_RESET}                      ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}   ${C_GHOST}[12]${C_RESET} LDAP Enumeration       ${C_SHADOW}ldapsearch${C_RESET}                      ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}   ${C_GHOST}[13]${C_RESET} NFS Enumeration        ${C_SHADOW}showmount${C_RESET}                       ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}                                                                   ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}║${C_RESET}                       ${C_RED}[B] ← Back${C_RESET}                                  ${C_CYAN}║${C_RESET}"
        echo -e "    ${C_CYAN}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
        echo
        echo -ne "    ${C_CYAN}▶${C_RESET} "
        read -r choice

        case "$choice" in
            1|2|3|4|5|6|7|8|9|10|11|12|13)
                echo -ne "    ${C_CYAN}Target (IP/hostname/CIDR): ${C_RESET}"
                read -r target
                [[ -z "$target" ]] && { log_error "Target required"; continue; }
                ;;
        esac

        case "$choice" in
            1)  run_nmap_quick "$target" ;;
            2)  run_nmap_full "$target" ;;
            3)  run_nmap_stealth "$target" ;;
            4)  run_nmap_udp "$target" ;;
            5)  run_nmap_vuln "$target" ;;
            6)  run_masscan "$target" ;;
            7)  run_rustscan "$target" ;;
            8)  run_nmap_service "$target" ;;
            9)  run_nmap_os "$target" ;;
            10) run_smb_enum "$target" ;;
            11) run_snmp_enum "$target" ;;
            12) run_ldap_enum "$target" ;;
            13) run_nfs_enum "$target" ;;
            b|B|0)
                return
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac
        echo -e "\n    ${C_SHADOW}Press Enter to continue...${C_RESET}"
        read -r
    done
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORT FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Nmap
export -f run_nmap_scan run_nmap_quick run_nmap_full run_nmap_stealth run_nmap_udp
export -f run_nmap_vuln run_nmap_service run_nmap_os run_nmap_custom

# Other scanners
export -f run_masscan run_rustscan run_unicornscan run_zmap

# Service enumeration
export -f run_smb_enum run_snmp_enum run_ldap_enum run_nfs_enum run_rpc_enum

# Menu
export -f scanning_menu
