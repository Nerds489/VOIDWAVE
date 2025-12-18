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
# Wizard library: interactive guided workflows for common tasks
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_WIZARDS_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_WIZARDS_LOADED=1

# ═══════════════════════════════════════════════════════════════════════════════
# WIZARD HELPERS (only define if not already defined by ui.sh)
# ═══════════════════════════════════════════════════════════════════════════════

# Simple menu selector (ui.sh has a better version with non-interactive support)
if ! declare -F select_option &>/dev/null; then
    select_option() {
        local prompt="$1"
        shift
        local options=("$@")
        local choice

        echo -e "\n    ${C_CYAN:-}${prompt}:${C_RESET:-}"
        for i in "${!options[@]}"; do
            echo "    $((i+1))) ${options[$i]}"
        done

        while true; do
            read -rp "    Select [1-${#options[@]}]: " choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
                echo "${options[$((choice-1))]}"
                return 0
            fi
            echo "    Invalid selection"
        done
    }
fi

# Text input prompt (ui.sh has a better version with non-interactive support)
if ! declare -F prompt_input &>/dev/null; then
    prompt_input() {
        local prompt="$1"
        local default="${2:-}"
        local value

        if [[ -n "$default" ]]; then
            read -rp "    ${prompt} [${default}]: " value
            echo "${value:-$default}"
        else
            while true; do
                read -rp "    ${prompt}: " value
                [[ -n "$value" ]] && { echo "$value"; return 0; }
                echo "    Input required"
            done
        fi
    }
fi

# Press enter to continue
if ! declare -F press_enter &>/dev/null; then
    press_enter() {
        [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] && return 0
        read -rp "    Press Enter to continue..."
    }
fi

# ═══════════════════════════════════════════════════════════════════════════════
# FIRST RUN WIZARD
# ═══════════════════════════════════════════════════════════════════════════════

first_run_wizard() {
    # Skip in non-interactive mode or when not attached to a terminal
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] && return 0
    [[ ! -t 0 ]] && return 0

    clear_screen 2>/dev/null || clear
    show_banner "${VERSION:-}" 2>/dev/null || true
    draw_header "Welcome to VOIDWAVE" 2>/dev/null || echo -e "\n    === Welcome to VOIDWAVE ==="

    echo -e "\n    First-time setup wizard\n"

    # Step 1: Check privileges
    echo -e "    ${C_CYAN:-}[1/4]${C_RESET:-} Checking privileges..."
    if [[ $EUID -eq 0 ]]; then
        echo -e "    ${C_GREEN:-}✓${C_RESET:-} Running as root"
    else
        echo -e "    ${C_YELLOW:-}!${C_RESET:-} Not root — some features will be limited"
    fi

    # Step 2: Check essential tools
    echo -e "\n    ${C_CYAN:-}[2/4]${C_RESET:-} Checking essential tools..."
    local tools_missing=0
    for tool in nmap curl whois dig; do
        if command -v "$tool" &>/dev/null; then
            echo -e "    ${C_GREEN:-}✓${C_RESET:-} $tool"
        else
            echo -e "    ${C_RED:-}✗${C_RESET:-} $tool (not found)"
            ((tools_missing++)) || true
        fi
    done

    if [[ $tools_missing -gt 0 ]]; then
        echo -e "\n    ${C_YELLOW:-}!${C_RESET:-} $tools_missing tool(s) missing"
        echo "    Run 'voidwave-install' to install dependencies"
    fi

    # Step 3: Create directories
    echo -e "\n    ${C_CYAN:-}[3/4]${C_RESET:-} Creating directories..."
    local dirs=(
        "${VOIDWAVE_HOME:-$HOME/.voidwave}"
        "${CONFIG_DIR:-$HOME/.voidwave/config}"
        "${LOG_DIR:-$HOME/.voidwave/logs}"
        "${OUTPUT_DIR:-$HOME/.voidwave/output}"
        "${SESSION_DIR:-$HOME/.voidwave/sessions}"
    )
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir" 2>/dev/null || true
        echo -e "    ${C_GREEN:-}✓${C_RESET:-} ${dir/#$HOME/~}"
    done

    # Step 4: Mark complete
    echo -e "\n    ${C_CYAN:-}[4/4]${C_RESET:-} Finalizing..."
    local config_dir="${CONFIG_DIR:-$HOME/.voidwave/config}"
    touch "$config_dir/.wizard_complete" 2>/dev/null || true
    echo -e "    ${C_GREEN:-}✓${C_RESET:-} Setup complete"

    echo -e "\n    ${C_GREEN:-}VOIDWAVE is ready!${C_RESET:-}"
    echo -e "    Run 'voidwave --help' for usage\n"

    press_enter
}

# Check if first run needed
check_first_run() {
    # Skip in non-interactive mode or when not attached to a terminal
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] && return 0
    [[ ! -t 0 ]] && return 0
    local config_dir="${CONFIG_DIR:-$HOME/.voidwave/config}"
    [[ -f "$config_dir/.wizard_complete" ]] && return 0
    first_run_wizard
}

# ═══════════════════════════════════════════════════════════════════════════════
# SCAN WIZARD
# ═══════════════════════════════════════════════════════════════════════════════

scan_wizard() {
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] && {
        echo "Error: scan_wizard requires interactive mode"
        return 1
    }

    draw_header "Scan Wizard" 2>/dev/null || echo -e "\n    === Scan Wizard ==="

    # Step 1: Get target
    echo -e "\n    ${C_CYAN:-}Step 1: Target${C_RESET:-}"
    local target
    target=$(prompt_input "Enter target (IP, hostname, or CIDR)")

    # Validate target
    if declare -f validate_target &>/dev/null; then
        if ! validate_target "$target" 2>/dev/null; then
            echo -e "    ${C_RED:-}✗${C_RESET:-} Invalid target: $target"
            return 1
        fi
    fi
    echo -e "    ${C_GREEN:-}✓${C_RESET:-} Target: $target"

    # Step 2: Select scan type
    echo -e "\n    ${C_CYAN:-}Step 2: Scan Type${C_RESET:-}"
    local scan_type
    scan_type=$(select_option "Select scan type" "Quick" "Standard" "Full" "Stealth")

    local nmap_opts=""
    local scan_desc=""
    case "$scan_type" in
        Quick)
            nmap_opts="-T4 -F"
            scan_desc="Fast scan of top 100 ports"
            ;;
        Standard)
            nmap_opts="-sS -sV -T3"
            scan_desc="SYN scan with service detection"
            ;;
        Full)
            nmap_opts="-sS -sV -sC -O -p- -T3"
            scan_desc="Full port scan with OS and script detection"
            ;;
        Stealth)
            nmap_opts="-sS -T1 -f --data-length 24"
            scan_desc="Slow fragmented scan for IDS evasion"
            ;;
    esac
    echo -e "    ${C_GREEN:-}✓${C_RESET:-} $scan_type: $scan_desc"

    # Step 3: Output location
    echo -e "\n    ${C_CYAN:-}Step 3: Output${C_RESET:-}"
    local output_base="${OUTPUT_DIR:-$HOME/.voidwave/output}"
    local output_file="$output_base/scan_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$output_base" 2>/dev/null || true
    echo -e "    ${C_GREEN:-}✓${C_RESET:-} Output: $output_file.*"

    # Step 4: Confirm and execute
    echo -e "\n    ${C_CYAN:-}Step 4: Confirm${C_RESET:-}"
    echo -e "    Command: nmap $nmap_opts -oA \"$output_file\" $target"
    echo ""

    if ! confirm "Start scan?" "n"; then
        echo -e "    ${C_YELLOW:-}Cancelled${C_RESET:-}"
        return 0
    fi

    # Check nmap
    if ! command -v nmap &>/dev/null; then
        echo -e "    ${C_RED:-}✗${C_RESET:-} nmap not found"
        return 1
    fi

    # Start session before scan
    local sid=""
    if declare -f session_start &>/dev/null; then
        sid=$(session_start "scan")
        session_set "target" "$target"
        session_set "scan_type" "$scan_type"
        session_set "nmap_opts" "$nmap_opts"
        session_set "output_file" "$output_file"
        session_set "total" "1"
    fi

    # Execute
    echo -e "\n    ${C_CYAN:-}Scanning...${C_RESET:-}\n"

    local scan_status=0
    if [[ $EUID -eq 0 ]]; then
        # shellcheck disable=SC2086
        nmap $nmap_opts -oA "$output_file" "$target" || scan_status=$?
    else
        echo -e "    ${C_YELLOW:-}!${C_RESET:-} Not root — some scan types may fail"
        # shellcheck disable=SC2086
        nmap $nmap_opts -oA "$output_file" "$target" || scan_status=$?
    fi

    echo ""

    if [[ $scan_status -eq 0 ]]; then
        # Update session on success
        if [[ -n "$sid" ]] && declare -f session_set &>/dev/null; then
            session_set "progress" "1"
            session_end
        fi
        echo -e "    ${C_GREEN:-}✓${C_RESET:-} Scan complete"
        echo -e "    ${C_GREEN:-}✓${C_RESET:-} Results saved to:"
        for ext in nmap gnmap xml; do
            [[ -f "$output_file.$ext" ]] && echo "      - $output_file.$ext"
        done
    else
        # Mark session as failed
        if [[ -n "$sid" ]] && declare -f session_fail &>/dev/null; then
            session_fail "nmap exited with code $scan_status"
        fi
        echo -e "    ${C_RED:-}✗${C_RESET:-} Scan failed (exit code: $scan_status)"
    fi

    return $scan_status
}

# ═══════════════════════════════════════════════════════════════════════════════
# WIFI WIZARD
# ═══════════════════════════════════════════════════════════════════════════════

wifi_wizard() {
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] && {
        echo "Error: wifi_wizard requires interactive mode"
        return 1
    }

    # Require root
    if [[ $EUID -ne 0 ]]; then
        echo -e "    ${C_RED:-}✗${C_RESET:-} WiFi wizard requires root privileges"
        echo "    Run: sudo voidwave wizard wifi"
        return 1
    fi

    # Check required tools
    local missing_tools=0
    for tool in airmon-ng airodump-ng iw timeout; do
        if ! command -v "$tool" &>/dev/null; then
            echo -e "    ${C_RED:-}✗${C_RESET:-} $tool not found"
            ((missing_tools++)) || true
        fi
    done

    if [[ $missing_tools -gt 0 ]]; then
        echo -e "\n    Install missing tools:"
        echo "    - aircrack-ng suite: apt install aircrack-ng"
        echo "    - iw: apt install iw"
        echo "    - timeout: apt install coreutils"
        return 1
    fi

    draw_header "WiFi Assessment Wizard" 2>/dev/null || echo -e "\n    === WiFi Assessment Wizard ==="

    # Track if we enable monitor mode (for cleanup)
    local monitor_enabled_by_wizard=0
    local monitor_iface=""

    # Step 1: List wireless interfaces
    echo -e "\n    ${C_CYAN:-}Step 1: Select Interface${C_RESET:-}"

    local -a ifaces=()
    local line
    while IFS= read -r line; do
        [[ -n "$line" ]] && ifaces+=("$line")
    done < <(iw dev 2>/dev/null | awk '/Interface/{print $2}')

    if [[ ${#ifaces[@]} -eq 0 ]]; then
        echo -e "    ${C_RED:-}✗${C_RESET:-} No wireless interfaces found"
        return 1
    fi

    local iface
    if [[ ${#ifaces[@]} -eq 1 ]]; then
        iface="${ifaces[0]}"
        echo -e "    ${C_GREEN:-}✓${C_RESET:-} Found interface: $iface"
    else
        iface=$(select_option "Select interface" "${ifaces[@]}")
    fi

    # Step 2: Check/enable monitor mode
    echo -e "\n    ${C_CYAN:-}Step 2: Monitor Mode${C_RESET:-}"

    local mode
    mode=$(iw dev "$iface" info 2>/dev/null | awk '/type/{print $2}')

    if [[ "$mode" == "monitor" ]]; then
        echo -e "    ${C_GREEN:-}✓${C_RESET:-} Already in monitor mode"
    else
        echo -e "    ${C_YELLOW:-}!${C_RESET:-} Interface is in managed mode"

        if confirm "Enable monitor mode?" "n"; then
            echo -e "    Enabling monitor mode..."

            # Kill interfering processes
            airmon-ng check kill &>/dev/null || true

            # Enable monitor mode
            if airmon-ng start "$iface" &>/dev/null; then
                # Check for new interface name (usually wlan0mon)
                local new_iface="${iface}mon"
                if iw dev "$new_iface" info &>/dev/null; then
                    monitor_iface="$new_iface"
                    iface="$new_iface"
                else
                    monitor_iface="$iface"
                fi
                monitor_enabled_by_wizard=1
                echo -e "    ${C_GREEN:-}✓${C_RESET:-} Monitor mode enabled: $iface"
            else
                echo -e "    ${C_RED:-}✗${C_RESET:-} Failed to enable monitor mode"
                return 1
            fi
        else
            echo -e "    ${C_YELLOW:-}!${C_RESET:-} Continuing in managed mode (limited functionality)"
        fi
    fi

    # Step 3: Select action
    echo -e "\n    ${C_CYAN:-}Step 3: Select Action${C_RESET:-}"
    local action
    action=$(select_option "What do you want to do?" "Scan networks" "Capture handshake" "Exit")

    case "$action" in
        "Scan networks")
            echo -e "\n    ${C_CYAN:-}Scanning for networks (30 seconds)...${C_RESET:-}"
            echo "    Press Ctrl+C to stop early"
            echo ""
            timeout 30 airodump-ng "$iface" 2>/dev/null || true
            ;;
        "Capture handshake")
            local bssid channel output_cap

            echo -e "\n    ${C_CYAN:-}Handshake Capture Setup${C_RESET:-}"
            bssid=$(prompt_input "Target BSSID (e.g., AA:BB:CC:DD:EE:FF)")
            channel=$(prompt_input "Channel (1-14)")

            output_cap="${OUTPUT_DIR:-$HOME/.voidwave/output}/capture_$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$(dirname "$output_cap")" 2>/dev/null || true

            echo -e "\n    ${C_CYAN:-}Capturing on channel $channel...${C_RESET:-}"
            echo "    Output: $output_cap"
            echo "    Press Ctrl+C when handshake captured"
            echo ""

            airodump-ng -c "$channel" --bssid "$bssid" -w "$output_cap" "$iface" 2>/dev/null || true

            [[ -f "${output_cap}-01.cap" ]] && echo -e "\n    ${C_GREEN:-}✓${C_RESET:-} Capture saved: ${output_cap}-01.cap"
            ;;
        "Exit")
            ;;
    esac

    # Step 4: Cleanup (only if we enabled monitor mode)
    if [[ $monitor_enabled_by_wizard -eq 1 ]]; then
        echo -e "\n    ${C_CYAN:-}Step 4: Cleanup${C_RESET:-}"
        if confirm "Disable monitor mode and restore networking?" "n"; then
            airmon-ng stop "$monitor_iface" &>/dev/null || true
            systemctl restart NetworkManager &>/dev/null || service network-manager restart &>/dev/null || true
            echo -e "    ${C_GREEN:-}✓${C_RESET:-} Monitor mode disabled"
        fi
    fi

    echo -e "\n    ${C_GREEN:-}WiFi wizard complete${C_RESET:-}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# PENETRATION TEST WIZARD
# ═══════════════════════════════════════════════════════════════════════════════

wizard_pentest() {
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] && return 1

    clear_screen 2>/dev/null || clear
    show_banner "${VERSION:-}"

    echo -e "    ${C_CYAN:-}+======================================================+${C_RESET:-}"
    echo -e "    ${C_CYAN:-}|          PENETRATION TEST WIZARD                     |${C_RESET:-}"
    echo -e "    ${C_CYAN:-}+======================================================+${C_RESET:-}"
    echo ""
    echo "    This wizard will guide you through a structured pentest:"
    echo ""
    echo "    Phase 1: Reconnaissance (passive information gathering)"
    echo "    Phase 2: Scanning (active network discovery)"
    echo "    Phase 3: Enumeration (service identification)"
    echo "    Phase 4: Vulnerability Assessment"
    echo "    Phase 5: Exploitation (optional)"
    echo "    Phase 6: Reporting"
    echo ""

    confirm "Start penetration test wizard?" || return 0

    # Collect target information
    echo ""
    echo -e "    ${C_BOLD:-}Target Information${C_RESET:-}"
    echo ""

    local target scope engagement_type

    read -rp "    Target (domain or IP range): " target
    [[ -z "$target" ]] && return 1

    echo ""
    echo "    Engagement type:"
    echo "    1) Black box (no prior knowledge)"
    echo "    2) Gray box (limited knowledge)"
    echo "    3) White box (full knowledge)"
    echo ""
    read -rp "    Select [1-3]: " engagement_type

    echo ""
    echo "    Scope restrictions (comma-separated IPs/ranges to exclude):"
    read -rp "    Exclusions [none]: " scope

    # Create output directory
    local outdir="${VOIDWAVE_OUTPUT_DIR:-$HOME/.voidwave/output}/pentest_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$outdir"/{recon,scan,enum,vuln,exploit,report}

    echo ""
    echo -e "    ${C_GREEN:-}Output directory: $outdir${C_RESET:-}"
    echo ""

    # Phase 1: Reconnaissance
    echo -e "    ${C_CYAN:-}======================================================${C_RESET:-}"
    echo -e "    ${C_BOLD:-}PHASE 1: Reconnaissance${C_RESET:-}"
    echo -e "    ${C_CYAN:-}======================================================${C_RESET:-}"
    echo ""

    if confirm "Run passive reconnaissance?"; then
        echo ""
        echo -e "    ${C_GRAY:-}[1/4] WHOIS lookup...${C_RESET:-}"
        whois "$target" > "$outdir/recon/whois.txt" 2>/dev/null

        echo -e "    ${C_GRAY:-}[2/4] DNS enumeration...${C_RESET:-}"
        dig ANY "$target" > "$outdir/recon/dns.txt" 2>/dev/null
        host "$target" >> "$outdir/recon/dns.txt" 2>/dev/null

        echo -e "    ${C_GRAY:-}[3/4] Subdomain discovery...${C_RESET:-}"
        if command -v subfinder &>/dev/null; then
            subfinder -d "$target" -silent > "$outdir/recon/subdomains.txt" 2>/dev/null
        fi

        echo -e "    ${C_GRAY:-}[4/4] Email harvesting...${C_RESET:-}"
        if command -v theHarvester &>/dev/null || command -v theharvester &>/dev/null; then
            local hcmd="theHarvester"
            command -v theharvester &>/dev/null && hcmd="theharvester"
            $hcmd -d "$target" -b google,bing -l 100 > "$outdir/recon/emails.txt" 2>/dev/null
        fi

        echo -e "    ${C_GREEN:-}Recon complete${C_RESET:-}"
    fi

    wait_for_keypress 2>/dev/null || press_enter

    # Phase 2: Scanning
    echo ""
    echo -e "    ${C_CYAN:-}======================================================${C_RESET:-}"
    echo -e "    ${C_BOLD:-}PHASE 2: Scanning${C_RESET:-}"
    echo -e "    ${C_CYAN:-}======================================================${C_RESET:-}"
    echo ""

    if confirm "Run network scanning?"; then
        echo ""

        if ! command -v nmap &>/dev/null; then
            echo -e "    ${C_RED:-}nmap not found, skipping${C_RESET:-}"
        else
            echo -e "    ${C_GRAY:-}[1/3] Host discovery...${C_RESET:-}"
            nmap -sn "$target" -oN "$outdir/scan/hosts.txt" 2>/dev/null

            echo -e "    ${C_GRAY:-}[2/3] Port scan (top 1000)...${C_RESET:-}"
            nmap -T4 -F "$target" -oN "$outdir/scan/ports_quick.txt" -oX "$outdir/scan/ports_quick.xml" 2>/dev/null

            if confirm "    Run full port scan (slower)?"; then
                echo -e "    ${C_GRAY:-}[3/3] Full port scan...${C_RESET:-}"
                nmap -T3 -p- "$target" -oN "$outdir/scan/ports_full.txt" -oX "$outdir/scan/ports_full.xml" 2>/dev/null
            fi

            echo -e "    ${C_GREEN:-}Scanning complete${C_RESET:-}"
        fi
    fi

    wait_for_keypress 2>/dev/null || press_enter

    # Phase 3: Enumeration
    echo ""
    echo -e "    ${C_CYAN:-}======================================================${C_RESET:-}"
    echo -e "    ${C_BOLD:-}PHASE 3: Enumeration${C_RESET:-}"
    echo -e "    ${C_CYAN:-}======================================================${C_RESET:-}"
    echo ""

    if confirm "Run service enumeration?"; then
        echo ""

        if command -v nmap &>/dev/null; then
            echo -e "    ${C_GRAY:-}[1/2] Service detection...${C_RESET:-}"
            nmap -sV -T4 "$target" -oN "$outdir/enum/services.txt" 2>/dev/null

            echo -e "    ${C_GRAY:-}[2/2] OS detection...${C_RESET:-}"
            if [[ $EUID -eq 0 ]]; then
                nmap -O "$target" -oN "$outdir/enum/os.txt" 2>/dev/null
            else
                echo -e "    ${C_YELLOW:-}OS detection requires root, skipping${C_RESET:-}"
            fi

            echo -e "    ${C_GREEN:-}Enumeration complete${C_RESET:-}"
        fi
    fi

    wait_for_keypress 2>/dev/null || press_enter

    # Phase 4: Vulnerability Assessment
    echo ""
    echo -e "    ${C_CYAN:-}======================================================${C_RESET:-}"
    echo -e "    ${C_BOLD:-}PHASE 4: Vulnerability Assessment${C_RESET:-}"
    echo -e "    ${C_CYAN:-}======================================================${C_RESET:-}"
    echo ""

    if confirm "Run vulnerability scanning?"; then
        echo ""

        if command -v nmap &>/dev/null; then
            echo -e "    ${C_GRAY:-}[1/2] NSE vuln scripts...${C_RESET:-}"
            nmap --script=vuln "$target" -oN "$outdir/vuln/nmap_vuln.txt" 2>/dev/null
        fi

        if command -v nikto &>/dev/null; then
            echo -e "    ${C_GRAY:-}[2/2] Web vulnerability scan...${C_RESET:-}"
            nikto -h "$target" -output "$outdir/vuln/nikto.txt" 2>/dev/null
        fi

        echo -e "    ${C_GREEN:-}Vulnerability assessment complete${C_RESET:-}"
    fi

    wait_for_keypress 2>/dev/null || press_enter

    # Phase 5: Exploitation (optional)
    echo ""
    echo -e "    ${C_CYAN:-}======================================================${C_RESET:-}"
    echo -e "    ${C_BOLD:-}PHASE 5: Exploitation${C_RESET:-}"
    echo -e "    ${C_CYAN:-}======================================================${C_RESET:-}"
    echo ""

    echo -e "    ${C_YELLOW:-}Exploitation is manual and requires careful judgment.${C_RESET:-}"
    echo ""
    echo "    Recommended next steps:"
    echo "    - Review vulnerability scan results"
    echo "    - Use searchsploit to find exploits"
    echo "    - Test exploits in isolated environment first"
    echo "    - Document all exploitation attempts"
    echo ""

    if confirm "Launch Metasploit?"; then
        if command -v msfconsole &>/dev/null; then
            echo ""
            echo -e "    ${C_CYAN:-}Launching Metasploit...${C_RESET:-}"
            msfconsole 2>&1 || true
        else
            echo -e "    ${C_RED:-}Metasploit not found${C_RESET:-}"
        fi
    fi

    wait_for_keypress 2>/dev/null || press_enter

    # Phase 6: Reporting
    echo ""
    echo -e "    ${C_CYAN:-}======================================================${C_RESET:-}"
    echo -e "    ${C_BOLD:-}PHASE 6: Report Generation${C_RESET:-}"
    echo -e "    ${C_CYAN:-}======================================================${C_RESET:-}"
    echo ""

    # Generate summary report
    local report="$outdir/report/pentest_summary.txt"

    {
        echo "VOIDWAVE Penetration Test Report"
        echo "=================================="
        echo ""
        echo "Target: $target"
        echo "Date: $(date)"
        echo "Type: $(case "$engagement_type" in 1) echo "Black Box";; 2) echo "Gray Box";; 3) echo "White Box";; esac)"
        echo "Exclusions: ${scope:-none}"
        echo ""
        echo "Files Generated:"
        echo "----------------"
        find "$outdir" -type f -name "*.txt" | while read -r f; do
            echo "  - ${f#$outdir/}"
        done
        echo ""
        echo "Summary:"
        echo "--------"

        if [[ -f "$outdir/recon/subdomains.txt" ]]; then
            local sub_count
            sub_count=$(wc -l < "$outdir/recon/subdomains.txt" 2>/dev/null || echo 0)
            echo "  Subdomains found: $sub_count"
        fi

        if [[ -f "$outdir/scan/hosts.txt" ]]; then
            local host_count
            host_count=$(grep -c "Host is up" "$outdir/scan/hosts.txt" 2>/dev/null || echo 0)
            echo "  Live hosts: $host_count"
        fi

        if [[ -f "$outdir/scan/ports_quick.txt" ]]; then
            local port_count
            port_count=$(grep -cE "^[0-9]+/tcp.*open" "$outdir/scan/ports_quick.txt" 2>/dev/null || echo 0)
            echo "  Open ports: $port_count"
        fi

    } > "$report"

    echo -e "    ${C_GREEN:-}Report generated: $report${C_RESET:-}"
    echo ""
    echo -e "    ${C_BOLD:-}Output Directory:${C_RESET:-}"
    ls -la "$outdir" | sed 's/^/    /'
    echo ""

    wait_for_keypress 2>/dev/null || press_enter

    echo ""
    echo -e "    ${C_GREEN:-}Penetration test wizard complete!${C_RESET:-}"
    echo -e "    ${C_GRAY:-}All results saved to: $outdir${C_RESET:-}"
    echo ""

    wait_for_keypress 2>/dev/null || press_enter
}

# ═══════════════════════════════════════════════════════════════════════════════
# RECONNAISSANCE WIZARD
# ═══════════════════════════════════════════════════════════════════════════════

wizard_recon() {
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] && return 1

    clear_screen 2>/dev/null || clear
    show_banner "${VERSION:-}"

    echo -e "    ${C_CYAN:-}+======================================================+${C_RESET:-}"
    echo -e "    ${C_CYAN:-}|          RECONNAISSANCE WIZARD                       |${C_RESET:-}"
    echo -e "    ${C_CYAN:-}+======================================================+${C_RESET:-}"
    echo ""
    echo "    This wizard performs comprehensive passive reconnaissance:"
    echo ""
    echo "    - WHOIS information"
    echo "    - DNS records (A, MX, NS, TXT)"
    echo "    - Subdomain enumeration"
    echo "    - Email harvesting"
    echo "    - Technology detection"
    echo "    - SSL certificate analysis"
    echo ""

    local target
    read -rp "    Target domain: " target
    [[ -z "$target" ]] && return 1

    # Validate domain format
    if ! is_valid_domain "$target" 2>/dev/null; then
        if [[ ! "$target" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+$ ]]; then
            echo -e "    ${C_YELLOW:-}Warning: '$target' may not be a valid domain${C_RESET:-}"
            confirm "Continue anyway?" || return 1
        fi
    fi

    # Create output directory
    local outdir="${VOIDWAVE_OUTPUT_DIR:-$HOME/.voidwave/output}/recon_${target}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$outdir"

    echo ""
    echo -e "    ${C_GREEN:-}Output: $outdir${C_RESET:-}"
    echo ""

    local total=7 current=0

    # 1. WHOIS
    ((current++)) || true
    echo -e "    ${C_GRAY:-}[$current/$total] WHOIS lookup...${C_RESET:-}"
    if command -v whois &>/dev/null; then
        whois "$target" > "$outdir/whois.txt" 2>/dev/null
        local registrar
        registrar=$(grep -i "registrar:" "$outdir/whois.txt" 2>/dev/null | head -1 | cut -d: -f2- | xargs)
        [[ -n "$registrar" ]] && echo -e "      Registrar: $registrar"
    else
        echo -e "      ${C_YELLOW:-}whois not installed${C_RESET:-}"
    fi

    # 2. DNS Records
    ((current++)) || true
    echo -e "    ${C_GRAY:-}[$current/$total] DNS enumeration...${C_RESET:-}"
    {
        echo "=== A Records ==="
        dig +short A "$target" 2>/dev/null
        echo ""
        echo "=== MX Records ==="
        dig +short MX "$target" 2>/dev/null
        echo ""
        echo "=== NS Records ==="
        dig +short NS "$target" 2>/dev/null
        echo ""
        echo "=== TXT Records ==="
        dig +short TXT "$target" 2>/dev/null
        echo ""
        echo "=== SOA Record ==="
        dig +short SOA "$target" 2>/dev/null
    } > "$outdir/dns.txt" 2>/dev/null

    local a_record
    a_record=$(dig +short A "$target" 2>/dev/null | head -1)
    [[ -n "$a_record" ]] && echo -e "      A Record: $a_record"

    # 3. Subdomains
    ((current++)) || true
    echo -e "    ${C_GRAY:-}[$current/$total] Subdomain discovery...${C_RESET:-}"
    if command -v subfinder &>/dev/null; then
        subfinder -d "$target" -silent > "$outdir/subdomains.txt" 2>/dev/null
        local sub_count
        sub_count=$(wc -l < "$outdir/subdomains.txt" 2>/dev/null || echo 0)
        echo -e "      Found: $sub_count subdomains"
    elif command -v amass &>/dev/null; then
        timeout 120 amass enum -passive -d "$target" > "$outdir/subdomains.txt" 2>/dev/null
        local sub_count
        sub_count=$(wc -l < "$outdir/subdomains.txt" 2>/dev/null || echo 0)
        echo -e "      Found: $sub_count subdomains"
    else
        echo -e "      ${C_YELLOW:-}No subdomain tools installed (subfinder/amass)${C_RESET:-}"
    fi

    # 4. Email Harvesting
    ((current++)) || true
    echo -e "    ${C_GRAY:-}[$current/$total] Email harvesting...${C_RESET:-}"
    local hcmd=""
    command -v theHarvester &>/dev/null && hcmd="theHarvester"
    command -v theharvester &>/dev/null && hcmd="theharvester"

    if [[ -n "$hcmd" ]]; then
        $hcmd -d "$target" -b google,bing -l 100 > "$outdir/emails_raw.txt" 2>/dev/null
        grep -oE "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" "$outdir/emails_raw.txt" 2>/dev/null | sort -u > "$outdir/emails.txt"
        local email_count
        email_count=$(wc -l < "$outdir/emails.txt" 2>/dev/null || echo 0)
        echo -e "      Found: $email_count emails"
    else
        echo -e "      ${C_YELLOW:-}theHarvester not installed${C_RESET:-}"
    fi

    # 5. Technology Detection
    ((current++)) || true
    echo -e "    ${C_GRAY:-}[$current/$total] Technology detection...${C_RESET:-}"
    if command -v whatweb &>/dev/null; then
        whatweb -q "https://$target" > "$outdir/technology.txt" 2>/dev/null
        echo -e "      Technologies identified"
    else
        # Fallback: HTTP headers
        curl -sI "https://$target" > "$outdir/headers.txt" 2>/dev/null
        local server
        server=$(grep -i "^server:" "$outdir/headers.txt" 2>/dev/null | cut -d: -f2- | xargs)
        [[ -n "$server" ]] && echo -e "      Server: $server"
    fi

    # 6. SSL Certificate
    ((current++)) || true
    echo -e "    ${C_GRAY:-}[$current/$total] SSL certificate analysis...${C_RESET:-}"
    if command -v openssl &>/dev/null; then
        echo | openssl s_client -connect "$target:443" -servername "$target" 2>/dev/null | openssl x509 -noout -text > "$outdir/ssl_cert.txt" 2>/dev/null

        local issuer expiry
        issuer=$(openssl s_client -connect "$target:443" -servername "$target" 2>/dev/null </dev/null | openssl x509 -noout -issuer 2>/dev/null | sed 's/issuer=//')
        expiry=$(openssl s_client -connect "$target:443" -servername "$target" 2>/dev/null </dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

        [[ -n "$issuer" ]] && echo -e "      Issuer: $issuer"
        [[ -n "$expiry" ]] && echo -e "      Expires: $expiry"
    fi

    # 7. Generate Summary
    ((current++)) || true
    echo -e "    ${C_GRAY:-}[$current/$total] Generating summary...${C_RESET:-}"

    {
        echo "VOIDWAVE Reconnaissance Report"
        echo "================================"
        echo ""
        echo "Target: $target"
        echo "Date: $(date)"
        echo ""
        echo "Findings Summary"
        echo "----------------"
        echo ""

        if [[ -f "$outdir/whois.txt" ]]; then
            echo "WHOIS:"
            grep -iE "^(registrar|creation|expir|registrant org)" "$outdir/whois.txt" 2>/dev/null | head -5 | sed 's/^/  /'
            echo ""
        fi

        if [[ -f "$outdir/dns.txt" ]]; then
            echo "DNS:"
            echo "  A: $(dig +short A "$target" 2>/dev/null | head -1)"
            echo "  MX: $(dig +short MX "$target" 2>/dev/null | head -1)"
            echo ""
        fi

        if [[ -f "$outdir/subdomains.txt" ]]; then
            local sub_count
            sub_count=$(wc -l < "$outdir/subdomains.txt")
            echo "Subdomains: $sub_count found"
            head -10 "$outdir/subdomains.txt" | sed 's/^/  /'
            [[ $sub_count -gt 10 ]] && echo "  ... and $((sub_count - 10)) more"
            echo ""
        fi

        if [[ -f "$outdir/emails.txt" ]]; then
            local email_count
            email_count=$(wc -l < "$outdir/emails.txt")
            echo "Emails: $email_count found"
            head -5 "$outdir/emails.txt" | sed 's/^/  /'
            echo ""
        fi

    } > "$outdir/summary.txt"

    echo ""
    echo -e "    ${C_GREEN:-}Reconnaissance complete!${C_RESET:-}"
    echo ""
    echo -e "    ${C_BOLD:-}Files generated:${C_RESET:-}"
    ls "$outdir"/*.txt 2>/dev/null | while read -r f; do
        local size
        size=$(du -h "$f" 2>/dev/null | cut -f1)
        echo "      $(basename "$f") ($size)"
    done
    echo ""
    echo -e "    ${C_GRAY:-}Output directory: $outdir${C_RESET:-}"
    echo ""

    if confirm "View summary?"; then
        echo ""
        cat "$outdir/summary.txt" | sed 's/^/    /'
    fi

    wait_for_keypress 2>/dev/null || press_enter
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export -f select_option prompt_input press_enter
export -f first_run_wizard check_first_run
export -f scan_wizard wifi_wizard
export -f wizard_pentest wizard_recon
