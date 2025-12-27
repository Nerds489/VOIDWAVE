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
#
# VOIDWAVE_ROOT Resolution Order:
#   1. VOIDWAVE_ROOT environment variable (if set and valid)
#   2. Script's actual location (following symlinks)
#   3. /usr/local/share/voidwave (system install)
#   4. /opt/voidwave (alternative system install)
#   5. ~/.local/share/voidwave (user install)
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_VOIDWAVE_VERSION_LOADED:-}" ]] && return 0
readonly _VOIDWAVE_VERSION_LOADED=1

# --- VOIDWAVE_ROOT Resolution ------------------------------------------------
# If VOIDWAVE_ROOT is not already set, compute it from this file's location.
# This file lives in lib/, so the root is one directory up.
if [[ -z "${VOIDWAVE_ROOT:-}" ]]; then
    # Follow symlinks to get actual script location
    _vw_script_path=""
    if command -v readlink &>/dev/null; then
        _vw_script_path="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null)" || _vw_script_path="${BASH_SOURCE[0]}"
    else
        _vw_script_path="${BASH_SOURCE[0]}"
    fi

    if ! VOIDWAVE_ROOT="$(cd "$(dirname "$_vw_script_path")/.." 2>/dev/null && pwd)"; then
        # Fallback: check standard locations
        if [[ -d "/usr/local/share/voidwave/lib" ]]; then
            VOIDWAVE_ROOT="/usr/local/share/voidwave"
        elif [[ -d "/opt/voidwave/lib" ]]; then
            VOIDWAVE_ROOT="/opt/voidwave"
        elif [[ -d "${HOME}/.local/share/voidwave/lib" ]]; then
            VOIDWAVE_ROOT="${HOME}/.local/share/voidwave"
        else
            echo "ERROR: Failed to resolve VOIDWAVE_ROOT from ${BASH_SOURCE[0]}" >&2
            return 1
        fi
    fi
    unset _vw_script_path
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
