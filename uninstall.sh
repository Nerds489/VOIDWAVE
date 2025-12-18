#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE Uninstaller
# ═══════════════════════════════════════════════════════════════════════════════
# Removes VOIDWAVE installation including:
#   - Wrapper scripts from /usr/local/bin
#   - Install root (/opt/voidwave, /usr/local/lib/voidwave, etc.)
#   - Bash completion files
#   - User config (optional)
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Configuration
readonly BIN_DIR="${PREFIX:-/usr/local/bin}"
readonly COMP_DIR="${COMPDIR:-/etc/bash_completion.d}"

# All possible install roots (system and user)
declare -a INSTALL_ROOTS=(
    "/opt/voidwave"
    "/usr/local/lib/voidwave"
    "/usr/lib/voidwave"
    "/usr/local/share/voidwave"
)

# User paths
if [[ -n "${SUDO_USER:-}" ]]; then
    USER_HOME="/home/$SUDO_USER"
else
    USER_HOME="$HOME"
fi
readonly USER_CONFIG="$USER_HOME/.voidwave"
readonly USER_INSTALL="$USER_HOME/.local/share/voidwave"

# Add user install to roots
INSTALL_ROOTS+=("$USER_INSTALL")

#───────────────────────────────────────────────────────────────────────────────
# Output helpers
#───────────────────────────────────────────────────────────────────────────────
info()    { echo "[*] $*"; }
success() { echo "[+] $*"; }
warn()    { echo "[!] $*"; }

#───────────────────────────────────────────────────────────────────────────────
# Main uninstall logic
#───────────────────────────────────────────────────────────────────────────────
main() {
    info "Uninstalling VOIDWAVE..."
    echo ""

    local removed=0

    # Remove wrapper scripts from bin directory
    for f in "$BIN_DIR/voidwave" "$BIN_DIR/voidwave-install"; do
        if [[ -f "$f" || -L "$f" ]]; then
            if rm -f "$f" 2>/dev/null; then
                success "Removed: $f"
                ((removed++)) || true
            else
                warn "Could not remove: $f (permission denied?)"
            fi
        fi
    done

    # Remove install roots
    for root in "${INSTALL_ROOTS[@]}"; do
        if [[ -d "$root" ]]; then
            if rm -rf "$root" 2>/dev/null; then
                success "Removed: $root"
                ((removed++)) || true
            else
                warn "Could not remove: $root (permission denied?)"
            fi
        fi
    done

    # Remove completion files
    for f in "$COMP_DIR/voidwave" "$COMP_DIR/voidwave-install"; do
        if [[ -f "$f" ]]; then
            if rm -f "$f" 2>/dev/null; then
                success "Removed: $f"
                ((removed++)) || true
            else
                warn "Could not remove: $f"
            fi
        fi
    done

    # Handle user config directory
    if [[ -d "$USER_CONFIG" ]]; then
        echo ""
        if [[ -t 0 ]]; then
            read -r -p "[?] Remove user config at $USER_CONFIG? [y/N]: " ans
        else
            ans="n"
        fi

        if [[ "${ans,,}" == y* ]]; then
            if rm -rf "$USER_CONFIG" 2>/dev/null; then
                success "Removed: $USER_CONFIG"
                ((removed++)) || true
            else
                warn "Could not remove: $USER_CONFIG"
            fi
        else
            info "Keeping: $USER_CONFIG"
        fi
    fi

    echo ""
    if [[ $removed -gt 0 ]]; then
        success "Uninstall complete ($removed items removed)"
    else
        info "Nothing to uninstall (VOIDWAVE not found)"
    fi
}

main "$@"
