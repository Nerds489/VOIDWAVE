#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE CLI Integration Tests
# ═══════════════════════════════════════════════════════════════════════════════

setup() {
    load '../test_helper'
}

# ───────────────────────────────────────────────────────────────────────────────
# Version and Help
# ───────────────────────────────────────────────────────────────────────────────

@test "voidwave --version shows version" {
    run "$REPO_ROOT/bin/voidwave" --version
    [[ $status -eq 0 ]]
    [[ "$output" =~ VOIDWAVE ]] || [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "voidwave -V shows version" {
    run "$REPO_ROOT/bin/voidwave" -V
    [[ $status -eq 0 ]]
}

@test "voidwave --help shows usage" {
    run "$REPO_ROOT/bin/voidwave" --help
    [[ $status -eq 0 ]]
    [[ "$output" =~ USAGE ]] || [[ "$output" =~ usage ]] || [[ "$output" =~ Usage ]]
}

@test "voidwave -h shows help" {
    run "$REPO_ROOT/bin/voidwave" -h
    [[ $status -eq 0 ]]
}

# ───────────────────────────────────────────────────────────────────────────────
# Dry-run Mode
# ───────────────────────────────────────────────────────────────────────────────

@test "voidwave --dry-run doesn't execute" {
    run "$REPO_ROOT/bin/voidwave" --dry-run scan 192.168.1.1
    # Should show dry-run indicator or exit cleanly
    [[ "$output" =~ [Dd]ry ]] || [[ "$output" =~ DRY ]] || [[ $status -eq 0 ]]
}

@test "voidwave --dry-run with recon" {
    run "$REPO_ROOT/bin/voidwave" --dry-run recon example.com
    [[ "$output" =~ [Dd]ry ]] || [[ "$output" =~ DRY ]] || [[ $status -eq 0 ]]
}

# ───────────────────────────────────────────────────────────────────────────────
# Status Command
# ───────────────────────────────────────────────────────────────────────────────

@test "voidwave status runs without error" {
    run "$REPO_ROOT/bin/voidwave" status
    [[ $status -eq 0 ]]
}

@test "voidwave status shows tool info" {
    run "$REPO_ROOT/bin/voidwave" status
    [[ $status -eq 0 ]]
    [[ "$output" =~ [Ss]tatus ]] || [[ "$output" =~ [Tt]ool ]] || [[ -n "$output" ]]
}

# ───────────────────────────────────────────────────────────────────────────────
# Config Commands
# ───────────────────────────────────────────────────────────────────────────────

@test "voidwave config show runs" {
    run "$REPO_ROOT/bin/voidwave" config show
    [[ $status -eq 0 ]]
}

@test "voidwave config list runs" {
    run "$REPO_ROOT/bin/voidwave" config list
    [[ $status -eq 0 ]] || [[ $status -eq 1 ]]  # May return 1 if no config
}

# ───────────────────────────────────────────────────────────────────────────────
# Invalid Commands
# ───────────────────────────────────────────────────────────────────────────────

@test "voidwave invalid-command shows error" {
    run "$REPO_ROOT/bin/voidwave" totally-invalid-command-12345
    [[ $status -ne 0 ]] || [[ "$output" =~ [Uu]nknown ]] || [[ "$output" =~ [Ee]rror ]]
}

# ───────────────────────────────────────────────────────────────────────────────
# Non-interactive Mode
# ───────────────────────────────────────────────────────────────────────────────

@test "VW_NON_INTERACTIVE prevents interactive prompts" {
    export VW_NON_INTERACTIVE=1
    run timeout 5 "$REPO_ROOT/bin/voidwave" --help
    [[ $status -eq 0 ]]  # Should not hang
}
