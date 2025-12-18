#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Test Suite: Configuration System
# ═══════════════════════════════════════════════════════════════════════════════
# Tests for persistent configuration management
# ═══════════════════════════════════════════════════════════════════════════════

# Get the project root directory
VOIDWAVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# Setup - use temporary HOME to avoid modifying real config
setup() {
    # Create temporary home directory for test isolation
    export TEST_HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$TEST_HOME"

    # Override HOME and VOIDWAVE paths to use temp directory
    export HOME="$TEST_HOME"
    export VOIDWAVE_HOME="$TEST_HOME/.voidwave"
    export VOIDWAVE_CONFIG_DIR="$VOIDWAVE_HOME/config"
    export VOIDWAVE_CONFIG_FILE="$VOIDWAVE_CONFIG_DIR/config.conf"

    # Suppress extraneous output during tests
    export VW_SUPPRESS_OUTPUT=1

    # Path to voidwave CLI
    VOIDWAVE="$BATS_TEST_DIRNAME/../bin/voidwave"
}

# Teardown - cleanup temp files
teardown() {
    rm -rf "$TEST_HOME" 2>/dev/null || true
}

#───────────────────────────────────────────────────────────────────────────────
# Config show tests
#───────────────────────────────────────────────────────────────────────────────

@test "voidwave config show returns 0" {
    run "$VOIDWAVE" config show
    [ "$status" -eq 0 ]
}

@test "voidwave config show displays configuration header" {
    run "$VOIDWAVE" config show
    [ "$status" -eq 0 ]
    [[ "$output" == *"Configuration"* ]]
}

@test "voidwave config show displays config file path" {
    run "$VOIDWAVE" config show
    [ "$status" -eq 0 ]
    [[ "$output" == *".voidwave"* ]]
}

@test "voidwave config (no subcommand) shows config" {
    run "$VOIDWAVE" config
    [ "$status" -eq 0 ]
    [[ "$output" == *"Configuration"* ]]
}

#───────────────────────────────────────────────────────────────────────────────
# Config get tests
#───────────────────────────────────────────────────────────────────────────────

@test "voidwave config get log_level returns non-empty value" {
    run "$VOIDWAVE" config get log_level
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "voidwave config get log_level returns INFO by default" {
    run "$VOIDWAVE" config get log_level
    [ "$status" -eq 0 ]
    [ "$output" = "INFO" ]
}

@test "voidwave config get file_logging returns true by default" {
    run "$VOIDWAVE" config get file_logging
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "voidwave config get without key fails" {
    run "$VOIDWAVE" config get
    [ "$status" -ne 0 ]
}

@test "voidwave config get nonexistent_key fails" {
    run "$VOIDWAVE" config get nonexistent_key_xyz123
    [ "$status" -ne 0 ]
}

#───────────────────────────────────────────────────────────────────────────────
# Config set tests
#───────────────────────────────────────────────────────────────────────────────

@test "voidwave config set test_key test_value persists" {
    # Set a test key
    run "$VOIDWAVE" config set test_key test_value
    [ "$status" -eq 0 ]

    # Get should return the value
    run "$VOIDWAVE" config get test_key
    [ "$status" -eq 0 ]
    [ "$output" = "test_value" ]
}

@test "voidwave config set updates existing key" {
    # Set initial value
    run "$VOIDWAVE" config set log_level DEBUG
    [ "$status" -eq 0 ]

    # Verify it was set
    run "$VOIDWAVE" config get log_level
    [ "$status" -eq 0 ]
    [ "$output" = "DEBUG" ]
}

@test "voidwave config set without key fails" {
    run "$VOIDWAVE" config set
    [ "$status" -ne 0 ]
}

@test "voidwave config set without value fails" {
    run "$VOIDWAVE" config set somekey
    [ "$status" -ne 0 ]
}

#───────────────────────────────────────────────────────────────────────────────
# Config path tests
#───────────────────────────────────────────────────────────────────────────────

@test "voidwave config path returns correct path" {
    run "$VOIDWAVE" config path
    [ "$status" -eq 0 ]
    [[ "$output" == *".voidwave/config/config.conf"* ]]
}

#───────────────────────────────────────────────────────────────────────────────
# Config edit tests (non-interactive behavior)
#───────────────────────────────────────────────────────────────────────────────

@test "voidwave config edit fails in non-interactive mode" {
    export VW_NON_INTERACTIVE=1
    run "$VOIDWAVE" config edit
    [ "$status" -ne 0 ]
}

@test "voidwave config edit fails without TTY" {
    # Run without TTY by piping input
    run bash -c "echo '' | $VOIDWAVE config edit"
    [ "$status" -ne 0 ]
}

#───────────────────────────────────────────────────────────────────────────────
# Config reset tests
#───────────────────────────────────────────────────────────────────────────────

@test "voidwave config reset restores defaults in non-interactive mode" {
    # First, change a value
    run "$VOIDWAVE" config set log_level DEBUG
    [ "$status" -eq 0 ]

    # Reset in non-interactive mode (skips confirmation)
    export VW_NON_INTERACTIVE=1
    run "$VOIDWAVE" config reset
    [ "$status" -eq 0 ]

    # Verify it was reset to default
    unset VW_NON_INTERACTIVE
    run "$VOIDWAVE" config get log_level
    [ "$status" -eq 0 ]
    [ "$output" = "INFO" ]
}

#───────────────────────────────────────────────────────────────────────────────
# Config file creation tests
#───────────────────────────────────────────────────────────────────────────────

@test "config file is created on first run" {
    # Remove any existing config
    rm -f "$VOIDWAVE_CONFIG_FILE"

    # Run a command that triggers init_config
    run "$VOIDWAVE" config show
    [ "$status" -eq 0 ]

    # Verify config file was created
    [ -f "$VOIDWAVE_CONFIG_FILE" ]
}

@test "config file has correct permissions" {
    run "$VOIDWAVE" config show
    [ "$status" -eq 0 ]

    # Check permissions (should be 600)
    perms=$(stat -c %a "$VOIDWAVE_CONFIG_FILE" 2>/dev/null || stat -f %Lp "$VOIDWAVE_CONFIG_FILE" 2>/dev/null)
    [ "$perms" = "600" ]
}

@test "config directory is created if missing" {
    # Remove config directory
    rm -rf "$VOIDWAVE_CONFIG_DIR"

    # Run command
    run "$VOIDWAVE" config show
    [ "$status" -eq 0 ]

    # Verify directory was created
    [ -d "$VOIDWAVE_CONFIG_DIR" ]
}

#───────────────────────────────────────────────────────────────────────────────
# Invalid subcommand tests
#───────────────────────────────────────────────────────────────────────────────

@test "voidwave config invalid_subcommand fails" {
    run "$VOIDWAVE" config invalid_subcommand_xyz
    [ "$status" -ne 0 ]
}

#───────────────────────────────────────────────────────────────────────────────
# Custom key persistence tests
#───────────────────────────────────────────────────────────────────────────────

@test "custom keys survive config reload" {
    # Set a custom key
    run "$VOIDWAVE" config set my_custom_setting my_custom_value
    [ "$status" -eq 0 ]

    # Set another key to trigger a file rewrite
    run "$VOIDWAVE" config set log_level WARNING
    [ "$status" -eq 0 ]

    # Custom key should still be there
    run "$VOIDWAVE" config get my_custom_setting
    [ "$status" -eq 0 ]
    [ "$output" = "my_custom_value" ]
}
