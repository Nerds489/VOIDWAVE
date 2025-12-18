#!/usr/bin/env bats
# VOIDWAVE Stress Tests
# Tests for modules/stress.sh functions
# NOTE: Tests use stubs to avoid real network operations

setup() {
    VOIDWAVE_ROOT="$BATS_TEST_DIRNAME/.."
    VOIDWAVE="$VOIDWAVE_ROOT/bin/voidwave"
    export VOIDWAVE_ROOT
    export VW_NON_INTERACTIVE=1

    # Create temp directory for stubs
    TEST_TMPDIR=$(mktemp -d)
    export TEST_TMPDIR

    # Create stub bin directory
    STUB_BIN="$TEST_TMPDIR/bin"
    mkdir -p "$STUB_BIN"

    # Create stub ping (always succeeds)
    cat > "$STUB_BIN/ping" << 'STUBEOF'
#!/usr/bin/env bash
exit 0
STUBEOF
    chmod +x "$STUB_BIN/ping"

    # Create stub hping3 (always succeeds)
    cat > "$STUB_BIN/hping3" << 'STUBEOF'
#!/usr/bin/env bash
echo "HPING stub executed with args: $*"
exit 0
STUBEOF
    chmod +x "$STUB_BIN/hping3"

    # Create stub tc (always succeeds)
    cat > "$STUB_BIN/tc" << 'STUBEOF'
#!/usr/bin/env bash
echo "TC stub executed with args: $*"
exit 0
STUBEOF
    chmod +x "$STUB_BIN/tc"

    # Prepend stub bin to PATH
    export PATH="$STUB_BIN:$PATH"

    # Source libraries
    set +e
    trap - ERR
    source "$VOIDWAVE_ROOT/lib/core.sh"
    source "$VOIDWAVE_ROOT/lib/ui.sh"
    source "$VOIDWAVE_ROOT/lib/safety.sh"
    source "$VOIDWAVE_ROOT/lib/detection.sh"
    source "$VOIDWAVE_ROOT/lib/utils.sh"
    source "$VOIDWAVE_ROOT/modules/stress.sh"
    set +e
    trap - ERR
}

teardown() {
    # Clean up temp directory
    if [[ -n "$TEST_TMPDIR" ]] && [[ -d "$TEST_TMPDIR" ]]; then
        rm -rf "$TEST_TMPDIR"
    fi
}

#===============================================================================
# stress_prescan() tests
#===============================================================================

@test "stress_prescan fails on empty target" {
    run stress_prescan ""
    [ "$status" -ne 0 ]
}

@test "stress_prescan fails on invalid target (non-interactive denies)" {
    export VW_NON_INTERACTIVE=1
    # Invalid target like a protected IP should fail
    run stress_prescan "127.0.0.1"
    # In non-interactive mode, confirm_dangerous will deny
    [ "$status" -ne 0 ]
}

@test "stress_prescan shows legal warning" {
    export VW_NON_INTERACTIVE=1
    run stress_prescan "192.168.1.100"
    # Even though it fails (non-interactive denial), output should contain warning
    [[ "$output" == *"STRESS TESTING"* ]] || [[ "$output" == *"WARNING"* ]] || [[ "$output" == *"PERMISSION"* ]]
}

#===============================================================================
# run_hping_attack() tests
#===============================================================================

@test "run_hping_attack refuses when hping3 missing" {
    # Remove hping3 from PATH
    rm -f "$STUB_BIN/hping3"

    run run_hping_attack "192.168.1.1"
    [ "$status" -ne 0 ]
}

@test "run_hping_attack requires target argument" {
    run run_hping_attack ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"No target"* ]]
}

@test "run_hping_attack dry-run prints command and exits 0" {
    export VW_DRY_RUN=1
    export VW_NON_INTERACTIVE=0
    export VW_UNSAFE_MODE=1

    # Create a mock confirm_dangerous that always succeeds
    confirm_dangerous() { return 0; }
    export -f confirm_dangerous

    # Also mock validate_target to succeed
    validate_target() { return 0; }
    export -f validate_target

    run run_hping_attack "192.168.1.1" 80 syn 10 100
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY-RUN]"* ]]
    [[ "$output" == *"hping3"* ]]
}

@test "run_hping_attack rejects unknown attack type" {
    export VW_DRY_RUN=1
    export VW_UNSAFE_MODE=1

    # Mock confirm_dangerous and validate_target
    confirm_dangerous() { return 0; }
    validate_target() { return 0; }
    export -f confirm_dangerous validate_target

    run run_hping_attack "192.168.1.1" 80 "invalidtype" 10 100
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown attack type"* ]]
}

#===============================================================================
# run_netem() tests
#===============================================================================

@test "run_netem refuses when tc missing" {
    # Remove tc from PATH
    rm -f "$STUB_BIN/tc"

    run run_netem "lo"
    [ "$status" -ne 0 ]
}

@test "run_netem requires interface argument" {
    run run_netem ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"No interface"* ]]
}

@test "run_netem refuses invalid interface" {
    run run_netem "nonexistent_iface_xyz123"
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "run_netem dry-run prints command and exits 0" {
    export VW_DRY_RUN=1

    # Mock confirm_dangerous to always succeed
    confirm_dangerous() { return 0; }
    export -f confirm_dangerous

    # Use loopback interface which exists
    run run_netem "lo" delay 100ms 5
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY-RUN]"* ]]
    [[ "$output" == *"tc"* ]]
}

@test "run_netem rejects unknown impairment type" {
    export VW_DRY_RUN=1

    # Mock confirm_dangerous
    confirm_dangerous() { return 0; }
    export -f confirm_dangerous

    run run_netem "lo" "invalidimpairment" 100ms 5
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown impairment type"* ]]
}

#===============================================================================
# confirm_dangerous enforcement tests
#===============================================================================

@test "stress_prescan enforces confirm_dangerous (non-interactive denial)" {
    export VW_NON_INTERACTIVE=1
    unset VW_UNSAFE_MODE

    # Mock validate_target to succeed
    validate_target() { return 0; }
    export -f validate_target

    run stress_prescan "192.168.1.100"
    # Should fail because confirm_dangerous denies in non-interactive mode
    [ "$status" -ne 0 ]
}

@test "run_netem enforces confirm_dangerous (non-interactive denial)" {
    export VW_NON_INTERACTIVE=1
    unset VW_UNSAFE_MODE

    run run_netem "lo" delay 100ms 5
    # Should fail because confirm_dangerous denies in non-interactive mode
    [ "$status" -ne 0 ]
}

#===============================================================================
# CLI tests
#===============================================================================

@test "voidwave stress (no args) shows usage" {
    run "$VOIDWAVE" stress
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"hping"* ]]
    [[ "$output" == *"netem"* ]]
}

@test "voidwave stress hping without target fails" {
    run "$VOIDWAVE" stress hping
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing target"* ]]
}

@test "voidwave stress netem without interface fails" {
    run "$VOIDWAVE" stress netem
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing interface"* ]]
}

@test "voidwave stress unknown subcommand fails" {
    run "$VOIDWAVE" stress foobar
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown stress subcommand"* ]]
}

#===============================================================================
# Syntax check
#===============================================================================

@test "modules/stress.sh passes bash -n syntax check" {
    run bash -n "$VOIDWAVE_ROOT/modules/stress.sh"
    [ "$status" -eq 0 ]
}
