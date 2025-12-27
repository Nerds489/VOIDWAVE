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
# Status Menu: tool availability, system info, installation helper
# ═══════════════════════════════════════════════════════════════════════════════

[[ -n "${_VOIDWAVE_STATUS_MENU_LOADED:-}" ]] && return 0
declare -r _VOIDWAVE_STATUS_MENU_LOADED=1

# Tool definitions: name|category|package
declare -a _TOOLS=(
    "nmap|Scanning|nmap"
    "masscan|Scanning|masscan"
    "nikto|Scanning|nikto"
    "aircrack-ng|Wireless|aircrack-ng"
    "airmon-ng|Wireless|aircrack-ng"
    "airodump-ng|Wireless|aircrack-ng"
    "reaver|Wireless|reaver"
    "wifite|Wireless|wifite"
    "msfconsole|Exploitation|metasploit-framework"
    "searchsploit|Exploitation|exploitdb"
    "sqlmap|Exploitation|sqlmap"
    "hydra|Credentials|hydra"
    "hashcat|Credentials|hashcat"
    "john|Credentials|john"
    "tcpdump|Traffic|tcpdump"
    "wireshark|Traffic|wireshark"
    "tshark|Traffic|tshark"
    "arpspoof|Traffic|dsniff"
    "theHarvester|OSINT|theharvester"
    "whois|OSINT|whois"
    "dig|OSINT|dnsutils"
    "subfinder|OSINT|subfinder"
    "hping3|Stress|hping3"
    "slowloris|Stress|slowloris"
    "iperf3|Stress|iperf3"
    "curl|Utility|curl"
    "wget|Utility|wget"
    "git|Utility|git"
    "jq|Utility|jq"
    "openssl|Utility|openssl"
)

show_status_menu() {
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] && return 1

    while true; do
        clear_screen 2>/dev/null || clear
        show_banner "${VERSION:-}"

        echo -e "    ${C_BOLD:-}Tool Status${C_RESET:-}"
        echo ""
        echo "    1) Full Status Check"
        echo "    2) Quick Status (installed only)"
        echo "    3) Check by Category"
        echo "    4) Install Missing Tools"
        echo "    5) System Info"
        echo "    0) Back"
        echo ""

        local choice
        echo -en "    ${C_PURPLE:-}▶${C_RESET:-} Select [0-5]: "
        read -r choice
        choice="${choice//[[:space:]]/}"

        case "$choice" in
            1) _status_full ;;
            2) _status_quick ;;
            3) _status_category ;;
            4) _status_install ;;
            5) _status_system ;;
            0) return 0 ;;
            "") continue ;;
            *) echo -e "    ${C_RED:-}[!] Invalid option: '$choice'${C_RESET:-}"; sleep 1 ;;
        esac
    done
}

_get_tool_version() {
    local tool="$1"
    local version=""

    case "$tool" in
        nmap) version=$(nmap --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+') ;;
        hydra) version=$(hydra -h 2>/dev/null | head -1 | grep -oE 'v[0-9.]+' | tr -d 'v') ;;
        hashcat) version=$(hashcat --version 2>/dev/null | grep -oE '[0-9]+\.[0-9.]+') ;;
        john) version=$(john --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9.]+') ;;
        sqlmap) version=$(sqlmap --version 2>/dev/null | grep -oE '[0-9]+\.[0-9.]+') ;;
        aircrack-ng) version=$(aircrack-ng --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+') ;;
        msfconsole) version=$(msfconsole -v 2>/dev/null | grep -oE '[0-9]+\.[0-9.]+' | head -1) ;;
        curl) version=$(curl --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9.]+' | head -1) ;;
        wireshark) version=$(wireshark --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9.]+') ;;
        tcpdump) version=$(tcpdump --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9.]+') ;;
        *) version=$(command -v "$tool" &>/dev/null && echo "installed" || echo "") ;;
    esac

    echo "${version:-unknown}"
}

_status_full() {
    echo ""
    echo -e "    ${C_CYAN:-}VOIDWAVE Tool Status${C_RESET:-}"
    echo ""

    printf "    %-18s %-10s %-12s %-15s\n" "Tool" "Status" "Version" "Category"
    printf "    %s\n" "$(printf '─%.0s' {1..58})"

    local installed=0 missing=0

    for entry in "${_TOOLS[@]}"; do
        IFS='|' read -r tool category package <<< "$entry"

        local status version color

        if command -v "$tool" &>/dev/null; then
            status="+"
            color="${C_GREEN:-}"
            version=$(_get_tool_version "$tool")
            ((installed++)) || true
        else
            status="x"
            color="${C_RED:-}"
            version="-"
            ((missing++)) || true
        fi

        printf "    ${color}%-18s %-10s${C_RESET:-} %-12s %-15s\n" "$tool" "$status" "$version" "$category"
    done

    echo ""
    printf "    %s\n" "$(printf '─%.0s' {1..58})"
    echo -e "    ${C_GREEN:-}Installed: $installed${C_RESET:-}  ${C_RED:-}Missing: $missing${C_RESET:-}  Total: ${#_TOOLS[@]}"
    echo ""

    wait_for_keypress
}

_status_quick() {
    echo ""
    echo -e "    ${C_CYAN:-}Installed Tools${C_RESET:-}"
    echo ""

    local count=0
    local current_cat=""

    for entry in "${_TOOLS[@]}"; do
        IFS='|' read -r tool category package <<< "$entry"

        if command -v "$tool" &>/dev/null; then
            if [[ "$category" != "$current_cat" ]]; then
                [[ -n "$current_cat" ]] && echo ""
                echo -e "    ${C_BOLD:-}$category:${C_RESET:-}"
                current_cat="$category"
            fi
            echo "      + $tool"
            ((count++)) || true
        fi
    done

    echo ""
    echo -e "    ${C_GREEN:-}Total: $count tools installed${C_RESET:-}"
    echo ""

    wait_for_keypress
}

_status_category() {
    echo ""
    echo "    1) Scanning"
    echo "    2) Wireless"
    echo "    3) Exploitation"
    echo "    4) Credentials"
    echo "    5) Traffic"
    echo "    6) OSINT"
    echo "    7) Stress"
    echo "    8) Utility"
    echo ""

    local choice
    read -rp "    Category [1-8]: " choice

    local category
    case "$choice" in
        1) category="Scanning" ;;
        2) category="Wireless" ;;
        3) category="Exploitation" ;;
        4) category="Credentials" ;;
        5) category="Traffic" ;;
        6) category="OSINT" ;;
        7) category="Stress" ;;
        8) category="Utility" ;;
        *) return ;;
    esac

    echo ""
    echo -e "    ${C_CYAN:-}$category Tools${C_RESET:-}"
    echo ""

    printf "    %-18s %-10s %-12s %-20s\n" "Tool" "Status" "Version" "Package"
    printf "    %s\n" "$(printf '─%.0s' {1..62})"

    for entry in "${_TOOLS[@]}"; do
        IFS='|' read -r tool cat package <<< "$entry"

        [[ "$cat" != "$category" ]] && continue

        local status version color

        if command -v "$tool" &>/dev/null; then
            status="+"
            color="${C_GREEN:-}"
            version=$(_get_tool_version "$tool")
        else
            status="x"
            color="${C_RED:-}"
            version="-"
        fi

        printf "    ${color}%-18s %-10s${C_RESET:-} %-12s %-20s\n" "$tool" "$status" "$version" "$package"
    done

    echo ""

    wait_for_keypress
}

_status_install() {
    echo ""

    if [[ $EUID -ne 0 ]]; then
        echo -e "    ${C_RED:-}Installing tools requires root${C_RESET:-}"
        wait_for_keypress
        return 1
    fi

    # Find missing tools
    local -a missing_tools=()
    local -a missing_packages=()

    for entry in "${_TOOLS[@]}"; do
        IFS='|' read -r tool category package <<< "$entry"

        if ! command -v "$tool" &>/dev/null; then
            # Avoid duplicate packages
            local found=0
            for pkg in "${missing_packages[@]}"; do
                [[ "$pkg" == "$package" ]] && found=1 && break
            done

            if [[ $found -eq 0 ]]; then
                missing_tools+=("$tool")
                missing_packages+=("$package")
            fi
        fi
    done

    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        echo -e "    ${C_GREEN:-}All tools installed!${C_RESET:-}"
        wait_for_keypress
        return 0
    fi

    echo -e "    ${C_CYAN:-}Missing Packages:${C_RESET:-}"
    echo ""
    for ((i=0; i<${#missing_packages[@]}; i++)); do
        echo "    - ${missing_packages[$i]}"
    done
    echo ""

    echo "    1) Install all missing"
    echo "    2) Select packages"
    echo "    0) Cancel"
    echo ""

    local choice
    read -rp "    Select [0-2]: " choice

    case "$choice" in
        1)
            echo ""
            echo -e "    ${C_CYAN:-}Installing packages...${C_RESET:-}"
            echo ""

            # Detect package manager
            local pm=""
            if command -v apt-get &>/dev/null; then
                pm="apt-get install -y"
                apt-get update -qq
            elif command -v dnf &>/dev/null; then
                pm="dnf install -y"
            elif command -v pacman &>/dev/null; then
                pm="pacman -S --noconfirm"
            else
                echo -e "    ${C_RED:-}Unknown package manager${C_RESET:-}"
                wait_for_keypress
                return 1
            fi

            for pkg in "${missing_packages[@]}"; do
                echo -e "    Installing: $pkg"
                $pm "$pkg" 2>&1 | tail -3 | sed 's/^/      /'
            done

            echo ""
            echo -e "    ${C_GREEN:-}Installation complete${C_RESET:-}"
            ;;
        2)
            echo ""
            echo "    Enter package numbers (space-separated):"
            for ((i=0; i<${#missing_packages[@]}; i++)); do
                echo "    $((i+1))) ${missing_packages[$i]}"
            done
            echo ""

            local selections
            read -rp "    Select: " selections

            local pm=""
            command -v apt-get &>/dev/null && pm="apt-get install -y"
            command -v dnf &>/dev/null && pm="dnf install -y"
            command -v pacman &>/dev/null && pm="pacman -S --noconfirm"

            for num in $selections; do
                if [[ "$num" =~ ^[0-9]+$ ]] && ((num >= 1 && num <= ${#missing_packages[@]})); then
                    local pkg="${missing_packages[$((num-1))]}"
                    echo -e "    Installing: $pkg"
                    $pm "$pkg" 2>&1 | tail -3 | sed 's/^/      /'
                fi
            done
            ;;
    esac

    wait_for_keypress
}

_status_system() {
    echo ""
    echo -e "    ${C_CYAN:-}System Information${C_RESET:-}"
    echo ""

    echo -e "    ${C_BOLD:-}OS:${C_RESET:-}"
    if [[ -f /etc/os-release ]]; then
        local os_name os_id
        os_name=$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release | tr -d '"')
        os_id=$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"')
        echo "      Name: ${os_name:-unknown}"
        echo "      ID: ${os_id:-unknown}"
    fi
    echo "      Kernel: $(uname -r)"
    echo "      Arch: $(uname -m)"

    echo ""
    echo -e "    ${C_BOLD:-}Resources:${C_RESET:-}"
    echo "      CPU: $(nproc) cores"
    echo "      RAM: $(free -h 2>/dev/null | awk '/^Mem:/{print $2}' || echo 'unknown')"
    echo "      Disk: $(df -h / 2>/dev/null | awk 'NR==2{print $4}' || echo 'unknown') free"

    echo ""
    echo -e "    ${C_BOLD:-}Network:${C_RESET:-}"
    local ifaces
    ifaces=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -v lo | head -5 | tr '\n' ' ')
    echo "      Interfaces: $ifaces"

    local default_ip
    default_ip=$(get_local_ip 2>/dev/null || ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    echo "      Local IP: ${default_ip:-unknown}"

    local gateway
    gateway=$(get_default_gateway 2>/dev/null || ip route 2>/dev/null | awk '/default/{print $3; exit}')
    echo "      Gateway: ${gateway:-unknown}"

    echo ""
    echo -e "    ${C_BOLD:-}VOIDWAVE:${C_RESET:-}"
    echo "      Version: ${VERSION:-unknown}"
    echo "      Root: ${VOIDWAVE_ROOT:-unknown}"
    echo "      Home: ${VOIDWAVE_HOME:-$HOME/.voidwave}"

    echo ""

    wait_for_keypress
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

export -f show_status_menu _get_tool_version
export -f _status_full _status_quick _status_category
export -f _status_install _status_system
