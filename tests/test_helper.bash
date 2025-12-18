#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE Test Helper
# ═══════════════════════════════════════════════════════════════════════════════
# Common setup for all bats tests

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT
export VOIDWAVE_ROOT="$REPO_ROOT"
export NR_NON_INTERACTIVE=1
export NO_COLOR=1
export TEST_TEMP="/tmp/voidwave_test_$$"

mkdir -p "$TEST_TEMP"
trap 'rm -rf "$TEST_TEMP"' EXIT
