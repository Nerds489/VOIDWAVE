#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE 2.0 Uninstaller
# ═══════════════════════════════════════════════════════════════════════════════
# Removes VOIDWAVE Python package and associated files.
#
# Usage:
#   ./uninstall.sh              # Interactive uninstall
#   ./uninstall.sh --all        # Remove everything including config
#   ./uninstall.sh --keep-config # Remove package but keep config
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
VOIDWAVE 2.0 Uninstaller

Usage: ./uninstall.sh [OPTIONS]

Options:
  --all          Remove everything including config and data
  --keep-config  Remove package but keep configuration
  --help         Show this help message

EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)         OPT_ALL=1; shift ;;
        --keep-config) OPT_KEEP_CONFIG=1; shift ;;
        --help|-h)     show_help; exit 0 ;;
        *)             error "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

#═══════════════════════════════════════════════════════════════════════════════
# MAIN UNINSTALL
#═══════════════════════════════════════════════════════════════════════════════

main() {
    echo ""
    echo "${BOLD}VOIDWAVE Uninstaller${RESET}"
    echo "════════════════════════════════════════"
    echo ""

    local removed=0

    # Determine the actual user home (handle sudo)
    local user_home="$HOME"
    if [[ $EUID -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]]; then
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6 2>/dev/null || echo "/home/$SUDO_USER")
    fi

    #───────────────────────────────────────────────────────────────────────────
    # Remove Python package (pipx)
    #───────────────────────────────────────────────────────────────────────────
    if command -v pipx &>/dev/null; then
        log "Checking pipx..."
        if pipx list 2>/dev/null | grep -q voidwave; then
            log "Removing VOIDWAVE via pipx..."
            if pipx uninstall voidwave 2>/dev/null; then
                success "Removed via pipx"
                ((removed++))
            else
                warn "pipx uninstall failed"
            fi
        fi
    fi

    #───────────────────────────────────────────────────────────────────────────
    # Remove Python package (pip - user)
    #───────────────────────────────────────────────────────────────────────────
    log "Checking pip (user)..."
    if pip3 show voidwave &>/dev/null 2>&1; then
        log "Removing VOIDWAVE via pip..."
        pip3 uninstall -y voidwave 2>/dev/null && ((removed++)) || true
    fi

    #───────────────────────────────────────────────────────────────────────────
    # Remove Python package (pip - system, if root)
    #───────────────────────────────────────────────────────────────────────────
    if [[ $EUID -eq 0 ]]; then
        log "Checking pip (system)..."
        if pip3 show voidwave &>/dev/null 2>&1; then
            pip3 uninstall -y voidwave 2>/dev/null && ((removed++)) || true
        fi
    fi

    #───────────────────────────────────────────────────────────────────────────
    # Remove any stray voidwave commands
    #───────────────────────────────────────────────────────────────────────────
    local -a bin_paths=(
        "$user_home/.local/bin/voidwave"
        "/usr/local/bin/voidwave"
        "/usr/bin/voidwave"
    )

    for bin in "${bin_paths[@]}"; do
        if [[ -f "$bin" ]] || [[ -L "$bin" ]]; then
            log "Removing $bin..."
            if rm -f "$bin" 2>/dev/null; then
                success "Removed $bin"
                ((removed++))
            else
                warn "Could not remove $bin (permission denied?)"
            fi
        fi
    done

    #───────────────────────────────────────────────────────────────────────────
    # Remove data directory
    #───────────────────────────────────────────────────────────────────────────
    local data_dir="$user_home/.local/share/voidwave"
    if [[ -d "$data_dir" ]]; then
        log "Removing data directory: $data_dir"
        rm -rf "$data_dir" && ((removed++))
        success "Removed $data_dir"
    fi

    #───────────────────────────────────────────────────────────────────────────
    # Remove cache
    #───────────────────────────────────────────────────────────────────────────
    local cache_dir="$user_home/.cache/voidwave"
    if [[ -d "$cache_dir" ]]; then
        log "Removing cache: $cache_dir"
        rm -rf "$cache_dir" && ((removed++))
        success "Removed $cache_dir"
    fi

    # Also clear pipx cache for voidwave
    if [[ -d "$user_home/.cache/pipx" ]]; then
        log "Clearing pipx cache..."
        rm -rf "$user_home/.cache/pipx" 2>/dev/null || true
    fi

    #───────────────────────────────────────────────────────────────────────────
    # Handle config directory
    #───────────────────────────────────────────────────────────────────────────
    local config_dir="$user_home/.voidwave"
    if [[ -d "$config_dir" ]]; then
        if [[ $OPT_ALL -eq 1 ]]; then
            log "Removing config: $config_dir"
            rm -rf "$config_dir" && ((removed++))
            success "Removed $config_dir"
        elif [[ $OPT_KEEP_CONFIG -eq 1 ]]; then
            log "Keeping config: $config_dir"
        else
            # Interactive mode
            echo ""
            if [[ -t 0 ]]; then
                read -r -p "Remove configuration directory $config_dir? [y/N]: " ans
                if [[ "${ans,,}" == y* ]]; then
                    rm -rf "$config_dir" && ((removed++))
                    success "Removed $config_dir"
                else
                    log "Keeping $config_dir"
                fi
            else
                log "Keeping $config_dir (use --all to remove)"
            fi
        fi
    fi

    #───────────────────────────────────────────────────────────────────────────
    # Remove old bash-based installation (if exists)
    #───────────────────────────────────────────────────────────────────────────
    local -a old_roots=(
        "/opt/voidwave"
        "/usr/local/share/voidwave"
        "/usr/local/lib/voidwave"
        "$user_home/.local/share/voidwave"
    )

    for old_root in "${old_roots[@]}"; do
        if [[ -d "$old_root" ]] && [[ -f "$old_root/VERSION" ]]; then
            log "Found old installation at $old_root"
            if rm -rf "$old_root" 2>/dev/null; then
                success "Removed $old_root"
                ((removed++))
            else
                warn "Could not remove $old_root"
            fi
        fi
    done

    #───────────────────────────────────────────────────────────────────────────
    # Clean up PATH entries (inform user)
    #───────────────────────────────────────────────────────────────────────────
    local -a rc_files=("$user_home/.bashrc" "$user_home/.zshrc")
    for rc in "${rc_files[@]}"; do
        if [[ -f "$rc" ]] && grep -q "VOIDWAVE" "$rc" 2>/dev/null; then
            warn "Found VOIDWAVE PATH entry in $rc"
            warn "You may want to manually remove the VOIDWAVE lines"
        fi
    done

    #───────────────────────────────────────────────────────────────────────────
    # Summary
    #───────────────────────────────────────────────────────────────────────────
    echo ""
    echo "════════════════════════════════════════"
    if [[ $removed -gt 0 ]]; then
        success "Uninstall complete ($removed items removed)"
    else
        log "No VOIDWAVE installation found"
    fi

    # Verify removal
    if command -v voidwave &>/dev/null; then
        echo ""
        warn "Warning: 'voidwave' command still exists at $(command -v voidwave)"
        warn "You may need to remove it manually or restart your terminal"
    fi
}

main "$@"
