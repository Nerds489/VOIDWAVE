#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE - Version Resolution Helper
# ═══════════════════════════════════════════════════════════════════════════════
# Copyright (c) 2025 Nerds489
# SPDX-License-Identifier: Apache-2.0
#
# Shared helper for resolving VOIDWAVE_ROOT and VERSION.
# This centralizes version handling to prevent drift between CLI output,
# VERSION file, documentation, and release workflow.
#
# Usage:
#   source "$VOIDWAVE_ROOT/lib/version.sh"   # If VOIDWAVE_ROOT is already set
#   source "/path/to/lib/version.sh"          # Auto-detects VOIDWAVE_ROOT
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_VERSION_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_VERSION_LOADED=1

# --- VOIDWAVE_ROOT Resolution ------------------------------------------------
# If VOIDWAVE_ROOT is not already set, compute it from this file's location.
# This file lives in lib/, so the root is one directory up.
if [[ -z "${VOIDWAVE_ROOT:-}" ]]; then
    if ! VOIDWAVE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"; then
        echo "ERROR: Failed to resolve VOIDWAVE_ROOT from ${BASH_SOURCE[0]}" >&2
        return 1
    fi
fi
readonly VOIDWAVE_ROOT 2>/dev/null || true  # May already be readonly

# --- VERSION Resolution -------------------------------------------------------
# Read VERSION file (first line, strip whitespace). Fallback to "unknown".
if [[ -z "${VERSION:-}" ]]; then
    if [[ -f "$VOIDWAVE_ROOT/VERSION" ]]; then
        IFS= read -r VERSION < "$VOIDWAVE_ROOT/VERSION"
        VERSION="${VERSION//[[:space:]]/}"
    else
        VERSION="unknown"
    fi
fi
readonly VERSION 2>/dev/null || true  # May already be readonly

# --- Exports ------------------------------------------------------------------
export VOIDWAVE_ROOT VERSION
