#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Test Suite: Syntax Validation
# ═══════════════════════════════════════════════════════════════════════════════
# Tests that all shell scripts pass bash -n syntax checking
# ═══════════════════════════════════════════════════════════════════════════════

# Get the project root directory
VOIDWAVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

#───────────────────────────────────────────────────────────────────────────────
# Main scripts syntax tests
#───────────────────────────────────────────────────────────────────────────────

@test "voidwave passes bash -n syntax check" {
    run bash -n "$VOIDWAVE_ROOT/voidwave"
    [ "$status" -eq 0 ]
}

@test "voidwave-install passes bash -n syntax check" {
    run bash -n "$VOIDWAVE_ROOT/voidwave-install"
    [ "$status" -eq 0 ]
}

#───────────────────────────────────────────────────────────────────────────────
# Library files syntax tests
#───────────────────────────────────────────────────────────────────────────────

@test "lib/core.sh passes bash -n syntax check" {
    run bash -n "$VOIDWAVE_ROOT/lib/core.sh"
    [ "$status" -eq 0 ]
}

@test "lib/ui.sh passes bash -n syntax check" {
    run bash -n "$VOIDWAVE_ROOT/lib/ui.sh"
    [ "$status" -eq 0 ]
}

@test "lib/utils.sh passes bash -n syntax check" {
    run bash -n "$VOIDWAVE_ROOT/lib/utils.sh"
    [ "$status" -eq 0 ]
}

@test "lib/detection.sh passes bash -n syntax check" {
    run bash -n "$VOIDWAVE_ROOT/lib/detection.sh"
    [ "$status" -eq 0 ]
}

@test "All lib/*.sh files pass bash -n syntax check" {
    for file in "$VOIDWAVE_ROOT"/lib/*.sh; do
        if [ -f "$file" ]; then
            run bash -n "$file"
            if [ "$status" -ne 0 ]; then
                echo "FAILED: $file"
                echo "$output"
                return 1
            fi
        fi
    done
}

#───────────────────────────────────────────────────────────────────────────────
# Module files syntax tests
#───────────────────────────────────────────────────────────────────────────────

@test "modules/recon.sh passes bash -n syntax check" {
    run bash -n "$VOIDWAVE_ROOT/modules/recon.sh"
    [ "$status" -eq 0 ]
}

@test "modules/wireless.sh passes bash -n syntax check" {
    run bash -n "$VOIDWAVE_ROOT/modules/wireless.sh"
    [ "$status" -eq 0 ]
}

@test "modules/scanning.sh passes bash -n syntax check" {
    run bash -n "$VOIDWAVE_ROOT/modules/scanning.sh"
    [ "$status" -eq 0 ]
}

@test "modules/exploit.sh passes bash -n syntax check" {
    run bash -n "$VOIDWAVE_ROOT/modules/exploit.sh"
    [ "$status" -eq 0 ]
}

@test "modules/credentials.sh passes bash -n syntax check" {
    run bash -n "$VOIDWAVE_ROOT/modules/credentials.sh"
    [ "$status" -eq 0 ]
}

@test "modules/traffic.sh passes bash -n syntax check" {
    run bash -n "$VOIDWAVE_ROOT/modules/traffic.sh"
    [ "$status" -eq 0 ]
}

@test "modules/osint.sh passes bash -n syntax check" {
    run bash -n "$VOIDWAVE_ROOT/modules/osint.sh"
    [ "$status" -eq 0 ]
}

@test "All modules/*.sh files pass bash -n syntax check" {
    for file in "$VOIDWAVE_ROOT"/modules/*.sh; do
        if [ -f "$file" ]; then
            run bash -n "$file"
            if [ "$status" -ne 0 ]; then
                echo "FAILED: $file"
                echo "$output"
                return 1
            fi
        fi
    done
}

#───────────────────────────────────────────────────────────────────────────────
# Comprehensive syntax check
#───────────────────────────────────────────────────────────────────────────────

@test "All .sh files in project pass bash -n syntax check" {
    failed_files=""

    # Check all .sh files
    while IFS= read -r -d '' file; do
        if bash -n "$file" 2>/dev/null; then
            : # Pass
        else
            failed_files="$failed_files $file"
        fi
    done < <(find "$VOIDWAVE_ROOT" -name "*.sh" -type f -print0 2>/dev/null)

    if [ -n "$failed_files" ]; then
        echo "Failed files:$failed_files"
        return 1
    fi
}
