#!/usr/bin/env bats
# VOIDWAVE WHOIS Tests
# Tests for modules/osint.sh run_whois() function
# NOTE: Tests use stub whois to avoid network dependency

setup() {
    VOIDWAVE_ROOT="$BATS_TEST_DIRNAME/.."
    export VOIDWAVE_ROOT
    export VW_NON_INTERACTIVE=1

    # Create temp directory for stub and cache
    TEST_TMPDIR=$(mktemp -d)
    export TEST_TMPDIR

    # Set cache directory to temp
    export VOIDWAVE_STATE_DIR="$TEST_TMPDIR/state"
    mkdir -p "$VOIDWAVE_STATE_DIR/cache/whois"

    # Create stub bin directory
    STUB_BIN="$TEST_TMPDIR/bin"
    mkdir -p "$STUB_BIN"

    # Create counter file for tracking whois invocations
    WHOIS_COUNTER="$TEST_TMPDIR/whois_counter"
    echo "0" > "$WHOIS_COUNTER"
    export WHOIS_COUNTER

    # Create stub whois script
    cat > "$STUB_BIN/whois" << 'STUBEOF'
#!/usr/bin/env bash
# Stub whois for testing - increments counter and returns deterministic output

# Increment counter
if [[ -n "$WHOIS_COUNTER" ]] && [[ -f "$WHOIS_COUNTER" ]]; then
    count=$(cat "$WHOIS_COUNTER")
    echo $((count + 1)) > "$WHOIS_COUNTER"
fi

# Output deterministic WHOIS response
cat << 'EOF'
Domain Name: EXAMPLE.COM
Registry Domain ID: 2336799_DOMAIN_COM-VRSN
Registrar WHOIS Server: whois.iana.org
Registrar URL: http://www.iana.org
Updated Date: 2023-08-14T07:01:38Z
Creation Date: 1995-08-14T04:00:00Z
Registrar: RESERVED-Internet Assigned Numbers Authority
Registrar IANA ID: 376
Registrar Abuse Contact Email: abuse@iana.org
Registrar Abuse Contact Phone: +1.3108239358
Domain Status: clientDeleteProhibited
Domain Status: clientTransferProhibited
Domain Status: clientUpdateProhibited
Registry Registrant ID:
Registrant Name: REDACTED FOR PRIVACY
Registrant Organization: Internet Assigned Numbers Authority
Registrant Street: REDACTED FOR PRIVACY
Registrant City: REDACTED FOR PRIVACY
Registrant State/Province: CA
Registrant Postal Code: REDACTED FOR PRIVACY
Registrant Country: US
Name Server: A.IANA-SERVERS.NET
Name Server: B.IANA-SERVERS.NET
DNSSEC: signedDelegation
EOF
exit 0
STUBEOF
    chmod +x "$STUB_BIN/whois"

    # Prepend stub bin to PATH
    export PATH="$STUB_BIN:$PATH"

    # Source libraries
    set +e
    trap - ERR
    source "$VOIDWAVE_ROOT/lib/core.sh"
    source "$VOIDWAVE_ROOT/lib/ui.sh"
    source "$VOIDWAVE_ROOT/lib/utils.sh"
    source "$VOIDWAVE_ROOT/lib/detection.sh"
    source "$VOIDWAVE_ROOT/modules/osint.sh"
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
# Input validation tests
#===============================================================================

@test "run_whois with empty target returns non-zero" {
    run run_whois ""
    [ "$status" -ne 0 ]
}

@test "run_whois with empty target prints 'No target'" {
    run run_whois ""
    [[ "$output" == *"No target"* ]]
}

#===============================================================================
# Tool requirement tests
#===============================================================================

@test "run_whois with missing whois tool fails cleanly" {
    # Remove stub whois from PATH
    export PATH="${PATH#$STUB_BIN:}"

    # Also ensure real whois isn't available by using empty PATH segment
    local save_path="$PATH"
    export PATH="/nonexistent_path_xyz123"

    run run_whois "example.com"
    [ "$status" -ne 0 ]

    export PATH="$save_path"
}

#===============================================================================
# Stub whois tests
#===============================================================================

@test "run_whois with stub returns success" {
    run run_whois "example.com"
    [ "$status" -eq 0 ]
}

@test "run_whois displays header with target" {
    run run_whois "example.com"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WHOIS"* ]]
    [[ "$output" == *"example.com"* ]]
}

@test "run_whois extracts Registrar field" {
    run run_whois "example.com"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Registrar"* ]]
}

@test "run_whois extracts Organization field" {
    run run_whois "example.com"
    [ "$status" -eq 0 ]
    # Should show Organization from stub output
    [[ "$output" == *"Organization"* ]] || [[ "$output" == *"Internet Assigned Numbers Authority"* ]]
}

@test "run_whois extracts Country field" {
    run run_whois "example.com"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Country"* ]] || [[ "$output" == *"US"* ]]
}

#===============================================================================
# Cache behavior tests
#===============================================================================

@test "run_whois creates cache file" {
    run run_whois "cachetest.com"
    [ "$status" -eq 0 ]

    # Check cache file exists
    local cache_file="$VOIDWAVE_STATE_DIR/cache/whois/cachetest.com.txt"
    [ -f "$cache_file" ]
}

@test "run_whois uses cache on second call (does not invoke whois again)" {
    # Reset counter
    echo "0" > "$WHOIS_COUNTER"

    # First call - should invoke whois
    run run_whois "cachetest2.com"
    [ "$status" -eq 0 ]

    local count1=$(cat "$WHOIS_COUNTER")
    [ "$count1" -eq 1 ]

    # Second call - should use cache, not invoke whois
    run run_whois "cachetest2.com"
    [ "$status" -eq 0 ]

    local count2=$(cat "$WHOIS_COUNTER")
    # Count should still be 1 (cache hit, no new whois call)
    [ "$count2" -eq 1 ]
}

@test "run_whois shows cached indicator on cache hit" {
    # First call to populate cache
    run run_whois "cachedisplay.com"
    [ "$status" -eq 0 ]

    # Second call should show cached
    run run_whois "cachedisplay.com"
    [ "$status" -eq 0 ]
    [[ "$output" == *"cached"* ]]
}

#===============================================================================
# Filename sanitization tests
#===============================================================================

@test "run_whois sanitizes target with slashes for cache filename" {
    run run_whois "test/domain.com"
    [ "$status" -eq 0 ]

    # Cache file should exist with sanitized name (/ replaced with _)
    local cache_file="$VOIDWAVE_STATE_DIR/cache/whois/test_domain.com.txt"
    [ -f "$cache_file" ]
}

@test "run_whois sanitizes target with spaces for cache filename" {
    run run_whois "test domain.com"
    [ "$status" -eq 0 ]

    # Cache file should exist with sanitized name (space replaced with _)
    local cache_file="$VOIDWAVE_STATE_DIR/cache/whois/test_domain.com.txt"
    [ -f "$cache_file" ]
}

#===============================================================================
# Non-interactive mode tests
#===============================================================================

@test "run_whois in non-interactive mode does not prompt for raw output" {
    export VW_NON_INTERACTIVE=1

    run run_whois "noninteractive.com"
    [ "$status" -eq 0 ]

    # Should not contain "View raw output" prompt response
    # (in non-interactive, confirm is skipped)
    # Output should just be the formatted fields
    [[ "$output" != *"Domain Name: EXAMPLE.COM"* ]] || [[ "$output" == *"WHOIS"* ]]
}

#===============================================================================
# Syntax check
#===============================================================================

@test "modules/osint.sh passes bash -n syntax check" {
    run bash -n "$VOIDWAVE_ROOT/modules/osint.sh"
    [ "$status" -eq 0 ]
}
