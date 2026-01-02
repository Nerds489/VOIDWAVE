#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE Pre-Flight System
# ═══════════════════════════════════════════════════════════════════════════════
# Validates requirements before attacks:
# - Root privileges
# - Interface selection
# - Monitor mode
# - Tool availability
# - Auto-fix when possible
# ═══════════════════════════════════════════════════════════════════════════════

[[ -n "${_VOIDWAVE_PREFLIGHT_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_PREFLIGHT_LOADED=1

# Source auto-detection module
source "${BASH_SOURCE%/*}/auto.sh" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════════
# REQUIREMENT DEFINITIONS
# ═══════════════════════════════════════════════════════════════════════════════

# Format: "req1 req2 req3" - all required
# Use | for OR: "tool1|tool2" means either works
declare -gA ATTACK_REQUIREMENTS=(
    # WPS
    [wps_pixie]="root monitor_mode reaver|bully pixiewps"
    [wps_bruteforce]="root monitor_mode reaver|bully"
    [wps_known]="root monitor_mode reaver|bully"
    [wps_algorithm]="root monitor_mode reaver|bully"
    
    # WPA
    [pmkid]="root monitor_mode hcxdumptool"
    [handshake]="root monitor_mode airodump-ng aireplay-ng"
    [crack_aircrack]="aircrack-ng capture_file wordlist"
    [crack_hashcat]="hashcat hash_file wordlist"
    
    # Evil Twin
    [eviltwin]="root interface hostapd dnsmasq"
    [eviltwin_full]="root dual_interface|vif hostapd dnsmasq lighttpd handshake_file"
    
    # DoS
    [deauth]="root monitor_mode aireplay-ng"
    [amok]="root monitor_mode mdk4"
    [beacon_flood]="root monitor_mode mdk4"
    
    # Other Wireless
    [wep]="root monitor_mode aircrack-ng aireplay-ng"
    [enterprise]="root monitor_mode hostapd-wpe|hostapd"
    [scan]="root interface airodump-ng"
    [wps_scan]="root monitor_mode wash"

    # ═══════════════════════════════════════════════════════════════════════════
    # RECON
    # ═══════════════════════════════════════════════════════════════════════════
    [recon_dns]="dig|host"
    [recon_subdomain]="subfinder|amass|host"
    [recon_whois]="whois"
    [recon_email]="theHarvester|theharvester"
    [recon_tech]="whatweb|curl"
    [recon_full]="dig whois curl"

    # ═══════════════════════════════════════════════════════════════════════════
    # SCANNING
    # ═══════════════════════════════════════════════════════════════════════════
    [scan_quick]="nmap"
    [scan_full]="nmap"
    [scan_version]="nmap"
    [scan_os]="root nmap"
    [scan_vuln]="nmap"
    [scan_stealth]="root nmap"
    [scan_udp]="root nmap"
    [scan_custom]="nmap"

    # ═══════════════════════════════════════════════════════════════════════════
    # CREDENTIALS
    # ═══════════════════════════════════════════════════════════════════════════
    [creds_hydra]="hydra"
    [creds_hashcat]="hashcat"
    [creds_john]="john"
    [creds_identify]=""
    [creds_wordlist]=""
    [creds_extract]=""

    # ═══════════════════════════════════════════════════════════════════════════
    # OSINT
    # ═══════════════════════════════════════════════════════════════════════════
    [osint_harvester]="theHarvester|theharvester"
    [osint_shodan]="curl"
    [osint_dorks]=""
    [osint_social]="curl"
    [osint_reputation]="whois|curl"
    [osint_domain]="whois dig curl"
    [osint_full]="whois dig curl"

    # ═══════════════════════════════════════════════════════════════════════════
    # TRAFFIC
    # ═══════════════════════════════════════════════════════════════════════════
    [traffic_tcpdump]="root tcpdump"
    [traffic_wireshark]="wireshark"
    [traffic_arpspoof]="root arpspoof"
    [traffic_dnsspoof]="root dnsspoof"
    [traffic_sniff]="root tcpdump"
    [traffic_pcap]="tcpdump|tshark"

    # ═══════════════════════════════════════════════════════════════════════════
    # EXPLOIT
    # ═══════════════════════════════════════════════════════════════════════════
    [exploit_msf]="msfconsole"
    [exploit_searchsploit]="searchsploit"
    [exploit_sqlmap]="sqlmap"
    [exploit_revshell]=""
    [exploit_payload]="msfvenom"
    [exploit_nikto]="nikto"

    # ═══════════════════════════════════════════════════════════════════════════
    # STRESS TESTING
    # ═══════════════════════════════════════════════════════════════════════════
    [stress_http]="root hping3|slowloris|curl"
    [stress_syn]="root hping3"
    [stress_udp]="root hping3"
    [stress_icmp]="root hping3|ping"
    [stress_conn]=""
    [stress_bandwidth]="iperf3"
)

# ═══════════════════════════════════════════════════════════════════════════════
# REQUIREMENT CHECKERS
# ═══════════════════════════════════════════════════════════════════════════════

# Check single requirement
_req_check() {
    local req="$1"
    
    case "$req" in
        root)           [[ $EUID -eq 0 ]] ;;
        interface)      [[ -n "${_CURRENT_IFACE:-}" ]] ;;
        monitor_mode)   [[ -n "${_MONITOR_IFACE:-}" ]] ;;
        dual_interface) [[ $(iw dev 2>/dev/null | grep -c Interface) -ge 2 ]] ;;
        vif)            _check_vif_support ;;
        wordlist)       [[ -f "${VOIDWAVE_WORDLIST:-/usr/share/wordlists/rockyou.txt}" ]] ;;
        capture_file)   [[ -n "${_CAPTURE_FILE:-}" && -f "${_CAPTURE_FILE:-}" ]] ;;
        hash_file)      [[ -n "${_HASH_FILE:-}" && -f "${_HASH_FILE:-}" ]] ;;
        handshake_file) [[ -n "${_HANDSHAKE_FILE:-}" && -f "${_HANDSHAKE_FILE:-}" ]] ;;
        *)              command -v "$req" &>/dev/null ;;
    esac
}

# Check requirement with OR support
_req_check_or() {
    local req="$1"
    if [[ "$req" == *"|"* ]]; then
        local IFS='|'
        for alt in $req; do
            _req_check "$alt" && return 0
        done
        return 1
    fi
    _req_check "$req"
}

# Check VIF support on current adapter
_check_vif_support() {
    local iface="${_CURRENT_IFACE:-}"
    [[ -z "$iface" ]] && return 1
    local phy
    phy=$(iw dev "$iface" info 2>/dev/null | awk '/wiphy/{print $2}')
    [[ -z "$phy" ]] && return 1
    iw phy "phy$phy" info 2>/dev/null | grep -q "AP/VLAN"
}

# ═══════════════════════════════════════════════════════════════════════════════
# PRE-FLIGHT CHECK
# ═══════════════════════════════════════════════════════════════════════════════

# Run pre-flight check for attack type
# Args: $1 = attack type
# Returns: 0 = ready, 1 = missing requirements
# Side effect: Prints status and offers auto-fix
preflight() {
    local attack="$1"
    local reqs="${ATTACK_REQUIREMENTS[$attack]:-}"
    
    [[ -z "$reqs" ]] && return 0  # No requirements defined
    
    local -a missing=()
    local -a satisfied=()
    
    # Check each requirement
    for req in $reqs; do
        if _req_check_or "$req"; then
            satisfied+=("$req")
        else
            missing+=("$req")
        fi
    done
    
    # All good?
    if [[ ${#missing[@]} -eq 0 ]]; then
        return 0
    fi
    
    # Show what's missing
    echo ""
    echo -e "    ${C_RED}━━━ MISSING REQUIREMENTS ━━━${C_RESET}"
    echo ""
    
    for req in "${missing[@]}"; do
        _show_requirement_status "$req" "missing"
    done
    
    echo ""
    
    # Offer auto-fix
    local fixable=0
    for req in "${missing[@]}"; do
        _can_autofix "$req" && ((fixable++))
    done
    
    if [[ $fixable -gt 0 ]]; then
        echo -e "    ${C_YELLOW}Can auto-fix $fixable requirement(s)${C_RESET}"
        echo ""
        if confirm "    Auto-fix now?"; then
            _do_autofix "${missing[@]}"
            # Re-check
            preflight "$attack"
            return $?
        fi
    fi
    
    return 1
}

# Show requirement status with description
_show_requirement_status() {
    local req="$1"
    local status="$2"
    
    local icon color
    if [[ "$status" == "ok" ]]; then
        icon="✓"; color="${C_GREEN}"
    else
        icon="✗"; color="${C_RED}"
    fi
    
    local desc
    case "$req" in
        root)           desc="Root privileges - run with sudo" ;;
        interface)      desc="Wireless interface selected" ;;
        monitor_mode)   desc="Monitor mode enabled" ;;
        dual_interface) desc="Two wireless adapters" ;;
        vif)            desc="Virtual Interface support" ;;
        wordlist)       desc="Wordlist file available" ;;
        capture_file)   desc="Capture file selected" ;;
        hash_file)      desc="Hash file selected" ;;
        handshake_file) desc="Handshake file captured" ;;
        reaver)         desc="Reaver - apt install reaver" ;;
        bully)          desc="Bully - apt install bully" ;;
        pixiewps)       desc="Pixiewps - apt install pixiewps" ;;
        wash)           desc="Wash - apt install reaver" ;;
        hcxdumptool)    desc="hcxdumptool - apt install hcxdumptool" ;;
        airodump-ng)    desc="airodump-ng - apt install aircrack-ng" ;;
        aireplay-ng)    desc="aireplay-ng - apt install aircrack-ng" ;;
        aircrack-ng)    desc="aircrack-ng - apt install aircrack-ng" ;;
        hashcat)        desc="Hashcat - apt install hashcat" ;;
        hostapd)        desc="hostapd - apt install hostapd" ;;
        hostapd-wpe)    desc="hostapd-wpe - build from source" ;;
        dnsmasq)        desc="dnsmasq - apt install dnsmasq" ;;
        lighttpd)       desc="lighttpd - apt install lighttpd" ;;
        mdk4)           desc="mdk4 - apt install mdk4" ;;
        *)              desc="$req" ;;
    esac
    
    echo -e "    ${color}${icon}${C_RESET} $desc"
}

# ═══════════════════════════════════════════════════════════════════════════════
# AUTO-FIX
# ═══════════════════════════════════════════════════════════════════════════════

_can_autofix() {
    local req="$1"
    case "$req" in
        interface|monitor_mode) return 0 ;;
        *) return 1 ;;
    esac
}

_do_autofix() {
    local -a reqs=("$@")

    for req in "${reqs[@]}"; do
        case "$req" in
            interface)
                # Use smart auto-detection if available
                if type -t auto_interface &>/dev/null; then
                    auto_interface
                else
                    echo -e "    ${C_CYAN:-}⟳ Auto-selecting interface...${C_RESET:-}"
                    local iface
                    iface=$(iw dev 2>/dev/null | awk '/Interface/{print $2; exit}')
                    if [[ -n "$iface" ]]; then
                        _CURRENT_IFACE="$iface"
                        echo -e "    ${C_GREEN:-}✓${C_RESET:-} Selected: $iface"
                    fi
                fi
                ;;
            monitor_mode)
                # Use smart auto-detection if available
                if type -t auto_monitor &>/dev/null; then
                    auto_monitor
                elif [[ -n "${_CURRENT_IFACE:-}" ]]; then
                    echo -e "    ${C_CYAN:-}⟳ Enabling monitor mode...${C_RESET:-}"
                    airmon-ng check kill &>/dev/null
                    if airmon-ng start "$_CURRENT_IFACE" &>/dev/null; then
                        sleep 1
                        _MONITOR_IFACE=$(ls /sys/class/net/ 2>/dev/null | grep -E "${_CURRENT_IFACE}mon|mon[0-9]" | head -1)
                        [[ -z "$_MONITOR_IFACE" ]] && _MONITOR_IFACE="${_CURRENT_IFACE}"
                        echo -e "    ${C_GREEN:-}✓${C_RESET:-} Monitor mode: $_MONITOR_IFACE"
                    fi
                fi
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# AUTO-PREPARE (No prompts - fully automatic)
# ═══════════════════════════════════════════════════════════════════════════════

# Automatically prepare everything needed for an attack
# This is the "just make it work" function
# Args: $1 = attack type
# Returns: 0 if ready, 1 if impossible to prepare
auto_preflight() {
    local attack="$1"

    # Use auto_prepare from auto.sh if available
    if type -t auto_prepare &>/dev/null; then
        case "$attack" in
            wps_*|wps)
                auto_prepare "wps"
                ;;
            pmkid|handshake|*capture*)
                auto_prepare "wireless"
                ;;
            deauth|amok|beacon*|dos)
                auto_prepare "deauth"
                ;;
            scan*|recon*)
                auto_prepare "scan"
                ;;
            exploit*|crack*|creds*)
                auto_prepare "network"
                ;;
            *)
                auto_prepare "full"
                ;;
        esac
        return $?
    fi

    # Fallback to regular preflight with auto-fix
    local reqs="${ATTACK_REQUIREMENTS[$attack]:-}"
    [[ -z "$reqs" ]] && return 0

    local -a missing=()

    for req in $reqs; do
        if ! _req_check_or "$req"; then
            missing+=("$req")
        fi
    done

    # Try to auto-fix what we can
    if [[ ${#missing[@]} -gt 0 ]]; then
        _do_autofix "${missing[@]}"
    fi

    # Re-check
    for req in $reqs; do
        _req_check_or "$req" || return 1
    done

    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# QUICK CHECKS
# ═══════════════════════════════════════════════════════════════════════════════

# Quick check - returns silently, for use in conditionals
require_root() { [[ $EUID -eq 0 ]]; }
require_interface() { [[ -n "${_CURRENT_IFACE:-}" ]]; }
require_monitor() { [[ -n "${_MONITOR_IFACE:-}" ]]; }

# Verbose check with message
ensure_root() {
    require_root && return 0
    echo -e "    ${C_RED}✗ Root required - run with sudo${C_RESET}"
    return 1
}

ensure_interface() {
    require_interface && return 0
    echo -e "    ${C_RED}✗ Select interface first (option 1)${C_RESET}"
    return 1
}

ensure_monitor() {
    require_monitor && return 0
    echo -e "    ${C_RED}✗ Enable monitor mode first (option 2)${C_RESET}"
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export -f preflight _req_check _req_check_or auto_preflight
export -f require_root require_interface require_monitor
export -f ensure_root ensure_interface ensure_monitor
