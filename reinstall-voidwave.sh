#!/usr/bin/env bash
#═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE Reinstall Script
# One-shot cleanup and installation of modular VOIDWAVE (v6.x)
#═══════════════════════════════════════════════════════════════════════════════
# Usage:
#   Interactive:     sudo ./reinstall-voidwave.sh
#   Non-interactive: sudo VW_NON_INTERACTIVE=1 VW_FORCE_REINSTALL=1 ./reinstall-voidwave.sh
#
# Environment Variables:
#   VW_NON_INTERACTIVE=1  - Run without prompts (requires VW_FORCE_REINSTALL=1)
#   VW_FORCE_REINSTALL=1  - Required in non-interactive mode to proceed
#   VW_KEEP_CONFIG=1      - Skip prompt about removing user config (keep it)
#   VW_REMOVE_CONFIG=1    - Skip prompt about removing user config (remove it)
#═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail
umask 077

#───────────────────────────────────────────────────────────────────────────────
# Configuration
#───────────────────────────────────────────────────────────────────────────────
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTALL_BIN="/usr/local/bin"
readonly INSTALL_SHARE="/usr/local/share/voidwave"
readonly COMP_DIR="/etc/bash_completion.d"

#───────────────────────────────────────────────────────────────────────────────
# Immutable system detection
#───────────────────────────────────────────────────────────────────────────────
IS_IMMUTABLE=0
IS_STEAMDECK=0

# Detect immutable systems (SteamOS, Silverblue, Bazzite, etc.)
_detect_immutable() {
    # Check for SteamOS/Bazzite/ChimeraOS
    if [[ -f /etc/os-release ]]; then
        local os_id
        os_id=$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"')
        case "$os_id" in
            steamos|bazzite|chimeraos|vanilla|blendos|carbonos)
                IS_IMMUTABLE=1
                [[ "$os_id" == "steamos" || "$os_id" == "bazzite" ]] && IS_STEAMDECK=1
                return 0
                ;;
        esac
    fi

    # Check for rpm-ostree (Silverblue, Kinoite, etc.)
    if command -v rpm-ostree &>/dev/null; then
        IS_IMMUTABLE=1
        return 0
    fi

    # Check for ostree
    if [[ -d /ostree ]] || [[ -d /sysroot/ostree ]]; then
        IS_IMMUTABLE=1
        return 0
    fi

    # Check for NixOS
    if [[ -f /etc/NIXOS ]] || [[ -d /nix/store ]]; then
        IS_IMMUTABLE=1
        return 0
    fi

    # Check for read-only root
    if grep -q " / .*\bro\b" /proc/mounts 2>/dev/null; then
        IS_IMMUTABLE=1
        return 0
    fi

    return 1
}

# All possible install roots (must match install.sh)
declare -a INSTALL_ROOTS=(
    "/opt/voidwave"
    "/usr/local/lib/voidwave"
    "/usr/lib/voidwave"
    "/usr/local/share/voidwave"
)

# Determine user config directory
if [[ -n "${SUDO_USER:-}" ]]; then
    readonly USER_CONFIG="/home/$SUDO_USER/.voidwave"
    readonly USER_INSTALL_ROOT="/home/$SUDO_USER/.local/share/voidwave"
    readonly USER_BIN_DIR="/home/$SUDO_USER/.local/bin"
else
    readonly USER_CONFIG="$HOME/.voidwave"
    readonly USER_INSTALL_ROOT="$HOME/.local/share/voidwave"
    readonly USER_BIN_DIR="$HOME/.local/bin"
fi

# Read expected version from VERSION file
if [[ -f "$SCRIPT_DIR/VERSION" ]]; then
    EXPECTED_VERSION="$(cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]')"
else
    EXPECTED_VERSION="unknown"
fi
readonly EXPECTED_VERSION

#───────────────────────────────────────────────────────────────────────────────
# Output helpers
#───────────────────────────────────────────────────────────────────────────────
info()    { echo "[*] $*" >&2; }
success() { echo "[+] $*" >&2; }
warn()    { echo "[!] $*" >&2; }
fatal()   { echo "[FATAL] $*" >&2; exit 1; }

#───────────────────────────────────────────────────────────────────────────────
# Check if running non-interactively
#───────────────────────────────────────────────────────────────────────────────
is_non_interactive() {
    [[ "${VW_NON_INTERACTIVE:-0}" == "1" ]] || [[ ! -t 0 ]]
}

#───────────────────────────────────────────────────────────────────────────────
# Preflight checks
#───────────────────────────────────────────────────────────────────────────────
preflight_checks() {
    # Detect immutable systems first
    _detect_immutable || true

    # On immutable systems, allow non-root execution for user-mode reinstall
    if [[ $IS_IMMUTABLE -eq 1 ]]; then
        if [[ $EUID -ne 0 ]]; then
            info "Immutable system detected - running in user-mode reinstall"
        else
            warn "Immutable system detected (read-only root filesystem)"
            warn "Will only reinstall to user directory: $USER_INSTALL_ROOT"
        fi
    else
        # Standard systems must be run as root
        if [[ $EUID -ne 0 ]]; then
            fatal "This script must be run as root. Use: sudo $0"
        fi
    fi

    # Check source files exist (modular structure)
    [[ -f "$SCRIPT_DIR/bin/voidwave" ]] || fatal "Source not found: $SCRIPT_DIR/bin/voidwave"
    [[ -d "$SCRIPT_DIR/lib" ]] || fatal "Source not found: $SCRIPT_DIR/lib/"
    [[ -d "$SCRIPT_DIR/modules" ]] || fatal "Source not found: $SCRIPT_DIR/modules/"
    [[ -f "$SCRIPT_DIR/install.sh" ]] || fatal "Source not found: $SCRIPT_DIR/install.sh"

    # Non-interactive mode requires explicit force flag
    if is_non_interactive; then
        if [[ "${VW_FORCE_REINSTALL:-0}" != "1" ]]; then
            fatal "Non-interactive mode requires VW_FORCE_REINSTALL=1 to proceed.
       This is a safety measure to prevent accidental reinstalls in CI/automation.

       To run non-interactively:
         sudo VW_NON_INTERACTIVE=1 VW_FORCE_REINSTALL=1 $0"
        fi
    fi
}

#───────────────────────────────────────────────────────────────────────────────
# Show what will be done
#───────────────────────────────────────────────────────────────────────────────
show_plan() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "  VOIDWAVE Reinstall Script"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "  Source directory: $SCRIPT_DIR"
    echo "  Target version:   $EXPECTED_VERSION"
    if [[ $IS_IMMUTABLE -eq 1 ]]; then
        echo "  System type:      Immutable (read-only root)"
        if [[ $IS_STEAMDECK -eq 1 ]]; then
            echo "  Platform:         Steam Deck / SteamOS"
        fi
    fi
    echo ""
    echo "  This script will:"
    echo ""
    echo "  UNINSTALL (remove):"
    if [[ $IS_IMMUTABLE -eq 1 ]]; then
        echo "    - $USER_BIN_DIR/voidwave"
        echo "    - $USER_BIN_DIR/voidwave-install"
        echo "    - $USER_INSTALL_ROOT/"
    else
        echo "    - $INSTALL_BIN/voidwave"
        echo "    - $INSTALL_BIN/voidwave-install"
        echo "    - Install roots: /opt/voidwave, /usr/local/lib/voidwave, etc."
        echo "    - $COMP_DIR/voidwave* (if exists)"
    fi
    if [[ -d "$USER_CONFIG" ]]; then
        echo "    - $USER_CONFIG/ (will prompt)"
    fi
    echo ""
    echo "  INSTALL (create):"
    if [[ $IS_IMMUTABLE -eq 1 ]]; then
        echo "    - Run ./install.sh --user to install to $USER_INSTALL_ROOT"
    else
        echo "    - Run ./install.sh to install modular v6.x"
    fi
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
}

#───────────────────────────────────────────────────────────────────────────────
# Prompt for confirmation (interactive only)
#───────────────────────────────────────────────────────────────────────────────
confirm_proceed() {
    if is_non_interactive; then
        info "Non-interactive mode with VW_FORCE_REINSTALL=1 - proceeding automatically"
        return 0
    fi

    echo -n "[?] Proceed with reinstall? [y/N]: "
    read -r response < /dev/tty || response="n"
    if [[ "${response,,}" != "y" && "${response,,}" != "yes" ]]; then
        info "Reinstall cancelled by user."
        exit 0
    fi
}

#───────────────────────────────────────────────────────────────────────────────
# Phase 1: Uninstall
#───────────────────────────────────────────────────────────────────────────────
phase_uninstall() {
    echo ""
    info "Phase 1: Uninstalling..."
    echo ""

    # On immutable systems, only clean user paths
    if [[ $IS_IMMUTABLE -eq 1 ]]; then
        info "Immutable system - removing user installation only"

        # Remove user binaries
        for f in "$USER_BIN_DIR"/voidwave "$USER_BIN_DIR"/voidwave-install "$USER_BIN_DIR"/voidwave.old "$USER_BIN_DIR"/voidwave.bak; do
            if [[ -f "$f" ]]; then
                if rm -f "$f" 2>/dev/null; then
                    success "Removed: $f"
                else
                    warn "Could not remove: $f (continuing anyway)"
                fi
            fi
        done

        # Remove user install root
        if [[ -d "$USER_INSTALL_ROOT" ]]; then
            if rm -rf "$USER_INSTALL_ROOT" 2>/dev/null; then
                success "Removed: $USER_INSTALL_ROOT"
            else
                warn "Could not remove: $USER_INSTALL_ROOT (continuing anyway)"
            fi
        fi

        if [[ $IS_STEAMDECK -eq 1 ]]; then
            info "Note: System paths skipped on Steam Deck (read-only root)"
        fi
    else
        # Standard system cleanup
        # Try using uninstall.sh if it exists (but don't prompt for config removal)
        if [[ -x "$SCRIPT_DIR/uninstall.sh" ]]; then
            info "Running uninstall.sh..."
            # Run uninstall.sh but feed it 'n' to skip config removal (we handle it separately)
            echo "n" | "$SCRIPT_DIR/uninstall.sh" 2>/dev/null || true
        fi

        # Remove legacy and current binaries from /usr/local/bin
        for f in "$INSTALL_BIN"/voidwave "$INSTALL_BIN"/voidwave-install "$INSTALL_BIN"/voidwave.old "$INSTALL_BIN"/voidwave.bak; do
            if [[ -f "$f" ]]; then
                if rm -f "$f" 2>/dev/null; then
                    success "Removed: $f"
                else
                    warn "Could not remove: $f (continuing anyway)"
                fi
            fi
        done

        # Remove all possible install roots
        for root in "${INSTALL_ROOTS[@]}"; do
            if [[ -d "$root" ]]; then
                if rm -rf "$root" 2>/dev/null; then
                    success "Removed: $root"
                else
                    warn "Could not remove: $root (continuing anyway)"
                fi
            fi
        done

        # Remove completion files
        for f in "$COMP_DIR"/voidwave "$COMP_DIR"/voidwave-install; do
            if [[ -f "$f" ]]; then
                rm -f "$f" 2>/dev/null && success "Removed: $f" || true
            fi
        done
    fi

    # Handle user config directory
    if [[ -d "$USER_CONFIG" ]]; then
        local remove_config="n"

        if [[ "${VW_REMOVE_CONFIG:-0}" == "1" ]]; then
            remove_config="y"
        elif [[ "${VW_KEEP_CONFIG:-0}" == "1" ]]; then
            remove_config="n"
        elif is_non_interactive; then
            remove_config="n"  # Default to keeping config in non-interactive mode
        else
            echo ""
            echo -n "[?] Remove user config at $USER_CONFIG? [y/N]: "
            read -r remove_config < /dev/tty || remove_config="n"
        fi

        if [[ "${remove_config,,}" == "y" || "${remove_config,,}" == "yes" ]]; then
            if rm -rf "$USER_CONFIG" 2>/dev/null; then
                success "Removed: $USER_CONFIG"
            else
                warn "Could not remove: $USER_CONFIG"
            fi
        else
            info "Keeping: $USER_CONFIG"
        fi
    fi

    success "Uninstall phase complete"
}

#───────────────────────────────────────────────────────────────────────────────
# Phase 2: Install
#───────────────────────────────────────────────────────────────────────────────
phase_install() {
    echo ""
    info "Phase 2: Installing modular VOIDWAVE..."
    echo ""

    if [[ ! -x "$SCRIPT_DIR/install.sh" ]]; then
        fatal "install.sh not found or not executable at $SCRIPT_DIR/install.sh"
    fi

    # Run install.sh with appropriate flags
    if [[ $IS_IMMUTABLE -eq 1 ]]; then
        info "Installing to user directory (immutable system)"
        if [[ $IS_STEAMDECK -eq 1 ]]; then
            info "Steam Deck: Installation will persist across SteamOS updates"
        fi
        if ! "$SCRIPT_DIR/install.sh" --user; then
            fatal "Installation failed. Check output above for details."
        fi
    else
        # Standard system install (it handles everything including legacy cleanup verification)
        if ! "$SCRIPT_DIR/install.sh"; then
            fatal "Installation failed. Check output above for details."
        fi
    fi

    success "Install phase complete"
}

#───────────────────────────────────────────────────────────────────────────────
# Phase 3: Verification
#───────────────────────────────────────────────────────────────────────────────
phase_verify() {
    echo ""
    info "Phase 3: Verifying installation..."
    echo ""

    local fail=0

    # Check command exists in PATH
    if ! command -v voidwave &>/dev/null; then
        warn "FAIL: 'voidwave' command not found in PATH"
        fail=1
    else
        success "voidwave found: $(command -v voidwave)"
    fi

    # Check version matches expected
    local installed_version=""
    if installed_version=$(voidwave --version 2>&1); then
        # Extract version number (format: "voidwave vX.Y.Z ...")
        local ver_num
        ver_num=$(echo "$installed_version" | grep -oP 'v?\K[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")

        if [[ -z "$ver_num" ]]; then
            warn "FAIL: Could not parse version from: $installed_version"
            fail=1
        elif [[ "$ver_num" != "$EXPECTED_VERSION" ]]; then
            warn "FAIL: Version mismatch - expected $EXPECTED_VERSION, got $ver_num"
            fail=1
        else
            success "Version verified: $ver_num"
        fi
    else
        warn "FAIL: 'voidwave --version' failed"
        fail=1
    fi

    # Check binary is the modular wrapper (not monolith)
    local installed_bin
    installed_bin=$(command -v voidwave 2>/dev/null || echo "")
    if [[ -n "$installed_bin" && -f "$installed_bin" ]]; then
        local file_size
        file_size=$(stat -c%s "$installed_bin" 2>/dev/null || stat -f%z "$installed_bin" 2>/dev/null || echo "0")

        if [[ "$file_size" -gt 100000 ]]; then
            warn "FAIL: Installed binary appears to be legacy monolith (size: ${file_size} bytes)"
            fail=1
        else
            success "Binary size OK: ${file_size} bytes (modular wrapper)"
        fi
    fi

    echo ""

    if [[ $fail -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

#───────────────────────────────────────────────────────────────────────────────
# Main
#───────────────────────────────────────────────────────────────────────────────
main() {
    preflight_checks
    show_plan
    confirm_proceed

    phase_uninstall
    phase_install

    if phase_verify; then
        echo ""
        echo "═══════════════════════════════════════════════════════════════════════════════"
        success "VOIDWAVE v$EXPECTED_VERSION reinstalled successfully!"
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo ""
        if [[ $IS_IMMUTABLE -eq 1 ]]; then
            echo "  Installation type: User-mode (immutable system)"
            echo "  Install location:  $USER_INSTALL_ROOT"
            echo "  Binaries:          $USER_BIN_DIR"
            if [[ $IS_STEAMDECK -eq 1 ]]; then
                echo ""
                echo "  Steam Deck Notes:"
                echo "    - Installation is in your home directory and will persist"
                echo "    - Add $USER_BIN_DIR to your PATH if not already added"
                echo "    - Use Desktop Mode for best VOIDWAVE experience"
            fi
        fi
        echo ""
        echo "  Commands:"
        echo "    voidwave --help       Show help"
        echo "    voidwave --version    Show version"
        echo "    voidwave status       Show tool status"
        echo "    voidwave config show  Show configuration"
        echo ""
        if [[ $IS_IMMUTABLE -eq 1 ]] || [[ -n "$USER_BIN_DIR" ]]; then
            echo "  If 'voidwave' is not found, restart your terminal or run:"
            echo "    source ~/.bashrc"
            echo ""
        fi
        exit 0
    else
        echo ""
        echo "═══════════════════════════════════════════════════════════════════════════════"
        warn "Reinstall completed with verification errors."
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "  Check the output above for details."
        if [[ $IS_IMMUTABLE -eq 1 ]]; then
            echo "  You may need to manually investigate or run:"
            echo "    rm -f $USER_BIN_DIR/voidwave*"
            echo "    ./install.sh --user"
        else
            echo "  You may need to manually investigate or run:"
            echo "    sudo rm -f /usr/local/bin/voidwave*"
            echo "    sudo ./install.sh"
        fi
        echo ""
        exit 1
    fi
}

main "$@"
