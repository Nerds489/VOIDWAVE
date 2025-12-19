#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOID WAVE - The Complete Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
# ═══════════════════════════════════════════════════════════════════════════════
#
# Main Menu System: New unified menu with all attack modules
# ═══════════════════════════════════════════════════════════════════════════════

[[ -n "${_VOIDWAVE_MENU_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_MENU_LOADED=1

# Source dependencies
source "${BASH_SOURCE[0]%/*}/version.sh"
source "${VOIDWAVE_ROOT}/lib/core.sh"
source "${VOIDWAVE_ROOT}/lib/ui.sh"

# Source all submenu modules
_MENU_DIR="${VOIDWAVE_ROOT:-$(dirname "${BASH_SOURCE[0]}")/..}/lib/menus"

for _menu_file in "$_MENU_DIR"/*.sh; do
    [[ -f "$_menu_file" ]] && source "$_menu_file"
done

# Source wireless loader for new attack functions
[[ -f "${VOIDWAVE_ROOT}/lib/wireless_loader.sh" ]] && source "${VOIDWAVE_ROOT}/lib/wireless_loader.sh"

# Track state for cleanup
declare -g _MENU_ACTIVE=0
declare -g _CURRENT_IFACE=""
declare -g _MONITOR_IFACE=""

# ═══════════════════════════════════════════════════════════════════════════════
# NEW STYLED BANNER
# ═══════════════════════════════════════════════════════════════════════════════

show_voidwave_banner() {
    local ver="${1:-$VERSION}"

    echo -e "${C_PURPLE:-\033[0;35m}"
    cat << 'BANNER'
    ██╗   ██╗ ██████╗ ██╗██████╗     ██╗    ██╗ █████╗ ██╗   ██╗███████╗
    ██║   ██║██╔═══██╗██║██╔══██╗    ██║    ██║██╔══██╗██║   ██║██╔════╝
    ██║   ██║██║   ██║██║██║  ██║    ██║ █╗ ██║███████║██║   ██║█████╗
    ╚██╗ ██╔╝██║   ██║██║██║  ██║    ██║███╗██║██╔══██║╚██╗ ██╔╝██╔══╝
     ╚████╔╝ ╚██████╔╝██║██████╔╝    ╚███╔███╔╝██║  ██║ ╚████╔╝ ███████╗
      ╚═══╝   ╚═════╝ ╚═╝╚═════╝      ╚══╝╚══╝ ╚═╝  ╚═╝  ╚═══╝  ╚══════╝
BANNER
    echo -e "${C_RESET:-\033[0m}"
    echo -e "    ${C_CYAN:-}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET:-}"
    echo -e "    ${C_WHITE:-}The Complete Offensive Security Framework${C_RESET:-}              ${C_GRAY:-}v${ver}${C_RESET:-}"
    echo -e "    ${C_CYAN:-}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET:-}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATUS LINE
# ═══════════════════════════════════════════════════════════════════════════════

show_status_line() {
    local iface_status="${C_GRAY:-}No interface${C_RESET:-}"
    local monitor_status="${C_GRAY:-}Monitor: OFF${C_RESET:-}"
    local root_status="${C_RED:-}User${C_RESET:-}"

    [[ $EUID -eq 0 ]] && root_status="${C_GREEN:-}Root${C_RESET:-}"
    [[ -n "$_CURRENT_IFACE" ]] && iface_status="${C_CYAN:-}$_CURRENT_IFACE${C_RESET:-}"
    [[ -n "$_MONITOR_IFACE" ]] && monitor_status="${C_GREEN:-}Monitor: $_MONITOR_IFACE${C_RESET:-}"

    echo -e "    ${C_GRAY:-}[${C_RESET:-}${root_status}${C_GRAY:-}]${C_RESET:-}  ${C_GRAY:-}[${C_RESET:-}${iface_status}${C_GRAY:-}]${C_RESET:-}  ${C_GRAY:-}[${C_RESET:-}${monitor_status}${C_GRAY:-}]${C_RESET:-}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# MENU STYLING HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

print_menu_header() {
    local title="$1"
    echo -e "    ${C_BOLD:-}${C_PURPLE:-}◆ ${title}${C_RESET:-}"
    echo -e "    ${C_GRAY:-}────────────────────────────────────────────────────────${C_RESET:-}"
}

print_menu_section() {
    local title="$1"
    echo ""
    echo -e "    ${C_CYAN:-}▸ ${title}${C_RESET:-}"
}

print_menu_item() {
    local num="$1"
    local label="$2"
    local desc="${3:-}"

    if [[ -n "$desc" ]]; then
        printf "    ${C_WHITE:-}%3s${C_RESET:-}) ${C_BOLD:-}%-22s${C_RESET:-} ${C_GRAY:-}%s${C_RESET:-}\n" "$num" "$label" "$desc"
    else
        printf "    ${C_WHITE:-}%3s${C_RESET:-}) ${C_BOLD:-}%s${C_RESET:-}\n" "$num" "$label"
    fi
}

print_menu_footer() {
    echo ""
    echo -e "    ${C_GRAY:-}────────────────────────────────────────────────────────${C_RESET:-}"
    printf "    ${C_WHITE:-}%3s${C_RESET:-}) ${C_RED:-}%s${C_RESET:-}\n" "0" "Back"
    echo ""
}

prompt_choice() {
    local max="$1"
    local choice
    read -rp "    ${C_PURPLE:-}▶${C_RESET:-} Select [0-${max}]: " choice
    echo "$choice"
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
# ═══════════════════════════════════════════════════════════════════════════════

cleanup_on_exit() {
    [[ $_MENU_ACTIVE -eq 0 ]] && return

    # Restore monitor mode if active
    [[ -n "${_MONITOR_IFACE:-}" ]] && {
        airmon-ng stop "$_MONITOR_IFACE" &>/dev/null
        systemctl restart NetworkManager &>/dev/null || true
    }

    # End active session
    type -t session_end &>/dev/null && session_end

    echo ""
    echo -e "    ${C_PURPLE:-}VOID WAVE${C_RESET:-} — \"The airwaves belong to those who listen.\""
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN MENU
# ═══════════════════════════════════════════════════════════════════════════════

show_main_menu() {
    while true; do
        clear_screen 2>/dev/null || clear
        show_voidwave_banner "${VERSION:-}"
        show_status_line

        print_menu_header "MAIN MENU"

        print_menu_section "Network Operations"
        print_menu_item "1" "Reconnaissance" "nmap, masscan, discovery"
        print_menu_item "2" "Scanning" "ports, services, vulns"
        print_menu_item "3" "OSINT" "theHarvester, Shodan, recon-ng"

        print_menu_section "Wireless Assault"
        print_menu_item "4" "WiFi Attacks" "WPS, PMKID, handshakes, Evil Twin"
        print_menu_item "5" "Pillage Mode" "automated attack chains"

        print_menu_section "Attack & Access"
        print_menu_item "6" "Exploitation" "Metasploit, SQLmap, web attacks"
        print_menu_item "7" "Credentials" "hashcat, hydra, cracking"
        print_menu_item "8" "Traffic" "capture, MITM, analysis"

        print_menu_section "Tools & Config"
        print_menu_item "9" "Stress Testing" "hping3, DoS, netem"
        print_menu_item "10" "Tool Status" "check installed tools"
        print_menu_item "11" "Settings" "configuration"

        print_menu_footer

        local choice
        choice=$(prompt_choice 11)

        case "$choice" in
            1) show_recon_menu_new || true ;;
            2) show_scan_menu_new || true ;;
            3) show_osint_menu_new || true ;;
            4) show_wireless_menu_new || true ;;
            5) show_pillage_menu || true ;;
            6) show_exploit_menu_new || true ;;
            7) show_creds_menu_new || true ;;
            8) show_traffic_menu_new || true ;;
            9) show_stress_menu_new || true ;;
            10) { type -t show_status_menu &>/dev/null && show_status_menu || show_tool_status_simple; } || true ;;
            11) { type -t show_settings_menu &>/dev/null && show_settings_menu || echo "Settings not loaded"; } || true ;;
            0)
                if confirm "Exit VOID WAVE?"; then
                    cleanup_on_exit
                    exit 0
                fi
                ;;
            ""|" ")
                # Empty input - just redraw menu
                continue
                ;;
            *)
                echo -e "    ${C_RED:-}Invalid option: '$choice'${C_RESET:-}"
                sleep 1
                ;;
        esac

        [[ "$choice" =~ ^[1-9]$|^1[01]$ ]] && wait_for_keypress
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# NEW RECONNAISSANCE MENU
# ═══════════════════════════════════════════════════════════════════════════════

show_recon_menu_new() {
    while true; do
        clear_screen 2>/dev/null || clear
        show_voidwave_banner "${VERSION:-}"

        print_menu_header "RECONNAISSANCE"

        print_menu_section "Nmap Scanning"
        print_menu_item "1" "Quick Scan" "-T4 -F top ports"
        print_menu_item "2" "Full Scan" "all 65535 ports"
        print_menu_item "3" "Stealth Scan" "SYN scan, low profile"
        print_menu_item "4" "UDP Scan" "UDP services"
        print_menu_item "5" "Vuln Scan" "NSE vulnerability scripts"
        print_menu_item "6" "Service Detection" "version detection"
        print_menu_item "7" "OS Detection" "fingerprinting"
        print_menu_item "8" "Custom Scan" "specify flags"

        print_menu_section "Fast Scanners"
        print_menu_item "9" "Masscan" "millions of packets/sec"
        print_menu_item "10" "Rustscan" "rust-powered speed"
        print_menu_item "11" "Unicornscan" "async scanning"
        print_menu_item "12" "ZMap" "internet-scale"

        print_menu_section "Discovery"
        print_menu_item "13" "ARP Scan" "local network"
        print_menu_item "14" "Netdiscover" "passive/active"
        print_menu_item "15" "Ping Sweep" "ICMP discovery"

        print_menu_section "Enumeration"
        print_menu_item "16" "DNS Enum" "dnsenum/dnsrecon"
        print_menu_item "17" "SSL Analysis" "sslscan/sslyze"
        print_menu_item "18" "SMB Enum" "shares, users"
        print_menu_item "19" "SNMP Sweep" "community strings"

        print_menu_footer

        local choice target network iface domain host flags ports port
        choice=$(prompt_choice 19)

        # Helper for getting network/target with memory
        _get_target_or_network() {
            local prompt_type="${1:-target}"
            if type -t get_resource_with_memory &>/dev/null; then
                get_resource_with_memory "network" "Select $prompt_type" "_scan_local_networks"
            else
                local val
                read -rp "    ${prompt_type^}: " val
                echo "$val"
            fi
        }

        case "$choice" in
            1|2|3|4|5|6|7)
                target=$(_get_target_or_network "target")
                [[ -z "$target" ]] && { echo -e "    ${C_YELLOW:-}No target selected${C_RESET:-}"; sleep 1; continue; }
                case "$choice" in
                    1) run_nmap_quick "$target" 2>/dev/null || true ;;
                    2) run_nmap_full "$target" 2>/dev/null || true ;;
                    3) run_nmap_stealth "$target" 2>/dev/null || true ;;
                    4) run_nmap_udp "$target" 2>/dev/null || true ;;
                    5) run_nmap_vuln "$target" 2>/dev/null || true ;;
                    6) run_nmap_service "$target" 2>/dev/null || true ;;
                    7) run_nmap_os "$target" 2>/dev/null || true ;;
                esac
                ;;
            8)
                target=$(_get_target_or_network "target")
                [[ -z "$target" ]] && { echo -e "    ${C_YELLOW:-}No target selected${C_RESET:-}"; sleep 1; continue; }
                read -rp "    Flags: " flags
                run_nmap_custom "$target" "$flags" 2>/dev/null || true
                ;;
            9)
                target=$(_get_target_or_network "target")
                [[ -z "$target" ]] && { echo -e "    ${C_YELLOW:-}No target selected${C_RESET:-}"; sleep 1; continue; }
                read -rp "    Ports [1-65535]: " ports
                run_masscan "$target" "${ports:-1-65535}" 2>/dev/null || true
                ;;
            10|11)
                target=$(_get_target_or_network "target")
                [[ -z "$target" ]] && { echo -e "    ${C_YELLOW:-}No target selected${C_RESET:-}"; sleep 1; continue; }
                case "$choice" in
                    10) run_rustscan "$target" 2>/dev/null || true ;;
                    11) run_unicornscan "$target" 2>/dev/null || true ;;
                esac
                ;;
            12)
                target=$(_get_target_or_network "target")
                [[ -z "$target" ]] && { echo -e "    ${C_YELLOW:-}No target selected${C_RESET:-}"; sleep 1; continue; }
                read -rp "    Port [80]: " port
                run_zmap "$target" "${port:-80}" 2>/dev/null || true
                ;;
            13)
                network=$(_get_target_or_network "network")
                run_arp_scan "${network:-192.168.1.0/24}" 2>/dev/null || true
                ;;
            14)
                if type -t get_resource_with_memory &>/dev/null; then
                    iface=$(get_resource_with_memory "interface" "Select interface" "_scan_network_interfaces")
                else
                    read -rp "    Interface: " iface
                fi
                run_netdiscover "${iface:-eth0}" 2>/dev/null || true
                ;;
            15|19)
                network=$(_get_target_or_network "network")
                [[ -z "$network" ]] && { echo -e "    ${C_YELLOW:-}No network selected${C_RESET:-}"; sleep 1; continue; }
                case "$choice" in
                    15) run_ping_sweep "$network" 2>/dev/null || true ;;
                    19) run_snmp_sweep "$network" 2>/dev/null || true ;;
                esac
                ;;
            16)
                read -rp "    Domain: " domain
                [[ -n "$domain" ]] && { run_dnsenum "$domain" 2>/dev/null || true; }
                ;;
            17)
                host=$(_get_target_or_network "host")
                [[ -n "$host" ]] && { run_sslscan "$host" 2>/dev/null || true; }
                ;;
            18)
                target=$(_get_target_or_network "target")
                [[ -n "$target" ]] && { run_smb_enum "$target" 2>/dev/null || true; }
                ;;
            0) return 0 ;;
            *) echo -e "    ${C_RED:-}Invalid option${C_RESET:-}"; sleep 1; continue ;;
        esac

        [[ "$choice" != "0" ]] && wait_for_keypress
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# NEW SCANNING MENU
# ═══════════════════════════════════════════════════════════════════════════════

show_scan_menu_new() {
    while true; do
        clear_screen 2>/dev/null || clear
        show_voidwave_banner "${VERSION:-}"

        print_menu_header "SCANNING & ENUMERATION"

        print_menu_section "Port Scanning"
        print_menu_item "1" "Basic Scan" "SYN + version detection"
        print_menu_item "2" "Quick Ports" "top 100 ports"
        print_menu_item "3" "Full Ports" "1-65535"
        print_menu_item "4" "Stealth Mode" "evade detection"

        print_menu_section "Service Enum"
        print_menu_item "5" "Version Detect" "service versions"
        print_menu_item "6" "SMB Shares" "enum shares/users"
        print_menu_item "7" "SNMP Enum" "community scan"

        print_menu_section "Vulnerability"
        print_menu_item "8" "NSE Scripts" "nmap vuln scan"
        print_menu_item "9" "Nuclei" "template scanner"

        print_menu_footer

        local choice target network
        choice=$(prompt_choice 9)

        case "$choice" in
            1|2|3|4|5|6|8)
                # Use memory-based target selection
                if type -t get_resource_with_memory &>/dev/null; then
                    target=$(get_resource_with_memory "network" "Select scan target" "_scan_local_networks")
                else
                    read -rp "    Target: " target
                fi
                [[ -z "$target" ]] && { echo -e "    ${C_YELLOW:-}No target selected${C_RESET:-}"; sleep 1; continue; }
                case "$choice" in
                    1) run_nmap_scan "$target" 2>/dev/null || echo -e "    ${C_RED:-}Scan failed or cancelled${C_RESET:-}" ;;
                    2) run_nmap_quick "$target" 2>/dev/null || echo -e "    ${C_RED:-}Scan failed or cancelled${C_RESET:-}" ;;
                    3) run_nmap_full "$target" 2>/dev/null || echo -e "    ${C_RED:-}Scan failed or cancelled${C_RESET:-}" ;;
                    4) run_nmap_stealth "$target" 2>/dev/null || echo -e "    ${C_RED:-}Scan failed or cancelled${C_RESET:-}" ;;
                    5) run_nmap_service "$target" 2>/dev/null || echo -e "    ${C_RED:-}Scan failed or cancelled${C_RESET:-}" ;;
                    6) run_smb_enum "$target" 2>/dev/null || echo -e "    ${C_RED:-}Scan failed or cancelled${C_RESET:-}" ;;
                    8) run_nmap_vuln "$target" 2>/dev/null || echo -e "    ${C_RED:-}Scan failed or cancelled${C_RESET:-}" ;;
                esac
                ;;
            7)
                # Network-specific for SNMP
                if type -t get_resource_with_memory &>/dev/null; then
                    network=$(get_resource_with_memory "network" "Select network for SNMP sweep" "_scan_local_networks")
                else
                    read -rp "    Network: " network
                fi
                [[ -n "$network" ]] && { run_snmp_sweep "$network" 2>/dev/null || echo -e "    ${C_RED:-}Scan failed or cancelled${C_RESET:-}"; }
                ;;
            9)
                read -rp "    Target URL: " target
                [[ -n "$target" ]] && { run_nuclei "$target" 2>/dev/null || echo -e "    ${C_RED:-}Scan failed or cancelled${C_RESET:-}"; }
                ;;
            0) return 0 ;;
            *) echo -e "    ${C_RED:-}Invalid option${C_RESET:-}"; sleep 1; continue ;;
        esac

        [[ "$choice" != "0" ]] && wait_for_keypress
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# NEW OSINT MENU
# ═══════════════════════════════════════════════════════════════════════════════

show_osint_menu_new() {
    while true; do
        clear_screen 2>/dev/null || clear
        show_voidwave_banner "${VERSION:-}"

        print_menu_header "OSINT - Open Source Intelligence"

        print_menu_section "Domain & Email"
        print_menu_item "1" "theHarvester" "emails, hosts, subdomains"
        print_menu_item "2" "Recon-ng" "modular framework"
        print_menu_item "3" "Amass" "subdomain enumeration"
        print_menu_item "4" "Subfinder" "fast subdomain discovery"

        print_menu_section "Shodan"
        print_menu_item "5" "Host Lookup" "IP information"
        print_menu_item "6" "Search Query" "custom search"
        print_menu_item "7" "Domain Info" "domain assets"

        print_menu_section "DNS & WHOIS"
        print_menu_item "8" "WHOIS" "registration info"
        print_menu_item "9" "DNS Enum" "records enumeration"
        print_menu_item "10" "Reverse DNS" "PTR records"

        print_menu_section "Username OSINT"
        print_menu_item "11" "Sherlock" "social media search"
        print_menu_item "12" "Holehe" "email checker"
        print_menu_item "13" "Google Dorks" "generate dorks"

        print_menu_section "Advanced"
        print_menu_item "14" "SpiderFoot" "automated OSINT"
        print_menu_item "15" "Maltego" "visual analysis"

        print_menu_footer

        local choice input
        choice=$(prompt_choice 15)

        case "$choice" in
            1)  read -rp "    Domain: " input
                [[ -n "$input" ]] && run_theharvester "$input" ;;
            2)  read -rp "    Domain: " input
                [[ -n "$input" ]] && run_recon_ng "$input" ;;
            3)  read -rp "    Domain: " input
                [[ -n "$input" ]] && run_amass "$input" ;;
            4)  read -rp "    Domain: " input
                [[ -n "$input" ]] && run_subfinder "$input" ;;
            5)  read -rp "    IP Address: " input
                [[ -n "$input" ]] && run_shodan_host "$input" ;;
            6)  read -rp "    Search Query: " input
                [[ -n "$input" ]] && run_shodan_search "$input" ;;
            7)  read -rp "    Domain: " input
                [[ -n "$input" ]] && run_shodan_domain "$input" ;;
            8)  read -rp "    Domain/IP: " input
                [[ -n "$input" ]] && run_whois "$input" ;;
            9)  read -rp "    Domain: " input
                [[ -n "$input" ]] && run_dns_enum "$input" ;;
            10) read -rp "    IP Address: " input
                [[ -n "$input" ]] && run_reverse_dns "$input" ;;
            11) read -rp "    Username: " input
                [[ -n "$input" ]] && run_sherlock "$input" ;;
            12) read -rp "    Email: " input
                [[ -n "$input" ]] && run_holehe "$input" ;;
            13) read -rp "    Domain: " input
                [[ -n "$input" ]] && generate_dorks "$input" ;;
            14) read -rp "    Target: " input
                [[ -n "$input" ]] && run_spiderfoot "$input" ;;
            15) run_maltego ;;
            0) return 0 ;;
            *) echo -e "    ${C_RED:-}Invalid option${C_RESET:-}"; sleep 1 ;;
        esac

        [[ "$choice" != "0" ]] && wait_for_keypress
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# NEW WIRELESS ATTACK MENU
# ═══════════════════════════════════════════════════════════════════════════════

show_wireless_menu_new() {
    # Root check
    if [[ $EUID -ne 0 ]]; then
        echo -e "    ${C_RED:-}Wireless attacks require root privileges${C_RESET:-}"
        echo "    Run: sudo voidwave"
        return 1
    fi

    while true; do
        clear_screen 2>/dev/null || clear
        show_voidwave_banner "${VERSION:-}"
        show_status_line

        print_menu_header "WIRELESS ATTACKS"

        print_menu_section "Interface"
        print_menu_item "1" "Select Interface" "choose wireless adapter"
        print_menu_item "2" "Monitor Mode ON" "enable injection"
        print_menu_item "3" "Monitor Mode OFF" "restore managed"
        print_menu_item "4" "MAC Spoof" "change MAC address"

        print_menu_section "Scanning"
        print_menu_item "5" "Scan Networks" "airodump-ng"
        print_menu_item "6" "Target Info" "detailed scan"

        print_menu_section "WPS Attacks"
        print_menu_item "10" "Pixie-Dust" "offline PIN attack"
        print_menu_item "11" "PIN Bruteforce" "online attack"
        print_menu_item "12" "Known PINs" "vendor defaults"
        print_menu_item "13" "Algorithm PINs" "ComputePIN, EasyBox"

        print_menu_section "WPA/WPA2"
        print_menu_item "20" "PMKID Capture" "clientless attack"
        print_menu_item "21" "Handshake Capture" "4-way handshake"
        print_menu_item "22" "Smart Deauth" "intelligent capture"

        print_menu_section "Evil Twin"
        print_menu_item "30" "Evil Twin Full" "captive portal"
        print_menu_item "31" "Open AP" "simple honeypot"
        print_menu_item "32" "WPA Honeypot" "password capture"

        print_menu_section "DoS Attacks"
        print_menu_item "40" "Deauth Attack" "kick clients"
        print_menu_item "41" "Amok Mode" "mass deauth"
        print_menu_item "42" "Beacon Flood" "fake networks"
        print_menu_item "43" "Pursuit Mode" "follow target"

        print_menu_section "Legacy"
        print_menu_item "50" "WEP Attack" "full WEP suite"
        print_menu_item "51" "Enterprise" "WPA-Enterprise attack"

        print_menu_section "Advanced"
        print_menu_item "60" "Hidden SSID" "reveal hidden"
        print_menu_item "61" "WPA3 Check" "downgrade test"
        print_menu_item "62" "Wifite Auto" "automated audit"

        print_menu_footer

        local choice
        choice=$(prompt_choice 62)

        _handle_wireless_choice "$choice"

        [[ "$choice" == "0" ]] && return 0
        [[ "$choice" != "0" ]] && wait_for_keypress
    done
}

_handle_wireless_choice() {
    local choice="$1"
    local bssid channel essid client

    case "$choice" in
        # Interface management
        1) _select_wireless_interface ;;
        2) _enable_monitor_mode ;;
        3) _disable_monitor_mode ;;
        4) _mac_spoof_menu ;;

        # Scanning
        5) _wireless_scan_networks ;;
        6) _detailed_target_scan ;;

        # WPS Attacks
        10) _wps_pixie_attack ;;
        11) _wps_bruteforce_attack ;;
        12) _wps_known_pins ;;
        13) _wps_algorithm_pins ;;

        # WPA/WPA2
        20) _pmkid_capture ;;
        21) _handshake_capture ;;
        22) _smart_handshake_capture ;;

        # Evil Twin
        30) _eviltwin_full ;;
        31) _eviltwin_simple ;;
        32) _eviltwin_wpa ;;

        # DoS
        40) _deauth_attack ;;
        41) _amok_mode ;;
        42) _beacon_flood ;;
        43) _pursuit_mode ;;

        # Legacy
        50) _wep_attack_menu ;;
        51) _enterprise_attack ;;

        # Advanced
        60) _hidden_ssid_reveal ;;
        61) _wpa3_check ;;
        62) _run_wifite ;;

        0) return 0 ;;
        *) echo -e "    ${C_RED:-}Invalid option${C_RESET:-}"; sleep 1 ;;
    esac
}

# Wireless helper functions

# Ensure interface is selected, auto-select if not
_ensure_interface() {
    if [[ -z "$_CURRENT_IFACE" ]]; then
        _select_wireless_interface || return 1
    fi
    return 0
}

# Ensure monitor mode is enabled, auto-enable if not
_ensure_monitor_mode() {
    if [[ -z "$_MONITOR_IFACE" ]]; then
        _enable_monitor_mode || return 1
    fi
    return 0
}

# Get the best available interface (monitor if available, else current)
_get_wireless_iface() {
    echo "${_MONITOR_IFACE:-$_CURRENT_IFACE}"
}

_select_wireless_interface() {
    # Direct selection - memory system has issues with command substitution
    echo ""
    echo -e "    ${C_CYAN:-}Select wireless interface${C_RESET:-}"
    echo ""

    local -a ifaces=()
    while IFS= read -r iface; do
        [[ -n "$iface" ]] && ifaces+=("$iface")
    done < <(iw dev 2>/dev/null | awk '/Interface/{print $2}')

    if [[ ${#ifaces[@]} -eq 0 ]]; then
        echo -e "    ${C_RED:-}No wireless interfaces found${C_RESET:-}"
        return 1
    fi

    for i in "${!ifaces[@]}"; do
        local mode
        mode=$(iw dev "${ifaces[$i]}" info 2>/dev/null | awk '/type/{print $2}')
        echo -e "    $((i+1))) ${ifaces[$i]} ${C_SHADOW:-}($mode)${C_RESET:-}"
    done
    echo ""

    local num
    read -rp "    Select [1-${#ifaces[@]}]: " num
    if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "${#ifaces[@]}" ]]; then
        _CURRENT_IFACE="${ifaces[$((num-1))]}"
        # Save to memory if available
        type -t memory_add &>/dev/null && memory_add "interface" "$_CURRENT_IFACE"
        echo -e "    ${C_GREEN:-}Selected: $_CURRENT_IFACE${C_RESET:-}"
        return 0
    fi

    echo -e "    ${C_RED:-}Invalid selection${C_RESET:-}"
    return 1
}

_enable_monitor_mode() {
    # Auto-select interface if not set
    if [[ -z "$_CURRENT_IFACE" ]]; then
        _select_wireless_interface || return 1
    fi

    local iface="$_CURRENT_IFACE"

    echo ""
    echo -e "    ${C_CYAN:-}Enabling monitor mode on $iface...${C_RESET:-}"
    airmon-ng check kill 2>&1 | sed 's/^/    /'

    if ! airmon-ng start "$iface" 2>&1 | sed 's/^/    /'; then
        echo -e "    ${C_RED:-}Failed to start airmon-ng${C_RESET:-}"
        return 1
    fi

    # Find new monitor interface
    sleep 1  # Give system time to create interface
    _MONITOR_IFACE=$(ls /sys/class/net/ 2>/dev/null | grep -E "${iface}mon|mon[0-9]" | head -1)

    # Check if interface changed to monitor mode in-place
    if [[ -z "$_MONITOR_IFACE" ]]; then
        if iw dev "$iface" info 2>/dev/null | grep -q "type monitor"; then
            _MONITOR_IFACE="$iface"
        else
            _MONITOR_IFACE="${iface}mon"
        fi
    fi

    if [[ -d "/sys/class/net/$_MONITOR_IFACE" ]] || iw dev "$_MONITOR_IFACE" info &>/dev/null; then
        echo ""
        echo -e "    ${C_GREEN:-}Monitor mode enabled: $_MONITOR_IFACE${C_RESET:-}"
    else
        echo -e "    ${C_RED:-}Failed to enable monitor mode${C_RESET:-}"
        _MONITOR_IFACE=""
        return 1
    fi
}

_disable_monitor_mode() {
    local iface="${_MONITOR_IFACE:-}"
    [[ -z "$iface" ]] && { read -rp "    Monitor interface: " iface; }
    [[ -z "$iface" ]] && { echo -e "    ${C_RED:-}No interface specified${C_RESET:-}"; return 1; }

    echo -e "    ${C_CYAN:-}Disabling monitor mode on $iface...${C_RESET:-}"
    airmon-ng stop "$iface" &>/dev/null
    systemctl restart NetworkManager &>/dev/null || true
    _MONITOR_IFACE=""
    echo -e "    ${C_GREEN:-}Monitor mode disabled${C_RESET:-}"
}

_mac_spoof_menu() {
    # Auto-select interface if not set
    if [[ -z "$_CURRENT_IFACE" ]]; then
        _select_wireless_interface || return 1
    fi

    local iface="$_CURRENT_IFACE"

    echo ""
    echo -e "    ${C_CYAN:-}MAC Spoof - Interface: $iface${C_RESET:-}"
    echo ""
    echo "    1) Random MAC"
    echo "    2) Specific MAC"
    echo "    3) Vendor (Intel)"
    echo "    4) Restore Original"
    echo "    0) Cancel"
    echo ""
    read -rp "    Select: " opt

    case "$opt" in
        1) mac_randomize "$iface" 2>/dev/null || macchanger -r "$iface" 2>&1 | sed 's/^/    /' ;;
        2) read -rp "    MAC: " mac; mac_clone "$iface" "$mac" 2>/dev/null || macchanger -m "$mac" "$iface" 2>&1 | sed 's/^/    /' ;;
        3) mac_spoof_vendor "$iface" intel 2>/dev/null || macchanger -a "$iface" 2>&1 | sed 's/^/    /' ;;
        4) mac_restore "$iface" 2>/dev/null || macchanger -p "$iface" 2>&1 | sed 's/^/    /' ;;
        0) return 0 ;;
    esac
}

# Scan for wireless networks
_wireless_scan_networks() {
    # Ensure we have an interface (prefer monitor mode)
    _ensure_interface || return 1

    local iface="${_MONITOR_IFACE:-$_CURRENT_IFACE}"

    echo ""
    echo -e "    ${C_CYAN:-}Scanning networks on $iface${C_RESET:-}"
    echo -e "    ${C_YELLOW:-}Press Ctrl+C to stop${C_RESET:-}"
    echo ""

    local duration
    read -rp "    Duration in seconds [30]: " duration
    duration="${duration:-30}"

    timeout "$duration" airodump-ng "$iface" 2>/dev/null || true
}

# Detailed target scan
_detailed_target_scan() {
    _ensure_interface || return 1

    local iface="${_MONITOR_IFACE:-$_CURRENT_IFACE}"

    echo ""
    echo -e "    ${C_CYAN:-}Detailed network scan on $iface${C_RESET:-}"
    echo ""

    local bssid
    read -rp "    Target BSSID (or blank for all): " bssid

    local channel
    read -rp "    Channel (or blank for hopping): " channel

    echo ""
    echo -e "    ${C_YELLOW:-}Press Ctrl+C to stop${C_RESET:-}"
    echo ""

    local cmd="airodump-ng"
    [[ -n "$bssid" ]] && cmd="$cmd --bssid $bssid"
    [[ -n "$channel" ]] && cmd="$cmd -c $channel"
    cmd="$cmd $iface"

    eval "$cmd" 2>/dev/null || true
}

# Get wireless AP target with memory support
# Returns: BSSID|CHANNEL|ESSID
_get_target_info() {
    local bssid channel essid

    # Check for recent wireless targets in memory
    if type -t memory_has &>/dev/null && memory_has "wireless"; then
        echo ""
        echo -e "    ${C_CYAN:-}Select target AP${C_RESET:-}"
        echo ""
        echo -e "    ${C_SHADOW:-}Recent targets:${C_RESET:-}"

        local -a targets=()
        local idx=1
        while IFS='|' read -r timestamp value rest; do
            [[ -z "$value" ]] && continue
            targets+=("$value|$rest")
            local age
            age=$(_memory_time_ago "$timestamp" 2>/dev/null || echo "")
            echo -e "    ${C_GHOST:-}[$idx]${C_RESET:-} $value ${C_SHADOW:-}($age)${C_RESET:-}"
            ((idx++))
        done < <(memory_get "wireless" 5 2>/dev/null)

        echo ""
        echo -e "    ${C_GHOST:-}[S]${C_RESET:-} Scan for networks"
        echo -e "    ${C_GHOST:-}[M]${C_RESET:-} Enter manually"
        echo ""

        local choice
        read -rp "    Select: " choice

        case "${choice,,}" in
            s|scan)
                # Run scan and let user select
                echo -e "    ${C_CYAN:-}Scanning... (Ctrl+C to stop when ready)${C_RESET:-}"
                local iface="${_MONITOR_IFACE:-$_CURRENT_IFACE}"
                [[ -n "$iface" ]] && timeout 15 airodump-ng "$iface" 2>/dev/null || true
                # Fall through to manual entry
                ;;
            m|manual)
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#targets[@]} )); then
                    local selected="${targets[$((choice-1))]}"
                    echo "$selected"
                    return 0
                fi
                ;;
        esac
    fi

    # Manual entry
    echo ""
    read -rp "    Target BSSID: " bssid
    [[ -z "$bssid" ]] && return 1
    read -rp "    Channel: " channel
    [[ -z "$channel" ]] && return 1
    read -rp "    ESSID (optional): " essid

    local target_info="${bssid}|${channel}|${essid}"

    # Save to memory
    type -t memory_add &>/dev/null && memory_add "wireless" "$bssid" "channel=$channel" "essid=$essid"

    echo "$target_info"
}

# Quick BSSID/Channel getter for attacks
_get_bssid_channel() {
    local info
    info=$(_get_target_info)
    [[ -z "$info" ]] && return 1

    local bssid channel
    bssid=$(echo "$info" | cut -d'|' -f1)
    channel=$(echo "$info" | cut -d'|' -f2)

    echo "$bssid $channel"
}

_detailed_target_scan() {
    local iface="${_MONITOR_IFACE:-$_CURRENT_IFACE}"
    [[ -z "$iface" ]] && { echo -e "    ${C_RED:-}No interface selected${C_RESET:-}"; return 1; }

    local target_info bssid channel
    target_info=$(_get_target_info) || return 1
    bssid=$(echo "$target_info" | cut -d'|' -f1)
    channel=$(echo "$target_info" | cut -d'|' -f2)

    airodump-ng --bssid "$bssid" -c "$channel" "$iface" 2>/dev/null || true
}

_wps_pixie_attack() {
    _ensure_monitor_mode || return 1
    local iface="$_MONITOR_IFACE"

    local target_info bssid channel
    target_info=$(_get_target_info) || return 1
    bssid=$(echo "$target_info" | cut -d'|' -f1)
    channel=$(echo "$target_info" | cut -d'|' -f2)

    if type -t wps_pixie_auto &>/dev/null; then
        wps_pixie_auto "$iface" "$bssid" "$channel"
    else
        reaver -i "$iface" -b "$bssid" -c "$channel" -K 1 -vvv 2>/dev/null || true
    fi
}

_wps_bruteforce_attack() {
    _ensure_monitor_mode || return 1
    local iface="$_MONITOR_IFACE"

    local target_info bssid channel
    target_info=$(_get_target_info) || return 1
    bssid=$(echo "$target_info" | cut -d'|' -f1)
    channel=$(echo "$target_info" | cut -d'|' -f2)

    if type -t wps_bruteforce_reaver &>/dev/null; then
        wps_bruteforce_reaver "$iface" "$bssid" "$channel"
    else
        reaver -i "$iface" -b "$bssid" -c "$channel" -vvv 2>/dev/null || true
    fi
}

_wps_known_pins() {
    _ensure_monitor_mode || return 1
    local iface="$_MONITOR_IFACE"

    local target_info bssid channel
    target_info=$(_get_target_info) || return 1
    bssid=$(echo "$target_info" | cut -d'|' -f1)
    channel=$(echo "$target_info" | cut -d'|' -f2)

    if type -t wps_try_known_pins &>/dev/null; then
        wps_try_known_pins "$iface" "$bssid" "$channel"
    else
        echo -e "    ${C_YELLOW:-}Function not available${C_RESET:-}"
    fi
}

_wps_algorithm_pins() {
    _ensure_monitor_mode || return 1
    local iface="$_MONITOR_IFACE"

    local target_info bssid channel
    target_info=$(_get_target_info) || return 1
    bssid=$(echo "$target_info" | cut -d'|' -f1)
    channel=$(echo "$target_info" | cut -d'|' -f2)

    if type -t wps_try_algorithm_pins &>/dev/null; then
        wps_try_algorithm_pins "$iface" "$bssid" "$channel"
    else
        echo -e "    ${C_YELLOW:-}Function not available${C_RESET:-}"
    fi
}

_pmkid_capture() {
    _ensure_monitor_mode || return 1
    local iface="$_MONITOR_IFACE"

    local target_info bssid essid
    target_info=$(_get_target_info) || return 1
    bssid=$(echo "$target_info" | cut -d'|' -f1)
    essid=$(echo "$target_info" | cut -d'|' -f3)

    if type -t pmkid_capture_target &>/dev/null; then
        pmkid_capture_target "$iface" "$bssid" "$essid"
    elif command -v hcxdumptool &>/dev/null; then
        hcxdumptool -i "$iface" --filterlist_ap="$bssid" --filtermode=2 -o capture.pcapng 2>/dev/null || true
    else
        echo -e "    ${C_RED:-}hcxdumptool not installed${C_RESET:-}"
    fi
}

_handshake_capture() {
    _ensure_monitor_mode || return 1
    local iface="$_MONITOR_IFACE"

    local target_info bssid channel essid
    target_info=$(_get_target_info) || return 1
    bssid=$(echo "$target_info" | cut -d'|' -f1)
    channel=$(echo "$target_info" | cut -d'|' -f2)
    essid=$(echo "$target_info" | cut -d'|' -f3)

    if type -t handshake_capture_full &>/dev/null; then
        handshake_capture_full "$iface" "$bssid" "$channel" "$essid"
    else
        echo -e "    ${C_CYAN:-}Starting capture in background...${C_RESET:-}"
        airodump-ng --bssid "$bssid" -c "$channel" -w handshake "$iface" &
        local dump_pid=$!
        sleep 5
        echo -e "    ${C_CYAN:-}Sending deauth...${C_RESET:-}"
        aireplay-ng -0 10 -a "$bssid" "$iface"
        sleep 30
        kill $dump_pid 2>/dev/null
    fi
}

_smart_handshake_capture() {
    _ensure_monitor_mode || return 1
    local iface="$_MONITOR_IFACE"

    local target_info bssid channel essid
    target_info=$(_get_target_info) || return 1
    bssid=$(echo "$target_info" | cut -d'|' -f1)
    channel=$(echo "$target_info" | cut -d'|' -f2)
    essid=$(echo "$target_info" | cut -d'|' -f3)

    if type -t handshake_smart_deauth &>/dev/null; then
        handshake_smart_deauth "$iface" "$bssid" "$channel" "$essid"
    else
        _handshake_capture
    fi
}

_eviltwin_full() {
    _ensure_interface || return 1

    local ap_iface deauth_iface ssid bssid channel lang

    echo ""
    echo -e "    ${C_CYAN:-}Evil Twin requires 2 interfaces (or VIF support)${C_RESET:-}"
    echo -e "    ${C_SHADOW:-}Current interface: $_CURRENT_IFACE${C_RESET:-}"
    echo ""
    read -rp "    AP Interface [$_CURRENT_IFACE]: " ap_iface
    ap_iface="${ap_iface:-$_CURRENT_IFACE}"
    read -rp "    Deauth Interface (or same for VIF): " deauth_iface
    deauth_iface="${deauth_iface:-$ap_iface}"
    read -rp "    SSID to clone: " ssid
    read -rp "    Target BSSID: " bssid
    read -rp "    Channel: " channel
    read -rp "    Portal language [en]: " lang

    if type -t et_attack_full &>/dev/null; then
        et_attack_full "$ap_iface" "$deauth_iface" "$ssid" "$bssid" "$channel" "${lang:-en}"
    else
        echo -e "    ${C_YELLOW:-}Evil Twin module not loaded${C_RESET:-}"
    fi
}

_eviltwin_simple() {
    _ensure_interface || return 1

    local iface="$_CURRENT_IFACE"
    local ssid channel

    echo ""
    read -rp "    Interface [$iface]: " input_iface
    iface="${input_iface:-$iface}"
    read -rp "    SSID: " ssid
    read -rp "    Channel [6]: " channel

    if type -t et_attack_simple &>/dev/null; then
        et_attack_simple "$iface" "$ssid" "${channel:-6}"
    else
        echo -e "    ${C_YELLOW:-}Evil Twin module not loaded${C_RESET:-}"
    fi
}

_eviltwin_wpa() {
    _ensure_interface || return 1

    local iface="$_CURRENT_IFACE"
    local ssid channel password

    echo ""
    read -rp "    Interface [$iface]: " input_iface
    iface="${input_iface:-$iface}"
    read -rp "    SSID: " ssid
    read -rp "    Channel [6]: " channel
    read -rp "    WPA Password: " password

    if type -t et_attack_wpa &>/dev/null; then
        et_attack_wpa "$iface" "$ssid" "${channel:-6}" "$password"
    else
        echo -e "    ${C_YELLOW:-}Evil Twin module not loaded${C_RESET:-}"
    fi
}

_deauth_attack() {
    _ensure_monitor_mode || return 1
    local iface="$_MONITOR_IFACE"

    local target_info bssid client count
    target_info=$(_get_target_info) || return 1
    bssid=$(echo "$target_info" | cut -d'|' -f1)

    read -rp "    Client MAC (blank=broadcast): " client
    read -rp "    Packet count [10]: " count

    if type -t dos_deauth &>/dev/null; then
        dos_deauth "$iface" "$bssid" "$client" "${count:-10}"
    else
        if [[ -n "$client" ]]; then
            aireplay-ng -0 "${count:-10}" -a "$bssid" -c "$client" "$iface" 2>/dev/null || true
        else
            aireplay-ng -0 "${count:-10}" -a "$bssid" "$iface" 2>/dev/null || true
        fi
    fi
}

_amok_mode() {
    _ensure_monitor_mode || return 1
    local iface="$_MONITOR_IFACE"

    if type -t dos_amok_mode &>/dev/null; then
        dos_amok_mode "$iface"
    elif command -v mdk4 &>/dev/null; then
        mdk4 "$iface" d
    elif command -v mdk3 &>/dev/null; then
        mdk3 "$iface" d
    else
        echo -e "    ${C_RED:-}mdk3/mdk4 not installed${C_RESET:-}"
    fi
}

_beacon_flood() {
    _ensure_monitor_mode || return 1
    local iface="$_MONITOR_IFACE"

    if type -t dos_beacon_flood &>/dev/null; then
        dos_beacon_flood "$iface"
    elif command -v mdk4 &>/dev/null; then
        mdk4 "$iface" b -a -c 1
    else
        echo -e "    ${C_RED:-}mdk4 not installed${C_RESET:-}"
    fi
}

_pursuit_mode() {
    _ensure_monitor_mode || return 1
    local iface="$_MONITOR_IFACE"

    local target_info bssid
    target_info=$(_get_target_info) || return 1
    bssid=$(echo "$target_info" | cut -d'|' -f1)

    if type -t dos_pursuit_mode &>/dev/null; then
        dos_pursuit_mode "$iface" "$bssid"
    else
        echo -e "    ${C_YELLOW:-}Pursuit mode not available${C_RESET:-}"
    fi
}

_wep_attack_menu() {
    _ensure_monitor_mode || return 1
    local iface="$_MONITOR_IFACE"

    local target_info bssid channel essid
    target_info=$(_get_target_info) || return 1
    bssid=$(echo "$target_info" | cut -d'|' -f1)
    channel=$(echo "$target_info" | cut -d'|' -f2)
    essid=$(echo "$target_info" | cut -d'|' -f3)

    if type -t wep_attack_full &>/dev/null; then
        wep_attack_full "$iface" "$bssid" "$channel" "$essid"
    else
        echo -e "    ${C_CYAN:-}Running basic WEP attack...${C_RESET:-}"
        airodump-ng --bssid "$bssid" -c "$channel" -w wep_capture "$iface" &
        sleep 5
        aireplay-ng -1 0 -a "$bssid" "$iface"
        aireplay-ng -3 -b "$bssid" "$iface"
    fi
}

_enterprise_attack() {
    _ensure_interface || return 1

    local ap_iface deauth_iface ssid bssid channel

    echo ""
    echo -e "    ${C_CYAN:-}Enterprise Attack (WPA-Enterprise)${C_RESET:-}"
    echo -e "    ${C_SHADOW:-}Current interface: $_CURRENT_IFACE${C_RESET:-}"
    echo ""
    read -rp "    AP Interface [$_CURRENT_IFACE]: " ap_iface
    ap_iface="${ap_iface:-$_CURRENT_IFACE}"
    read -rp "    Deauth Interface (or same): " deauth_iface
    deauth_iface="${deauth_iface:-$ap_iface}"
    read -rp "    SSID: " ssid
    read -rp "    Target BSSID: " bssid
    read -rp "    Channel: " channel

    if type -t ent_attack_full &>/dev/null; then
        ent_attack_full "$ap_iface" "$deauth_iface" "$ssid" "$bssid" "$channel"
    else
        echo -e "    ${C_YELLOW:-}Enterprise module not loaded${C_RESET:-}"
    fi
}

_hidden_ssid_reveal() {
    _ensure_monitor_mode || return 1
    local iface="$_MONITOR_IFACE"

    local target_info bssid channel
    target_info=$(_get_target_info) || return 1
    bssid=$(echo "$target_info" | cut -d'|' -f1)
    channel=$(echo "$target_info" | cut -d'|' -f2)

    if type -t hidden_reveal_deauth &>/dev/null; then
        hidden_reveal_deauth "$iface" "$bssid" "$channel"
    else
        aireplay-ng -0 5 -a "$bssid" "$iface" 2>/dev/null || true
    fi
}

_wpa3_check() {
    _ensure_monitor_mode || return 1
    local iface="$_MONITOR_IFACE"

    local target_info bssid channel
    target_info=$(_get_target_info) || return 1
    bssid=$(echo "$target_info" | cut -d'|' -f1)
    channel=$(echo "$target_info" | cut -d'|' -f2)

    if type -t wpa3_check &>/dev/null; then
        wpa3_check "$iface" "$bssid" "$channel"
    else
        echo -e "    ${C_YELLOW:-}WPA3 check not available${C_RESET:-}"
    fi
}

_run_wifite() {
    if command -v wifite &>/dev/null; then
        wifite
    else
        echo -e "    ${C_RED:-}wifite not installed${C_RESET:-}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# PILLAGE MODE MENU
# ═══════════════════════════════════════════════════════════════════════════════

show_pillage_menu() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "    ${C_RED:-}Pillage mode requires root${C_RESET:-}"
        return 1
    fi

    while true; do
        clear_screen 2>/dev/null || clear
        show_voidwave_banner "${VERSION:-}"

        print_menu_header "PILLAGE MODE - Automated Attacks"

        print_menu_section "Automated Modes"
        print_menu_item "1" "Full Pillage" "attack all networks"
        print_menu_item "2" "Continuous Pillage" "rescan and attack"
        print_menu_item "3" "Smart Mode" "prioritize weak targets"

        print_menu_section "Targeted"
        print_menu_item "4" "Target BSSID" "attack specific AP"
        print_menu_item "5" "Target ESSID" "attack by name"

        print_menu_section "Options"
        print_menu_item "6" "Set Attack Chain" "customize attacks"
        print_menu_item "7" "Set Filters" "power, encryption"
        print_menu_item "8" "Schedule Attack" "time-based"

        print_menu_section "Results"
        print_menu_item "9" "View Results" "cracked passwords"
        print_menu_item "10" "Export Results" "save to file"

        print_menu_footer

        local choice iface
        choice=$(prompt_choice 10)

        iface="${_MONITOR_IFACE:-$_CURRENT_IFACE}"
        [[ -z "$iface" ]] && [[ "$choice" =~ ^[1-5]$ ]] && {
            echo -e "    ${C_RED:-}No interface selected${C_RESET:-}"
            wait_for_keypress
            continue
        }

        case "$choice" in
            1) type -t auto_pillage &>/dev/null && auto_pillage "$iface" || echo "Function not available" ;;
            2) type -t auto_pillage_continuous &>/dev/null && auto_pillage_continuous "$iface" || echo "Function not available" ;;
            3) type -t auto_smart &>/dev/null && auto_smart "$iface" || echo "Function not available" ;;
            4) local target_info bssid
               target_info=$(_get_target_info) || continue
               bssid=$(echo "$target_info" | cut -d'|' -f1)
               type -t auto_target_bssid &>/dev/null && auto_target_bssid "$iface" "$bssid" || echo "Function not available" ;;
            5) read -rp "    Target ESSID: " essid
               type -t auto_target_essid &>/dev/null && auto_target_essid "$iface" "$essid" || echo "Function not available" ;;
            6) _set_attack_chain ;;
            7) _set_filters ;;
            8) local target_info bssid time
               read -rp "    Time (HH:MM): " time
               target_info=$(_get_target_info) || continue
               bssid=$(echo "$target_info" | cut -d'|' -f1)
               type -t auto_schedule &>/dev/null && auto_schedule "$iface" "$time" "$bssid" || echo "Function not available" ;;
            9) type -t auto_show_results &>/dev/null && auto_show_results || wireless_loot_show_cracked 2>/dev/null ;;
            10) read -rp "    Output file: " outfile
                type -t auto_export_results &>/dev/null && auto_export_results "$outfile" || echo "Function not available" ;;
            0) return 0 ;;
            *) echo -e "    ${C_RED:-}Invalid option${C_RESET:-}"; sleep 1 ;;
        esac

        [[ "$choice" != "0" ]] && wait_for_keypress
    done
}

_set_attack_chain() {
    echo ""
    echo -e "    ${C_CYAN:-}Available attacks: pmkid, handshake, wps, wep${C_RESET:-}"
    echo -e "    ${C_CYAN:-}Current chain: ${AUTO_ATTACK_CHAIN[*]:-pmkid handshake wps}${C_RESET:-}"
    read -rp "    New chain (space-separated): " chain
    if [[ -n "$chain" ]]; then
        IFS=' ' read -ra AUTO_ATTACK_CHAIN <<< "$chain"
        export AUTO_ATTACK_CHAIN
        echo -e "    ${C_GREEN:-}Chain set: ${AUTO_ATTACK_CHAIN[*]}${C_RESET:-}"
    fi
}

_set_filters() {
    echo ""
    echo -e "    ${C_CYAN:-}Current filters:${C_RESET:-}"
    echo -e "    Min power: ${AUTO_MIN_POWER:--70}"
    echo -e "    Encryption: ${AUTO_ENCRYPTION_FILTER:-any}"
    echo ""
    read -rp "    Min power [-70]: " power
    read -rp "    Encryption [any/wep/wpa/wpa2]: " enc

    [[ -n "$power" ]] && export AUTO_MIN_POWER="$power"
    [[ -n "$enc" ]] && export AUTO_ENCRYPTION_FILTER="$enc"
    echo -e "    ${C_GREEN:-}Filters updated${C_RESET:-}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# NEW EXPLOITATION MENU
# ═══════════════════════════════════════════════════════════════════════════════

show_exploit_menu_new() {
    while true; do
        clear_screen 2>/dev/null || clear
        show_voidwave_banner "${VERSION:-}"

        print_menu_header "EXPLOITATION"

        print_menu_section "Metasploit"
        print_menu_item "1" "Metasploit Console" "msfconsole"
        print_menu_item "2" "MSF Resource" "run .rc script"
        print_menu_item "3" "MSFvenom" "payload generator"

        print_menu_section "Web Attacks"
        print_menu_item "4" "SQLmap" "SQL injection"
        print_menu_item "5" "SQLmap Advanced" "full options"
        print_menu_item "6" "XSStrike" "XSS testing"
        print_menu_item "7" "Commix" "command injection"

        print_menu_section "Web Scanners"
        print_menu_item "8" "Nikto" "web server scan"
        print_menu_item "9" "Gobuster" "directory brute"
        print_menu_item "10" "Dirb" "content discovery"
        print_menu_item "11" "Feroxbuster" "recursive scan"
        print_menu_item "12" "Nuclei" "vuln templates"

        print_menu_section "Research"
        print_menu_item "13" "Searchsploit" "exploit-db search"

        print_menu_footer

        local choice target
        choice=$(prompt_choice 13)

        case "$choice" in
            1) run_metasploit ;;
            2) read -rp "    RC file: " rc
               [[ -n "$rc" ]] && run_metasploit_rc "$rc" ;;
            3) read -rp "    Payload: " payload
               read -rp "    LHOST: " lhost
               read -rp "    LPORT: " lport
               read -rp "    Format: " format
               run_msfvenom "$payload" "LHOST=$lhost" "LPORT=$lport" "$format" ;;
            4) read -rp "    Target URL: " target
               [[ -n "$target" ]] && run_sqlmap "$target" ;;
            5) read -rp "    Target URL: " target
               read -rp "    Options: " opts
               [[ -n "$target" ]] && run_sqlmap_advanced "$target" "$opts" ;;
            6) read -rp "    Target URL: " target
               [[ -n "$target" ]] && run_xsstrike "$target" ;;
            7) read -rp "    Target URL: " target
               [[ -n "$target" ]] && run_commix "$target" ;;
            8) read -rp "    Target URL: " target
               [[ -n "$target" ]] && run_nikto "$target" ;;
            9) read -rp "    Target URL: " target
               read -rp "    Wordlist: " wl
               [[ -n "$target" ]] && run_gobuster "$target" "$wl" ;;
            10) read -rp "    Target URL: " target
                [[ -n "$target" ]] && run_dirb "$target" ;;
            11) read -rp "    Target URL: " target
                read -rp "    Wordlist: " wl
                [[ -n "$target" ]] && run_feroxbuster "$target" "$wl" ;;
            12) read -rp "    Target URL: " target
                [[ -n "$target" ]] && run_nuclei "$target" ;;
            13) read -rp "    Search term: " term
                [[ -n "$term" ]] && run_searchsploit "$term" ;;
            0) return 0 ;;
            *) echo -e "    ${C_RED:-}Invalid option${C_RESET:-}"; sleep 1 ;;
        esac

        [[ "$choice" != "0" ]] && wait_for_keypress
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# NEW CREDENTIALS MENU
# ═══════════════════════════════════════════════════════════════════════════════

show_creds_menu_new() {
    while true; do
        clear_screen 2>/dev/null || clear
        show_voidwave_banner "${VERSION:-}"

        print_menu_header "CREDENTIAL ATTACKS"

        print_menu_section "Hashcat (GPU)"
        print_menu_item "1" "Hashcat Attack" "GPU cracking"
        print_menu_item "2" "Hashcat Rules" "rule-based"
        print_menu_item "3" "Hashcat Custom" "custom flags"
        print_menu_item "4" "Crack WPA" "WiFi hashes"

        print_menu_section "John the Ripper"
        print_menu_item "5" "John Attack" "CPU cracking"
        print_menu_item "6" "John WiFi" "WPA hashes"

        print_menu_section "Network Brute"
        print_menu_item "7" "Hydra SSH" "SSH brute force"
        print_menu_item "8" "Hydra Custom" "any protocol"
        print_menu_item "9" "Medusa" "parallel attack"
        print_menu_item "10" "ncrack" "network cracker"

        print_menu_section "Active Directory"
        print_menu_item "11" "CrackMapExec" "SMB attacks"
        print_menu_item "12" "CME Enum" "enumeration"
        print_menu_item "13" "Secretsdump" "dump hashes"

        print_menu_section "WiFi Cracking"
        print_menu_item "14" "Auto Crack" "detect & crack"
        print_menu_item "15" "Batch Crack" "multiple files"
        print_menu_item "16" "Aircrack WPA" "CPU cracking"

        print_menu_section "Utilities"
        print_menu_item "17" "Convert Hashcat" "format conversion"
        print_menu_item "18" "GPU Info" "detect GPU"
        print_menu_item "19" "Find Wordlist" "locate wordlists"

        print_menu_footer

        local choice
        choice=$(prompt_choice 19)

        _handle_creds_choice "$choice"

        [[ "$choice" == "0" ]] && return 0
        [[ "$choice" != "0" ]] && wait_for_keypress
    done
}

_handle_creds_choice() {
    local choice="$1"
    local hashes wordlist target mode user pass proto rules capture dir input bssid flags

    # Helper for target selection with memory
    _get_cred_target() {
        if type -t get_resource_with_memory &>/dev/null; then
            get_resource_with_memory "host" "Select target host" "_scan_local_hosts"
        else
            local val
            read -rp "    Target: " val
            echo "$val"
        fi
    }

    case "$choice" in
        1) read -rp "    Hash file: " hashes
           read -rp "    Wordlist: " wordlist
           read -rp "    Mode (0=MD5): " mode
           run_hashcat_gpu "$hashes" "$wordlist" "${mode:-0}" 2>/dev/null || true ;;
        2) read -rp "    Hash file: " hashes
           read -rp "    Wordlist: " wordlist
           read -rp "    Mode: " mode
           read -rp "    Rules file: " rules
           run_hashcat_rules "$hashes" "$wordlist" "$mode" "$rules" 2>/dev/null || true ;;
        3) read -rp "    Hash file: " hashes
           read -rp "    Custom flags: " flags
           run_hashcat_custom "$hashes" "$flags" 2>/dev/null || true ;;
        4) read -rp "    Hash file (.22000): " hashes
           read -rp "    Wordlist: " wordlist
           { type -t crack_hashcat &>/dev/null && crack_hashcat "$hashes" wpa "$wordlist"; } || run_hashcat_gpu "$hashes" "$wordlist" 22000 2>/dev/null || true ;;
        5) read -rp "    Hash file: " hashes
           read -rp "    Wordlist: " wordlist
           run_john "$hashes" "$wordlist" 2>/dev/null || true ;;
        6) read -rp "    Hash file: " hashes
           read -rp "    Wordlist: " wordlist
           run_john_wifi "$hashes" "$wordlist" 2>/dev/null || true ;;
        7) target=$(_get_cred_target)
           [[ -z "$target" ]] && return
           read -rp "    Username: " user
           read -rp "    Wordlist: " wordlist
           run_hydra_ssh "$target" "$user" "$wordlist" 2>/dev/null || true ;;
        8) target=$(_get_cred_target)
           [[ -z "$target" ]] && return
           read -rp "    Protocol: " proto
           read -rp "    Username: " user
           read -rp "    Wordlist: " wordlist
           run_hydra "$target" "$proto" "$user" "$wordlist" 2>/dev/null || true ;;
        9) target=$(_get_cred_target)
           [[ -z "$target" ]] && return
           read -rp "    Protocol: " proto
           read -rp "    Username: " user
           read -rp "    Wordlist: " wordlist
           run_medusa "$target" "$proto" "$user" "$wordlist" 2>/dev/null || true ;;
        10) target=$(_get_cred_target)
            [[ -z "$target" ]] && return
            read -rp "    Protocol: " proto
            read -rp "    Username: " user
            read -rp "    Wordlist: " wordlist
            run_ncrack "$target" "$proto" "$user" "$wordlist" 2>/dev/null || true ;;
        11) target=$(_get_cred_target)
            [[ -z "$target" ]] && return
            read -rp "    Protocol [smb]: " proto
            read -rp "    Username: " user
            read -rp "    Password: " pass
            run_crackmapexec "$target" "${proto:-smb}" "$user" "$pass" 2>/dev/null || true ;;
        12) target=$(_get_cred_target)
            [[ -z "$target" ]] && return
            read -rp "    Username: " user
            read -rp "    Password: " pass
            run_cme_enum "$target" "$user" "$pass" 2>/dev/null || true ;;
        13) target=$(_get_cred_target)
            [[ -z "$target" ]] && return
            read -rp "    Username: " user
            read -rp "    Password: " pass
            run_secretsdump "$target" "$user" "$pass" 2>/dev/null || true ;;
        14) read -rp "    Capture file: " capture
            read -rp "    Wordlist: " wordlist
            { type -t crack_auto &>/dev/null && crack_auto "$capture" "$wordlist"; } || echo "Function not available" ;;
        15) read -rp "    Directory: " dir
            read -rp "    Wordlist: " wordlist
            { type -t crack_batch &>/dev/null && crack_batch "$dir" "$wordlist"; } || echo "Function not available" ;;
        16) read -rp "    Capture file: " capture
            read -rp "    Wordlist: " wordlist
            read -rp "    BSSID: " bssid
            { type -t crack_aircrack_wpa &>/dev/null && crack_aircrack_wpa "$capture" "$wordlist" "$bssid"; } || aircrack-ng -w "$wordlist" -b "$bssid" "$capture" 2>/dev/null || true ;;
        17) read -rp "    Input file: " input
            { type -t convert_to_hashcat &>/dev/null && convert_to_hashcat "$input"; } || echo "Function not available" ;;
        18) { type -t crack_detect_gpu &>/dev/null && crack_detect_gpu; } || echo "Function not available" ;;
        19) { type -t crack_list_wordlists &>/dev/null && crack_list_wordlists; } || ls -la /usr/share/wordlists/ 2>/dev/null ;;
        0) return 0 ;;
        *) echo -e "    ${C_RED:-}Invalid option${C_RESET:-}"; sleep 1 ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# NEW TRAFFIC MENU
# ═══════════════════════════════════════════════════════════════════════════════

show_traffic_menu_new() {
    while true; do
        clear_screen 2>/dev/null || clear
        show_voidwave_banner "${VERSION:-}"

        print_menu_header "TRAFFIC ANALYSIS"

        print_menu_section "Packet Capture"
        print_menu_item "1" "tcpdump" "CLI capture"
        print_menu_item "2" "Wireshark" "GUI analysis"
        print_menu_item "3" "tshark" "CLI Wireshark"

        print_menu_section "MITM Attacks"
        print_menu_item "4" "Ettercap" "ARP spoofing"
        print_menu_item "5" "Bettercap" "modern MITM"
        print_menu_item "6" "mitmproxy" "HTTP intercept"

        print_menu_section "Analysis"
        print_menu_item "7" "Analyze PCAP" "parse capture"
        print_menu_item "8" "Extract Files" "carve data"

        print_menu_footer

        local choice iface
        choice=$(prompt_choice 8)

        # Helper for interface selection with memory
        _get_traffic_iface() {
            if type -t get_resource_with_memory &>/dev/null; then
                get_resource_with_memory "interface" "Select interface" "_scan_wireless_interfaces"
            else
                local val
                read -rp "    Interface: " val
                echo "$val"
            fi
        }

        # Helper for host/gateway selection with memory
        _get_traffic_host() {
            local prompt="${1:-Host}"
            if type -t get_resource_with_memory &>/dev/null; then
                get_resource_with_memory "host" "Select $prompt" "_scan_local_hosts"
            else
                local val
                read -rp "    $prompt: " val
                echo "$val"
            fi
        }

        case "$choice" in
            1)
               iface=$(_get_traffic_iface)
               [[ -z "$iface" ]] && { echo -e "    ${C_YELLOW:-}No interface selected${C_RESET:-}"; sleep 1; continue; }
               read -rp "    Filter: " filter
               { type -t run_tcpdump &>/dev/null && run_tcpdump "$iface" "$filter" || tcpdump -i "$iface" "$filter"; } 2>/dev/null || true ;;
            2)
               iface=$(_get_traffic_iface)
               [[ -z "$iface" ]] && { echo -e "    ${C_YELLOW:-}No interface selected${C_RESET:-}"; sleep 1; continue; }
               if type -t run_wireshark &>/dev/null; then
                   run_wireshark "$iface" 2>/dev/null || true
               else
                   wireshark -i "$iface" 2>/dev/null &
               fi ;;
            3)
               iface=$(_get_traffic_iface)
               [[ -z "$iface" ]] && { echo -e "    ${C_YELLOW:-}No interface selected${C_RESET:-}"; sleep 1; continue; }
               read -rp "    Filter: " filter
               { type -t run_tshark &>/dev/null && run_tshark "$iface" "$filter" || tshark -i "$iface" "$filter"; } 2>/dev/null || true ;;
            4)
               iface=$(_get_traffic_iface)
               [[ -z "$iface" ]] && { echo -e "    ${C_YELLOW:-}No interface selected${C_RESET:-}"; sleep 1; continue; }
               local gw target
               gw=$(_get_traffic_host "Gateway")
               [[ -z "$gw" ]] && { echo -e "    ${C_YELLOW:-}No gateway selected${C_RESET:-}"; sleep 1; continue; }
               target=$(_get_traffic_host "Target")
               [[ -z "$target" ]] && { echo -e "    ${C_YELLOW:-}No target selected${C_RESET:-}"; sleep 1; continue; }
               { type -t run_ettercap &>/dev/null && run_ettercap "$iface" "$gw" "$target" || ettercap -T -i "$iface" -M arp:remote /"$gw"// /"$target"//; } 2>/dev/null || true ;;
            5)
               iface=$(_get_traffic_iface)
               [[ -z "$iface" ]] && { echo -e "    ${C_YELLOW:-}No interface selected${C_RESET:-}"; sleep 1; continue; }
               { type -t run_bettercap &>/dev/null && run_bettercap "$iface" || bettercap -iface "$iface"; } 2>/dev/null || true ;;
            6)
               local port
               read -rp "    Port [8080]: " port
               { type -t run_mitmproxy &>/dev/null && run_mitmproxy "${port:-8080}" || mitmproxy -p "${port:-8080}"; } 2>/dev/null || true ;;
            7)
               local pcap
               read -rp "    PCAP file: " pcap
               [[ -z "$pcap" ]] && { echo -e "    ${C_YELLOW:-}No file specified${C_RESET:-}"; sleep 1; continue; }
               tshark -r "$pcap" -q -z io,stat,1 2>/dev/null || true ;;
            8)
               local pcap outdir
               read -rp "    PCAP file: " pcap
               [[ -z "$pcap" ]] && { echo -e "    ${C_YELLOW:-}No file specified${C_RESET:-}"; sleep 1; continue; }
               read -rp "    Output dir [/tmp/extracted]: " outdir
               tshark -r "$pcap" --export-objects "http,${outdir:-/tmp/extracted}" 2>/dev/null || true ;;
            0) return 0 ;;
            *) echo -e "    ${C_RED:-}Invalid option${C_RESET:-}"; sleep 1 ;;
        esac

        [[ "$choice" != "0" ]] && wait_for_keypress
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# NEW STRESS MENU
# ═══════════════════════════════════════════════════════════════════════════════

show_stress_menu_new() {
    while true; do
        clear_screen 2>/dev/null || clear
        show_voidwave_banner "${VERSION:-}"

        print_menu_header "STRESS TESTING"

        print_menu_section "Network Stress"
        print_menu_item "1" "hping3 SYN" "TCP SYN flood"
        print_menu_item "2" "hping3 UDP" "UDP flood"
        print_menu_item "3" "hping3 ICMP" "ICMP flood"
        print_menu_item "4" "Slowloris" "HTTP slow"

        print_menu_section "Network Impairment"
        print_menu_item "5" "Add Delay" "latency injection"
        print_menu_item "6" "Add Loss" "packet loss"
        print_menu_item "7" "Add Corrupt" "packet corruption"
        print_menu_item "8" "Clear Netem" "remove impairment"

        print_menu_footer

        local choice target iface
        choice=$(prompt_choice 8)

        # Helper for target selection with memory
        _get_stress_target() {
            if type -t get_resource_with_memory &>/dev/null; then
                get_resource_with_memory "host" "Select target" "_scan_local_hosts"
            else
                local val
                read -rp "    Target: " val
                echo "$val"
            fi
        }

        # Helper for interface selection with memory
        _get_stress_iface() {
            if type -t get_resource_with_memory &>/dev/null; then
                get_resource_with_memory "interface" "Select interface" "_scan_wireless_interfaces"
            else
                local val
                read -rp "    Interface: " val
                echo "$val"
            fi
        }

        case "$choice" in
            1)
               target=$(_get_stress_target)
               [[ -z "$target" ]] && { echo -e "    ${C_YELLOW:-}No target selected${C_RESET:-}"; sleep 1; continue; }
               local port dur
               read -rp "    Port [80]: " port
               read -rp "    Duration [30]: " dur
               run_hping_attack "$target" "${port:-80}" syn "${dur:-30}" 1000 2>/dev/null || true ;;
            2)
               target=$(_get_stress_target)
               [[ -z "$target" ]] && { echo -e "    ${C_YELLOW:-}No target selected${C_RESET:-}"; sleep 1; continue; }
               local port dur
               read -rp "    Port [53]: " port
               read -rp "    Duration [30]: " dur
               run_hping_attack "$target" "${port:-53}" udp "${dur:-30}" 1000 2>/dev/null || true ;;
            3)
               target=$(_get_stress_target)
               [[ -z "$target" ]] && { echo -e "    ${C_YELLOW:-}No target selected${C_RESET:-}"; sleep 1; continue; }
               local dur
               read -rp "    Duration [30]: " dur
               run_hping_attack "$target" 0 icmp "${dur:-30}" 1000 2>/dev/null || true ;;
            4)
               target=$(_get_stress_target)
               [[ -z "$target" ]] && { echo -e "    ${C_YELLOW:-}No target selected${C_RESET:-}"; sleep 1; continue; }
               local port
               read -rp "    Port [80]: " port
               { type -t run_slowloris &>/dev/null && run_slowloris "$target" "${port:-80}" || echo "    Function not available"; } 2>/dev/null || true ;;
            5)
               iface=$(_get_stress_iface)
               [[ -z "$iface" ]] && { echo -e "    ${C_YELLOW:-}No interface selected${C_RESET:-}"; sleep 1; continue; }
               local delay dur
               read -rp "    Delay [100ms]: " delay
               read -rp "    Duration [60]: " dur
               run_netem "$iface" delay "${delay:-100ms}" "${dur:-60}" 2>/dev/null || true ;;
            6)
               iface=$(_get_stress_iface)
               [[ -z "$iface" ]] && { echo -e "    ${C_YELLOW:-}No interface selected${C_RESET:-}"; sleep 1; continue; }
               local loss dur
               read -rp "    Loss % [10]: " loss
               read -rp "    Duration [60]: " dur
               run_netem "$iface" loss "${loss:-10}%" "${dur:-60}" 2>/dev/null || true ;;
            7)
               iface=$(_get_stress_iface)
               [[ -z "$iface" ]] && { echo -e "    ${C_YELLOW:-}No interface selected${C_RESET:-}"; sleep 1; continue; }
               local corrupt dur
               read -rp "    Corrupt % [5]: " corrupt
               read -rp "    Duration [60]: " dur
               run_netem "$iface" corrupt "${corrupt:-5}%" "${dur:-60}" 2>/dev/null || true ;;
            8)
               iface=$(_get_stress_iface)
               [[ -z "$iface" ]] && { echo -e "    ${C_YELLOW:-}No interface selected${C_RESET:-}"; sleep 1; continue; }
               tc qdisc del dev "$iface" root 2>/dev/null || true
               echo -e "    ${C_GREEN:-}Impairment cleared${C_RESET:-}" ;;
            0) return 0 ;;
            *) echo -e "    ${C_RED:-}Invalid option${C_RESET:-}"; sleep 1 ;;
        esac

        [[ "$choice" != "0" ]] && wait_for_keypress
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# FALLBACK TOOL STATUS
# ═══════════════════════════════════════════════════════════════════════════════

show_tool_status_simple() {
    clear_screen 2>/dev/null || clear
    show_voidwave_banner "${VERSION:-}"

    print_menu_header "TOOL STATUS"

    local tools=(
        "nmap" "masscan" "rustscan"
        "aircrack-ng" "reaver" "bully" "pixiewps"
        "hcxdumptool" "hcxtools" "mdk4" "hostapd"
        "hashcat" "john" "hydra" "medusa"
        "metasploit" "sqlmap" "nikto" "gobuster"
        "wireshark" "tcpdump" "ettercap" "bettercap"
        "theHarvester" "recon-ng" "sherlock"
    )

    echo ""
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            echo -e "    ${C_GREEN:-}✓${C_RESET:-} $tool"
        else
            echo -e "    ${C_RED:-}✗${C_RESET:-} $tool"
        fi
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# ENTRY POINTS
# ═══════════════════════════════════════════════════════════════════════════════

menu_loop() {
    # Require a TTY for interactive menu
    if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
        # Print to both stdout and stderr to ensure visibility
        printf '%s\n' "Error: Interactive menu requires a terminal."
        printf '%s\n' "Run 'voidwave --help' for CLI options."
        # Return success to avoid triggering error handler
        return 0
    fi

    _MENU_ACTIVE=1
    # Register cleanup for EXIT (uses cleanup registry)
    register_cleanup cleanup_on_exit
    # Keep signal handlers for interactive interrupt handling
    trap cleanup_on_exit INT TERM
    show_main_menu
}

run_interactive() {
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] && {
        echo "Error: Interactive menu requires TTY."
        return 1
    }

    [[ ! -t 0 ]] && {
        echo "Error: No TTY available."
        return 1
    }

    menu_loop
}

validate_menus() {
    local errors=0
    for menu in recon_menu_new scan_menu_new wireless_menu_new exploit_menu_new creds_menu_new traffic_menu_new osint_menu_new stress_menu_new pillage_menu; do
        if ! type -t "show_${menu}" &>/dev/null; then
            echo "MISSING: show_${menu}"
            ((errors++)) || true
        fi
    done
    return $errors
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export -f cleanup_on_exit show_main_menu menu_loop run_interactive validate_menus
export -f show_voidwave_banner show_status_line
export -f print_menu_header print_menu_section print_menu_item print_menu_footer prompt_choice
