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
# Detection library: system, distro, package manager, tools, network interfaces
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_DETECTION_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_DETECTION_LOADED=1

# Source core library
source "${BASH_SOURCE%/*}/core.sh"

#═══════════════════════════════════════════════════════════════════════════════
# WIRELESS DETECTION (single source of truth)
#═══════════════════════════════════════════════════════════════════════════════

# Check if interface is wireless (supports monitor mode)
# Args: $1 = interface name
# Returns: 0 if wireless, 1 if not
is_wireless_interface() {
    local iface="${1:-}"
    [[ -z "$iface" ]] && return 1

    # sysfs (most reliable if present)
    [[ -d "/sys/class/net/$iface/wireless" ]] && return 0

    # iw (modern)
    if command -v iw &>/dev/null; then
        iw dev "$iface" info &>/dev/null 2>&1 && return 0
    fi

    # /proc/net/wireless (older, but common; note leading whitespace)
    if [[ -r /proc/net/wireless ]]; then
        grep -q "^[[:space:]]*${iface}:" /proc/net/wireless 2>/dev/null && return 0
    fi

    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# GLOBAL VARIABLES (set by detect_system)
#═══════════════════════════════════════════════════════════════════════════════

declare -g DISTRO=""
declare -g DISTRO_FAMILY=""
declare -g PKG_MANAGER=""
declare -g PKG_INSTALL=""
declare -g PKG_UPDATE=""
declare -g PKG_SEARCH=""
declare -g PKG_REMOVE=""

#═══════════════════════════════════════════════════════════════════════════════
# DISTRIBUTION DETECTION
#═══════════════════════════════════════════════════════════════════════════════

# Detect Linux distribution
# NOTE: We parse instead of source to avoid VERSION variable conflicts with /etc/os-release
# Returns: distro name (debian, fedora, arch, etc.) or "unknown"
detect_distro() {
    local distro=""

    if [[ -f /etc/os-release ]]; then
        # Parse instead of source to avoid variable conflicts (VERSION, etc.)
        # Use sed instead of grep -oP for Alpine/BusyBox compatibility
        distro=$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"')
    elif [[ -f /etc/lsb-release ]]; then
        distro=$(sed -n 's/^DISTRIB_ID=//p' /etc/lsb-release | tr -d '"' | tr '[:upper:]' '[:lower:]')
    elif [[ -f /etc/debian_version ]]; then
        distro="debian"
    elif [[ -f /etc/fedora-release ]]; then
        distro="fedora"
    elif [[ -f /etc/centos-release ]]; then
        distro="centos"
    elif [[ -f /etc/arch-release ]]; then
        distro="arch"
    elif [[ -f /etc/gentoo-release ]]; then
        distro="gentoo"
    elif [[ -f /etc/alpine-release ]]; then
        distro="alpine"
    fi

    echo "${distro:-unknown}"
}

# Detect distro family
# Args: $1 = distro name
# Returns: family name (debian, redhat, arch, etc.)
detect_distro_family() {
    local distro="${1:-$(detect_distro)}"

    case "$distro" in
        debian|ubuntu|kali|parrot|linuxmint|pop|elementary|zorin|mx)
            echo "debian"
            ;;
        fedora|rhel|centos|rocky|alma|oracle|amazon)
            echo "redhat"
            ;;
        arch|manjaro|endeavouros|blackarch|arcolinux|garuda)
            echo "arch"
            ;;
        opensuse*|suse|sles)
            echo "suse"
            ;;
        alpine)
            echo "alpine"
            ;;
        gentoo|funtoo)
            echo "gentoo"
            ;;
        void)
            echo "void"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

#═══════════════════════════════════════════════════════════════════════════════
# PACKAGE MANAGER DETECTION
#═══════════════════════════════════════════════════════════════════════════════

# Detect and return package manager name
# Returns: apt, dnf, pacman, etc. or "unknown"
detect_package_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    elif command -v apk &>/dev/null; then
        echo "apk"
    elif command -v emerge &>/dev/null; then
        echo "emerge"
    elif command -v xbps-install &>/dev/null; then
        echo "xbps"
    else
        echo "unknown"
    fi
}

# Setup package manager variables based on detected manager
# Sets: PKG_MANAGER, PKG_INSTALL, PKG_UPDATE, PKG_SEARCH, PKG_REMOVE
setup_package_manager() {
    PKG_MANAGER=$(detect_package_manager)

    case "$PKG_MANAGER" in
        apt)
            PKG_INSTALL="apt-get install -y"
            PKG_UPDATE="apt-get update"
            PKG_SEARCH="apt-cache search"
            PKG_REMOVE="apt-get remove -y"
            ;;
        dnf)
            PKG_INSTALL="dnf install -y"
            PKG_UPDATE="dnf check-update"
            PKG_SEARCH="dnf search"
            PKG_REMOVE="dnf remove -y"
            ;;
        yum)
            PKG_INSTALL="yum install -y"
            PKG_UPDATE="yum check-update"
            PKG_SEARCH="yum search"
            PKG_REMOVE="yum remove -y"
            ;;
        pacman)
            PKG_INSTALL="pacman -S --noconfirm"
            PKG_UPDATE="pacman -Sy"
            PKG_SEARCH="pacman -Ss"
            PKG_REMOVE="pacman -R --noconfirm"
            ;;
        zypper)
            PKG_INSTALL="zypper install -y"
            PKG_UPDATE="zypper refresh"
            PKG_SEARCH="zypper search"
            PKG_REMOVE="zypper remove -y"
            ;;
        apk)
            PKG_INSTALL="apk add"
            PKG_UPDATE="apk update"
            PKG_SEARCH="apk search"
            PKG_REMOVE="apk del"
            ;;
        emerge)
            PKG_INSTALL="emerge"
            PKG_UPDATE="emerge --sync"
            PKG_SEARCH="emerge --search"
            PKG_REMOVE="emerge --unmerge"
            ;;
        xbps)
            PKG_INSTALL="xbps-install -y"
            PKG_UPDATE="xbps-install -S"
            PKG_SEARCH="xbps-query -Rs"
            PKG_REMOVE="xbps-remove -y"
            ;;
        *)
            PKG_INSTALL=""
            PKG_UPDATE=""
            PKG_SEARCH=""
            PKG_REMOVE=""
            return 1
            ;;
    esac

    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# TOOL REGISTRY
#═══════════════════════════════════════════════════════════════════════════════

# Tool to package name mapping
# Maps logical tool name to OS package name for installation
declare -gA TOOL_PACKAGES=(
    [nmap]="nmap"
    [masscan]="masscan"
    [nikto]="nikto"
    [hydra]="hydra"
    [john]="john"
    [hashcat]="hashcat"
    [aircrack-ng]="aircrack-ng"
    [airodump-ng]="aircrack-ng"
    [aireplay-ng]="aircrack-ng"
    [hping3]="hping3"
    [tcpdump]="tcpdump"
    [tshark]="tshark"
    [whois]="whois"
    [dig]="dnsutils"
    [curl]="curl"
    [jq]="jq"
    [gobuster]="gobuster"
    [netcat]="netcat"
    [nc]="netcat"
    [sqlmap]="sqlmap"
    [wfuzz]="wfuzz"
    [dirb]="dirb"
    [sslscan]="sslscan"
    [enum4linux]="enum4linux"
    [nbtscan]="nbtscan"
    [arp-scan]="arp-scan"
    [iw]="iw"
    [iwconfig]="wireless-tools"
    [macchanger]="macchanger"
    [reaver]="reaver"
    [bully]="bully"
    [wifite]="wifite"
    [mdk4]="mdk4"
    [hostapd]="hostapd"
    [dnsmasq]="dnsmasq"
)

# Tool categories for organized status display
# Maps category name to space-separated list of tools
declare -gA TOOL_CATEGORIES=(
    [recon]="nmap masscan whois dig arp-scan nbtscan"
    [wireless]="aircrack-ng airodump-ng aireplay-ng iw iwconfig macchanger reaver bully wifite mdk4"
    [scanning]="nmap nikto gobuster dirb sslscan"
    [credentials]="hydra john hashcat"
    [traffic]="tcpdump tshark"
    [stress]="hping3 mdk4"
    [web]="nikto gobuster sqlmap wfuzz dirb curl"
    [enumeration]="enum4linux nbtscan whois"
    [network]="hostapd dnsmasq netcat"
    [utilities]="curl jq"
)

#═══════════════════════════════════════════════════════════════════════════════
# DISTRO-AWARE PACKAGE NAME MAPPING
#═══════════════════════════════════════════════════════════════════════════════

# Get the correct package name for the current distro family
# Args: $1 = tool name (binary name)
# Returns: package name to install for this distro
# Uses DISTRO_FAMILY (set by detect_system) to determine correct package
tool_package_name() {
    local tool="$1"
    local family="${DISTRO_FAMILY:-unknown}"

    # Handle empty input
    [[ -z "$tool" ]] && { echo "$tool"; return 1; }

    # Suite tools - all distros map to parent package
    case "$tool" in
        airodump-ng|aireplay-ng|airmon-ng|airbase-ng|airdecap-ng|airdecloak-ng|airserv-ng|airtun-ng|besside-ng|easside-ng|packetforge-ng|tkiptun-ng|wesside-ng)
            echo "aircrack-ng"
            return 0
            ;;
    esac

    # Distro-family specific mappings
    case "$tool" in
        # DNS utilities
        dig|nslookup|host)
            case "$family" in
                debian)  echo "dnsutils" ;;
                redhat)  echo "bind-utils" ;;
                arch)    echo "bind" ;;
                suse)    echo "bind-utils" ;;
                alpine)  echo "bind-tools" ;;
                *)       echo "dnsutils" ;;
            esac
            return 0
            ;;

        # Wireshark/tshark
        tshark)
            case "$family" in
                debian)  echo "tshark" ;;
                redhat)  echo "wireshark-cli" ;;
                arch)    echo "wireshark-cli" ;;
                suse)    echo "wireshark" ;;
                alpine)  echo "tshark" ;;
                *)       echo "tshark" ;;
            esac
            return 0
            ;;

        wireshark)
            case "$family" in
                arch)    echo "wireshark-qt" ;;
                *)       echo "wireshark" ;;
            esac
            return 0
            ;;

        # Netcat variants
        netcat|nc)
            case "$family" in
                debian)  echo "netcat-openbsd" ;;
                redhat)  echo "nmap-ncat" ;;
                arch)    echo "openbsd-netcat" ;;
                suse)    echo "netcat-openbsd" ;;
                alpine)  echo "netcat-openbsd" ;;
                *)       echo "netcat" ;;
            esac
            return 0
            ;;

        # Python pip
        pip3|pip)
            case "$family" in
                debian)  echo "python3-pip" ;;
                redhat)  echo "python3-pip" ;;
                arch)    echo "python-pip" ;;
                suse)    echo "python3-pip" ;;
                alpine)  echo "py3-pip" ;;
                *)       echo "python3-pip" ;;
            esac
            return 0
            ;;

        # Wireless tools
        iwconfig|iwlist)
            echo "wireless-tools"
            return 0
            ;;

        # John the Ripper
        john)
            case "$family" in
                debian)  echo "john" ;;
                redhat)  echo "john" ;;
                arch)    echo "john" ;;
                *)       echo "john" ;;
            esac
            return 0
            ;;

        # Whois
        whois)
            case "$family" in
                alpine)  echo "whois" ;;
                *)       echo "whois" ;;
            esac
            return 0
            ;;

        # Traceroute
        traceroute)
            case "$family" in
                debian)  echo "traceroute" ;;
                redhat)  echo "traceroute" ;;
                arch)    echo "traceroute" ;;
                alpine)  echo "busybox-extras" ;;
                *)       echo "traceroute" ;;
            esac
            return 0
            ;;
    esac

    # Check if tool is in TOOL_PACKAGES registry
    if [[ -n "${TOOL_PACKAGES[$tool]:-}" ]]; then
        echo "${TOOL_PACKAGES[$tool]}"
        return 0
    fi

    # Default: package name same as tool name
    echo "$tool"
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# TOOL DETECTION
#═══════════════════════════════════════════════════════════════════════════════

# Comprehensive list of binary directories to search
# Includes all common locations where tools might be installed
readonly TOOL_SEARCH_PATHS=(
    "/usr/bin"
    "/usr/local/bin"
    "/usr/sbin"
    "/usr/local/sbin"
    "/sbin"
    "/bin"
    "/opt/bin"
    "$HOME/.local/bin"
    "$HOME/go/bin"
)

# Check if a tool/command is installed
# Args: $1 = tool name, $2 = silent flag (1 = no log output)
# Returns: 0 if installed, 1 if not
# Falls back to common binary directories if command -v fails
check_tool() {
    local tool="$1"
    local silent="${2:-0}"
    local tool_path=""

    # Reject empty tool name
    [[ -z "$tool" ]] && return 1

    # First try command -v (checks PATH)
    if tool_path=$(command -v "$tool" 2>/dev/null); then
        [[ "$silent" != "1" ]] && log_success "$tool: $tool_path"
        return 0
    fi

    # Fallback: check comprehensive list of binary directories
    for dir in "${TOOL_SEARCH_PATHS[@]}"; do
        if [[ -x "${dir}/${tool}" ]]; then
            tool_path="${dir}/${tool}"
            [[ "$silent" != "1" ]] && log_success "$tool: $tool_path"
            return 0
        fi
    done

    # Not found
    [[ "$silent" != "1" ]] && log_error "$tool: NOT FOUND"
    return 1
}

# Check if tool is installed with optional binary name
# Args: $1 = tool name, $2 = binary name (optional, defaults to tool name)
# Returns: 0 if installed, 1 if not
check_tool_installed() {
    local tool="$1"
    local binary="${2:-$tool}"
    check_tool "$binary" 1
}

# Get path to a tool
# Args: $1 = tool name
# Returns: path to tool or empty string, exit code 0 if found, 1 if not
get_tool_path() {
    local tool="$1"
    local tool_path=""

    # Reject empty tool name
    [[ -z "$tool" ]] && { echo ""; return 1; }

    # Try command -v first
    if tool_path=$(command -v "$tool" 2>/dev/null); then
        echo "$tool_path"
        return 0
    fi

    # Fallback to comprehensive list of directories
    for dir in "${TOOL_SEARCH_PATHS[@]}"; do
        if [[ -x "${dir}/${tool}" ]]; then
            echo "${dir}/${tool}"
            return 0
        fi
    done

    echo ""
    return 1
}

# Get tool version (best-effort version detection)
# Args: $1 = tool name
# Returns: version string or empty; exits 1 if tool missing or version not parseable
check_tool_version() {
    local tool="$1"
    local version_output=""
    local version=""

    # Check if tool exists first
    if ! check_tool "$tool" 1; then
        return 1
    fi

    # Try common version flags in order
    local version_flags=("--version" "-version" "-v" "-V")
    for flag in "${version_flags[@]}"; do
        # Capture first line of output, suppress errors
        version_output=$("$tool" "$flag" 2>/dev/null | head -n1) || continue
        if [[ -n "$version_output" ]]; then
            # Extract version-looking token (e.g., 1.2.3, 7.94, etc.)
            if [[ "$version_output" =~ ([0-9]+\.[0-9]+(\.[0-9]+)?([._-][a-zA-Z0-9]+)?) ]]; then
                version="${BASH_REMATCH[1]}"
                echo "$version"
                return 0
            fi
        fi
    done

    # Could not parse version
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# TOOL INSTALLATION
#═══════════════════════════════════════════════════════════════════════════════

# Auto-install a missing tool (interactive mode only)
# Args: $1 = tool name
# Returns: 0 on success, 1 on failure or declined
auto_install_tool() {
    local tool="$1"
    local pkg=""

    [[ -z "$tool" ]] && return 1

    # Already installed - nothing to do
    if check_tool "$tool" 1; then
        return 0
    fi

    # Resolve package name using distro-aware mapping
    pkg=$(tool_package_name "$tool")

    log_warning "$tool is not installed"

    # Non-interactive mode: skip auto-install
    if [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] || [[ ! -t 0 ]]; then
        log_debug "Non-interactive mode: skipping auto-install for $tool"
        return 1
    fi

    # Check if package manager is available
    if [[ -z "${PKG_INSTALL:-}" ]]; then
        log_error "Package manager not configured. Run detect_system first."
        return 1
    fi

    # Prompt user for installation
    if ! confirm "Install $tool (package: $pkg)?" "n"; then
        log_info "User declined installation of $tool"
        return 1
    fi

    # Attempt installation
    log_info "Installing $pkg via package manager..."
    # shellcheck disable=SC2086  # PKG_INSTALL intentionally uses word splitting
    if run_with_sudo $PKG_INSTALL "$pkg"; then
        # Verify installation succeeded
        if check_tool "$tool" 1; then
            log_success "$tool installed successfully"
            log_audit "TOOL_INSTALL" "$tool" "success"
            return 0
        else
            log_error "Package installed but $tool binary not found"
            log_audit "TOOL_INSTALL" "$tool" "binary_not_found"
            return 1
        fi
    else
        log_error "Failed to install $tool"
        log_audit "TOOL_INSTALL" "$tool" "failed"
        return 1
    fi
}

# Require multiple tools, auto-installing if needed
# Args: list of tool names
# Returns: 0 if all tools available, 1 if any missing
require_tools() {
    local missing=()
    local tool=""

    # Check each tool
    for tool in "$@"; do
        if ! check_tool "$tool" 1; then
            missing+=("$tool")
        fi
    done

    # All tools present
    if [[ ${#missing[@]} -eq 0 ]]; then
        return 0
    fi

    # Report missing tools
    log_error "Missing tools: ${missing[*]}"

    # Attempt auto-install for each missing tool
    local failed=0
    for tool in "${missing[@]}"; do
        if ! auto_install_tool "$tool"; then
            ((failed++)) || true
        fi
    done

    # Check if all tools now available
    if [[ $failed -gt 0 ]]; then
        return 1
    fi

    # Final verification
    for tool in "${missing[@]}"; do
        if ! check_tool "$tool" 1; then
            log_error "Tool $tool still not available after install attempt"
            return 1
        fi
    done

    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# TOOL STATUS DISPLAY
#═══════════════════════════════════════════════════════════════════════════════

# Source UI library for draw_header (if not already loaded)
# Note: This is safe because ui.sh has multiple-source protection
source "${BASH_SOURCE%/*}/ui.sh" 2>/dev/null || true

# Show categorized tool status dashboard
# Displays all tools by category with installed/missing indicators
# Shows progress bar in interactive mode while scanning tools
show_tool_status() {
    local category=""
    local tools=""
    local tool=""
    local installed_count=0
    local missing_count=0
    local current_tool=0
    local total_tools=0
    local interactive=1

    # Check if interactive mode
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] || [[ ! -t 1 ]] && interactive=0

    # Count total tools first (for progress bar)
    for category in "${!TOOL_CATEGORIES[@]}"; do
        for tool in ${TOOL_CATEGORIES[$category]}; do
            ((++total_tools)) || true
        done
    done

    # Show progress bar while scanning (interactive mode only)
    if (( interactive && total_tools > 0 )); then
        declare -f show_progress_bar &>/dev/null && show_progress_bar 0 "$total_tools" "Scanning tools" 30
    fi

    # Collect results in arrays to display after progress completes
    declare -A category_results

    # Iterate through categories and check tools
    for category in "${!TOOL_CATEGORIES[@]}"; do
        tools="${TOOL_CATEGORIES[$category]}"
        local results=""

        for tool in $tools; do
            ((++current_tool)) || true

            # Update progress bar (interactive mode only)
            if (( interactive && total_tools > 0 )); then
                declare -f show_progress_bar &>/dev/null && show_progress_bar "$current_tool" "$total_tools" "Scanning tools" 30
            fi

            if check_tool "$tool" 1; then
                results+="${C_GREEN}✓${C_RESET} $tool\n"
                ((++installed_count)) || true
            else
                results+="${C_RED}✗${C_RESET} $tool\n"
                ((++missing_count)) || true
            fi
        done

        category_results["$category"]="$results"
    done

    # Draw header
    if declare -f draw_header &>/dev/null; then
        draw_header "Tool Status"
    else
        echo
        echo -e "    ${C_BOLD}${C_CYAN}Tool Status${C_RESET}"
        echo -e "    ${C_CYAN}════════════════════════════════════════════════════════════════════════${C_RESET}"
    fi

    # Display results by category
    for category in "${!TOOL_CATEGORIES[@]}"; do
        echo
        echo -e "    ${C_BOLD}${C_YELLOW}${category^^}${C_RESET}"
        echo -ne "    ${category_results[$category]}"
    done

    # Summary
    echo
    echo -e "    ${C_CYAN}────────────────────────────────────────────────────────────────────────${C_RESET}"
    echo -e "    ${C_GREEN}Installed:${C_RESET} $installed_count  ${C_RED}Missing:${C_RESET} $missing_count"
    echo
}

# Verify all registered tools are available (quick background check)
# Uses spinner for visual feedback in interactive mode
# Returns: 0 if all tools available, 1 if any missing
# Sets: _VERIFY_INSTALLED, _VERIFY_MISSING (space-separated tool names)
verify_tool_availability() {
    local interactive=1
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] || [[ ! -t 1 ]] && interactive=0

    # Create secure temp files (avoid predictable /tmp/.nr_* patterns)
    local tmp_installed tmp_missing
    tmp_installed=$(mktemp) || { log_error "Failed to create temp file"; return 1; }
    tmp_missing=$(mktemp) || { rm -f "$tmp_installed"; log_error "Failed to create temp file"; return 1; }

    # Inner function to check all tools (runs in background with spinner)
    # Uses tmp_installed and tmp_missing from parent scope
    _do_verify_tools() {
        local installed_list=""
        local missing_list=""
        local tool=""

        for tool in "${!TOOL_PACKAGES[@]}"; do
            if check_tool "$tool" 1; then
                installed_list+="$tool "
            else
                missing_list+="$tool "
            fi
        done

        # Store results in temp files (background process can't set parent vars)
        echo "${installed_list% }" > "$tmp_installed"
        echo "${missing_list% }" > "$tmp_missing"
    }

    # Run with spinner in interactive mode, plain in non-interactive
    if (( interactive )) && declare -f run_with_spinner &>/dev/null; then
        run_with_spinner "Verifying tool availability" _do_verify_tools
    else
        _do_verify_tools
    fi

    # Read results from temp files
    _VERIFY_INSTALLED=""
    _VERIFY_MISSING=""
    [[ -f "$tmp_installed" ]] && _VERIFY_INSTALLED=$(< "$tmp_installed")
    [[ -f "$tmp_missing" ]] && _VERIFY_MISSING=$(< "$tmp_missing")

    # Cleanup temp files
    rm -f "$tmp_installed" "$tmp_missing" 2>/dev/null

    # Count results
    local installed_count=0
    local missing_count=0
    [[ -n "$_VERIFY_INSTALLED" ]] && installed_count=$(echo "$_VERIFY_INSTALLED" | wc -w)
    [[ -n "$_VERIFY_MISSING" ]] && missing_count=$(echo "$_VERIFY_MISSING" | wc -w)

    log_info "Tool verification complete: $installed_count installed, $missing_count missing"

    # Return status based on missing tools
    [[ $missing_count -eq 0 ]]
}

#═══════════════════════════════════════════════════════════════════════════════
# NETWORK INTERFACE DETECTION
#═══════════════════════════════════════════════════════════════════════════════

# Check if network interface exists
# Args: $1 = interface name
# Returns: 0 if exists, 1 if not
check_interface() {
    local iface="$1"
    [[ -z "$iface" ]] && return 1
    [[ -d "/sys/class/net/$iface" ]]
}

# NOTE: is_wireless_interface is defined at the top of this file (line ~40)

# List all wireless interfaces
# Returns: space-separated list of wireless interface names
list_wireless_interfaces() {
    local interfaces=()

    for iface in /sys/class/net/*; do
        iface=$(basename "$iface")
        if [[ -d "/sys/class/net/$iface/wireless" ]]; then
            interfaces+=("$iface")
        fi
    done

    echo "${interfaces[*]}"
}

# Alias for compatibility
get_wireless_interfaces() {
    list_wireless_interfaces
}

# Get the default/primary network interface
# Returns: interface name or empty string
get_default_interface() {
    local iface=""

    # Method 1: Parse default route
    if command -v ip &>/dev/null; then
        iface=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -n1)
    fi

    # Method 2: Fallback to route command
    if [[ -z "$iface" ]] && command -v route &>/dev/null; then
        iface=$(route -n 2>/dev/null | awk '/^0.0.0.0/ {print $8}' | head -n1)
    fi

    # Method 3: Find first active interface
    if [[ -z "$iface" ]]; then
        for i in /sys/class/net/*; do
            local name
            name=$(basename "$i")
            [[ "$name" == "lo" ]] && continue
            if [[ "$(cat "/sys/class/net/$name/operstate" 2>/dev/null)" == "up" ]]; then
                iface="$name"
                break
            fi
        done
    fi

    echo "$iface"
}

# Get interface state (up/down/unknown)
# Args: $1 = interface name
# Returns: up, down, or unknown
get_interface_state() {
    local iface="$1"
    [[ -z "$iface" ]] && echo "unknown" && return

    if [[ -f "/sys/class/net/$iface/operstate" ]]; then
        cat "/sys/class/net/$iface/operstate" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Get interface MAC address
# Args: $1 = interface name
# Returns: MAC address or empty string
get_interface_mac() {
    local iface="$1"
    [[ -z "$iface" ]] && return

    if [[ -f "/sys/class/net/$iface/address" ]]; then
        cat "/sys/class/net/$iface/address" 2>/dev/null
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# SYSTEM DETECTION (MAIN FUNCTION)
#═══════════════════════════════════════════════════════════════════════════════

# Detect system and setup all variables
# Call this on startup to initialize detection
detect_system() {
    DISTRO=$(detect_distro)
    DISTRO_FAMILY=$(detect_distro_family "$DISTRO")
    setup_package_manager

    log_debug "System detected: $DISTRO ($DISTRO_FAMILY) with $PKG_MANAGER"
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORT FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

# Distribution detection
export -f detect_distro detect_distro_family

# Package manager
export -f detect_package_manager setup_package_manager

# Tool detection
export -f check_tool check_tool_installed get_tool_path check_tool_version

# Package name mapping (distro-aware)
export -f tool_package_name

# Tool installation
export -f auto_install_tool require_tools

# Tool status
export -f show_tool_status verify_tool_availability

# Network interfaces
export -f check_interface is_wireless_interface
export -f list_wireless_interfaces get_wireless_interfaces
export -f get_default_interface get_interface_state get_interface_mac

# System detection
export -f detect_system

# Export variables
export DISTRO DISTRO_FAMILY
export PKG_MANAGER PKG_INSTALL PKG_UPDATE PKG_SEARCH PKG_REMOVE
