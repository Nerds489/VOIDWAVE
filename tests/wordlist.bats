#!/usr/bin/env bats
# VOIDWAVE Wordlist Tests
# Tests for lib/utils.sh wordlist management functions
# NOTE: Tests are designed to work without actual wordlists installed

setup() {
    VOIDWAVE_ROOT="$BATS_TEST_DIRNAME/.."
    export VOIDWAVE_ROOT
    export VW_NON_INTERACTIVE=1

    # Source libraries for direct function testing
    # Disable error trap for testing
    set +e
    trap - ERR
    source "$VOIDWAVE_ROOT/lib/core.sh"
    source "$VOIDWAVE_ROOT/lib/utils.sh"
    # Re-disable after sourcing
    set +e
    trap - ERR
}

teardown() {
    # Clean up any temp files created during tests
    if [[ -n "${TEST_WORDLIST:-}" ]] && [[ -f "$TEST_WORDLIST" ]]; then
        rm -f "$TEST_WORDLIST"
    fi
}

#===============================================================================
# WORDLIST_PATHS and KNOWN_WORDLISTS tests
#===============================================================================

@test "WORDLIST_PATHS array is defined and non-empty" {
    [ "${#WORDLIST_PATHS[@]}" -gt 0 ]
}

@test "WORDLIST_PATHS contains /usr/share/wordlists" {
    local found=false
    for path in "${WORDLIST_PATHS[@]}"; do
        if [[ "$path" == "/usr/share/wordlists" ]]; then
            found=true
            break
        fi
    done
    [ "$found" = "true" ]
}

@test "WORDLIST_PATHS contains /usr/share/seclists" {
    local found=false
    for path in "${WORDLIST_PATHS[@]}"; do
        if [[ "$path" == "/usr/share/seclists" ]]; then
            found=true
            break
        fi
    done
    [ "$found" = "true" ]
}

@test "KNOWN_WORDLISTS associative array is defined" {
    [ "${#KNOWN_WORDLISTS[@]}" -gt 0 ]
}

@test "KNOWN_WORDLISTS contains rockyou mapping" {
    [ -n "${KNOWN_WORDLISTS[rockyou]:-}" ]
    [[ "${KNOWN_WORDLISTS[rockyou]}" == */rockyou.txt ]]
}

@test "KNOWN_WORDLISTS contains common mapping" {
    [ -n "${KNOWN_WORDLISTS[common]:-}" ]
}

#===============================================================================
# check_wordlists() tests
#===============================================================================

@test "check_wordlists runs and exits 0" {
    run check_wordlists
    [ "$status" -eq 0 ]
}

@test "check_wordlists outputs Checking wordlists message" {
    run check_wordlists
    [[ "$output" == *"Checking wordlists"* ]]
}

@test "check_wordlists shows rockyou status" {
    run check_wordlists
    # Should show either found (✓) or not found (✗) for rockyou
    [[ "$output" == *"rockyou"* ]]
}

@test "check_wordlists shows common status" {
    run check_wordlists
    # Should show either found (✓) or not found (✗) for common
    [[ "$output" == *"common"* ]]
}

#===============================================================================
# require_wordlist() tests
#===============================================================================

@test "require_wordlist with temp file succeeds" {
    # Create a temp file with content
    TEST_WORDLIST=$(mktemp)
    echo "password123" > "$TEST_WORDLIST"
    echo "admin" >> "$TEST_WORDLIST"
    echo "root" >> "$TEST_WORDLIST"

    run require_wordlist "$TEST_WORDLIST"
    [ "$status" -eq 0 ]
    [ "$output" = "$TEST_WORDLIST" ]
}

@test "require_wordlist with nonexistent path fails" {
    run require_wordlist "/nonexistent/path/to/wordlist.txt"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Wordlist not found"* ]]
}

@test "require_wordlist with empty file fails" {
    # Create an empty temp file
    TEST_WORDLIST=$(mktemp)

    run require_wordlist "$TEST_WORDLIST"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Wordlist is empty"* ]]
}

@test "require_wordlist echoes validated path on success" {
    # Create a temp file with content
    TEST_WORDLIST=$(mktemp)
    echo "test_password" > "$TEST_WORDLIST"

    run require_wordlist "$TEST_WORDLIST"
    [ "$status" -eq 0 ]
    # Output should be the path
    [ "$output" = "$TEST_WORDLIST" ]
}

#===============================================================================
# ensure_rockyou() tests
#===============================================================================

@test "ensure_rockyou in VW_NON_INTERACTIVE=1 does not prompt" {
    export VW_NON_INTERACTIVE=1

    # Skip if rockyou actually exists (can't test the failure path)
    if [[ -f "/usr/share/wordlists/rockyou.txt" ]]; then
        skip "rockyou.txt exists on this system"
    fi

    run ensure_rockyou
    # Should fail without prompting
    [ "$status" -eq 1 ]
    # Should contain the warning message
    [[ "$output" == *"rockyou.txt not found"* ]]
}

@test "ensure_rockyou returns existing rockyou path when present (mocked)" {
    mkdir -p "$BATS_TMPDIR/usr/share/wordlists"
    export WORDLIST_BASE="$BATS_TMPDIR/usr/share/wordlists"
    echo "test" > "$WORDLIST_BASE/rockyou.txt"

    run ensure_rockyou
    [ "$status" -eq 0 ]
    [ "$output" = "$WORDLIST_BASE/rockyou.txt" ]
}

@test "ensure_rockyou handles compressed rockyou.txt.gz (mocked)" {
    mkdir -p "$BATS_TMPDIR/usr/share/wordlists"
    export WORDLIST_BASE="$BATS_TMPDIR/usr/share/wordlists"

    printf "password\nadmin\n" | gzip -c > "$WORDLIST_BASE/rockyou.txt.gz"

    run ensure_rockyou
    [ "$status" -eq 0 ]
    [ -f "$WORDLIST_BASE/rockyou.txt" ]
    [[ "$output" == *"rockyou.txt" ]]
}

#===============================================================================
# Integration tests
#===============================================================================

@test "require_wordlist with no args in non-interactive mode" {
    export VW_NON_INTERACTIVE=1

    # Skip if rockyou exists
    if [[ -f "/usr/share/wordlists/rockyou.txt" ]]; then
        skip "rockyou.txt exists on this system"
    fi

    run require_wordlist
    [ "$status" -eq 1 ]
}

@test "lib/utils.sh passes bash -n syntax check" {
    run bash -n "$VOIDWAVE_ROOT/lib/utils.sh"
    [ "$status" -eq 0 ]
}
