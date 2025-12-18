#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Test Suite: Help and Version
# ═══════════════════════════════════════════════════════════════════════════════
# Tests for CLI help output and version information
# ═══════════════════════════════════════════════════════════════════════════════

# Get the project root directory
VOIDWAVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

#───────────────────────────────────────────────────────────────────────────────
# voidwave help tests
#───────────────────────────────────────────────────────────────────────────────

@test "voidwave --help exits with code 0" {
    run "$VOIDWAVE_ROOT/voidwave" --help
    [ "$status" -eq 0 ]
}

@test "voidwave -h exits with code 0" {
    run "$VOIDWAVE_ROOT/voidwave" -h
    [ "$status" -eq 0 ]
}

@test "voidwave --help shows usage information" {
    run "$VOIDWAVE_ROOT/voidwave" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]] || [[ "$output" == *"USAGE"* ]]
}

@test "voidwave --help mentions available commands" {
    run "$VOIDWAVE_ROOT/voidwave" --help
    [ "$status" -eq 0 ]
    # Check for common command references
    [[ "$output" == *"scan"* ]] || [[ "$output" == *"recon"* ]] || [[ "$output" == *"--"* ]]
}

#───────────────────────────────────────────────────────────────────────────────
# voidwave version tests
#───────────────────────────────────────────────────────────────────────────────

@test "voidwave --version exits with code 0" {
    run "$VOIDWAVE_ROOT/voidwave" --version
    [ "$status" -eq 0 ]
}

@test "voidwave --version outputs version number" {
    run "$VOIDWAVE_ROOT/voidwave" --version
    [ "$status" -eq 0 ]
    # Version should contain a version pattern (e.g., 5.3.1)
    [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "voidwave version matches VERSION file" {
    # Read version from VERSION file
    version_file=$(cat "$VOIDWAVE_ROOT/VERSION" 2>/dev/null | tr -d '[:space:]')

    # Get version from voidwave --version
    run "$VOIDWAVE_ROOT/voidwave" --version
    [ "$status" -eq 0 ]

    # Check if version file content appears in output
    [[ "$output" == *"$version_file"* ]]
}

#───────────────────────────────────────────────────────────────────────────────
# voidwave-install help tests
#───────────────────────────────────────────────────────────────────────────────

@test "voidwave-install --help exits with code 0" {
    run "$VOIDWAVE_ROOT/voidwave-install" --help
    [ "$status" -eq 0 ]
}

@test "voidwave-install -h exits with code 0" {
    run "$VOIDWAVE_ROOT/voidwave-install" -h
    [ "$status" -eq 0 ]
}

@test "voidwave-install --help shows usage information" {
    run "$VOIDWAVE_ROOT/voidwave-install" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]] || [[ "$output" == *"USAGE"* ]] || [[ "$output" == *"install"* ]]
}

@test "voidwave-install --help mentions tool installation" {
    run "$VOIDWAVE_ROOT/voidwave-install" --help
    [ "$status" -eq 0 ]
    # Should mention tools or installation
    [[ "$output" == *"tool"* ]] || [[ "$output" == *"Tool"* ]] || [[ "$output" == *"install"* ]] || [[ "$output" == *"Install"* ]]
}

@test "voidwave-install help shows version in output" {
    run "$VOIDWAVE_ROOT/voidwave-install" --help
    [ "$status" -eq 0 ]
    # Version appears in help/usage output
    [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}
