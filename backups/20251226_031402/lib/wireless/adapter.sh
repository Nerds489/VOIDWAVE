#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Offensive Security Framework
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# Wireless Adapter: chipset detection, capability analysis, VIF support
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_WIRELESS_ADAPTER_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_WIRELESS_ADAPTER_LOADED=1

# Source core if not loaded
if ! declare -F log_info &>/dev/null; then
    source "${BASH_SOURCE%/*}/../core.sh"
fi

#═══════════════════════════════════════════════════════════════════════════════
# CHIPSET DATABASES
#═══════════════════════════════════════════════════════════════════════════════

# Chipsets with full VIF (Virtual Interface) support - recommended for Evil Twin
declare -ga VIF_WHITELIST=(
    "MT7921AUN"   # MediaTek - Alfa AWUS036AXML
    "MT7612U"     # MediaTek - Alfa AWUS036ACM
    "AR9271"      # Atheros - Alfa AWUS036NHA, TP-Link TL-WN722N v1
    "RT5572"      # Ralink - Panda PAU07/PAU09
    "RT3070"      # Ralink - Alfa AWUS036NH
    "RT2870"      # Ralink - older adapters
    "RTL8187"     # Realtek legacy - good injection support
    "ath9k_htc"   # Atheros driver (kernel)
    "rt2800usb"   # Ralink driver (kernel)
)

# Chipsets with known issues - may work but problematic
declare -ga VIF_BLACKLIST=(
    "RTL8188EU"   # Realtek - TP-Link TL-WN722N v2/v3 (no monitor mode)
    "RTL8812BU"   # Realtek - Alfa AWUS036ACU (driver issues)
    "RTL8814AU"   # Realtek - Alfa AWUS1900 (VIF issues)
    "RTL8821AU"   # Realtek (various issues)
    "RTL8811AU"   # Realtek (various issues)
)

# Chipsets rated by overall capability
declare -gA CHIPSET_RATINGS=(
    # Best - full VIF, excellent injection, dual-band
    ["MT7612U"]="best"
    ["MT7921AUN"]="best"
    ["AR9271"]="best"

    # Great - good VIF support, reliable injection
    ["RT5572"]="great"
    ["RT3070"]="great"
    ["RTL8187"]="great"
    ["RT2870"]="great"

    # Good - works but may have limitations
    ["RTL8812AU"]="good"
    ["RTL8811CU"]="good"

    # Poor - significant issues, not recommended
    ["RTL8188EU"]="poor"
    ["RTL8812BU"]="poor"
    ["RTL8814AU"]="poor"
)

# Known adapter models and their chipsets
declare -gA KNOWN_ADAPTERS=(
    ["AWUS036NHA"]="AR9271"
    ["AWUS036ACM"]="MT7612U"
    ["AWUS036AXML"]="MT7921AUN"
    ["AWUS036NH"]="RT3070"
    ["AWUS036ACH"]="RTL8812AU"
    ["AWUS036ACS"]="RTL8811AU"
    ["AWUS1900"]="RTL8814AU"
    ["TL-WN722N"]="AR9271"  # v1 only
    ["PAU09"]="RT5572"
    ["PAU07"]="RT5572"
)

#═══════════════════════════════════════════════════════════════════════════════
# ADAPTER DETECTION
#═══════════════════════════════════════════════════════════════════════════════

# Get adapter driver name
# Args: $1 = interface name
# Returns: driver name or empty
adapter_get_driver() {
    local iface="$1"
    local driver_path="/sys/class/net/$iface/device/driver"

    if [[ -L "$driver_path" ]]; then
        basename "$(readlink -f "$driver_path")"
    else
        # Try ethtool as fallback
        if command -v ethtool &>/dev/null; then
            ethtool -i "$iface" 2>/dev/null | awk '/^driver:/{print $2}'
        fi
    fi
}

# Get adapter chipset
# Args: $1 = interface name
# Returns: chipset identifier or "unknown"
adapter_get_chipset() {
    local iface="$1"
    local driver chipset=""

    driver=$(adapter_get_driver "$iface")

    # Map driver to chipset
    case "$driver" in
        ath9k_htc)
            chipset="AR9271"
            ;;
        rt2800usb)
            # Need to check specific device
            local product
            product=$(cat "/sys/class/net/$iface/device/product" 2>/dev/null)
            case "$product" in
                *5572*) chipset="RT5572" ;;
                *3070*) chipset="RT3070" ;;
                *2870*) chipset="RT2870" ;;
                *) chipset="RT2800" ;;
            esac
            ;;
        mt76x2u)
            chipset="MT7612U"
            ;;
        mt7921u)
            chipset="MT7921AUN"
            ;;
        rtl8187)
            chipset="RTL8187"
            ;;
        8812au|88XXau|rtl8812au)
            chipset="RTL8812AU"
            ;;
        8814au|rtl8814au)
            chipset="RTL8814AU"
            ;;
        r8188eu|8188eu)
            chipset="RTL8188EU"
            ;;
        *)
            # Try to get from lsusb
            local usb_id
            usb_id=$(cat "/sys/class/net/$iface/device/uevent" 2>/dev/null | grep PRODUCT | cut -d= -f2)
            if [[ -n "$usb_id" ]]; then
                chipset="USB:$usb_id"
            else
                chipset="unknown"
            fi
            ;;
    esac

    echo "$chipset"
}

# Get adapter rating
# Args: $1 = interface name
# Returns: best, great, good, poor, or unknown
adapter_get_rating() {
    local iface="$1"
    local chipset

    chipset=$(adapter_get_chipset "$iface")

    if [[ -n "${CHIPSET_RATINGS[$chipset]+isset}" ]]; then
        echo "${CHIPSET_RATINGS[$chipset]}"
    else
        echo "unknown"
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# CAPABILITY DETECTION
#═══════════════════════════════════════════════════════════════════════════════

# Check if adapter supports monitor mode
# Args: $1 = interface name
# Returns: 0 if supported, 1 if not
adapter_supports_monitor() {
    local iface="$1"

    # Check via iw
    if command -v iw &>/dev/null; then
        local phy
        phy=$(iw dev "$iface" info 2>/dev/null | awk '/wiphy/{print $2}')
        if [[ -n "$phy" ]]; then
            iw phy "phy$phy" info 2>/dev/null | grep -q "monitor" && return 0
        fi
    fi

    # Check via iwconfig
    if command -v iwconfig &>/dev/null; then
        iwconfig "$iface" 2>/dev/null | grep -q "Mode:" && return 0
    fi

    return 1
}

# Check if adapter supports packet injection
# Args: $1 = interface name
# Returns: 0 if supported, 1 if not
# Note: Full test requires root and monitor mode
adapter_supports_injection() {
    local iface="$1"

    # Quick check - blacklisted chipsets never support injection well
    local chipset
    chipset=$(adapter_get_chipset "$iface")

    for blacklisted in "${VIF_BLACKLIST[@]}"; do
        if [[ "$chipset" == "$blacklisted" ]]; then
            return 1
        fi
    done

    # Whitelisted chipsets support injection
    for whitelisted in "${VIF_WHITELIST[@]}"; do
        if [[ "$chipset" == "$whitelisted" ]]; then
            return 0
        fi
    done

    # Unknown - assume yes but warn
    return 0
}

# Test packet injection capability (requires root and monitor mode)
# Args: $1 = interface name (must be in monitor mode)
# Returns: 0 if injection works, 1 if not
adapter_test_injection() {
    local iface="$1"

    if [[ $EUID -ne 0 ]]; then
        log_warning "Injection test requires root"
        return 1
    fi

    if ! command -v aireplay-ng &>/dev/null; then
        log_warning "aireplay-ng required for injection test"
        return 1
    fi

    log_info "Testing injection on $iface..."

    # Run injection test
    local result
    result=$(aireplay-ng --test "$iface" 2>&1)

    if echo "$result" | grep -q "Injection is working"; then
        log_success "Injection working on $iface"
        return 0
    else
        log_error "Injection failed on $iface"
        return 1
    fi
}

# Check if adapter supports VIF (Virtual Interface)
# Args: $1 = interface name
# Returns: 0 if supported, 1 if not
adapter_supports_vif() {
    local iface="$1"
    local chipset

    chipset=$(adapter_get_chipset "$iface")

    # Check whitelist
    for whitelisted in "${VIF_WHITELIST[@]}"; do
        if [[ "$chipset" == "$whitelisted" ]]; then
            return 0
        fi
    done

    # Check via iw - can we add interfaces?
    if command -v iw &>/dev/null; then
        local phy
        phy=$(iw dev "$iface" info 2>/dev/null | awk '/wiphy/{print $2}')
        if [[ -n "$phy" ]]; then
            # Check if multiple interface types supported
            local types
            types=$(iw phy "phy$phy" info 2>/dev/null | grep -A20 "valid interface combinations" | grep -c "managed\|AP\|monitor")
            [[ $types -ge 2 ]] && return 0
        fi
    fi

    return 1
}

# Check if adapter supports 5GHz
# Args: $1 = interface name
# Returns: 0 if supported, 1 if not
adapter_supports_5ghz() {
    local iface="$1"

    if command -v iw &>/dev/null; then
        local phy
        phy=$(iw dev "$iface" info 2>/dev/null | awk '/wiphy/{print $2}')
        if [[ -n "$phy" ]]; then
            iw phy "phy$phy" info 2>/dev/null | grep -qE "5[0-9]{3} MHz" && return 0
        fi
    fi

    return 1
}

# Get all supported channels
# Args: $1 = interface name
# Returns: space-separated list of channels
adapter_get_channels() {
    local iface="$1"
    local channels=""

    if command -v iw &>/dev/null; then
        local phy
        phy=$(iw dev "$iface" info 2>/dev/null | awk '/wiphy/{print $2}')
        if [[ -n "$phy" ]]; then
            channels=$(iw phy "phy$phy" info 2>/dev/null | \
                       sed -n 's/.*\[\([0-9]*\)\].*/\1/p' | sort -n | uniq | tr '\n' ' ')
        fi
    fi

    # Fallback to common channels if detection failed
    if [[ -z "$channels" ]]; then
        channels="1 2 3 4 5 6 7 8 9 10 11"
        if adapter_supports_5ghz "$iface"; then
            channels="$channels 36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 149 153 157 161 165"
        fi
    fi

    echo "$channels"
}

#═══════════════════════════════════════════════════════════════════════════════
# ADAPTER INFO
#═══════════════════════════════════════════════════════════════════════════════

# Get comprehensive adapter information
# Args: $1 = interface name
# Returns: multiline info string
adapter_get_info() {
    local iface="$1"

    local driver chipset rating
    local has_monitor has_injection has_vif has_5ghz

    driver=$(adapter_get_driver "$iface")
    chipset=$(adapter_get_chipset "$iface")
    rating=$(adapter_get_rating "$iface")

    adapter_supports_monitor "$iface" && has_monitor="yes" || has_monitor="no"
    adapter_supports_injection "$iface" && has_injection="yes" || has_injection="no"
    adapter_supports_vif "$iface" && has_vif="yes" || has_vif="no"
    adapter_supports_5ghz "$iface" && has_5ghz="yes" || has_5ghz="no"

    # Get MAC address
    local mac
    mac=$(cat "/sys/class/net/$iface/address" 2>/dev/null || echo "unknown")

    # Get current mode
    local mode="unknown"
    if command -v iw &>/dev/null; then
        mode=$(iw dev "$iface" info 2>/dev/null | awk '/type/{print $2}')
    fi

    echo "Interface:    $iface"
    echo "MAC Address:  $mac"
    echo "Driver:       $driver"
    echo "Chipset:      $chipset"
    echo "Rating:       $rating"
    echo "Mode:         $mode"
    echo "Monitor:      $has_monitor"
    echo "Injection:    $has_injection"
    echo "VIF Support:  $has_vif"
    echo "5GHz:         $has_5ghz"
}

# Display adapter info with colors
# Args: $1 = interface name
adapter_show_info() {
    local iface="$1"

    local driver chipset rating
    local has_monitor has_injection has_vif has_5ghz

    driver=$(adapter_get_driver "$iface")
    chipset=$(adapter_get_chipset "$iface")
    rating=$(adapter_get_rating "$iface")

    adapter_supports_monitor "$iface" && has_monitor="yes" || has_monitor="no"
    adapter_supports_injection "$iface" && has_injection="yes" || has_injection="no"
    adapter_supports_vif "$iface" && has_vif="yes" || has_vif="no"
    adapter_supports_5ghz "$iface" && has_5ghz="yes" || has_5ghz="no"

    local mac mode
    mac=$(cat "/sys/class/net/$iface/address" 2>/dev/null || echo "unknown")
    mode=$(iw dev "$iface" info 2>/dev/null | awk '/type/{print $2}' || echo "unknown")

    # Rating color
    local rating_color
    case "$rating" in
        best)    rating_color="${C_GREEN}" ;;
        great)   rating_color="${C_CYAN}" ;;
        good)    rating_color="${C_YELLOW}" ;;
        poor)    rating_color="${C_RED}" ;;
        *)       rating_color="${C_GRAY}" ;;
    esac

    # Capability colors
    local mon_color inj_color vif_color ghz_color
    [[ "$has_monitor" == "yes" ]]    && mon_color="${C_GREEN}" || mon_color="${C_RED}"
    [[ "$has_injection" == "yes" ]]  && inj_color="${C_GREEN}" || inj_color="${C_RED}"
    [[ "$has_vif" == "yes" ]]        && vif_color="${C_GREEN}" || vif_color="${C_RED}"
    [[ "$has_5ghz" == "yes" ]]       && ghz_color="${C_GREEN}" || ghz_color="${C_GRAY}"

    echo ""
    echo -e "    ${C_CYAN}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "    ${C_CYAN}║${C_RESET}                    ${C_BOLD}ADAPTER: $iface${C_RESET}                              ${C_CYAN}║${C_RESET}"
    echo -e "    ${C_CYAN}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
    printf "    ${C_GHOST}%-14s${C_RESET} %s\n" "MAC Address:" "$mac"
    printf "    ${C_GHOST}%-14s${C_RESET} %s\n" "Driver:" "$driver"
    printf "    ${C_GHOST}%-14s${C_RESET} %s\n" "Chipset:" "$chipset"
    printf "    ${C_GHOST}%-14s${C_RESET} ${rating_color}%s${C_RESET}\n" "Rating:" "$rating"
    printf "    ${C_GHOST}%-14s${C_RESET} %s\n" "Mode:" "$mode"
    echo ""
    echo -e "    ${C_SHADOW}──── Capabilities ────${C_RESET}"
    printf "    ${C_GHOST}%-14s${C_RESET} ${mon_color}%s${C_RESET}\n" "Monitor:" "$has_monitor"
    printf "    ${C_GHOST}%-14s${C_RESET} ${inj_color}%s${C_RESET}\n" "Injection:" "$has_injection"
    printf "    ${C_GHOST}%-14s${C_RESET} ${vif_color}%s${C_RESET}\n" "VIF Support:" "$has_vif"
    printf "    ${C_GHOST}%-14s${C_RESET} ${ghz_color}%s${C_RESET}\n" "5GHz:" "$has_5ghz"
    echo ""
}

# List all wireless adapters with ratings
adapter_list_all() {
    local found=0

    echo ""
    echo -e "    ${C_CYAN}Available Wireless Adapters${C_RESET}"
    echo -e "    ${C_SHADOW}$(printf '─%.0s' {1..60})${C_RESET}"
    echo ""

    for iface_path in /sys/class/net/*; do
        local iface
        iface=$(basename "$iface_path")

        # Skip non-wireless
        [[ ! -d "$iface_path/wireless" ]] && continue

        local chipset rating mode mac
        chipset=$(adapter_get_chipset "$iface")
        rating=$(adapter_get_rating "$iface")
        mode=$(iw dev "$iface" info 2>/dev/null | awk '/type/{print $2}' || echo "managed")
        mac=$(cat "$iface_path/address" 2>/dev/null | cut -c1-8)

        # Rating indicator
        local rating_indicator
        case "$rating" in
            best)    rating_indicator="${C_GREEN}★★★${C_RESET}" ;;
            great)   rating_indicator="${C_CYAN}★★☆${C_RESET}" ;;
            good)    rating_indicator="${C_YELLOW}★☆☆${C_RESET}" ;;
            poor)    rating_indicator="${C_RED}☆☆☆${C_RESET}" ;;
            *)       rating_indicator="${C_GRAY}???${C_RESET}" ;;
        esac

        printf "    ${C_GREEN}%-12s${C_RESET} ${C_GHOST}%-12s${C_RESET} %-10s %s ${C_SHADOW}(%s)${C_RESET}\n" \
            "$iface" "$chipset" "$mode" "$rating_indicator" "$mac..."

        ((found++)) || true
    done

    if [[ $found -eq 0 ]]; then
        echo -e "    ${C_RED}No wireless adapters found${C_RESET}"
        return 1
    fi

    echo ""
    echo -e "    ${C_SHADOW}Rating: ${C_GREEN}★★★${C_RESET}=Best ${C_CYAN}★★☆${C_RESET}=Great ${C_YELLOW}★☆☆${C_RESET}=Good ${C_RED}☆☆☆${C_RESET}=Poor${C_RESET}"
    echo ""

    return 0
}

# Find best adapter for a specific task
# Args: $1 = task (evil_twin, injection, monitor, general)
# Returns: interface name or empty
adapter_find_best() {
    local task="${1:-general}"
    local best_iface=""
    local best_score=0

    for iface_path in /sys/class/net/*; do
        local iface
        iface=$(basename "$iface_path")

        # Skip non-wireless
        [[ ! -d "$iface_path/wireless" ]] && continue

        local score=0
        local rating
        rating=$(adapter_get_rating "$iface")

        # Base score from rating
        case "$rating" in
            best)    score=100 ;;
            great)   score=75 ;;
            good)    score=50 ;;
            poor)    score=25 ;;
            *)       score=10 ;;
        esac

        # Task-specific scoring
        case "$task" in
            evil_twin|eviltwin)
                adapter_supports_vif "$iface" && ((score+=50))
                adapter_supports_5ghz "$iface" && ((score+=20))
                ;;
            injection|inject)
                adapter_supports_injection "$iface" && ((score+=50))
                ;;
            monitor)
                adapter_supports_monitor "$iface" && ((score+=50))
                ;;
            *)
                adapter_supports_monitor "$iface" && ((score+=20))
                adapter_supports_injection "$iface" && ((score+=20))
                ;;
        esac

        if [[ $score -gt $best_score ]]; then
            best_score=$score
            best_iface="$iface"
        fi
    done

    echo "$best_iface"
}

#═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
#═══════════════════════════════════════════════════════════════════════════════

export -f adapter_get_driver adapter_get_chipset adapter_get_rating
export -f adapter_supports_monitor adapter_supports_injection adapter_test_injection
export -f adapter_supports_vif adapter_supports_5ghz adapter_get_channels
export -f adapter_get_info adapter_show_info adapter_list_all adapter_find_best
