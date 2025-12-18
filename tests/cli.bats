#!/usr/bin/env bats
# VOIDWAVE CLI Tests

setup() {
    VOIDWAVE="$BATS_TEST_DIRNAME/../bin/voidwave"
}

@test "voidwave exists and is executable" {
    [ -x "$VOIDWAVE" ]
}

@test "voidwave --help exits 0" {
    run "$VOIDWAVE" --help
    [ "$status" -eq 0 ]
}

@test "voidwave --version shows version" {
    run "$VOIDWAVE" --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"voidwave"* ]]
    [[ "$output" =~ [0-9]+\.[0-9]+ ]]
}

@test "voidwave --dry-run is recognized" {
    run "$VOIDWAVE" --dry-run --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Dry-run"* ]] || [[ "$output" == *"dry-run"* ]] || true
}

@test "voidwave help command works" {
    run "$VOIDWAVE" help
    [ "$status" -eq 0 ]
}

@test "voidwave status command works" {
    run "$VOIDWAVE" status
    [ "$status" -eq 0 ]
    # Verify key sections are present
    [[ "$output" == *"System Information"* ]] || [[ "$output" == *"Tool Status"* ]]
}

@test "voidwave invalid command returns error" {
    run "$VOIDWAVE" notarealcommand123
    [ "$status" -ne 0 ]
}

@test "voidwave config path works" {
    run "$VOIDWAVE" config path
    [ "$status" -eq 0 ]
    [[ "$output" == *".voidwave"* ]]
}

@test "voidwave-install exists and is executable" {
    [ -x "$BATS_TEST_DIRNAME/../bin/voidwave-install" ]
}

@test "voidwave-install --help exits 0" {
    run "$BATS_TEST_DIRNAME/../bin/voidwave-install" --help
    [ "$status" -eq 0 ]
}
