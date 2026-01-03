#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE Uninstaller
# ═══════════════════════════════════════════════════════════════════════════════
# Removes VOIDWAVE and associated files.
#
# Usage:
#   ./uninstall.sh              # Interactive uninstall
#   ./uninstall.sh --all        # Remove everything including config
#   ./uninstall.sh --keep-config # Remove but keep config
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Colors
if [[ -t 1 ]] && command -v tput &>/dev/null; then
    readonly RED=$(tput setaf 1)
    readonly GREEN=$(tput setaf 2)
    readonly YELLOW=$(tput setaf 3)
    readonly CYAN=$(tput setaf 6)
    readonly BOLD=$(tput bold)
    readonly RESET=$(tput sgr0)
else
    readonly RED="" GREEN="" YELLOW="" CYAN="" BOLD="" RESET=""
fi

log()     { echo "${CYAN}[*]${RESET} $*"; }
success() { echo "${GREEN}[✓]${RESET} $*"; }
warn()    { echo "${YELLOW}[!]${RESET} $*" >&2; }
error()   { echo "${RED}[✗]${RESET} $*" >&2; }

#═══════════════════════════════════════════════════════════════════════════════
# ARGUMENT PARSING
#═══════════════════════════════════════════════════════════════════════════════

OPT_ALL=0
OPT_KEEP_CONFIG=0

show_help() {
    cat << 'EOF'
VOIDWAVE Uninstaller

Usage: ./uninstall.sh [OPTIONS]

Options:
  --all          Remove everything including config and data
  --keep-config  Remove but keep configuration
  --help         Show this help message

EOF
}

for arg in "$@"; do
    case "$arg" in
        --all)         OPT_ALL=1 ;;
        --keep-config) OPT_KEEP_CONFIG=1 ;;
        --help|-h)     show_help; exit 0 ;;
        *)             error "Unknown option: $arg"; show_help; exit 1 ;;
    esac
done

#═══════════════════════════════════════════════════════════════════════════════
# UNINSTALL
#═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "${BOLD}VOIDWAVE Uninstaller${RESET}"
echo ""

# Remove symlinks from both locations
for dir in "/usr/local/bin" "$HOME/.local/bin"; do
    if [[ -e "$dir/voidwave" ]]; then
        if [[ -w "$dir" ]]; then
            rm -f "$dir/voidwave"
        else
            sudo rm -f "$dir/voidwave" 2>/dev/null || warn "Could not remove $dir/voidwave (need sudo)"
        fi
        success "Removed $dir/voidwave"
    fi
done

# Remove old pipx installation if exists
if command -v pipx &>/dev/null; then
    if pipx list 2>/dev/null | grep -q voidwave; then
        log "Removing pipx installation..."
        pipx uninstall voidwave 2>/dev/null && success "Removed pipx installation" || true
    fi
fi

# Handle config directory
if [[ -d "$HOME/.voidwave" ]]; then
    if [[ $OPT_ALL -eq 1 ]]; then
        rm -rf "$HOME/.voidwave"
        success "Removed ~/.voidwave"
    elif [[ $OPT_KEEP_CONFIG -eq 1 ]]; then
        log "Keeping ~/.voidwave config"
    else
        echo ""
        read -r -p "Remove config directory ~/.voidwave? [y/N]: " ans
        if [[ "${ans,,}" == y* ]]; then
            rm -rf "$HOME/.voidwave"
            success "Removed ~/.voidwave"
        else
            log "Kept ~/.voidwave"
        fi
    fi
fi

echo ""
success "Uninstall complete"
echo ""
