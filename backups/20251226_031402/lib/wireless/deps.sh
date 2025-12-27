#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# Wireless Dependencies: tool detection, installation, and availability checks
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_WIRELESS_DEPS_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_WIRELESS_DEPS_LOADED=1

# Source core if not loaded
if ! declare -F log_info &>/dev/null; then
    source "${BASH_SOURCE%/*}/../core.sh"
fi

#═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCY CATEGORIES
#═══════════════════════════════════════════════════════════════════════════════

# Essential tools (required for basic operations)
# Format: "package:binary1,binary2,..."
declare -ga DEPS_ESSENTIAL=(
    "aircrack-ng:airmon-ng,airodump-ng,aireplay-ng,aircrack-ng"
    "iw:iw"
    "wireless-tools:iwconfig"
    "net-tools:ifconfig"
    "iproute2:ip"
    "gawk:awk"
    "procps:pkill"
)

# WPS attack tools
declare -ga DEPS_WPS=(
    "reaver:reaver,wash"
    "bully:bully"
    "pixiewps:pixiewps"
)

# PMKID capture tools
declare -ga DEPS_PMKID=(
    "hcxdumptool:hcxdumptool"
    "hcxtools:hcxpcapngtool,hcxhashtool"
)

# DoS attack tools
declare -ga DEPS_DOS=(
    "mdk3:mdk3"
    "mdk4:mdk4"
)

# Evil Twin tools
declare -ga DEPS_EVIL_TWIN=(
    "hostapd:hostapd"
    "dnsmasq:dnsmasq"
    "lighttpd:lighttpd"
    "iptables:iptables"
    "nftables:nft"
    "isc-dhcp-server:dhcpd"
)

# Password cracking tools
declare -ga DEPS_CRACKING=(
    "hashcat:hashcat"
    "john:john"
    "crunch:crunch"
)

# Enterprise attack tools
declare -ga DEPS_ENTERPRISE=(
    "hostapd-wpe:hostapd-wpe"
    "openssl:openssl"
    "asleap:asleap"
    "freeradius:freeradius"
)

# Handshake validation tools
declare -ga DEPS_VALIDATION=(
    "tshark:tshark"
    "cowpatty:cowpatty"
    "pyrit:pyrit"
)

# MITM tools
declare -ga DEPS_MITM=(
    "bettercap:bettercap"
    "ettercap:ettercap"
    "sslstrip:sslstrip"
)

# Optional utilities
declare -ga DEPS_OPTIONAL=(
    "macchanger:macchanger"
    "rfkill:rfkill"
    "xterm:xterm"
    "tmux:tmux"
    "screen:screen"
    "wifite:wifite"
    "beef-xss:beef"
)

#═══════════════════════════════════════════════════════════════════════════════
# PACKAGE MANAGER DETECTION
#═══════════════════════════════════════════════════════════════════════════════

# Detect package manager
# Returns: apt, dnf, pacman, or empty
deps_get_package_manager() {
    if command -v apt &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    else
        echo ""
    fi
}

# Get install command for package manager
# Args: $1 = package manager, $2 = package name
deps_get_install_cmd() {
    local pm="$1"
    local pkg="$2"

    case "$pm" in
        apt)
            echo "sudo apt install -y $pkg"
            ;;
        dnf|yum)
            echo "sudo dnf install -y $pkg"
            ;;
        pacman)
            echo "sudo pacman -S --noconfirm $pkg"
            ;;
        zypper)
            echo "sudo zypper install -y $pkg"
            ;;
        *)
            echo "# Install $pkg using your package manager"
            ;;
    esac
}

#═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCY CHECKING
#═══════════════════════════════════════════════════════════════════════════════

# Check if a binary exists
# Args: $1 = binary name
# Returns: 0 if exists, 1 if not
deps_check_binary() {
    local binary="$1"
    command -v "$binary" &>/dev/null
}

# Check a dependency entry
# Args: $1 = entry (format: "package:binary1,binary2,...")
# Returns: 0 if all binaries exist, 1 if any missing
deps_check_entry() {
    local entry="$1"
    local package="${entry%%:*}"
    local binaries="${entry#*:}"

    IFS=',' read -ra bins <<< "$binaries"
    for bin in "${bins[@]}"; do
        if ! deps_check_binary "$bin"; then
            return 1
        fi
    done

    return 0
}

# Check a category of dependencies
# Args: $1 = category (essential, wps, pmkid, dos, evil_twin, cracking, enterprise, validation, mitm, optional)
# Returns: 0 if all present, 1 if any missing
# Outputs: missing dependencies to stdout
deps_check_category() {
    local category="$1"
    local missing=()
    local deps_array

    # Get the right array
    case "$category" in
        essential)   deps_array=("${DEPS_ESSENTIAL[@]}") ;;
        wps)         deps_array=("${DEPS_WPS[@]}") ;;
        pmkid)       deps_array=("${DEPS_PMKID[@]}") ;;
        dos)         deps_array=("${DEPS_DOS[@]}") ;;
        evil_twin)   deps_array=("${DEPS_EVIL_TWIN[@]}") ;;
        cracking)    deps_array=("${DEPS_CRACKING[@]}") ;;
        enterprise)  deps_array=("${DEPS_ENTERPRISE[@]}") ;;
        validation)  deps_array=("${DEPS_VALIDATION[@]}") ;;
        mitm)        deps_array=("${DEPS_MITM[@]}") ;;
        optional)    deps_array=("${DEPS_OPTIONAL[@]}") ;;
        *)
            log_error "Unknown dependency category: $category"
            return 1
            ;;
    esac

    for entry in "${deps_array[@]}"; do
        if ! deps_check_entry "$entry"; then
            local package="${entry%%:*}"
            missing+=("$package")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        printf '%s\n' "${missing[@]}"
        return 1
    fi

    return 0
}

# Check all wireless dependencies
# Returns: 0 if all essential present, 1 if any essential missing
deps_check_all() {
    local all_ok=0
    local pm
    pm=$(deps_get_package_manager)

    echo ""
    echo -e "    ${C_CYAN}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "    ${C_CYAN}║${C_RESET}                  ${C_BOLD}WIRELESS DEPENDENCIES${C_RESET}                           ${C_CYAN}║${C_RESET}"
    echo -e "    ${C_CYAN}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""

    local categories=(
        "essential:Essential Tools"
        "wps:WPS Attacks"
        "pmkid:PMKID Capture"
        "dos:DoS Attacks"
        "evil_twin:Evil Twin"
        "cracking:Password Cracking"
        "enterprise:Enterprise Attacks"
        "validation:Handshake Validation"
        "mitm:MITM Attacks"
        "optional:Optional Tools"
    )

    for cat_entry in "${categories[@]}"; do
        local cat_id="${cat_entry%%:*}"
        local cat_name="${cat_entry#*:}"

        echo -e "    ${C_SHADOW}──── $cat_name ────${C_RESET}"

        local missing
        missing=$(deps_check_category "$cat_id")

        if [[ -z "$missing" ]]; then
            echo -e "    ${C_GREEN}[✓]${C_RESET} All tools available"
        else
            if [[ "$cat_id" == "essential" ]]; then
                all_ok=1
            fi

            while IFS= read -r pkg; do
                echo -e "    ${C_RED}[✗]${C_RESET} Missing: $pkg"
                if [[ -n "$pm" ]]; then
                    echo -e "        ${C_SHADOW}$(deps_get_install_cmd "$pm" "$pkg")${C_RESET}"
                fi
            done <<< "$missing"
        fi
        echo ""
    done

    return $all_ok
}

#═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCY REQUIREMENTS
#═══════════════════════════════════════════════════════════════════════════════

# Check dependencies for a specific attack type
# Args: $1 = attack type
# Returns: 0 if ready, 1 if missing deps
deps_require_for_attack() {
    local attack_type="$1"
    local required_cats=()
    local missing=()

    # Map attack types to required categories
    case "$attack_type" in
        wps|wps_pixie|wps_pin)
            required_cats=("essential" "wps")
            ;;
        pmkid)
            required_cats=("essential" "pmkid")
            ;;
        handshake|capture)
            required_cats=("essential")
            ;;
        deauth|dos)
            required_cats=("essential" "dos")
            ;;
        evil_twin|eviltwin|rogue_ap)
            required_cats=("essential" "evil_twin")
            ;;
        wep)
            required_cats=("essential")
            ;;
        enterprise)
            required_cats=("essential" "enterprise")
            ;;
        crack|cracking)
            required_cats=("essential" "cracking")
            ;;
        mitm)
            required_cats=("essential" "mitm")
            ;;
        *)
            required_cats=("essential")
            ;;
    esac

    for cat in "${required_cats[@]}"; do
        local cat_missing
        cat_missing=$(deps_check_category "$cat")
        if [[ -n "$cat_missing" ]]; then
            while IFS= read -r pkg; do
                missing+=("$pkg")
            done <<< "$cat_missing"
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies for $attack_type attack:"
        local pm
        pm=$(deps_get_package_manager)
        for pkg in "${missing[@]}"; do
            echo -e "    ${C_RED}•${C_RESET} $pkg"
            if [[ -n "$pm" ]]; then
                echo -e "      ${C_SHADOW}$(deps_get_install_cmd "$pm" "$pkg")${C_RESET}"
            fi
        done
        return 1
    fi

    return 0
}

# Require specific tools (quick check)
# Args: tool names
# Returns: 0 if all present, 1 if any missing
deps_require() {
    local missing=()

    for tool in "$@"; do
        if ! deps_check_binary "$tool"; then
            missing+=("$tool")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing[*]}"
        return 1
    fi

    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# INSTALLATION HELPERS
#═══════════════════════════════════════════════════════════════════════════════

# Generate install script for missing dependencies
# Args: $1 = category (or "all")
# Outputs: install commands
deps_generate_install_script() {
    local category="${1:-all}"
    local pm
    pm=$(deps_get_package_manager)

    if [[ -z "$pm" ]]; then
        echo "# Unknown package manager - install manually"
        return 1
    fi

    echo "#!/bin/bash"
    echo "# VOIDWAVE Wireless Dependencies Installer"
    echo "# Generated: $(date)"
    echo ""
    echo "set -e"
    echo ""

    local categories
    if [[ "$category" == "all" ]]; then
        categories=("essential" "wps" "pmkid" "dos" "evil_twin" "cracking" "validation")
    else
        categories=("$category")
    fi

    for cat in "${categories[@]}"; do
        local missing
        missing=$(deps_check_category "$cat")
        if [[ -n "$missing" ]]; then
            echo "# $cat dependencies"
            while IFS= read -r pkg; do
                deps_get_install_cmd "$pm" "$pkg"
            done <<< "$missing"
            echo ""
        fi
    done

    echo "echo 'Installation complete!'"
}

# Quick install missing essential dependencies (requires root)
deps_install_essential() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Root required for installation"
        return 1
    fi

    local pm
    pm=$(deps_get_package_manager)

    if [[ -z "$pm" ]]; then
        log_error "No supported package manager found"
        return 1
    fi

    local missing
    missing=$(deps_check_category "essential")

    if [[ -z "$missing" ]]; then
        log_success "All essential dependencies already installed"
        return 0
    fi

    log_info "Installing missing essential dependencies..."

    while IFS= read -r pkg; do
        log_info "Installing $pkg..."
        case "$pm" in
            apt)
                apt update -qq && apt install -y "$pkg"
                ;;
            dnf|yum)
                dnf install -y "$pkg"
                ;;
            pacman)
                pacman -S --noconfirm "$pkg"
                ;;
            zypper)
                zypper install -y "$pkg"
                ;;
        esac
    done <<< "$missing"

    log_success "Essential dependencies installed"
}

#═══════════════════════════════════════════════════════════════════════════════
# TOOL VERSION DETECTION
#═══════════════════════════════════════════════════════════════════════════════

# Get tool version
# Args: $1 = tool name
# Returns: version string or "unknown"
deps_get_version() {
    local tool="$1"
    local version="unknown"

    case "$tool" in
        aircrack-ng|airodump-ng|aireplay-ng|airmon-ng)
            version=$(aircrack-ng --version 2>&1 | sed -n 's/.*Aircrack-ng \([0-9.]*\).*/\1/p' | head -1)
            ;;
        reaver)
            version=$(reaver -h 2>&1 | sed -n 's/.*Reaver v\([0-9.]*\).*/\1/p' | head -1)
            ;;
        bully)
            version=$(bully -h 2>&1 | sed -n 's/.*bully v\([0-9.]*\).*/\1/p' | head -1)
            ;;
        hashcat)
            version=$(hashcat --version 2>&1 | sed -n 's/.*v\([0-9.]*\).*/\1/p' | head -1)
            ;;
        hcxdumptool)
            version=$(hcxdumptool --version 2>&1 | head -1)
            ;;
        mdk3)
            version=$(mdk3 --help 2>&1 | head -1 | sed -n 's/.*v\([0-9]*\).*/\1/p' || echo "3.x")
            ;;
        mdk4)
            version=$(mdk4 --help 2>&1 | sed -n 's/.*v\([0-9.]*\).*/\1/p' | head -1 || echo "4.x")
            ;;
        hostapd)
            version=$(hostapd -v 2>&1 | sed -n 's/.*v\([0-9.]*\).*/\1/p' | head -1)
            ;;
        bettercap)
            version=$(bettercap --version 2>&1 | sed -n 's/.*v\([0-9.]*\).*/\1/p' | head -1)
            ;;
        wifite)
            version=$(wifite --version 2>&1 | sed -n 's/.*\([0-9.]*\).*/\1/p' | head -1)
            ;;
        *)
            # Try common version flags
            version=$("$tool" --version 2>&1 | sed -n 's/.*\([0-9]*\.[0-9.]*\).*/\1/p' | head -1 || echo "unknown")
            ;;
    esac

    echo "${version:-unknown}"
}

# Show installed tool versions
deps_show_versions() {
    local tools=(
        "aircrack-ng" "reaver" "bully" "hashcat" "hcxdumptool"
        "mdk4" "hostapd" "bettercap" "wifite"
    )

    echo ""
    echo -e "    ${C_CYAN}Installed Tool Versions${C_RESET}"
    echo -e "    ${C_SHADOW}$(printf '─%.0s' {1..40})${C_RESET}"

    for tool in "${tools[@]}"; do
        if deps_check_binary "$tool"; then
            local version
            version=$(deps_get_version "$tool")
            printf "    ${C_GREEN}%-15s${C_RESET} %s\n" "$tool" "$version"
        else
            printf "    ${C_RED}%-15s${C_RESET} ${C_SHADOW}not installed${C_RESET}\n" "$tool"
        fi
    done

    echo ""
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
#═══════════════════════════════════════════════════════════════════════════════

export -f deps_get_package_manager deps_get_install_cmd
export -f deps_check_binary deps_check_entry deps_check_category deps_check_all
export -f deps_require_for_attack deps_require
export -f deps_generate_install_script deps_install_essential
export -f deps_get_version deps_show_versions
