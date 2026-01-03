#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE Installer
# ═══════════════════════════════════════════════════════════════════════════════
# Installs the VOIDWAVE bash CLI to your system.
#
# Usage:
#   sudo ./install.sh         # Install system-wide to /usr/local/bin (recommended)
#   ./install.sh --user       # Install to ~/.local/bin (user only)
#   ./install.sh --uninstall  # Remove installation
#   ./install.sh --tools      # Also install security tools
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "unknown")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log()     { echo -e "${CYAN}[*]${RESET} $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*" >&2; }

# Determine install location
USER_MODE=false
if [[ "${1:-}" == "--user" || "${2:-}" == "--user" ]]; then
    USER_MODE=true
fi

if [[ "$USER_MODE" == true ]]; then
    BIN_DIR="$HOME/.local/bin"
elif [[ $EUID -eq 0 ]]; then
    BIN_DIR="/usr/local/bin"
else
    # Not root and not --user, default to user install with warning
    BIN_DIR="$HOME/.local/bin"
    USER_MODE=true
fi

#═══════════════════════════════════════════════════════════════════════════════
# INSTALL
#═══════════════════════════════════════════════════════════════════════════════

install_voidwave() {
    echo ""
    echo -e "${BOLD}VOIDWAVE ${VERSION} Installer${RESET}"
    echo ""

    # Create bin directory
    mkdir -p "$BIN_DIR"

    # Remove old pipx installation if exists
    if command -v pipx &>/dev/null; then
        if pipx list 2>/dev/null | grep -q voidwave; then
            log "Removing old Python TUI installation..."
            pipx uninstall voidwave 2>/dev/null || true
        fi
    fi

    # Remove existing symlinks from both locations
    for dir in "/usr/local/bin" "$HOME/.local/bin"; do
        if [[ -e "$dir/voidwave" ]]; then
            rm -f "$dir/voidwave" 2>/dev/null || true
        fi
    done

    # Set permissions
    chmod +x "$SCRIPT_DIR/voidwave"
    chmod +x "$SCRIPT_DIR/bin/voidwave"

    # Create symlink
    ln -sf "$SCRIPT_DIR/voidwave" "$BIN_DIR/voidwave"

    # Verify
    if [[ -L "$BIN_DIR/voidwave" ]]; then
        success "Installed to $BIN_DIR/voidwave"
    else
        error "Failed to create symlink"
        exit 1
    fi

    # Check PATH for user installs
    if [[ "$USER_MODE" == true ]] && [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        warn "$BIN_DIR not in PATH"
        echo ""
        echo "Add to your shell config:"
        echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
        echo "  source ~/.bashrc"
    fi

    echo ""
    success "VOIDWAVE ${VERSION} installed"
    echo ""
    if [[ "$USER_MODE" == true ]]; then
        echo "  Run: voidwave"
        warn "Note: 'sudo voidwave' won't work with user install"
        echo "  For sudo support, reinstall with: sudo ./install.sh"
    else
        echo "  Run: sudo voidwave"
    fi
    echo "  Help: voidwave --help"
    echo ""
}

#═══════════════════════════════════════════════════════════════════════════════
# UNINSTALL
#═══════════════════════════════════════════════════════════════════════════════

uninstall_voidwave() {
    echo ""
    echo -e "${BOLD}VOIDWAVE Uninstaller${RESET}"
    echo ""

    # Remove symlinks from both locations
    for dir in "/usr/local/bin" "$HOME/.local/bin"; do
        if [[ -e "$dir/voidwave" ]]; then
            rm -f "$dir/voidwave" 2>/dev/null || sudo rm -f "$dir/voidwave" 2>/dev/null || true
            success "Removed $dir/voidwave"
        fi
    done

    # Remove pipx if installed
    if command -v pipx &>/dev/null; then
        pipx uninstall voidwave 2>/dev/null && success "Removed pipx installation" || true
    fi

    # Ask about config
    if [[ -d "$HOME/.voidwave" ]]; then
        echo ""
        read -r -p "Remove config directory ~/.voidwave? [y/N]: " ans
        if [[ "${ans,,}" == y* ]]; then
            rm -rf "$HOME/.voidwave"
            success "Removed ~/.voidwave"
        fi
    fi

    echo ""
    success "Uninstall complete"
}

#═══════════════════════════════════════════════════════════════════════════════
# TOOLS
#═══════════════════════════════════════════════════════════════════════════════

install_tools() {
    if [[ -x "$SCRIPT_DIR/install-tools.sh" ]]; then
        exec "$SCRIPT_DIR/install-tools.sh" install-all
    else
        error "install-tools.sh not found"
        exit 1
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# MAIN
#═══════════════════════════════════════════════════════════════════════════════

# Parse arguments (handle --user appearing anywhere)
ACTION=""
for arg in "$@"; do
    case "$arg" in
        --uninstall|-u) ACTION="uninstall" ;;
        --tools|-t)     ACTION="tools" ;;
        --help|-h)      ACTION="help" ;;
        --user)         ;; # Already handled above
        *)              ;;
    esac
done

case "$ACTION" in
    uninstall)
        uninstall_voidwave
        ;;
    tools)
        install_voidwave
        install_tools
        ;;
    help)
        echo "VOIDWAVE Installer"
        echo ""
        echo "Usage:"
        echo "  sudo ./install.sh         Install system-wide (recommended)"
        echo "  ./install.sh --user       Install to ~/.local/bin"
        echo ""
        echo "Options:"
        echo "  --user          Install to ~/.local/bin instead of /usr/local/bin"
        echo "  --uninstall, -u Remove VOIDWAVE"
        echo "  --tools, -t     Install + security tools"
        echo "  --help, -h      Show this help"
        ;;
    *)
        install_voidwave
        ;;
esac
