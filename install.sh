#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE Installer
# ═══════════════════════════════════════════════════════════════════════════════
# Installs the VOIDWAVE bash CLI to your system.
#
# Usage:
#   ./install.sh              # Install to ~/.local/bin
#   ./install.sh --uninstall  # Remove installation
#   ./install.sh --tools      # Also install security tools
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "unknown")
readonly BIN_DIR="$HOME/.local/bin"

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

    # Remove existing symlink/file
    if [[ -e "$BIN_DIR/voidwave" ]]; then
        rm -f "$BIN_DIR/voidwave"
    fi

    # Create symlink
    ln -sf "$SCRIPT_DIR/voidwave" "$BIN_DIR/voidwave"
    chmod +x "$SCRIPT_DIR/voidwave"
    chmod +x "$SCRIPT_DIR/bin/voidwave"

    # Verify
    if [[ -L "$BIN_DIR/voidwave" ]]; then
        success "Installed to $BIN_DIR/voidwave"
    else
        error "Failed to create symlink"
        exit 1
    fi

    # Check PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        warn "$BIN_DIR not in PATH"
        echo ""
        echo "Add to your shell config:"
        echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
        echo "  source ~/.bashrc"
    fi

    echo ""
    success "VOIDWAVE ${VERSION} installed"
    echo ""
    echo "  Run: voidwave"
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

    # Remove symlink
    if [[ -e "$BIN_DIR/voidwave" ]]; then
        rm -f "$BIN_DIR/voidwave"
        success "Removed $BIN_DIR/voidwave"
    fi

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

case "${1:-}" in
    --uninstall|-u)
        uninstall_voidwave
        ;;
    --tools|-t)
        install_voidwave
        install_tools
        ;;
    --help|-h)
        echo "VOIDWAVE Installer"
        echo ""
        echo "Usage: ./install.sh [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --uninstall, -u   Remove VOIDWAVE"
        echo "  --tools, -t       Install + security tools"
        echo "  --help, -h        Show this help"
        ;;
    *)
        install_voidwave
        ;;
esac
