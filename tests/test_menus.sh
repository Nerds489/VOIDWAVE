#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE Menu Integration Tests
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== VOIDWAVE Menu Integration Tests ==="
echo ""

# Set VOIDWAVE_ROOT for sourcing
export VOIDWAVE_ROOT="$ROOT_DIR"
export VW_NON_INTERACTIVE=1

# Source ui.sh directly (includes colors and helpers we need)
source "$ROOT_DIR/lib/ui.sh" 2>/dev/null || true

# Track results
PASS=0
FAIL=0

check_menu() {
    local file="$1"
    local func="$2"
    local basename="${file##*/}"

    if [[ ! -f "$file" ]]; then
        echo "FAIL: $basename not found"
        ((FAIL++)) || true
        return 1
    fi

    if ! bash -n "$file" 2>/dev/null; then
        echo "FAIL: $basename has syntax errors"
        ((FAIL++)) || true
        return 1
    fi

    source "$file" 2>/dev/null || true

    if ! type -t "$func" &>/dev/null; then
        echo "FAIL: $func not defined in $basename"
        ((FAIL++)) || true
        return 1
    fi

    echo "PASS: $basename ($func)"
    ((PASS++)) || true
    return 0
}

# Test all menus
check_menu "$ROOT_DIR/lib/menu.sh" "show_main_menu"
check_menu "$ROOT_DIR/lib/menus/recon_menu.sh" "show_recon_menu"
check_menu "$ROOT_DIR/lib/menus/scan_menu.sh" "show_scan_menu"
check_menu "$ROOT_DIR/lib/menus/wireless_menu.sh" "show_wireless_menu"
check_menu "$ROOT_DIR/lib/menus/exploit_menu.sh" "show_exploit_menu"
check_menu "$ROOT_DIR/lib/menus/creds_menu.sh" "show_creds_menu"
check_menu "$ROOT_DIR/lib/menus/traffic_menu.sh" "show_traffic_menu"
check_menu "$ROOT_DIR/lib/menus/osint_menu.sh" "show_osint_menu"
check_menu "$ROOT_DIR/lib/menus/stress_menu.sh" "show_stress_menu"
check_menu "$ROOT_DIR/lib/menus/status_menu.sh" "show_status_menu"
check_menu "$ROOT_DIR/lib/menus/settings_menu.sh" "show_settings_menu"

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
