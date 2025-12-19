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
# SYSTEM DETECTION
#═══════════════════════════════════════════════════════════════════════════════

# System info (populated by _detect_system)
DISTRO_ID=""
DISTRO_NAME=""
DISTRO_FAMILY=""       # debian, redhat, arch, suse, alpine, nixos, unknown
PKG_MANAGER=""         # apt, dnf, yum, pacman, zypper, apk, nix, unknown
ARCH=""                # x86_64, aarch64, armv7l, etc.
IS_IMMUTABLE=0
IS_STEAMDECK=0
IS_WSL=0
IS_CONTAINER=0
IS_ROOT=0

# Full system detection
_detect_system() {
    # Architecture
    ARCH=$(uname -m)

    # Root check
    [[ $EUID -eq 0 ]] && IS_ROOT=1

    # Parse os-release
    if [[ -f /etc/os-release ]]; then
        DISTRO_ID=$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"' | head -1)
        DISTRO_NAME=$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release | tr -d '"' | head -1)
    fi

    # Detect distro family and package manager
    case "$DISTRO_ID" in
        ubuntu|debian|pop|linuxmint|elementary|zorin|kali|parrot|raspbian)
            DISTRO_FAMILY="debian"
            PKG_MANAGER="apt"
            ;;
        fedora|rhel|centos|rocky|alma|oracle|amazon)
            DISTRO_FAMILY="redhat"
            PKG_MANAGER="dnf"
            command -v dnf &>/dev/null || PKG_MANAGER="yum"
            ;;
        arch|manjaro|endeavouros|garuda|artix|cachyos)
            DISTRO_FAMILY="arch"
            PKG_MANAGER="pacman"
            ;;
        opensuse*|suse|sles)
            DISTRO_FAMILY="suse"
            PKG_MANAGER="zypper"
            ;;
        alpine)
            DISTRO_FAMILY="alpine"
            PKG_MANAGER="apk"
            ;;
        nixos)
            DISTRO_FAMILY="nixos"
            PKG_MANAGER="nix"
            ;;
        void)
            DISTRO_FAMILY="void"
            PKG_MANAGER="xbps"
            ;;
        gentoo)
            DISTRO_FAMILY="gentoo"
            PKG_MANAGER="emerge"
            ;;
        steamos|chimeraos)
            DISTRO_FAMILY="arch"  # SteamOS/ChimeraOS are Arch-based
            PKG_MANAGER="pacman"
            IS_STEAMDECK=1
            IS_IMMUTABLE=1
            ;;
        bazzite)
            DISTRO_FAMILY="redhat"  # Bazzite is Fedora Atomic-based
            PKG_MANAGER="rpm-ostree"
            IS_STEAMDECK=1
            IS_IMMUTABLE=1
            ;;
        silverblue|kinoite)
            DISTRO_FAMILY="redhat"
            PKG_MANAGER="rpm-ostree"
            IS_IMMUTABLE=1
            ;;
        vanilla|blendos)
            IS_IMMUTABLE=1
            ;;
        *)
            DISTRO_FAMILY="unknown"
            # Try to detect package manager
            if command -v apt-get &>/dev/null; then
                PKG_MANAGER="apt"
                DISTRO_FAMILY="debian"
            elif command -v dnf &>/dev/null; then
                PKG_MANAGER="dnf"
                DISTRO_FAMILY="redhat"
            elif command -v pacman &>/dev/null; then
                PKG_MANAGER="pacman"
                DISTRO_FAMILY="arch"
            elif command -v zypper &>/dev/null; then
                PKG_MANAGER="zypper"
                DISTRO_FAMILY="suse"
            elif command -v apk &>/dev/null; then
                PKG_MANAGER="apk"
                DISTRO_FAMILY="alpine"
            else
                PKG_MANAGER="unknown"
            fi
            ;;
    esac

    # Detect immutable systems (if not already set)
    if [[ $IS_IMMUTABLE -eq 0 ]]; then
        # rpm-ostree based (Silverblue, Kinoite, Bazzite, etc.)
        if command -v rpm-ostree &>/dev/null; then
            IS_IMMUTABLE=1
            PKG_MANAGER="rpm-ostree"
        # ostree
        elif [[ -d /ostree ]] || [[ -d /sysroot/ostree ]]; then
            IS_IMMUTABLE=1
        # NixOS
        elif [[ -f /etc/NIXOS ]] || [[ -d /nix/store ]]; then
            IS_IMMUTABLE=1
        # Read-only root
        elif grep -q " / .*\bro\b" /proc/mounts 2>/dev/null; then
            IS_IMMUTABLE=1
        fi
    fi

    # Detect WSL
    if [[ -f /proc/version ]] && grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then
        IS_WSL=1
    elif [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        IS_WSL=1
    fi

    # Detect if running inside a container
    if [[ -f /.dockerenv ]] || [[ -f /run/.containerenv ]]; then
        IS_CONTAINER=1
    elif grep -q "docker\|lxc\|podman" /proc/1/cgroup 2>/dev/null; then
        IS_CONTAINER=1
    fi
}

# Show detected system info (for debugging)
_show_system_info() {
    echo "System Information:" >&2
    echo "  Distro:      ${DISTRO_NAME:-$DISTRO_ID}" >&2
    echo "  Family:      $DISTRO_FAMILY" >&2
    echo "  Package Mgr: $PKG_MANAGER" >&2
    echo "  Arch:        $ARCH" >&2
    echo "  Immutable:   $([[ $IS_IMMUTABLE -eq 1 ]] && echo "Yes" || echo "No")" >&2
    echo "  Steam Deck:  $([[ $IS_STEAMDECK -eq 1 ]] && echo "Yes" || echo "No")" >&2
    echo "  WSL:         $([[ $IS_WSL -eq 1 ]] && echo "Yes" || echo "No")" >&2
    echo "  Container:   $([[ $IS_CONTAINER -eq 1 ]] && echo "Yes" || echo "No")" >&2
    echo "  Root:        $([[ $IS_ROOT -eq 1 ]] && echo "Yes" || echo "No")" >&2
}

#═══════════════════════════════════════════════════════════════════════════════
# ARGUMENT PARSING
#═══════════════════════════════════════════════════════════════════════════════

OPT_FORCE=0
OPT_USER=0
OPT_UNINSTALL=0
OPT_INFO=0
TOOL_INSTALL_ARGS=()

_show_help() {
    cat << 'HELPTEXT'
VOIDWAVE Installer

Usage:
  ./install.sh [OPTIONS] [-- TOOL_INSTALLER_ARGS...]

Options:
  --force       Overwrite existing installation
  --user        Install to user directory (~/.local/share/voidwave)
  --uninstall   Remove existing installation
  --info        Show detected system info and exit
  --help        Show this help message

IMMUTABLE SYSTEMS (SteamOS, Bazzite, Silverblue, etc.):
  These systems auto-detect and install to user directory.
  NO SUDO NEEDED - just run: ./install.sh

  After install, use distrobox for full pentesting:
    voidwave-distrobox create   # Create Kali container
    voidwave-distrobox setup    # Install tools
    voidwave-distrobox enter    # Enter container

TRADITIONAL SYSTEMS:
  System Install (requires root):
    sudo ./install.sh
    Installs to: /usr/local/share/voidwave
    Symlinks to: /usr/local/bin

  User Install (no root required):
    ./install.sh --user
    Installs to: ~/.local/share/voidwave
    Symlinks to: ~/.local/bin

Examples:
  ./install.sh                         # Auto-detect best method
  ./install.sh --force                 # Overwrite existing install
  sudo ./install.sh                    # Force system install
  ./install.sh -- --all                # Install + run tool installer
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
        --info|--sysinfo)
            OPT_INFO=1
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
# PRE-FLIGHT CHECKS
#═══════════════════════════════════════════════════════════════════════════════

_preflight_checks() {
    local errors=0

    # Check bash version (need 4.0+ for associative arrays)
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        _error "Bash 4.0 or later required (found ${BASH_VERSION})"
        errors=$((errors + 1))
    fi

    # Validate source directory structure
    if [[ ! -f "$SOURCE_DIR/bin/voidwave" ]]; then
        _error "Invalid source: bin/voidwave not found in $SOURCE_DIR"
        _error "Are you running install.sh from the VOIDWAVE directory?"
        errors=$((errors + 1))
    fi

    if [[ ! -f "$SOURCE_DIR/VERSION" ]]; then
        _error "Invalid source: VERSION file not found in $SOURCE_DIR"
        errors=$((errors + 1))
    fi

    if [[ ! -d "$SOURCE_DIR/lib" ]]; then
        _error "Invalid source: lib/ directory not found in $SOURCE_DIR"
        errors=$((errors + 1))
    fi

    # Check for common issues with running the script
    if [[ ! -x "$SOURCE_DIR/bin/voidwave" ]]; then
        _warn "bin/voidwave is not executable, fixing..."
        chmod +x "$SOURCE_DIR/bin/voidwave" 2>/dev/null || {
            _error "Cannot make bin/voidwave executable"
            errors=$((errors + 1))
        }
    fi

    # Check for restrictive file permissions that will cause issues
    for script in "$SOURCE_DIR/bin/"*; do
        if [[ -f "$script" ]] && [[ ! -r "$script" ]]; then
            _warn "Fixing restrictive permissions on $(basename "$script")"
            chmod a+r "$script" 2>/dev/null || true
        fi
    done

    if [[ $errors -gt 0 ]]; then
        _error "Pre-flight checks failed with $errors error(s)"
        exit 1
    fi

    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# INSTALL LOCATION SELECTION
#═══════════════════════════════════════════════════════════════════════════════

# Select the install root directory
# Sets: INSTALL_ROOT, BIN_DIR
_select_install_locations() {
    # Run full system detection
    _detect_system

    # Warn if running inside a container
    if [[ $IS_CONTAINER -eq 1 ]]; then
        _warn "Running inside a container (docker/podman/distrobox)"
        _warn "You probably want to install on the host system instead"
        echo "" >&2
    fi

    # Force user install on immutable systems
    if [[ $IS_IMMUTABLE -eq 1 ]] && [[ $OPT_USER -eq 0 ]]; then
        echo "" >&2
        echo "┌─────────────────────────────────────────────────────────────────┐" >&2
        echo "│  IMMUTABLE SYSTEM DETECTED                                      │" >&2
        printf "│  %-63s│\n" "${DISTRO_NAME:-$DISTRO_ID}" >&2
        echo "└─────────────────────────────────────────────────────────────────┘" >&2
        echo "" >&2

        # Warn if running with sudo unnecessarily
        if [[ $IS_ROOT -eq 1 ]] && [[ -n "${SUDO_USER:-}" ]]; then
            _warn "You ran with sudo, but it's not needed on immutable systems!"
            _warn "Next time just run: ./install.sh"
            echo "" >&2
        fi

        _log "Installing to user directory: ~/.local/share/voidwave"
        echo "" >&2
        echo "[i] On immutable systems, use distrobox for full pentesting:" >&2
        echo "    voidwave-distrobox create   # Create a Kali container" >&2
        echo "    voidwave-distrobox setup    # Install pentesting tools" >&2
        echo "    voidwave-distrobox enter    # Enter the container" >&2
        echo "" >&2
        OPT_USER=1
    fi

    # Determine the actual user home directory
    # When running with sudo, $HOME is /root, but we want the real user's home
    local USER_HOME="${HOME}"
    if [[ $EUID -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]]; then
        USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [[ -z "$USER_HOME" ]]; then
            USER_HOME="/home/$SUDO_USER"
        fi
    fi

    if [[ $OPT_USER -eq 1 ]] || ! _is_root; then
        # User install - use the real user's home, not root's
        INSTALL_ROOT="${USER_HOME}/.local/share/voidwave"
        BIN_DIR="${USER_HOME}/.local/bin"
        _log "User install mode selected"

        # Special handling for Steam Deck
        if [[ $IS_STEAMDECK -eq 1 ]]; then
            _log "Steam Deck detected - using optimized user install"
        fi
    else
        # System install - try locations in priority order
        # Prefer /usr/local/share/voidwave (FHS compliant for shared data)
        local -a roots=("/usr/local/share/voidwave" "/opt/voidwave" "/usr/local/lib/voidwave" "/usr/lib/voidwave")
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

    local -a roots=("/usr/local/share/voidwave" "/opt/voidwave" "/usr/local/lib/voidwave" "/usr/lib/voidwave" "${HOME}/.local/share/voidwave")
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

    # Remove wrappers/symlinks
    for bindir in "${bins[@]}"; do
        for wrapper in "$bindir/voidwave" "$bindir/voidwave-install" "$bindir/voidwave-distrobox"; do
            if [[ -f "$wrapper" ]] || [[ -L "$wrapper" ]]; then
                _log "Removing: $wrapper"
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

    # Source validation already done in _preflight_checks

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

    # Ensure bin scripts are executable and readable
    chmod +x "$INSTALL_ROOT/bin/voidwave"
    chmod +x "$INSTALL_ROOT/bin/voidwave-install" 2>/dev/null || true
    chmod +x "$INSTALL_ROOT/bin/voidwave-distrobox" 2>/dev/null || true
    # Ensure scripts are readable (some may have restrictive perms in repo)
    chmod a+r "$INSTALL_ROOT/bin/"* 2>/dev/null || true

    # If running with sudo, fix ownership to the actual user
    if [[ $EUID -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]] && [[ $OPT_USER -eq 1 ]]; then
        _log "Fixing ownership for user: $SUDO_USER"
        chown -R "$SUDO_USER:$SUDO_USER" "$INSTALL_ROOT"
    fi

    _log "Project files copied successfully"

    # Create bin directory if needed
    mkdir -p "$BIN_DIR"

    # Remove any existing symlinks/wrappers in target bin dir
    rm -f "$BIN_DIR/voidwave" "$BIN_DIR/voidwave-install" "$BIN_DIR/voidwave-distrobox" 2>/dev/null || true

    # Create symlinks (the binaries now resolve VOIDWAVE_ROOT by following symlinks)
    _log "Creating symlink: $BIN_DIR/voidwave -> $INSTALL_ROOT/bin/voidwave"
    ln -sf "$INSTALL_ROOT/bin/voidwave" "$BIN_DIR/voidwave"

    if [[ -f "$INSTALL_ROOT/bin/voidwave-install" ]]; then
        _log "Creating symlink: $BIN_DIR/voidwave-install -> $INSTALL_ROOT/bin/voidwave-install"
        ln -sf "$INSTALL_ROOT/bin/voidwave-install" "$BIN_DIR/voidwave-install"
    fi

    if [[ -f "$INSTALL_ROOT/bin/voidwave-distrobox" ]]; then
        _log "Creating symlink: $BIN_DIR/voidwave-distrobox -> $INSTALL_ROOT/bin/voidwave-distrobox"
        ln -sf "$INSTALL_ROOT/bin/voidwave-distrobox" "$BIN_DIR/voidwave-distrobox"
    fi

    # If running with sudo for user install, fix ownership of bin dir and symlinks
    if [[ $EUID -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]] && [[ $OPT_USER -eq 1 ]]; then
        chown -h "$SUDO_USER:$SUDO_USER" "$BIN_DIR/voidwave" "$BIN_DIR/voidwave-install" "$BIN_DIR/voidwave-distrobox" 2>/dev/null || true
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
    # Canonicalize paths for comparison on ostree systems where paths may differ
    local canonical_wrapper canonical_expected_bin
    canonical_wrapper=$(readlink -f "$wrapper_path" 2>/dev/null || echo "$wrapper_path")
    canonical_expected_bin=$(readlink -f "$BIN_DIR/voidwave" 2>/dev/null || echo "$BIN_DIR/voidwave")
    if [[ "$canonical_wrapper" != "$canonical_expected_bin" ]]; then
        _error "VERIFY FAILED: Wrapper not in expected location"
        _error "Expected: $BIN_DIR/voidwave (canonical: $canonical_expected_bin)"
        _error "Got: $wrapper_path (canonical: $canonical_wrapper)"
        errors=$((errors + 1))
    fi

    # 3. Check symlink or small wrapper (not a monolith)
    if [[ -L "$wrapper_path" ]]; then
        # It's a symlink - verify it points to the right place
        # On ostree systems (Bazzite/Silverblue), paths can have symlink indirection
        # e.g., /home/user -> /var/home/user, so we canonicalize both paths
        local link_target expected_target
        link_target=$(readlink -f "$wrapper_path" 2>/dev/null || readlink "$wrapper_path" 2>/dev/null)
        expected_target=$(readlink -f "$INSTALL_ROOT/bin/voidwave" 2>/dev/null || echo "$INSTALL_ROOT/bin/voidwave")
        if [[ "$link_target" != "$expected_target" ]]; then
            _error "VERIFY FAILED: Symlink points to wrong location"
            _error "Expected: $expected_target"
            _error "Got: $link_target"
            errors=$((errors + 1))
        else
            _log "Symlink verified: $wrapper_path -> $link_target"
        fi
    elif [[ -f "$wrapper_path" ]]; then
        local wrapper_size
        wrapper_size=$(stat -c%s "$wrapper_path" 2>/dev/null || stat -f%z "$wrapper_path" 2>/dev/null || echo "0")
        if [[ "$wrapper_size" -gt 100000 ]]; then
            _error "VERIFY FAILED: Wrapper is too large (${wrapper_size} bytes)"
            _error "This suggests a legacy monolith, not a wrapper"
            errors=$((errors + 1))
        fi
    fi

    # 4. Check that the target script exists and is executable
    if [[ ! -x "$INSTALL_ROOT/bin/voidwave" ]]; then
        _error "VERIFY FAILED: $INSTALL_ROOT/bin/voidwave not executable"
        errors=$((errors + 1))
    fi

    # 5. Check symlink target resolves correctly for system install
    if [[ "$OPT_USER" -ne 1 ]]; then
        local resolved_target
        resolved_target=$(readlink -f "$wrapper_path" 2>/dev/null || echo "")
        if [[ -n "$resolved_target" ]] && [[ "$resolved_target" == /home/* ]]; then
            _error "VERIFY FAILED: Symlink resolves to home directory"
            _error "System installs must not reference user home directories"
            _error "Got: $resolved_target"
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

    # Handle --info flag (show system info and exit)
    if [[ $OPT_INFO -eq 1 ]]; then
        _detect_system
        echo "" >&2
        _show_system_info
        exit 0
    fi

    # Run pre-flight checks first
    _preflight_checks

    # Handle uninstall
    if [[ $OPT_UNINSTALL -eq 1 ]]; then
        _do_uninstall
    fi

    # Select install locations (also detects immutable systems)
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
