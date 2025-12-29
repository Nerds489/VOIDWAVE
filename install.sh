#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE 2.0 Installer
# ═══════════════════════════════════════════════════════════════════════════════
# Modern Python TUI-based security framework installer.
# Supports all major Linux distributions and immutable systems.
#
# Usage:
#   ./install.sh                    # Auto-detect best install method
#   ./install.sh --user             # Force user install (pipx)
#   ./install.sh --system           # Force system install (requires root)
#   ./install.sh --tools            # Also install security tools
#   ./install.sh --tools-only       # Only install security tools
#   ./install.sh --uninstall        # Remove VOIDWAVE
#   ./install.sh --dev              # Install in development mode
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

readonly VERSION="2.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MIN_PYTHON_VERSION="3.11"

# Colors (if terminal supports them)
if [[ -t 1 ]] && command -v tput &>/dev/null; then
    readonly RED=$(tput setaf 1)
    readonly GREEN=$(tput setaf 2)
    readonly YELLOW=$(tput setaf 3)
    readonly BLUE=$(tput setaf 4)
    readonly MAGENTA=$(tput setaf 5)
    readonly CYAN=$(tput setaf 6)
    readonly BOLD=$(tput bold)
    readonly RESET=$(tput sgr0)
else
    readonly RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" BOLD="" RESET=""
fi

#═══════════════════════════════════════════════════════════════════════════════
# LOGGING
#═══════════════════════════════════════════════════════════════════════════════

log()     { echo "${CYAN}[*]${RESET} $*"; }
success() { echo "${GREEN}[✓]${RESET} $*"; }
warn()    { echo "${YELLOW}[!]${RESET} $*" >&2; }
error()   { echo "${RED}[✗]${RESET} $*" >&2; }
header()  { echo "${BOLD}${MAGENTA}$*${RESET}"; }
step()    { echo "${BLUE}==>${RESET} $*"; }

#═══════════════════════════════════════════════════════════════════════════════
# SYSTEM DETECTION
#═══════════════════════════════════════════════════════════════════════════════

DISTRO_ID=""
DISTRO_NAME=""
DISTRO_FAMILY=""
PKG_MANAGER=""
ARCH=""
IS_ROOT=0
IS_IMMUTABLE=0
IS_WSL=0
IS_CONTAINER=0
HAS_SUDO=0

detect_system() {
    ARCH=$(uname -m)
    [[ $EUID -eq 0 ]] && IS_ROOT=1
    command -v sudo &>/dev/null && HAS_SUDO=1

    # Parse os-release
    if [[ -f /etc/os-release ]]; then
        DISTRO_ID=$(grep -oP '^ID=\K.*' /etc/os-release | tr -d '"' | head -1)
        DISTRO_NAME=$(grep -oP '^PRETTY_NAME=\K.*' /etc/os-release | tr -d '"' | head -1)
    fi

    # Detect distro family and package manager
    case "$DISTRO_ID" in
        ubuntu|debian|pop|linuxmint|elementary|zorin|kali|parrot|raspbian)
            DISTRO_FAMILY="debian"; PKG_MANAGER="apt" ;;
        fedora|rhel|centos|rocky|alma|oracle|amazon)
            DISTRO_FAMILY="redhat"; PKG_MANAGER="dnf"
            command -v dnf &>/dev/null || PKG_MANAGER="yum" ;;
        arch|manjaro|endeavouros|garuda|artix|cachyos)
            DISTRO_FAMILY="arch"; PKG_MANAGER="pacman" ;;
        opensuse*|suse|sles)
            DISTRO_FAMILY="suse"; PKG_MANAGER="zypper" ;;
        alpine)
            DISTRO_FAMILY="alpine"; PKG_MANAGER="apk" ;;
        nixos)
            DISTRO_FAMILY="nixos"; PKG_MANAGER="nix"; IS_IMMUTABLE=1 ;;
        void)
            DISTRO_FAMILY="void"; PKG_MANAGER="xbps" ;;
        gentoo)
            DISTRO_FAMILY="gentoo"; PKG_MANAGER="emerge" ;;
        steamos|chimeraos)
            DISTRO_FAMILY="arch"; PKG_MANAGER="pacman"; IS_IMMUTABLE=1 ;;
        bazzite|silverblue|kinoite)
            DISTRO_FAMILY="redhat"; PKG_MANAGER="rpm-ostree"; IS_IMMUTABLE=1 ;;
        *)
            DISTRO_FAMILY="unknown"
            if command -v apt-get &>/dev/null; then PKG_MANAGER="apt"; DISTRO_FAMILY="debian"
            elif command -v dnf &>/dev/null; then PKG_MANAGER="dnf"; DISTRO_FAMILY="redhat"
            elif command -v pacman &>/dev/null; then PKG_MANAGER="pacman"; DISTRO_FAMILY="arch"
            elif command -v zypper &>/dev/null; then PKG_MANAGER="zypper"; DISTRO_FAMILY="suse"
            elif command -v apk &>/dev/null; then PKG_MANAGER="apk"; DISTRO_FAMILY="alpine"
            else PKG_MANAGER="unknown"
            fi ;;
    esac

    # Detect immutable (if not already)
    if [[ $IS_IMMUTABLE -eq 0 ]]; then
        command -v rpm-ostree &>/dev/null && IS_IMMUTABLE=1
        [[ -d /ostree ]] && IS_IMMUTABLE=1
        [[ -f /etc/NIXOS ]] && IS_IMMUTABLE=1
    fi

    # Detect WSL
    if grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        IS_WSL=1
    fi

    # Detect container
    if [[ -f /.dockerenv ]] || [[ -f /run/.containerenv ]] || \
       grep -qE "docker|lxc|podman" /proc/1/cgroup 2>/dev/null; then
        IS_CONTAINER=1
    fi
}

show_system_info() {
    header "System Information"
    echo "  Distro:      ${DISTRO_NAME:-$DISTRO_ID}"
    echo "  Family:      $DISTRO_FAMILY"
    echo "  Package Mgr: $PKG_MANAGER"
    echo "  Arch:        $ARCH"
    echo "  Root:        $([[ $IS_ROOT -eq 1 ]] && echo "Yes" || echo "No")"
    echo "  Immutable:   $([[ $IS_IMMUTABLE -eq 1 ]] && echo "Yes" || echo "No")"
    echo "  WSL:         $([[ $IS_WSL -eq 1 ]] && echo "Yes" || echo "No")"
    echo "  Container:   $([[ $IS_CONTAINER -eq 1 ]] && echo "Yes" || echo "No")"
}

#═══════════════════════════════════════════════════════════════════════════════
# ARGUMENT PARSING
#═══════════════════════════════════════════════════════════════════════════════

OPT_USER=0
OPT_SYSTEM=0
OPT_TOOLS=0
OPT_TOOLS_ONLY=0
OPT_DEV=0
OPT_UNINSTALL=0
OPT_FORCE=0
OPT_INFO=0

show_help() {
    cat << 'EOF'
VOIDWAVE 2.0 Installer

Usage: ./install.sh [OPTIONS]

Options:
  --user          Install for current user only (uses pipx)
  --system        Install system-wide (requires root)
  --tools         Also install optional security tools
  --tools-only    Only install security tools (skip VOIDWAVE)
  --dev           Install in development/editable mode
  --force         Overwrite existing installation
  --uninstall     Remove VOIDWAVE installation
  --info          Show system information and exit
  --help          Show this help message

Examples:
  ./install.sh                    # Auto-detect best method
  ./install.sh --user --tools     # User install + security tools
  sudo ./install.sh --system      # System-wide install
  ./install.sh --dev              # Development install

Immutable Systems (Steam Deck, Silverblue, Bazzite):
  Auto-detected, uses user install via pipx.
  For full pentesting, use distrobox with Kali.

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --user)       OPT_USER=1; shift ;;
            --system)     OPT_SYSTEM=1; shift ;;
            --tools)      OPT_TOOLS=1; shift ;;
            --tools-only) OPT_TOOLS_ONLY=1; shift ;;
            --dev)        OPT_DEV=1; shift ;;
            --force)      OPT_FORCE=1; shift ;;
            --uninstall)  OPT_UNINSTALL=1; shift ;;
            --info)       OPT_INFO=1; shift ;;
            --help|-h)    show_help; exit 0 ;;
            *)            error "Unknown option: $1"; show_help; exit 1 ;;
        esac
    done
}

#═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCY CHECKS
#═══════════════════════════════════════════════════════════════════════════════

PYTHON_CMD=""
PIP_CMD=""
PIPX_CMD=""

check_python() {
    step "Checking Python installation..."

    # Find Python 3.11+
    for py in python3.14 python3.13 python3.12 python3.11 python3 python; do
        if command -v "$py" &>/dev/null; then
            local ver
            ver=$("$py" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "0.0")
            if [[ "$(printf '%s\n' "$MIN_PYTHON_VERSION" "$ver" | sort -V | head -1)" == "$MIN_PYTHON_VERSION" ]]; then
                PYTHON_CMD="$py"
                log "Found Python $ver at $(command -v "$py")"
                break
            fi
        fi
    done

    if [[ -z "$PYTHON_CMD" ]]; then
        error "Python $MIN_PYTHON_VERSION or later required"
        echo ""
        echo "Install Python:"
        case "$DISTRO_FAMILY" in
            debian) echo "  sudo apt install python3.12 python3.12-venv python3-pip" ;;
            redhat) echo "  sudo dnf install python3.12" ;;
            arch)   echo "  sudo pacman -S python" ;;
            suse)   echo "  sudo zypper install python312" ;;
            alpine) echo "  sudo apk add python3" ;;
            *)      echo "  Install Python 3.11+ from your package manager" ;;
        esac
        exit 1
    fi
}

check_pip() {
    step "Checking pip..."

    # Try pip directly
    for pip in pip3 pip "$PYTHON_CMD -m pip"; do
        if $pip --version &>/dev/null; then
            PIP_CMD="$pip"
            break
        fi
    done

    if [[ -z "$PIP_CMD" ]]; then
        warn "pip not found, attempting to install..."
        case "$DISTRO_FAMILY" in
            debian) run_pkg_install python3-pip ;;
            redhat) run_pkg_install python3-pip ;;
            arch)   run_pkg_install python-pip ;;
            *)      $PYTHON_CMD -m ensurepip --user 2>/dev/null || true ;;
        esac
        PIP_CMD="$PYTHON_CMD -m pip"
    fi
}

check_pipx() {
    step "Checking pipx..."

    if command -v pipx &>/dev/null; then
        PIPX_CMD="pipx"
        log "Found pipx at $(command -v pipx)"
        return 0
    fi

    # Try to install pipx
    warn "pipx not found, attempting to install..."

    case "$DISTRO_FAMILY" in
        debian)
            run_pkg_install pipx || $PIP_CMD install --user pipx 2>/dev/null || true ;;
        redhat)
            run_pkg_install pipx || $PIP_CMD install --user pipx 2>/dev/null || true ;;
        arch)
            run_pkg_install python-pipx || $PIP_CMD install --user pipx 2>/dev/null || true ;;
        *)
            $PIP_CMD install --user pipx 2>/dev/null || true ;;
    esac

    # Check again
    if command -v pipx &>/dev/null; then
        PIPX_CMD="pipx"
    elif [[ -x "$HOME/.local/bin/pipx" ]]; then
        PIPX_CMD="$HOME/.local/bin/pipx"
    else
        # Try using pip module
        if $PYTHON_CMD -m pipx --version &>/dev/null; then
            PIPX_CMD="$PYTHON_CMD -m pipx"
        fi
    fi

    if [[ -z "$PIPX_CMD" ]]; then
        warn "Could not install pipx, will use pip instead"
        return 1
    fi

    # Ensure pipx path
    $PIPX_CMD ensurepath 2>/dev/null || true
    return 0
}

#═══════════════════════════════════════════════════════════════════════════════
# PACKAGE INSTALLATION HELPERS
#═══════════════════════════════════════════════════════════════════════════════

run_pkg_install() {
    local pkg="$1"
    local cmd=""

    case "$PKG_MANAGER" in
        apt)        cmd="apt-get install -y $pkg" ;;
        dnf)        cmd="dnf install -y $pkg" ;;
        yum)        cmd="yum install -y $pkg" ;;
        pacman)     cmd="pacman -S --noconfirm $pkg" ;;
        zypper)     cmd="zypper install -y $pkg" ;;
        apk)        cmd="apk add $pkg" ;;
        rpm-ostree) cmd="rpm-ostree install $pkg"; warn "May require reboot" ;;
        *)          warn "Unknown package manager"; return 1 ;;
    esac

    if [[ $IS_ROOT -eq 1 ]]; then
        eval "$cmd"
    elif [[ $HAS_SUDO -eq 1 ]]; then
        eval "sudo $cmd"
    else
        error "Root privileges required to install $pkg"
        return 1
    fi
}

# Map tool name to package name per distro
get_pkg_name() {
    local tool="$1"
    case "$DISTRO_FAMILY" in
        debian)
            case "$tool" in
                nmap) echo "nmap" ;;
                masscan) echo "masscan" ;;
                aircrack-ng) echo "aircrack-ng" ;;
                hashcat) echo "hashcat" ;;
                john) echo "john" ;;
                hydra) echo "hydra" ;;
                nikto) echo "nikto" ;;
                sqlmap) echo "sqlmap" ;;
                wireshark) echo "wireshark" ;;
                tcpdump) echo "tcpdump" ;;
                hping3) echo "hping3" ;;
                iperf3) echo "iperf3" ;;
                netcat) echo "netcat-openbsd" ;;
                gobuster) echo "gobuster" ;;
                ffuf) echo "ffuf" ;;
                nuclei) echo "" ;; # Not in repos
                subfinder) echo "" ;; # Not in repos
                theharvester) echo "" ;; # Use pip: pip3 install theHarvester
                *) echo "$tool" ;;
            esac ;;
        redhat)
            case "$tool" in
                nmap) echo "nmap" ;;
                masscan) echo "masscan" ;;
                aircrack-ng) echo "aircrack-ng" ;;
                hashcat) echo "hashcat" ;;
                john) echo "john" ;;
                hydra) echo "hydra" ;;
                wireshark) echo "wireshark-cli" ;;
                tcpdump) echo "tcpdump" ;;
                hping3) echo "hping3" ;;
                iperf3) echo "iperf3" ;;
                netcat) echo "nc" ;;
                *) echo "$tool" ;;
            esac ;;
        arch)
            case "$tool" in
                nmap) echo "nmap" ;;
                masscan) echo "masscan" ;;
                aircrack-ng) echo "aircrack-ng" ;;
                hashcat) echo "hashcat" ;;
                john) echo "john" ;;
                hydra) echo "hydra" ;;
                nikto) echo "nikto" ;;
                sqlmap) echo "sqlmap" ;;
                wireshark) echo "wireshark-cli" ;;
                tcpdump) echo "tcpdump" ;;
                hping3) echo "hping" ;;
                iperf3) echo "iperf3" ;;
                netcat) echo "gnu-netcat" ;;
                gobuster) echo "gobuster" ;;
                nuclei) echo "nuclei" ;;
                subfinder) echo "subfinder" ;;
                theharvester) echo "theharvester" ;;
                *) echo "$tool" ;;
            esac ;;
        *)
            echo "$tool" ;;
    esac
}

#═══════════════════════════════════════════════════════════════════════════════
# SECURITY TOOLS INSTALLATION
#═══════════════════════════════════════════════════════════════════════════════

# Core tools that most users will want
CORE_TOOLS=(
    nmap
    tcpdump
    netcat
    curl
    wget
)

# Network/scanning tools
NETWORK_TOOLS=(
    masscan
    wireshark
    hping3
)

# Wireless tools
WIRELESS_TOOLS=(
    aircrack-ng
)

# Password/cracking tools
CRACKING_TOOLS=(
    hashcat
    john
    hydra
)

# Web testing tools
WEB_TOOLS=(
    nikto
    sqlmap
    gobuster
    ffuf
)

# Recon tools
RECON_TOOLS=(
    whois
    dnsutils
    subfinder
    nuclei
)

# Stress testing tools
STRESS_TOOLS=(
    hping3
    iperf3
)

install_security_tools() {
    header "Installing Security Tools"
    echo ""

    if [[ $IS_IMMUTABLE -eq 1 ]]; then
        warn "Immutable system detected"
        warn "Security tools should be installed in a distrobox/toolbox container"
        echo ""
        echo "  distrobox create --name pentest --image docker.io/kalilinux/kali-rolling"
        echo "  distrobox enter pentest"
        echo "  sudo apt update && sudo apt install kali-linux-default"
        echo ""
        return 0
    fi

    local installed=0
    local failed=0
    local skipped=0

    # Combine all tools
    local -a ALL_TOOLS=("${CORE_TOOLS[@]}" "${NETWORK_TOOLS[@]}" "${WIRELESS_TOOLS[@]}"
                        "${CRACKING_TOOLS[@]}" "${WEB_TOOLS[@]}" "${RECON_TOOLS[@]}"
                        "${STRESS_TOOLS[@]}")

    for tool in "${ALL_TOOLS[@]}"; do
        # Skip if already installed
        if command -v "$tool" &>/dev/null; then
            log "$tool already installed"
            ((skipped++))
            continue
        fi

        local pkg
        pkg=$(get_pkg_name "$tool")

        if [[ -z "$pkg" ]]; then
            warn "$tool not available in repositories"
            ((failed++))
            continue
        fi

        step "Installing $tool ($pkg)..."
        if run_pkg_install "$pkg" 2>/dev/null; then
            success "Installed $tool"
            ((installed++))
        else
            warn "Failed to install $tool"
            ((failed++))
        fi
    done

    echo ""
    success "Tools: $installed installed, $skipped already present, $failed failed"
}

#═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE INSTALLATION
#═══════════════════════════════════════════════════════════════════════════════

install_voidwave_pipx() {
    header "Installing VOIDWAVE via pipx"

    if [[ $OPT_FORCE -eq 1 ]]; then
        log "Removing existing installation..."
        $PIPX_CMD uninstall voidwave 2>/dev/null || true
    fi

    if [[ $OPT_DEV -eq 1 ]]; then
        step "Installing in development mode..."
        $PIPX_CMD install --editable "$SCRIPT_DIR" --force
    else
        step "Installing from local source..."
        $PIPX_CMD install "$SCRIPT_DIR" --force
    fi

    # Verify installation
    if command -v voidwave &>/dev/null || [[ -x "$HOME/.local/bin/voidwave" ]]; then
        success "VOIDWAVE installed successfully"
        return 0
    else
        error "Installation verification failed"
        return 1
    fi
}

install_voidwave_pip() {
    header "Installing VOIDWAVE via pip"

    local pip_args=""
    [[ $OPT_USER -eq 1 ]] || [[ $IS_ROOT -eq 0 ]] && pip_args="--user"

    if [[ $OPT_DEV -eq 1 ]]; then
        step "Installing in development mode..."
        $PIP_CMD install $pip_args -e "$SCRIPT_DIR"
    else
        step "Installing from local source..."
        $PIP_CMD install $pip_args "$SCRIPT_DIR"
    fi

    # Verify
    if $PYTHON_CMD -c "import voidwave" 2>/dev/null; then
        success "VOIDWAVE installed successfully"
        return 0
    else
        error "Installation verification failed"
        return 1
    fi
}

install_voidwave() {
    # Check for existing installation
    if command -v voidwave &>/dev/null && [[ $OPT_FORCE -eq 0 ]]; then
        local existing_ver
        existing_ver=$(voidwave --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
        warn "VOIDWAVE $existing_ver already installed"
        echo "  Use --force to overwrite"
        echo "  Use --uninstall to remove first"
        return 1
    fi

    # Choose installation method
    if [[ -n "$PIPX_CMD" ]]; then
        install_voidwave_pipx
    else
        install_voidwave_pip
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# UNINSTALL
#═══════════════════════════════════════════════════════════════════════════════

uninstall_voidwave() {
    header "Uninstalling VOIDWAVE"
    local removed=0

    # Try pipx first
    if command -v pipx &>/dev/null; then
        step "Removing via pipx..."
        if pipx uninstall voidwave 2>/dev/null; then
            success "Removed via pipx"
            ((removed++))
        fi
    fi

    # Try pip
    step "Checking pip installations..."
    if $PIP_CMD show voidwave &>/dev/null; then
        $PIP_CMD uninstall -y voidwave 2>/dev/null && ((removed++))
    fi
    if $PIP_CMD show --user voidwave &>/dev/null 2>/dev/null; then
        $PIP_CMD uninstall --user -y voidwave 2>/dev/null && ((removed++))
    fi

    # Remove config directory (ask first)
    local config_dir="$HOME/.voidwave"
    if [[ -d "$config_dir" ]]; then
        echo ""
        if [[ -t 0 ]]; then
            read -r -p "Remove config directory $config_dir? [y/N]: " ans
            if [[ "${ans,,}" == y* ]]; then
                rm -rf "$config_dir"
                success "Removed $config_dir"
                ((removed++))
            else
                log "Keeping $config_dir"
            fi
        fi
    fi

    # Remove data directory
    local data_dir="$HOME/.local/share/voidwave"
    if [[ -d "$data_dir" ]]; then
        rm -rf "$data_dir"
        success "Removed $data_dir"
        ((removed++))
    fi

    echo ""
    if [[ $removed -gt 0 ]]; then
        success "Uninstall complete"
    else
        warn "No VOIDWAVE installation found"
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# PATH CONFIGURATION
#═══════════════════════════════════════════════════════════════════════════════

configure_path() {
    local bin_dir="$HOME/.local/bin"

    # Check if already in PATH
    if [[ ":$PATH:" == *":$bin_dir:"* ]]; then
        return 0
    fi

    # pipx ensurepath should handle this, but double-check
    local rc_files=()
    [[ -f "$HOME/.bashrc" ]] && rc_files+=("$HOME/.bashrc")
    [[ -f "$HOME/.zshrc" ]] && rc_files+=("$HOME/.zshrc")

    for rc in "${rc_files[@]}"; do
        if ! grep -q "\.local/bin" "$rc" 2>/dev/null; then
            echo "" >> "$rc"
            echo '# Added by VOIDWAVE installer' >> "$rc"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
            log "Added PATH to $rc"
        fi
    done

    if [[ ${#rc_files[@]} -gt 0 ]]; then
        warn "Restart your terminal or run: source ~/.bashrc"
    fi
}

#═══════════════════════════════════════════════════════════════════════════════
# MAIN
#═══════════════════════════════════════════════════════════════════════════════

main() {
    echo ""
    header "╔═══════════════════════════════════════════════════════════════╗"
    header "║           VOIDWAVE $VERSION Installer                          ║"
    header "║     Offensive Security Framework with Modern TUI             ║"
    header "╚═══════════════════════════════════════════════════════════════╝"
    echo ""

    parse_args "$@"
    detect_system

    # Show info and exit
    if [[ $OPT_INFO -eq 1 ]]; then
        show_system_info
        exit 0
    fi

    # Handle uninstall
    if [[ $OPT_UNINSTALL -eq 1 ]]; then
        check_python
        check_pip
        uninstall_voidwave
        exit 0
    fi

    # Warn about immutable systems
    if [[ $IS_IMMUTABLE -eq 1 ]]; then
        echo ""
        warn "Immutable system detected: ${DISTRO_NAME:-$DISTRO_ID}"
        log "Using user installation (pipx)"
        OPT_USER=1
        echo ""
    fi

    # Tools only mode
    if [[ $OPT_TOOLS_ONLY -eq 1 ]]; then
        install_security_tools
        exit 0
    fi

    # Check dependencies
    echo ""
    header "Checking Dependencies"
    check_python
    check_pip
    check_pipx || true  # Continue even if pipx fails

    # Validate source
    if [[ ! -f "$SCRIPT_DIR/pyproject.toml" ]]; then
        error "Invalid source directory: pyproject.toml not found"
        error "Run this script from the VOIDWAVE source directory"
        exit 1
    fi

    # Install VOIDWAVE
    echo ""
    if ! install_voidwave; then
        exit 1
    fi

    # Configure PATH
    configure_path

    # Install tools if requested
    if [[ $OPT_TOOLS -eq 1 ]]; then
        echo ""
        install_security_tools
    fi

    # Final message
    echo ""
    header "Installation Complete!"
    echo ""
    echo "  Run 'voidwave' to start the TUI"
    echo "  Run 'voidwave --help' for options"
    echo ""

    if [[ $OPT_TOOLS -eq 0 ]]; then
        echo "  Tip: Run './install.sh --tools' to install security tools"
        echo ""
    fi

    # Show PATH reminder if needed
    if ! command -v voidwave &>/dev/null; then
        warn "Restart your terminal or run: source ~/.bashrc"
    fi
}

main "$@"
