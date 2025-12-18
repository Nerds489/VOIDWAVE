#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Test Suite: System Detection
# ═══════════════════════════════════════════════════════════════════════════════
# Tests for distribution and package manager detection
# ═══════════════════════════════════════════════════════════════════════════════

# Get the project root directory
VOIDWAVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# Setup - source the detection library
setup() {
    # Source core first (required by detection)
    source "$VOIDWAVE_ROOT/lib/core.sh"
    source "$VOIDWAVE_ROOT/lib/detection.sh"
    # Clear ERR trap and pipefail to prevent interference with BATS test execution
    trap - ERR
    set +o pipefail
}

#───────────────────────────────────────────────────────────────────────────────
# Distribution detection tests
#───────────────────────────────────────────────────────────────────────────────

@test "detect_distro returns a non-empty value" {
    result=$(detect_distro)
    [ -n "$result" ]
}

@test "detect_distro returns a valid distro name" {
    result=$(detect_distro)

    # List of known valid distro names
    valid_distros="debian ubuntu kali parrot linuxmint pop elementary zorin mx fedora rhel centos rocky alma oracle amazon arch manjaro endeavouros blackarch arcolinux garuda opensuse suse sles alpine gentoo funtoo void unknown"

    # Check if result is in the valid list
    found=0
    for distro in $valid_distros; do
        if [ "$result" = "$distro" ]; then
            found=1
            break
        fi
    done

    [ "$found" -eq 1 ]
}

@test "detect_distro_family returns a non-empty value" {
    distro=$(detect_distro)
    result=$(detect_distro_family "$distro")
    [ -n "$result" ]
}

@test "detect_distro_family returns valid family name" {
    distro=$(detect_distro)
    result=$(detect_distro_family "$distro")

    # Valid family names
    valid_families="debian redhat arch suse alpine gentoo void unknown"

    found=0
    for family in $valid_families; do
        if [ "$result" = "$family" ]; then
            found=1
            break
        fi
    done

    [ "$found" -eq 1 ]
}

#───────────────────────────────────────────────────────────────────────────────
# Package manager detection tests
#───────────────────────────────────────────────────────────────────────────────

@test "detect_package_manager returns a non-empty value" {
    result=$(detect_package_manager)
    [ -n "$result" ]
}

@test "detect_package_manager returns valid package manager" {
    result=$(detect_package_manager)

    # Valid package managers
    valid_pkg_managers="apt dnf yum pacman zypper apk emerge xbps unknown"

    found=0
    for pkg in $valid_pkg_managers; do
        if [ "$result" = "$pkg" ]; then
            found=1
            break
        fi
    done

    [ "$found" -eq 1 ]
}

@test "setup_package_manager sets PKG_MANAGER variable" {
    setup_package_manager
    [ -n "$PKG_MANAGER" ]
}

@test "setup_package_manager sets PKG_INSTALL variable for known managers" {
    setup_package_manager

    # If we have a known package manager, PKG_INSTALL should be set
    if [ "$PKG_MANAGER" != "unknown" ]; then
        [ -n "$PKG_INSTALL" ]
    fi
}

#───────────────────────────────────────────────────────────────────────────────
# Tool detection tests
#───────────────────────────────────────────────────────────────────────────────

@test "check_tool returns 0 for existing command (bash)" {
    run check_tool "bash"
    [ "$status" -eq 0 ]
}

@test "check_tool returns 1 for non-existent command" {
    run check_tool "this_command_definitely_does_not_exist_12345"
    [ "$status" -eq 1 ]
}

@test "check_tool returns 1 for empty argument" {
    run check_tool ""
    [ "$status" -eq 1 ]
}

@test "get_tool_path returns path for existing command" {
    result=$(get_tool_path "bash")
    [ -n "$result" ]
    [ -x "$result" ]
}

@test "get_tool_path returns empty for non-existent command" {
    run bash -c '
        source ./lib/core.sh
        source ./lib/detection.sh
        p="$(get_tool_path definitely_not_a_real_command_12345 || true)"
        printf "%s" "$p"
    '
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

#───────────────────────────────────────────────────────────────────────────────
# Network interface detection tests
#───────────────────────────────────────────────────────────────────────────────

@test "check_interface returns 0 for loopback (lo)" {
    run check_interface "lo"
    [ "$status" -eq 0 ]
}

@test "check_interface returns 1 for non-existent interface" {
    run check_interface "nonexistent_interface_12345"
    [ "$status" -eq 1 ]
}

@test "check_interface returns 1 for empty argument" {
    run check_interface ""
    [ "$status" -eq 1 ]
}

@test "get_default_interface returns a value (may be empty on some systems)" {
    # This test just verifies the function runs without error
    run bash -c "source '$VOIDWAVE_ROOT/lib/core.sh'; source '$VOIDWAVE_ROOT/lib/detection.sh'; get_default_interface"
    [ "$status" -eq 0 ]
}

@test "get_interface_state returns valid state for loopback" {
    result=$(get_interface_state "lo")

    # Should return up, down, or unknown
    [[ "$result" == "up" ]] || [[ "$result" == "down" ]] || [[ "$result" == "unknown" ]]
}

@test "get_interface_mac returns MAC address format for loopback" {
    result=$(get_interface_mac "lo")

    # Loopback typically has 00:00:00:00:00:00
    # Just check it's either empty or matches MAC format
    if [ -n "$result" ]; then
        [[ "$result" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]
    fi
}

#───────────────────────────────────────────────────────────────────────────────
# System detection integration test
#───────────────────────────────────────────────────────────────────────────────

@test "detect_system sets all required variables" {
    detect_system

    # All these should be set after detect_system
    [ -n "$DISTRO" ]
    [ -n "$DISTRO_FAMILY" ]
    [ -n "$PKG_MANAGER" ]
}

@test "detect_system is idempotent (can be called multiple times)" {
    detect_system
    first_distro="$DISTRO"

    detect_system
    second_distro="$DISTRO"

    [ "$first_distro" = "$second_distro" ]
}

#───────────────────────────────────────────────────────────────────────────────
# Tool registry tests
#───────────────────────────────────────────────────────────────────────────────

@test "TOOL_PACKAGES registry is populated" {
    [ -n "${TOOL_PACKAGES[nmap]}" ]
    [ "${TOOL_PACKAGES[nmap]}" = "nmap" ]
}

@test "TOOL_PACKAGES maps dig to dnsutils" {
    [ "${TOOL_PACKAGES[dig]}" = "dnsutils" ]
}

@test "TOOL_PACKAGES maps aircrack suite tools" {
    [ "${TOOL_PACKAGES[airodump-ng]}" = "aircrack-ng" ]
    [ "${TOOL_PACKAGES[aireplay-ng]}" = "aircrack-ng" ]
}

@test "TOOL_CATEGORIES contains expected categories" {
    [ -n "${TOOL_CATEGORIES[recon]}" ]
    [ -n "${TOOL_CATEGORIES[wireless]}" ]
    [ -n "${TOOL_CATEGORIES[scanning]}" ]
    [ -n "${TOOL_CATEGORIES[credentials]}" ]
}

@test "TOOL_CATEGORIES recon contains nmap" {
    [[ "${TOOL_CATEGORIES[recon]}" == *"nmap"* ]]
}

#───────────────────────────────────────────────────────────────────────────────
# Tool version detection tests
#───────────────────────────────────────────────────────────────────────────────

@test "check_tool_version returns version for bash" {
    result=$(check_tool_version "bash")
    [ -n "$result" ]
    # Should match version pattern like 5.1.16 or 5.2
    [[ "$result" =~ ^[0-9]+\.[0-9]+ ]]
}

@test "check_tool_version returns 1 for non-existent tool" {
    run check_tool_version "this_command_definitely_does_not_exist_12345"
    [ "$status" -eq 1 ]
}

#───────────────────────────────────────────────────────────────────────────────
# Tool installation tests (non-interactive behavior)
#───────────────────────────────────────────────────────────────────────────────

@test "auto_install_tool returns 0 for already installed tool" {
    run auto_install_tool "bash"
    [ "$status" -eq 0 ]
}

@test "auto_install_tool returns 1 in non-interactive mode for missing tool" {
    export VW_NON_INTERACTIVE=1
    run auto_install_tool "this_tool_does_not_exist_xyz123"
    [ "$status" -eq 1 ]
}

@test "require_tools returns 0 when all tools present" {
    run require_tools bash grep
    [ "$status" -eq 0 ]
}

@test "require_tools returns 1 in non-interactive mode when tool missing" {
    export VW_NON_INTERACTIVE=1
    run require_tools "bash" "this_tool_does_not_exist_xyz123"
    [ "$status" -eq 1 ]
}

#───────────────────────────────────────────────────────────────────────────────
# Tool status display tests
#───────────────────────────────────────────────────────────────────────────────

@test "show_tool_status outputs Tool Status header" {
    run show_tool_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Tool Status"* ]]
}

@test "show_tool_status shows category names" {
    run show_tool_status
    [ "$status" -eq 0 ]
    # Should show at least one category (uppercased)
    [[ "$output" == *"RECON"* ]] || [[ "$output" == *"SCANNING"* ]] || [[ "$output" == *"UTILITIES"* ]]
}

@test "show_tool_status shows installed/missing summary" {
    run show_tool_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Installed:"* ]]
    [[ "$output" == *"Missing:"* ]]
}

#───────────────────────────────────────────────────────────────────────────────
# Expanded tool detection tests
#───────────────────────────────────────────────────────────────────────────────

@test "get_tool_path returns 1 for empty argument" {
    run bash -c '
        source ./lib/core.sh
        source ./lib/detection.sh
        get_tool_path ""
    '
    [ "$status" -eq 1 ]
}

@test "TOOL_SEARCH_PATHS includes standard directories" {
    # Verify the array contains expected paths
    [[ " ${TOOL_SEARCH_PATHS[*]} " == *" /usr/bin "* ]]
    [[ " ${TOOL_SEARCH_PATHS[*]} " == *" /usr/sbin "* ]]
    [[ " ${TOOL_SEARCH_PATHS[*]} " == *" /usr/local/bin "* ]]
    [[ " ${TOOL_SEARCH_PATHS[*]} " == *" /usr/local/sbin "* ]]
    [[ " ${TOOL_SEARCH_PATHS[*]} " == *" /sbin "* ]]
    [[ " ${TOOL_SEARCH_PATHS[*]} " == *" /bin "* ]]
}

#───────────────────────────────────────────────────────────────────────────────
# Distro-aware package name tests
#───────────────────────────────────────────────────────────────────────────────

@test "tool_package_name returns correct package for dig on debian family" {
    # Set distro family to debian
    DISTRO_FAMILY="debian"
    result=$(tool_package_name "dig")
    [ "$result" = "dnsutils" ]
}

@test "tool_package_name returns correct package for dig on redhat family" {
    DISTRO_FAMILY="redhat"
    result=$(tool_package_name "dig")
    [ "$result" = "bind-utils" ]
}

@test "tool_package_name returns correct package for dig on arch family" {
    DISTRO_FAMILY="arch"
    result=$(tool_package_name "dig")
    [ "$result" = "bind" ]
}

@test "tool_package_name maps airodump-ng to aircrack-ng" {
    result=$(tool_package_name "airodump-ng")
    [ "$result" = "aircrack-ng" ]
}

@test "tool_package_name maps aireplay-ng to aircrack-ng" {
    result=$(tool_package_name "aireplay-ng")
    [ "$result" = "aircrack-ng" ]
}

@test "tool_package_name maps airmon-ng to aircrack-ng" {
    result=$(tool_package_name "airmon-ng")
    [ "$result" = "aircrack-ng" ]
}

@test "tool_package_name returns tool name for unknown tool" {
    result=$(tool_package_name "unknown_tool_xyz123")
    [ "$result" = "unknown_tool_xyz123" ]
}

@test "tool_package_name returns 1 for empty input" {
    run tool_package_name ""
    [ "$status" -eq 1 ]
}

@test "tool_package_name returns tshark for debian family" {
    DISTRO_FAMILY="debian"
    result=$(tool_package_name "tshark")
    [ "$result" = "tshark" ]
}

@test "tool_package_name returns wireshark-cli for arch family tshark" {
    DISTRO_FAMILY="arch"
    result=$(tool_package_name "tshark")
    [ "$result" = "wireshark-cli" ]
}

@test "tool_package_name returns netcat-openbsd for debian family netcat" {
    DISTRO_FAMILY="debian"
    result=$(tool_package_name "netcat")
    [ "$result" = "netcat-openbsd" ]
}

@test "tool_package_name returns nmap-ncat for redhat family netcat" {
    DISTRO_FAMILY="redhat"
    result=$(tool_package_name "netcat")
    [ "$result" = "nmap-ncat" ]
}
