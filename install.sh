#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE System Installer
# ═══════════════════════════════════════════════════════════════════════════════
# Copies VOIDWAVE to a system root and creates callable wrappers.
# Supports all major Linux families: Debian, Fedora, Arch, openSUSE, Alpine.
#
# Usage:
#   sudo ./install.sh              # System install to /opt/voidwave
#   ./install.sh --user            # User install to ~/.local/share/voidwave
#   sudo ./install.sh --force      # Overwrite existing installation
#   sudo ./install.sh --uninstall  # Remove installation
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Source directory (where this script lives)
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#═══════════════════════════════════════════════════════════════════════════════
# IMMUTABLE/SPECIAL SYSTEM DETECTION
#═══════════════════════════════════════════════════════════════════════════════

IS_IMMUTABLE=0
IS_STEAMDECK=0
IS_WSL=0

# Detect immutable systems (SteamOS, Silverblue, Bazzite, etc.)
_detect_immutable() {
    # Check for SteamOS/Bazzite/ChimeraOS
    if [[ -f /etc/os-release ]]; then
        local os_id
        os_id=$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"')
        case "$os_id" in
            steamos|bazzite|chimeraos|vanilla|blendos)
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

# Detect WSL
_detect_wsl() {
    if [[ -f /proc/version ]] && grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then
        IS_WSL=1
        return 0
    fi
    if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        IS_WSL=1
        return 0
    fi
    return 1
}

#═══════════════════════════════════════════════════════════════════════════════
# ARGUMENT PARSING
#═══════════════════════════════════════════════════════════════════════════════

OPT_FORCE=0
OPT_USER=0
OPT_UNINSTALL=0
TOOL_INSTALL_ARGS=()

_show_help() {
    cat << 'HELPTEXT'
VOIDWAVE Installer

Usage:
  sudo ./install.sh [OPTIONS] [-- TOOL_INSTALLER_ARGS...]

Options:
  --force       Overwrite existing installation
  --user        Install to user directory (~/.local/share/voidwave)
  --uninstall   Remove existing installation
  --help        Show this help message

System Install (requires root):
  Installs to: /opt/voidwave (preferred) or /usr/local/lib/voidwave
  Wrapper to:  /usr/local/bin or /usr/bin

User Install (no root required):
  Installs to: ~/.local/share/voidwave
  Wrapper to:  ~/.local/bin

Examples:
  sudo ./install.sh                    # Standard system install
  sudo ./install.sh --force            # Overwrite existing install
  ./install.sh --user                  # User-local install
  sudo ./install.sh -- --all           # Install + run tool installer with --all
HELPTEXT
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            OPT_FORCE=1
            shift
            ;;
        --user)
            OPT_USER=1
            shift
            ;;
        --uninstall)
            OPT_UNINSTALL=1
            shift
            ;;
        --help|-h)
            _show_help
            exit 0
            ;;
        --)
            shift
            TOOL_INSTALL_ARGS=("$@")
            break
            ;;
        *)
            # Assume remaining args are for tool installer (backwards compat)
            TOOL_INSTALL_ARGS=("$@")
            break
            ;;
    esac
done

#═══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

_log() {
    echo "[*] $*" >&2
}

_warn() {
    echo "[!] $*" >&2
}

_error() {
    echo "[FATAL] $*" >&2
}

_success() {
    echo "[✓] $*" >&2
}

# Check if running as root
_is_root() {
    [[ $EUID -eq 0 ]]
}

# Check if a directory is writable (or can be created)
_is_writable() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        [[ -w "$dir" ]]
    else
        # Check if parent is writable (for creation)
        local parent
        parent="$(dirname "$dir")"
        [[ -d "$parent" && -w "$parent" ]]
    fi
}

# Check if a directory is in PATH
_dir_in_path() {
    local dir="$1"
    [[ ":$PATH:" == *":$dir:"* ]]
}

#═══════════════════════════════════════════════════════════════════════════════
# INSTALL LOCATION SELECTION
#═══════════════════════════════════════════════════════════════════════════════

# Select the install root directory
# Sets: INSTALL_ROOT, BIN_DIR
_select_install_locations() {
    # Detect special systems first
    _detect_immutable || true
    _detect_wsl || true

    # Force user install on immutable systems
    if [[ $IS_IMMUTABLE -eq 1 ]] && [[ $OPT_USER -eq 0 ]]; then
        _warn "Immutable system detected (SteamOS/Silverblue/etc.)"
        _warn "Forcing user-mode installation to ~/.local/share/voidwave"
        OPT_USER=1
    fi

    if [[ $OPT_USER -eq 1 ]] || ! _is_root; then
        # User install
        INSTALL_ROOT="${HOME}/.local/share/voidwave"
        BIN_DIR="${HOME}/.local/bin"
        _log "User install mode selected"

        # Special handling for Steam Deck
        if [[ $IS_STEAMDECK -eq 1 ]]; then
            _log "Steam Deck detected - using optimized user install"
        fi
    else
        # System install - try locations in priority order
        local -a roots=("/opt/voidwave" "/usr/local/lib/voidwave" "/usr/lib/voidwave")
        INSTALL_ROOT=""

        for root in "${roots[@]}"; do
            if _is_writable "$(dirname "$root")"; then
                INSTALL_ROOT="$root"
                break
            fi
        done

        if [[ -z "$INSTALL_ROOT" ]]; then
            # Fallback to user install instead of failing
            _warn "Cannot write to system directories, falling back to user install"
            INSTALL_ROOT="${HOME}/.local/share/voidwave"
            BIN_DIR="${HOME}/.local/bin"
            OPT_USER=1
            _log "User install mode selected (fallback)"
        else
            # Select bin directory
            if _is_writable "/usr/local/bin" || [[ ! -d "/usr/local/bin" ]]; then
                BIN_DIR="/usr/local/bin"
            elif _is_writable "/usr/bin"; then
                BIN_DIR="/usr/bin"
            else
                # Fallback to user bin
                _warn "Cannot write to system bin directories, using user bin"
                BIN_DIR="${HOME}/.local/bin"
            fi

            _log "System install mode selected"
        fi
    fi

    _log "Install root: $INSTALL_ROOT"
    _log "Bin directory: $BIN_DIR"
}

#═══════════════════════════════════════════════════════════════════════════════
# UNINSTALL
#═══════════════════════════════════════════════════════════════════════════════

_do_uninstall() {
    _log "Uninstalling VOIDWAVE..."

    local -a roots=("/opt/voidwave" "/usr/local/lib/voidwave" "/usr/lib/voidwave" "${HOME}/.local/share/voidwave")
    local -a bins=("/usr/local/bin" "/usr/bin" "${HOME}/.local/bin")
    local uninstall_removed_any=0
    local uninstall_failed_any=0

    # Remove install roots
    for root in "${roots[@]}"; do
        if [[ -d "$root" ]]; then
            _log "Removing: $root"
            if rm -rf "$root" 2>/dev/null; then
                uninstall_removed_any=1
            else
                _warn "Failed to remove: $root"
                uninstall_failed_any=1
            fi
        fi
    done

    # Remove wrappers
    for bindir in "${bins[@]}"; do
        for wrapper in "$bindir/voidwave" "$bindir/voidwave-install"; do
            if [[ -f "$wrapper" ]]; then
                _log "Removing wrapper: $wrapper"
                if rm -f "$wrapper" 2>/dev/null; then
                    uninstall_removed_any=1
                else
                    _warn "Failed to remove: $wrapper"
                    uninstall_failed_any=1
                fi
            fi
        done
    done

    # Remove PATH drop-in if exists
    if [[ -f "/etc/profile.d/voidwave.sh" ]]; then
        _log "Removing PATH drop-in: /etc/profile.d/voidwave.sh"
        if rm -f "/etc/profile.d/voidwave.sh" 2>/dev/null; then
            uninstall_removed_any=1
        else
            _warn "Failed to remove: /etc/profile.d/voidwave.sh"
            uninstall_failed_any=1
        fi
    fi

    # Final summary with proper exit codes
    if [[ $uninstall_failed_any -eq 1 ]]; then
        _warn "Uninstall incomplete - some files could not be removed (permission denied?)"
        exit 1
    elif [[ $uninstall_removed_any -eq 1 ]]; then
        _success "Uninstall complete"
        exit 0
    else
        _warn "No existing installation found"
        exit 0
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# LEGACY CLEANUP
#═══════════════════════════════════════════════════════════════════════════════
# Remove broken v5.x monolithic installs (>100KB binaries)

_cleanup_legacy() {
    # System paths vs user paths - distinguished for permission handling
    local -a system_legacy_bins=("/usr/local/bin/voidwave" "/usr/local/bin/voidwave-install"
                                  "/usr/bin/voidwave" "/usr/bin/voidwave-install")
    local -a user_legacy_bins=("${HOME}/.local/bin/voidwave" "${HOME}/.local/bin/voidwave-install")
    local legacy_found=0
    local removal_failed=0

    # Helper to check and remove a legacy binary
    # Args: $1 = path, $2 = "system" or "user"
    _try_remove_legacy() {
        local legacy_bin="$1"
        local path_type="$2"

        if [[ ! -f "$legacy_bin" ]]; then
            return 0
        fi

        local file_size=0
        file_size=$(stat -c%s "$legacy_bin" 2>/dev/null || stat -f%z "$legacy_bin" 2>/dev/null || echo "0")

        if [[ "$file_size" -le 100000 ]]; then
            return 0  # Not a legacy monolith
        fi

        if [[ $legacy_found -eq 0 ]]; then
            _warn "Legacy v5.x monolith detected - removing"
            legacy_found=1
        fi

        if rm -f "$legacy_bin" 2>/dev/null; then
            _log "Removed legacy: $legacy_bin"
            return 0
        fi

        # Removal failed
        if [[ "$path_type" == "system" ]] && ! _is_root; then
            # Non-root user cannot remove system paths - warn only, don't block
            _warn "Cannot remove legacy system file (no permission): $legacy_bin"
            _warn "This won't block your --user install, but you may want to remove it later with sudo."
            return 0  # Don't fail for --user installs
        else
            # Root user OR user path - this is fatal
            _error "Could not remove legacy file: $legacy_bin"
            _error "Permission denied. Run with sudo or manually remove."
            removal_failed=1
            return 1
        fi
    }

    # Process system paths
    for legacy_bin in "${system_legacy_bins[@]}"; do
        _try_remove_legacy "$legacy_bin" "system"
    done

    # Process user paths
    for legacy_bin in "${user_legacy_bins[@]}"; do
        _try_remove_legacy "$legacy_bin" "user"
    done

    if [[ $removal_failed -eq 1 ]]; then
        _error "Legacy cleanup failed. Cannot proceed."
        exit 1
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# INSTALLATION
#═══════════════════════════════════════════════════════════════════════════════

_do_install() {
    # Check if install root already exists
    if [[ -d "$INSTALL_ROOT" ]]; then
        if [[ $OPT_FORCE -eq 1 ]]; then
            _warn "Removing existing installation at $INSTALL_ROOT (--force)"
            rm -rf "$INSTALL_ROOT"
        else
            _error "Installation already exists at: $INSTALL_ROOT"
            _error "Use --force to overwrite, or --uninstall to remove first"
            exit 1
        fi
    fi

    # Validate source directory has required files
    if [[ ! -f "$SOURCE_DIR/bin/voidwave" ]]; then
        _error "Source validation failed: bin/voidwave not found in $SOURCE_DIR"
        exit 1
    fi
    if [[ ! -f "$SOURCE_DIR/VERSION" ]]; then
        _error "Source validation failed: VERSION file not found in $SOURCE_DIR"
        exit 1
    fi
    if [[ ! -d "$SOURCE_DIR/lib" ]]; then
        _error "Source validation failed: lib/ directory not found in $SOURCE_DIR"
        exit 1
    fi

    # Create install root
    _log "Creating install directory: $INSTALL_ROOT"
    mkdir -p "$INSTALL_ROOT"

    # Copy project files (excluding .git, tests, docs for size)
    _log "Copying VOIDWAVE to $INSTALL_ROOT..."

    # Required directories
    cp -r "$SOURCE_DIR/bin" "$INSTALL_ROOT/"
    cp -r "$SOURCE_DIR/lib" "$INSTALL_ROOT/"
    cp -r "$SOURCE_DIR/modules" "$INSTALL_ROOT/"

    # Required files
    cp "$SOURCE_DIR/VERSION" "$INSTALL_ROOT/"
    cp "$SOURCE_DIR/LICENSE" "$INSTALL_ROOT/" 2>/dev/null || true

    # Optional: completions
    if [[ -d "$SOURCE_DIR/completions" ]]; then
        cp -r "$SOURCE_DIR/completions" "$INSTALL_ROOT/"
    fi

    # Ensure bin scripts are executable
    chmod +x "$INSTALL_ROOT/bin/voidwave"
    chmod +x "$INSTALL_ROOT/bin/voidwave-install" 2>/dev/null || true

    _log "Project files copied successfully"

    # Create bin directory if needed
    mkdir -p "$BIN_DIR"

    # Remove any existing wrappers in target bin dir
    rm -f "$BIN_DIR/voidwave" "$BIN_DIR/voidwave-install" 2>/dev/null || true

    # Create voidwave wrapper
    _log "Creating wrapper: $BIN_DIR/voidwave"
    cat > "$BIN_DIR/voidwave" << WRAPPER
#!/usr/bin/env bash
# VOIDWAVE wrapper - installed by install.sh
# Install root: $INSTALL_ROOT

export VOIDWAVE_ROOT="$INSTALL_ROOT"
exec "\$VOIDWAVE_ROOT/bin/voidwave" "\$@"
WRAPPER
    chmod 755 "$BIN_DIR/voidwave"

    # Create voidwave-install wrapper
    if [[ -f "$INSTALL_ROOT/bin/voidwave-install" ]]; then
        _log "Creating wrapper: $BIN_DIR/voidwave-install"
        cat > "$BIN_DIR/voidwave-install" << WRAPPER
#!/usr/bin/env bash
# VOIDWAVE installer wrapper - installed by install.sh
# Install root: $INSTALL_ROOT

export VOIDWAVE_ROOT="$INSTALL_ROOT"
exec "\$VOIDWAVE_ROOT/bin/voidwave-install" "\$@"
WRAPPER
        chmod 755 "$BIN_DIR/voidwave-install"
    fi

    # Handle PATH configuration
    _setup_path_config
}

# Setup PATH configuration using best available method
_setup_path_config() {
    if _dir_in_path "$BIN_DIR"; then
        _log "PATH already includes $BIN_DIR"
        return 0
    fi

    local path_configured=0

    # For system installs with writable profile.d
    if [[ $OPT_USER -eq 0 ]] && _is_root && [[ -d "/etc/profile.d" ]] && _is_writable "/etc/profile.d"; then
        _log "Creating PATH drop-in: /etc/profile.d/voidwave.sh"
        cat > "/etc/profile.d/voidwave.sh" << DROPIN
# Added by VOIDWAVE installer
if [[ ":\$PATH:" != *":$BIN_DIR:"* ]]; then
    export PATH="$BIN_DIR:\$PATH"
fi
DROPIN
        chmod 644 "/etc/profile.d/voidwave.sh"
        path_configured=1
    fi

    # For user installs or when profile.d is not writable, configure shell rc files
    if [[ $path_configured -eq 0 ]]; then
        _configure_shell_rc_path
    fi
}

# Configure PATH in user's shell rc files
_configure_shell_rc_path() {
    local path_line="export PATH=\"$BIN_DIR:\$PATH\"  # Added by VOIDWAVE"
    local rc_files=()
    local configured=0

    # Determine which shell rc files to configure
    local user_home="${HOME}"
    if [[ $EUID -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]]; then
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    fi

    # Check for common shell rc files
    [[ -f "$user_home/.bashrc" ]] && rc_files+=("$user_home/.bashrc")
    [[ -f "$user_home/.zshrc" ]] && rc_files+=("$user_home/.zshrc")
    [[ -f "$user_home/.profile" ]] && rc_files+=("$user_home/.profile")

    # If no rc files exist, create .bashrc
    if [[ ${#rc_files[@]} -eq 0 ]]; then
        rc_files+=("$user_home/.bashrc")
    fi

    for rc_file in "${rc_files[@]}"; do
        # Skip if already configured
        if grep -q "# Added by VOIDWAVE" "$rc_file" 2>/dev/null; then
            _log "PATH already configured in $rc_file"
            configured=1
            continue
        fi

        # Add PATH configuration
        _log "Adding PATH to $rc_file"
        echo "" >> "$rc_file"
        echo "# VOIDWAVE PATH configuration" >> "$rc_file"
        echo "if [[ \":\$PATH:\" != *\":$BIN_DIR:\"* ]]; then" >> "$rc_file"
        echo "    $path_line" >> "$rc_file"
        echo "fi" >> "$rc_file"
        configured=1
    done

    if [[ $configured -eq 1 ]]; then
        _success "PATH configured in shell rc file(s)"
        _warn "Run 'source ~/.bashrc' or restart your terminal to apply"
    else
        _warn "$BIN_DIR is not in your PATH"
        _warn "Add this line to your shell rc file manually:"
        _warn "  $path_line"
    fi
}

# Finalize installation
_finalize_install() {
    _success "Installation complete: $INSTALL_ROOT"

    # Show special system info
    if [[ $IS_IMMUTABLE -eq 1 ]]; then
        echo "" >&2
        _log "Note: Running on immutable system"
        if [[ $IS_STEAMDECK -eq 1 ]]; then
            _log "Steam Deck detected - VOIDWAVE installed to user directory"
            _log "VOIDWAVE will persist across SteamOS updates"
        fi
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# POST-INSTALL VERIFICATION (STRICT)
#═══════════════════════════════════════════════════════════════════════════════

_verify_installation() {
    _log "Running post-install verification..."

    local errors=0

    # Ensure BIN_DIR is in PATH for verification
    export PATH="$BIN_DIR:$PATH"

    # 1. Check command resolves
    local wrapper_path
    wrapper_path="$(command -v voidwave 2>/dev/null || true)"
    if [[ -z "$wrapper_path" ]]; then
        _error "VERIFY FAILED: 'voidwave' command not found in PATH"
        _error "PATH includes: $PATH"
        errors=$((errors + 1))
    else
        _log "Command resolves to: $wrapper_path"
    fi

    # 2. Check wrapper exists and is in expected location
    if [[ "$wrapper_path" != "$BIN_DIR/voidwave" ]]; then
        _error "VERIFY FAILED: Wrapper not in expected location"
        _error "Expected: $BIN_DIR/voidwave"
        _error "Got: $wrapper_path"
        errors=$((errors + 1))
    fi

    # 3. Check wrapper is small (<100KB - not a monolith)
    if [[ -f "$wrapper_path" ]]; then
        local wrapper_size
        wrapper_size=$(stat -c%s "$wrapper_path" 2>/dev/null || stat -f%z "$wrapper_path" 2>/dev/null || echo "0")
        if [[ "$wrapper_size" -gt 100000 ]]; then
            _error "VERIFY FAILED: Wrapper is too large (${wrapper_size} bytes)"
            _error "This suggests a legacy monolith, not a wrapper"
            errors=$((errors + 1))
        fi
    fi

    # 4. Check wrapper contains VOIDWAVE_ROOT export
    if [[ -f "$wrapper_path" ]]; then
        if ! grep -q 'export VOIDWAVE_ROOT=' "$wrapper_path" 2>/dev/null; then
            _error "VERIFY FAILED: Wrapper missing VOIDWAVE_ROOT export"
            errors=$((errors + 1))
        fi
    fi

    # 5. Check VOIDWAVE_ROOT points to install root (not source repo)
    if [[ -f "$wrapper_path" ]]; then
        local embedded_root
        embedded_root=$(grep 'export VOIDWAVE_ROOT=' "$wrapper_path" | sed 's/.*VOIDWAVE_ROOT="\([^"]*\)".*/\1/' | head -1)
        if [[ "$embedded_root" != "$INSTALL_ROOT" ]]; then
            _error "VERIFY FAILED: VOIDWAVE_ROOT points to wrong location"
            _error "Expected: $INSTALL_ROOT"
            _error "Got: $embedded_root"
            errors=$((errors + 1))
        fi
        # Also verify it's not pointing to a /home/* path (source repo)
        if [[ "$embedded_root" == /home/* ]] && [[ "$OPT_USER" -ne 1 ]]; then
            _error "VERIFY FAILED: VOIDWAVE_ROOT points to home directory"
            _error "System installs must not reference user home directories"
            _error "Got: $embedded_root"
            errors=$((errors + 1))
        fi
    fi

    # 6. Check install root exists and has required files
    if [[ ! -d "$INSTALL_ROOT" ]]; then
        _error "VERIFY FAILED: Install root does not exist: $INSTALL_ROOT"
        errors=$((errors + 1))
    else
        if [[ ! -x "$INSTALL_ROOT/bin/voidwave" ]]; then
            _error "VERIFY FAILED: $INSTALL_ROOT/bin/voidwave not executable"
            errors=$((errors + 1))
        fi
        if [[ ! -f "$INSTALL_ROOT/VERSION" ]]; then
            _error "VERIFY FAILED: $INSTALL_ROOT/VERSION not found"
            errors=$((errors + 1))
        fi
        if [[ ! -d "$INSTALL_ROOT/lib" ]]; then
            _error "VERIFY FAILED: $INSTALL_ROOT/lib/ directory not found"
            errors=$((errors + 1))
        fi
    fi

    # 7. Test actual execution
    # Guard: wrapper_path must be non-empty, a file, and executable
    if [[ -z "$wrapper_path" ]]; then
        _error "VERIFY FAILED: Cannot test execution - wrapper_path is empty"
        errors=$((errors + 1))
    elif [[ ! -f "$wrapper_path" ]]; then
        _error "VERIFY FAILED: Cannot test execution - wrapper is not a file: $wrapper_path"
        errors=$((errors + 1))
    elif [[ ! -x "$wrapper_path" ]]; then
        _error "VERIFY FAILED: Cannot test execution - wrapper is not executable: $wrapper_path"
        errors=$((errors + 1))
    else
        local version_output
        version_output=$("$wrapper_path" --version 2>&1 || true)
        if [[ -z "$version_output" ]] || [[ "$version_output" == *"ERROR"* ]]; then
            _error "VERIFY FAILED: voidwave --version failed"
            _error "Output: $version_output"
            errors=$((errors + 1))
        else
            _log "Version output: $version_output"
        fi
    fi

    # Final result
    if [[ $errors -gt 0 ]]; then
        _error "Post-install verification FAILED with $errors error(s)"
        exit 1
    fi

    _success "Post-install verification PASSED"
}

#═══════════════════════════════════════════════════════════════════════════════
# MAIN
#═══════════════════════════════════════════════════════════════════════════════

main() {
    echo "═══════════════════════════════════════════════════════════════════" >&2
    echo " VOIDWAVE Installer" >&2
    echo "═══════════════════════════════════════════════════════════════════" >&2

    # Handle uninstall
    if [[ $OPT_UNINSTALL -eq 1 ]]; then
        _do_uninstall
    fi

    # Select install locations
    _select_install_locations

    # Cleanup legacy installs
    _cleanup_legacy

    # Perform installation
    _do_install

    # Verify installation
    _verify_installation

    # Finalize and show completion info
    _finalize_install

    # Run tool installer if args provided
    if [[ ${#TOOL_INSTALL_ARGS[@]} -gt 0 ]]; then
        _log "Running tool installer with args: ${TOOL_INSTALL_ARGS[*]}"
        "$BIN_DIR/voidwave-install" "${TOOL_INSTALL_ARGS[@]}"
    fi

    echo "" >&2
    _success "VOIDWAVE installed successfully!"
    _log "Run 'voidwave --help' to get started"

    # Remind about PATH on immutable/user installs
    if [[ $OPT_USER -eq 1 ]] || [[ $IS_IMMUTABLE -eq 1 ]]; then
        if ! _dir_in_path "$BIN_DIR"; then
            echo "" >&2
            _warn "Remember to restart your terminal or run:"
            _warn "  source ~/.bashrc"
        fi
    fi
}

main "$@"
