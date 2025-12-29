#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE Universal Tool Installer
# ═══════════════════════════════════════════════════════════════════════════════
# Multi-method installer with comprehensive fallback support:
#   1. System package managers (apt, dnf, pacman, zypper, apk)
#   2. pip/pipx (Python packages)
#   3. GitHub releases (binary downloads)
#   4. Go install
#   5. Cargo install (Rust)
#   6. Snap packages
#   7. Flatpak packages
#   8. AppImage downloads
#   9. Source compilation
#
# Usage:
#   ./install-tools.sh                    # Install all missing tools
#   ./install-tools.sh --list             # List all tools and status
#   ./install-tools.sh --install <tool>   # Install specific tool
#   ./install-tools.sh --category <cat>   # Install tools in category
#   ./install-tools.sh --missing          # Install only missing tools
#   ./install-tools.sh --update           # Update all installed tools
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

readonly INSTALLER_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Installation directories
readonly LOCAL_BIN="${HOME}/.local/bin"
readonly LOCAL_OPT="${HOME}/.local/opt"
readonly LOCAL_SHARE="${HOME}/.local/share"

# Temp directory for downloads
readonly TEMP_DIR="${TMPDIR:-/tmp}/voidwave-install-$$"

# Architecture detection
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64) ARCH="amd64"; ARCH_ALT="x86_64"; ARCH_GO="amd64" ;;
    aarch64|arm64) ARCH="arm64"; ARCH_ALT="aarch64"; ARCH_GO="arm64" ;;
    armv7l|armhf) ARCH="arm"; ARCH_ALT="armv7"; ARCH_GO="arm" ;;
    i686|i386) ARCH="386"; ARCH_ALT="i686"; ARCH_GO="386" ;;
    *) ARCH="unknown"; ARCH_ALT="unknown"; ARCH_GO="unknown" ;;
esac

# ═══════════════════════════════════════════════════════════════════════════════
# COLORS
# ═══════════════════════════════════════════════════════════════════════════════
if [[ -t 1 ]] && command -v tput &>/dev/null && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
    readonly RED=$(tput setaf 1)
    readonly GREEN=$(tput setaf 2)
    readonly YELLOW=$(tput setaf 3)
    readonly BLUE=$(tput setaf 4)
    readonly MAGENTA=$(tput setaf 5)
    readonly CYAN=$(tput setaf 6)
    readonly WHITE=$(tput setaf 7)
    readonly BOLD=$(tput bold)
    readonly DIM=$(tput dim)
    readonly RESET=$(tput sgr0)
else
    readonly RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" WHITE=""
    readonly BOLD="" DIM="" RESET=""
fi

# ═══════════════════════════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════════════════════════
log()       { echo -e "${CYAN}[*]${RESET} $*"; }
success()   { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()      { echo -e "${YELLOW}[!]${RESET} $*" >&2; }
error()     { echo -e "${RED}[✗]${RESET} $*" >&2; }
debug()     { [[ "${DEBUG:-0}" == "1" ]] && echo -e "${DIM}[D]${RESET} $*" >&2 || true; }
step()      { echo -e "${BLUE}==>${RESET} $*"; }
substep()   { echo -e "    ${DIM}→${RESET} $*"; }

header() {
    echo ""
    echo -e "${BOLD}${MAGENTA}═══════════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${MAGENTA}  $*${RESET}"
    echo -e "${BOLD}${MAGENTA}═══════════════════════════════════════════════════════════════${RESET}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# SYSTEM DETECTION
# ═══════════════════════════════════════════════════════════════════════════════
DISTRO_ID=""
DISTRO_FAMILY=""
PKG_MANAGER=""
IS_ROOT=0
HAS_SUDO=0
APT_UPDATED=0
AUTO_YES=0

detect_system() {
    [[ $EUID -eq 0 ]] && IS_ROOT=1
    command -v sudo &>/dev/null && HAS_SUDO=1

    # Parse os-release
    if [[ -f /etc/os-release ]]; then
        DISTRO_ID=$(grep -oP '^ID=\K.*' /etc/os-release | tr -d '"' | head -1)
    fi

    # Detect distro family and package manager
    case "$DISTRO_ID" in
        ubuntu|debian|pop|linuxmint|elementary|zorin|kali|parrot|raspbian|mx)
            DISTRO_FAMILY="debian"; PKG_MANAGER="apt" ;;
        fedora)
            DISTRO_FAMILY="fedora"; PKG_MANAGER="dnf" ;;
        rhel|centos|rocky|alma|oracle|amazon)
            DISTRO_FAMILY="redhat"; PKG_MANAGER="dnf"
            command -v dnf &>/dev/null || PKG_MANAGER="yum" ;;
        arch|manjaro|endeavouros|garuda|artix|cachyos|blackarch)
            DISTRO_FAMILY="arch"; PKG_MANAGER="pacman" ;;
        opensuse*|suse|sles)
            DISTRO_FAMILY="suse"; PKG_MANAGER="zypper" ;;
        alpine)
            DISTRO_FAMILY="alpine"; PKG_MANAGER="apk" ;;
        void)
            DISTRO_FAMILY="void"; PKG_MANAGER="xbps" ;;
        gentoo)
            DISTRO_FAMILY="gentoo"; PKG_MANAGER="emerge" ;;
        *)
            DISTRO_FAMILY="unknown"
            for pm in apt dnf yum pacman zypper apk; do
                if command -v "$pm" &>/dev/null; then
                    PKG_MANAGER="$pm"
                    break
                fi
            done ;;
    esac

    # Detect available installation methods
    HAS_PIP=$(command -v pip3 &>/dev/null && echo 1 || echo 0)
    HAS_PIPX=$(command -v pipx &>/dev/null && echo 1 || echo 0)
    HAS_GO=$(command -v go &>/dev/null && echo 1 || echo 0)
    HAS_CARGO=$(command -v cargo &>/dev/null && echo 1 || echo 0)
    HAS_SNAP=$(command -v snap &>/dev/null && echo 1 || echo 0)
    HAS_FLATPAK=$(command -v flatpak &>/dev/null && echo 1 || echo 0)
    HAS_CURL=$(command -v curl &>/dev/null && echo 1 || echo 0)
    HAS_WGET=$(command -v wget &>/dev/null && echo 1 || echo 0)
    HAS_GIT=$(command -v git &>/dev/null && echo 1 || echo 0)
}

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

# Run command with sudo if needed
run_privileged() {
    if [[ $IS_ROOT -eq 1 ]]; then
        "$@"
    elif [[ $HAS_SUDO -eq 1 ]]; then
        sudo "$@"
    else
        error "Root privileges required"
        return 1
    fi
}

# Download file
download() {
    local url="$1"
    local dest="$2"

    if [[ $HAS_CURL -eq 1 ]]; then
        curl -fsSL "$url" -o "$dest"
    elif [[ $HAS_WGET -eq 1 ]]; then
        wget -q "$url" -O "$dest"
    else
        error "No download tool available (curl/wget)"
        return 1
    fi
}

# Get latest GitHub release tag
get_github_latest() {
    local repo="$1"
    local url="https://api.github.com/repos/${repo}/releases/latest"

    if [[ $HAS_CURL -eq 1 ]]; then
        curl -fsSL "$url" 2>/dev/null | grep -oP '"tag_name":\s*"\K[^"]+' | head -1
    elif [[ $HAS_WGET -eq 1 ]]; then
        wget -qO- "$url" 2>/dev/null | grep -oP '"tag_name":\s*"\K[^"]+' | head -1
    fi
}

# Check if command exists
has_cmd() {
    command -v "$1" &>/dev/null
}

# Ensure directory exists
ensure_dir() {
    [[ -d "$1" ]] || mkdir -p "$1"
}

# Add to PATH if not present
ensure_path() {
    local dir="$1"
    if [[ ":$PATH:" != *":$dir:"* ]]; then
        export PATH="$dir:$PATH"
    fi
}

# Cleanup temp files
cleanup() {
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════════
# TOOL DEFINITIONS
# ═══════════════════════════════════════════════════════════════════════════════
# Format: TOOL_NAME|CATEGORY|BINARY_NAME|METHODS
#   Methods: pkg:NAME, pip:NAME, pipx:NAME, go:PATH, cargo:NAME,
#            github:REPO:PATTERN, snap:NAME, flatpak:ID, appimage:URL,
#            git:URL:BUILD_CMD

declare -A TOOLS=(
    # ═══════════════════ WIRELESS ═══════════════════
    ["aircrack-ng"]="wireless|aircrack-ng|pkg:aircrack-ng"
    ["airodump-ng"]="wireless|airodump-ng|pkg:aircrack-ng"
    ["aireplay-ng"]="wireless|aireplay-ng|pkg:aircrack-ng"
    ["airmon-ng"]="wireless|airmon-ng|pkg:aircrack-ng"
    ["reaver"]="wireless|reaver|pkg:reaver,github:t6x/reaver-wps-fork-t6x:reaver"
    ["bully"]="wireless|bully|pkg:bully,github:aanarchyy/bully:bully"
    ["wash"]="wireless|wash|pkg:reaver"
    ["wifite"]="wireless|wifite|pkg:wifite,pipx:wifite2,pip:wifite2,pygithub:derv82/wifite2"
    ["hostapd"]="wireless|hostapd|pkg:hostapd"
    ["dnsmasq"]="wireless|dnsmasq|pkg:dnsmasq"
    ["hcxdumptool"]="wireless|hcxdumptool|pkg:hcxdumptool,github:ZerBea/hcxdumptool:hcxdumptool"
    ["hcxpcapngtool"]="wireless|hcxpcapngtool|pkg:hcxtools,github:ZerBea/hcxtools:hcxpcapngtool"
    ["mdk4"]="wireless|mdk4|pkg:mdk4,github:aircrack-ng/mdk4:mdk4"
    ["kismet"]="wireless|kismet|pkg:kismet"
    ["fern-wifi-cracker"]="wireless|fern-wifi-cracker|pkg:fern-wifi-cracker"
    ["iw"]="wireless|iw|pkg:iw"
    ["macchanger"]="wireless|macchanger|pkg:macchanger"
    ["pixiewps"]="wireless|pixiewps|pkg:pixiewps,github:wiire-a/pixiewps:pixiewps"

    # ═══════════════════ SCANNING ═══════════════════
    ["nmap"]="scanning|nmap|pkg:nmap,snap:nmap"
    ["masscan"]="scanning|masscan|pkg:masscan,github:robertdavidgraham/masscan:masscan"
    ["rustscan"]="scanning|rustscan|pkg:rustscan,cargo:rustscan,github:RustScan/RustScan:rustscan"
    ["netdiscover"]="scanning|netdiscover|pkg:netdiscover"
    ["arp-scan"]="scanning|arp-scan|pkg:arp-scan"
    ["unicornscan"]="scanning|unicornscan|pkg:unicornscan"
    ["nbtscan"]="scanning|nbtscan|pkg:nbtscan"
    ["enum4linux"]="scanning|enum4linux|pkg:enum4linux,github:CiscoCXSecurity/enum4linux:enum4linux.pl"
    ["smbclient"]="scanning|smbclient|pkg:smbclient"
    ["onesixtyone"]="scanning|onesixtyone|pkg:onesixtyone"
    ["zmap"]="scanning|zmap|pkg:zmap,github:zmap/zmap:zmap"

    # ═══════════════════ CREDENTIALS ═══════════════════
    ["hashcat"]="credentials|hashcat|pkg:hashcat,github:hashcat/hashcat:hashcat"
    ["john"]="credentials|john|pkg:john,pkg:john-the-ripper"
    ["hydra"]="credentials|hydra|pkg:hydra,pkg:thc-hydra"
    ["medusa"]="credentials|medusa|pkg:medusa"
    ["ncrack"]="credentials|ncrack|pkg:ncrack"
    ["cewl"]="credentials|cewl|pkg:cewl,gem:cewl"
    ["crunch"]="credentials|crunch|pkg:crunch"
    ["ophcrack"]="credentials|ophcrack|pkg:ophcrack"
    ["responder"]="credentials|responder|pkg:responder,pipx:Responder,pygithub:lgandx/Responder"
    ["secretsdump.py"]="credentials|secretsdump.py|pkg:impacket-scripts,pipx:impacket,pip:impacket"
    ["mimikatz"]="credentials|mimikatz|github:gentilkiwi/mimikatz:mimikatz.exe"
    ["hashid"]="credentials|hashid|pkg:hashid,pipx:hashid,pip:hashid"
    ["hash-identifier"]="credentials|hash-identifier|pkg:hash-identifier"

    # ═══════════════════ OSINT ═══════════════════
    ["theHarvester"]="osint|theHarvester|pkg:theharvester,pipx:theHarvester,pygithub:laramies/theHarvester"
    ["whois"]="osint|whois|pkg:whois"
    ["dnsrecon"]="osint|dnsrecon|pkg:dnsrecon,pipx:dnsrecon,pip:dnsrecon"
    ["dnsenum"]="osint|dnsenum|pkg:dnsenum"
    ["sublist3r"]="osint|sublist3r|pkg:sublist3r,pipx:sublist3r,pip:sublist3r"
    ["subfinder"]="osint|subfinder|pkg:subfinder,go:github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest,github:projectdiscovery/subfinder:subfinder"
    ["amass"]="osint|amass|pkg:amass,go:github.com/owasp-amass/amass/v4/...@master,snap:amass,github:owasp-amass/amass:amass"
    ["maltego"]="osint|maltego|pkg:maltego"
    ["spiderfoot"]="osint|spiderfoot|pkg:spiderfoot,pipx:spiderfoot,pip:spiderfoot"
    ["shodan"]="osint|shodan|pkg:shodan,pipx:shodan,pip:shodan"
    ["recon-ng"]="osint|recon-ng|pkg:recon-ng,pipx:recon-ng,pip:recon-ng"
    ["exiftool"]="osint|exiftool|pkg:libimage-exiftool-perl,pkg:perl-image-exiftool,pkg:exiftool"
    ["metagoofil"]="osint|metagoofil|pkg:metagoofil,pipx:metagoofil,pip:metagoofil"
    ["sherlock"]="osint|sherlock|pipx:sherlock-project,pip:sherlock-project,pygithub:sherlock-project/sherlock"
    ["holehe"]="osint|holehe|pipx:holehe,pip:holehe,pygithub:megadose/holehe"
    ["photon"]="osint|photon|pipx:photon,pip:photon,pygithub:s0md3v/Photon"
    ["phoneinfoga"]="osint|phoneinfoga|github:sundowndev/phoneinfoga:phoneinfoga,go:github.com/sundowndev/phoneinfoga/v2@latest"

    # ═══════════════════ RECON ═══════════════════
    ["nikto"]="recon|nikto|pkg:nikto"
    ["whatweb"]="recon|whatweb|pkg:whatweb"
    ["dirb"]="recon|dirb|pkg:dirb"
    ["gobuster"]="recon|gobuster|pkg:gobuster,go:github.com/OJ/gobuster/v3@latest,github:OJ/gobuster:gobuster"
    ["feroxbuster"]="recon|feroxbuster|pkg:feroxbuster,cargo:feroxbuster,github:epi052/feroxbuster:feroxbuster"
    ["ffuf"]="recon|ffuf|pkg:ffuf,go:github.com/ffuf/ffuf/v2@latest,github:ffuf/ffuf:ffuf"
    ["wfuzz"]="recon|wfuzz|pkg:wfuzz,pipx:wfuzz,pip:wfuzz"
    ["wpscan"]="recon|wpscan|pkg:wpscan,gem:wpscan,snap:wpscan"
    ["joomscan"]="recon|joomscan|pkg:joomscan"
    ["wafw00f"]="recon|wafw00f|pkg:wafw00f,pipx:wafw00f,pip:wafw00f"
    ["sslyze"]="recon|sslyze|pkg:sslyze,pipx:sslyze,pip:sslyze"
    ["sslscan"]="recon|sslscan|pkg:sslscan"
    ["testssl"]="recon|testssl.sh|pkg:testssl.sh,github:drwetter/testssl.sh:testssl.sh"
    ["nuclei"]="recon|nuclei|pkg:nuclei,go:github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest,github:projectdiscovery/nuclei:nuclei"
    ["httpx"]="recon|httpx|go:github.com/projectdiscovery/httpx/cmd/httpx@latest,github:projectdiscovery/httpx:httpx"
    ["katana"]="recon|katana|go:github.com/projectdiscovery/katana/cmd/katana@latest,github:projectdiscovery/katana:katana"
    ["arjun"]="recon|arjun|pipx:arjun,pip:arjun,pygithub:s0md3v/Arjun"

    # ═══════════════════ TRAFFIC ═══════════════════
    ["tcpdump"]="traffic|tcpdump|pkg:tcpdump"
    ["tshark"]="traffic|tshark|pkg:tshark,pkg:wireshark-cli"
    ["wireshark"]="traffic|wireshark|pkg:wireshark,pkg:wireshark-qt,flatpak:org.wireshark.Wireshark"
    ["ettercap"]="traffic|ettercap|pkg:ettercap-text-only,pkg:ettercap"
    ["bettercap"]="traffic|bettercap|pkg:bettercap,github:bettercap/bettercap:bettercap"
    ["arpspoof"]="traffic|arpspoof|pkg:dsniff"
    ["mitmproxy"]="traffic|mitmproxy|pkg:mitmproxy,pipx:mitmproxy,pip:mitmproxy"
    ["dnsspoof"]="traffic|dnsspoof|pkg:dsniff"
    ["sslstrip"]="traffic|sslstrip|pkg:sslstrip,pipx:sslstrip,pip:sslstrip"
    ["scapy"]="traffic|scapy|pkg:python3-scapy,pipx:scapy,pip:scapy"
    ["netcat"]="traffic|nc|pkg:netcat-openbsd,pkg:netcat-traditional,pkg:nmap-ncat,pkg:gnu-netcat"
    ["socat"]="traffic|socat|pkg:socat"
    ["ngrep"]="traffic|ngrep|pkg:ngrep"

    # ═══════════════════ EXPLOIT ═══════════════════
    ["msfconsole"]="exploit|msfconsole|pkg:metasploit-framework,snap:metasploit-framework"
    ["searchsploit"]="exploit|searchsploit|pkg:exploitdb"
    ["sqlmap"]="exploit|sqlmap|pkg:sqlmap,pipx:sqlmap,pip:sqlmap"
    ["commix"]="exploit|commix|pkg:commix,pipx:commix,pip:commix"
    ["beef-xss"]="exploit|beef-xss|pkg:beef-xss"
    ["evil-winrm"]="exploit|evil-winrm|pkg:evil-winrm,gem:evil-winrm"
    ["crackmapexec"]="exploit|crackmapexec|pkg:crackmapexec,pipx:crackmapexec,pip:crackmapexec"
    ["pwncat"]="exploit|pwncat|pipx:pwncat-cs,pip:pwncat-cs"
    ["chisel"]="exploit|chisel|github:jpillora/chisel:chisel,go:github.com/jpillora/chisel@latest"
    ["ligolo-ng"]="exploit|ligolo-agent|github:nicocha30/ligolo-ng:ligolo"

    # ═══════════════════ STRESS ═══════════════════
    ["hping3"]="stress|hping3|pkg:hping3"
    ["iperf3"]="stress|iperf3|pkg:iperf3"
    ["slowloris"]="stress|slowloris|pkg:slowloris,pipx:slowloris,pip:slowloris"
    ["siege"]="stress|siege|pkg:siege"
    ["ab"]="stress|ab|pkg:apache2-utils,pkg:httpd-tools"
    ["vegeta"]="stress|vegeta|github:tsenart/vegeta:vegeta,go:github.com/tsenart/vegeta@latest"

    # ═══════════════════ UTILITY ═══════════════════
    ["curl"]="utility|curl|pkg:curl"
    ["wget"]="utility|wget|pkg:wget"
    ["git"]="utility|git|pkg:git"
    ["python3"]="utility|python3|pkg:python3"
    ["pip3"]="utility|pip3|pkg:python3-pip"
    ["pipx"]="utility|pipx|pkg:pipx,pip:pipx"
    ["go"]="utility|go|pkg:golang,pkg:go,snap:go"
    ["cargo"]="utility|cargo|pkg:cargo,pkg:rust"
    ["proxychains"]="utility|proxychains|pkg:proxychains4,pkg:proxychains-ng"
    ["tor"]="utility|tor|pkg:tor"
    ["openvpn"]="utility|openvpn|pkg:openvpn"
    ["tmux"]="utility|tmux|pkg:tmux"
    ["screen"]="utility|screen|pkg:screen"
    ["jq"]="utility|jq|pkg:jq"
    ["yq"]="utility|yq|pkg:yq,go:github.com/mikefarah/yq/v4@latest,github:mikefarah/yq:yq"
    ["bat"]="utility|bat|pkg:bat,cargo:bat,github:sharkdp/bat:bat"
    ["ripgrep"]="utility|rg|pkg:ripgrep,cargo:ripgrep,github:BurntSushi/ripgrep:rg"
    ["fd"]="utility|fd|pkg:fd-find,pkg:fd,cargo:fd-find,github:sharkdp/fd:fd"
    ["fzf"]="utility|fzf|pkg:fzf,go:github.com/junegunn/fzf@latest,github:junegunn/fzf:fzf"
)

# Package name overrides per distro family
declare -A PKG_OVERRIDES=(
    # Debian-specific
    ["debian:wireshark-cli"]="tshark"
    ["debian:netcat"]="netcat-openbsd"
    ["debian:john-the-ripper"]="john"
    ["debian:exiftool"]="libimage-exiftool-perl"
    ["debian:fd"]="fd-find"
    ["debian:bat"]="bat"
    ["debian:ripgrep"]="ripgrep"
    ["debian:thc-hydra"]="hydra"

    # Arch-specific
    ["arch:netcat"]="gnu-netcat"
    ["arch:hping3"]="hping"
    ["arch:wireshark"]="wireshark-qt"
    ["arch:fd-find"]="fd"
    ["arch:python3-pip"]="python-pip"
    ["arch:python3"]="python"
    ["arch:golang"]="go"

    # RedHat/Fedora-specific
    ["redhat:netcat"]="nmap-ncat"
    ["redhat:wireshark-cli"]="wireshark-cli"
    ["redhat:apache2-utils"]="httpd-tools"
    ["fedora:netcat"]="nmap-ncat"
    ["fedora:wireshark-cli"]="wireshark-cli"
    ["fedora:apache2-utils"]="httpd-tools"

    # SUSE-specific
    ["suse:netcat"]="netcat-openbsd"
    ["suse:wireshark-cli"]="wireshark"

    # Alpine-specific
    ["alpine:python3-pip"]="py3-pip"
)

# ═══════════════════════════════════════════════════════════════════════════════
# INSTALLATION METHODS
# ═══════════════════════════════════════════════════════════════════════════════

# Get package name for current distro
get_pkg_name() {
    local pkg="$1"
    local key="${DISTRO_FAMILY}:${pkg}"

    # Check for distro-specific override
    if [[ -n "${PKG_OVERRIDES[$key]:-}" ]]; then
        echo "${PKG_OVERRIDES[$key]}"
    else
        echo "$pkg"
    fi
}

# Install via system package manager
install_pkg() {
    local pkg="$1"
    local actual_pkg
    actual_pkg=$(get_pkg_name "$pkg")

    substep "Trying package: $actual_pkg"

    case "$PKG_MANAGER" in
        apt)
            if [[ "${APT_UPDATED:-0}" == "0" ]]; then
                run_privileged apt-get update -qq 2>/dev/null
                APT_UPDATED=1
            fi
            DEBIAN_FRONTEND=noninteractive run_privileged apt-get install -y "$actual_pkg" 2>/dev/null
            ;;
        dnf)
            run_privileged dnf install -y "$actual_pkg" 2>/dev/null
            ;;
        yum)
            run_privileged yum install -y "$actual_pkg" 2>/dev/null
            ;;
        pacman)
            # Try regular repos first, then AUR via yay/paru
            if run_privileged pacman -S --noconfirm "$actual_pkg" 2>/dev/null; then
                return 0
            elif command -v yay &>/dev/null; then
                yay -S --noconfirm "$actual_pkg" 2>/dev/null
            elif command -v paru &>/dev/null; then
                paru -S --noconfirm "$actual_pkg" 2>/dev/null
            else
                return 1
            fi
            ;;
        zypper)
            run_privileged zypper install -y "$actual_pkg" 2>/dev/null
            ;;
        apk)
            run_privileged apk add "$actual_pkg" 2>/dev/null
            ;;
        xbps)
            run_privileged xbps-install -y "$actual_pkg" 2>/dev/null
            ;;
        emerge)
            run_privileged emerge "$actual_pkg" 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Install via pip
install_pip() {
    local pkg="$1"
    substep "Trying pip: $pkg"

    if [[ $HAS_PIP -eq 1 ]]; then
        pip3 install --user "$pkg" 2>/dev/null
    else
        return 1
    fi
}

# Install via pipx
install_pipx() {
    local pkg="$1"
    substep "Trying pipx: $pkg"

    if [[ $HAS_PIPX -eq 1 ]]; then
        pipx install "$pkg" 2>/dev/null
    elif [[ $HAS_PIP -eq 1 ]]; then
        # Fall back to pip if pipx not available
        pip3 install --user "$pkg" 2>/dev/null
    else
        return 1
    fi
}

# Install via go install
install_go() {
    local pkg="$1"
    substep "Trying go install: $pkg"

    if [[ $HAS_GO -eq 1 ]]; then
        GOBIN="${LOCAL_BIN}" go install "$pkg" 2>/dev/null
    else
        return 1
    fi
}

# Install via cargo
install_cargo() {
    local pkg="$1"
    substep "Trying cargo install: $pkg"

    if [[ $HAS_CARGO -eq 1 ]]; then
        cargo install "$pkg" 2>/dev/null
    else
        return 1
    fi
}

# Install via snap
install_snap() {
    local pkg="$1"
    substep "Trying snap: $pkg"

    if [[ $HAS_SNAP -eq 1 ]]; then
        run_privileged snap install "$pkg" 2>/dev/null || \
        run_privileged snap install "$pkg" --classic 2>/dev/null
    else
        return 1
    fi
}

# Install via flatpak
install_flatpak() {
    local pkg="$1"
    substep "Trying flatpak: $pkg"

    if [[ $HAS_FLATPAK -eq 1 ]]; then
        flatpak install -y flathub "$pkg" 2>/dev/null
    else
        return 1
    fi
}

# Install via gem (Ruby)
install_gem() {
    local pkg="$1"
    substep "Trying gem: $pkg"

    if command -v gem &>/dev/null; then
        gem install "$pkg" --user-install 2>/dev/null || \
        run_privileged gem install "$pkg" 2>/dev/null
    else
        return 1
    fi
}

# Install from GitHub releases
install_github() {
    local spec="$1"
    local binary_name="$2"

    # Parse repo:pattern
    local repo pattern
    repo=$(echo "$spec" | cut -d: -f1)
    pattern=$(echo "$spec" | cut -d: -f2)
    [[ -z "$pattern" ]] && pattern="$binary_name"

    substep "Trying GitHub release: $repo"

    ensure_dir "$TEMP_DIR"
    ensure_dir "$LOCAL_BIN"

    # Get latest release
    local version
    version=$(get_github_latest "$repo")
    if [[ -z "$version" ]]; then
        debug "Failed to get latest release for $repo"
        return 1
    fi

    # Try common download patterns
    local base_url="https://github.com/${repo}/releases/download/${version}"
    local os="linux"
    local downloaded=0

    # Try various naming conventions
    local -a patterns=(
        "${pattern}_${version#v}_${os}_${ARCH}.tar.gz"
        "${pattern}_${version}_${os}_${ARCH}.tar.gz"
        "${pattern}-${version#v}-${os}-${ARCH}.tar.gz"
        "${pattern}-${os}-${ARCH}.tar.gz"
        "${pattern}_${os}_${ARCH}.tar.gz"
        "${pattern}-${ARCH_ALT}-${os}.tar.gz"
        "${pattern}_${ARCH_ALT}_${os}.tar.gz"
        "${pattern}-linux-${ARCH_GO}.tar.gz"
        "${pattern}_linux_${ARCH_GO}.tar.gz"
        "${pattern}-${ARCH_GO}.tar.gz"
        "${pattern}_${ARCH_GO}.tar.gz"
        # Zip variants
        "${pattern}_${version#v}_${os}_${ARCH}.zip"
        "${pattern}-${os}-${ARCH}.zip"
        # Plain binaries
        "${pattern}-${os}-${ARCH}"
        "${pattern}_${os}_${ARCH}"
    )

    for p in "${patterns[@]}"; do
        local url="${base_url}/${p}"
        local dest="${TEMP_DIR}/${p}"

        debug "Trying: $url"
        if download "$url" "$dest" 2>/dev/null; then
            downloaded=1

            # Extract if archive
            if [[ "$dest" == *.tar.gz ]] || [[ "$dest" == *.tgz ]]; then
                tar -xzf "$dest" -C "$TEMP_DIR" 2>/dev/null
            elif [[ "$dest" == *.zip ]]; then
                unzip -q "$dest" -d "$TEMP_DIR" 2>/dev/null
            fi

            # Find and install binary
            local binary
            binary=$(find "$TEMP_DIR" -name "$pattern" -type f -executable 2>/dev/null | head -1)
            [[ -z "$binary" ]] && binary=$(find "$TEMP_DIR" -name "$binary_name" -type f -executable 2>/dev/null | head -1)
            [[ -z "$binary" ]] && binary="$dest"

            if [[ -f "$binary" ]]; then
                chmod +x "$binary"
                cp "$binary" "${LOCAL_BIN}/${binary_name}"
                return 0
            fi

            break
        fi
    done

    return 1
}

# Clone and build from git
install_git() {
    local spec="$1"
    local binary_name="$2"

    # Parse URL:build_cmd
    local url build_cmd
    url=$(echo "$spec" | cut -d: -f1-2)  # Preserve https://
    build_cmd=$(echo "$spec" | cut -d: -f3-)

    substep "Trying git clone: $url"

    if [[ $HAS_GIT -eq 0 ]]; then
        return 1
    fi

    ensure_dir "$TEMP_DIR"
    ensure_dir "$LOCAL_BIN"

    local clone_dir="${TEMP_DIR}/$(basename "$url" .git)"

    if git clone --depth 1 "$url" "$clone_dir" 2>/dev/null; then
        cd "$clone_dir" || return 1

        if [[ -n "$build_cmd" ]]; then
            eval "$build_cmd" 2>/dev/null || return 1
        fi

        # Try to find the built binary
        local binary
        binary=$(find . -name "$binary_name" -type f -executable 2>/dev/null | head -1)

        if [[ -n "$binary" ]] && [[ -f "$binary" ]]; then
            cp "$binary" "${LOCAL_BIN}/${binary_name}"
            cd - >/dev/null
            return 0
        fi

        cd - >/dev/null
    fi

    return 1
}

# Install Python tool from GitHub (creates virtualenv + wrapper script)
install_python_github() {
    local repo="$1"
    local binary_name="$2"

    substep "Trying Python GitHub install: $repo"

    if [[ $HAS_GIT -eq 0 ]]; then
        return 1
    fi

    # Ensure python3-venv is available
    if ! python3 -m venv --help &>/dev/null; then
        substep "Installing python3-venv..."
        case "$PKG_MANAGER" in
            apt) run_privileged apt-get install -y python3-venv 2>/dev/null ;;
            dnf|yum) run_privileged $PKG_MANAGER install -y python3-virtualenv 2>/dev/null ;;
            pacman) run_privileged pacman -S --noconfirm python-virtualenv 2>/dev/null ;;
            *) ;;
        esac
    fi

    ensure_dir "$LOCAL_OPT"
    ensure_dir "$LOCAL_BIN"

    local install_dir="${LOCAL_OPT}/${binary_name}"
    local venv_dir="${install_dir}/.venv"
    local clone_url="https://github.com/${repo}.git"

    # Remove existing installation
    [[ -d "$install_dir" ]] && rm -rf "$install_dir"

    if git clone --depth 1 "$clone_url" "$install_dir" 2>/dev/null; then
        # Create virtualenv for isolated dependencies
        substep "Creating virtualenv..."
        python3 -m venv "$venv_dir" 2>/dev/null || {
            warn "Failed to create virtualenv, falling back to system Python"
            venv_dir=""
        }

        # Install requirements if present
        if [[ -f "${install_dir}/requirements.txt" ]]; then
            substep "Installing Python dependencies..."
            if [[ -n "$venv_dir" ]] && [[ -d "$venv_dir" ]]; then
                # Use virtualenv pip
                "${venv_dir}/bin/pip" install -r "${install_dir}/requirements.txt" 2>/dev/null || {
                    warn "Some dependencies may have failed to install"
                }
            else
                # Try pip with --user (might fail on PEP 668 systems)
                pip3 install --user -r "${install_dir}/requirements.txt" 2>/dev/null || \
                pip3 install --break-system-packages -r "${install_dir}/requirements.txt" 2>/dev/null || true
            fi
        fi

        # Also install the package itself if setup.py or pyproject.toml exists
        if [[ -f "${install_dir}/setup.py" ]] || [[ -f "${install_dir}/pyproject.toml" ]]; then
            substep "Installing package..."
            if [[ -n "$venv_dir" ]] && [[ -d "$venv_dir" ]]; then
                "${venv_dir}/bin/pip" install -e "$install_dir" 2>/dev/null || true
            fi
        fi

        # Determine Python to use
        local python_bin="python3"
        [[ -n "$venv_dir" ]] && [[ -d "$venv_dir" ]] && python_bin="${venv_dir}/bin/python"

        # Find main script
        local main_script=""
        for script in "${binary_name}.py" "${binary_name}" "main.py" "__main__.py"; do
            if [[ -f "${install_dir}/${script}" ]]; then
                main_script="${install_dir}/${script}"
                break
            fi
        done

        # Check for package with __main__.py (run via python -m)
        if [[ -z "$main_script" ]] && [[ -d "${install_dir}/${binary_name}" ]]; then
            if [[ -f "${install_dir}/${binary_name}/__main__.py" ]]; then
                # Create wrapper that uses python -m
                cat > "${LOCAL_BIN}/${binary_name}" << WRAPPER
#!/usr/bin/env bash
cd "${install_dir}" && "${python_bin}" -m ${binary_name} "\$@"
WRAPPER
                chmod +x "${LOCAL_BIN}/${binary_name}"
                return 0
            fi
        fi

        if [[ -n "$main_script" ]]; then
            # Create wrapper script
            cat > "${LOCAL_BIN}/${binary_name}" << WRAPPER
#!/usr/bin/env bash
cd "${install_dir}" && "${python_bin}" "${main_script}" "\$@"
WRAPPER
            chmod +x "${LOCAL_BIN}/${binary_name}"
            return 0
        fi

        # If no main script found but package was installed, try entry point
        if [[ -n "$venv_dir" ]] && [[ -f "${venv_dir}/bin/${binary_name}" ]]; then
            # Link the entry point
            ln -sf "${venv_dir}/bin/${binary_name}" "${LOCAL_BIN}/${binary_name}"
            return 0
        fi
    fi

    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN INSTALLATION LOGIC
# ═══════════════════════════════════════════════════════════════════════════════

# Install a single tool with fallbacks
install_tool() {
    local tool_name="$1"
    local tool_def="${TOOLS[$tool_name]:-}"

    if [[ -z "$tool_def" ]]; then
        error "Unknown tool: $tool_name"
        return 1
    fi

    # Parse definition
    local category binary_name methods
    IFS='|' read -r category binary_name methods <<< "$tool_def"

    # Check if already installed
    if has_cmd "$binary_name"; then
        success "$tool_name already installed"
        return 0
    fi

    step "Installing $tool_name..."

    # Try each method in order
    IFS=',' read -ra method_list <<< "$methods"

    for method in "${method_list[@]}"; do
        local method_type method_arg
        method_type=$(echo "$method" | cut -d: -f1)
        method_arg=$(echo "$method" | cut -d: -f2-)

        case "$method_type" in
            pkg)
                if install_pkg "$method_arg"; then
                    if has_cmd "$binary_name"; then
                        success "$tool_name installed via package manager"
                        return 0
                    fi
                fi
                ;;
            pip)
                if install_pip "$method_arg"; then
                    if has_cmd "$binary_name"; then
                        success "$tool_name installed via pip"
                        return 0
                    fi
                fi
                ;;
            pipx)
                if install_pipx "$method_arg"; then
                    if has_cmd "$binary_name"; then
                        success "$tool_name installed via pipx"
                        return 0
                    fi
                fi
                ;;
            go)
                if install_go "$method_arg"; then
                    if has_cmd "$binary_name"; then
                        success "$tool_name installed via go"
                        return 0
                    fi
                fi
                ;;
            cargo)
                if install_cargo "$method_arg"; then
                    if has_cmd "$binary_name"; then
                        success "$tool_name installed via cargo"
                        return 0
                    fi
                fi
                ;;
            snap)
                if install_snap "$method_arg"; then
                    if has_cmd "$binary_name"; then
                        success "$tool_name installed via snap"
                        return 0
                    fi
                fi
                ;;
            flatpak)
                if install_flatpak "$method_arg"; then
                    success "$tool_name installed via flatpak"
                    return 0
                fi
                ;;
            gem)
                if install_gem "$method_arg"; then
                    if has_cmd "$binary_name"; then
                        success "$tool_name installed via gem"
                        return 0
                    fi
                fi
                ;;
            github)
                if install_github "$method_arg" "$binary_name"; then
                    ensure_path "$LOCAL_BIN"
                    if has_cmd "$binary_name"; then
                        success "$tool_name installed via GitHub release"
                        return 0
                    fi
                fi
                ;;
            git)
                if install_git "$method_arg" "$binary_name"; then
                    ensure_path "$LOCAL_BIN"
                    if has_cmd "$binary_name"; then
                        success "$tool_name installed via git"
                        return 0
                    fi
                fi
                ;;
            pygithub)
                if install_python_github "$method_arg" "$binary_name"; then
                    ensure_path "$LOCAL_BIN"
                    if has_cmd "$binary_name"; then
                        success "$tool_name installed via Python GitHub clone"
                        return 0
                    fi
                fi
                ;;
            appimage)
                substep "AppImage installation not yet implemented"
                ;;
        esac
    done

    warn "Failed to install $tool_name (tried all methods)"
    return 1
}

# Get all tools in a category
get_tools_by_category() {
    local category="$1"
    local -a result=()

    for tool in "${!TOOLS[@]}"; do
        local cat
        cat=$(echo "${TOOLS[$tool]}" | cut -d'|' -f1)
        if [[ "$cat" == "$category" ]]; then
            result+=("$tool")
        fi
    done

    # Sort and output
    printf '%s\n' "${result[@]}" | sort
}

# Get all categories
get_categories() {
    local -A categories
    for tool in "${!TOOLS[@]}"; do
        local cat
        cat=$(echo "${TOOLS[$tool]}" | cut -d'|' -f1)
        categories[$cat]=1
    done
    printf '%s\n' "${!categories[@]}" | sort
}

# Check tool status
check_tool() {
    local tool_name="$1"
    local tool_def="${TOOLS[$tool_name]:-}"

    if [[ -z "$tool_def" ]]; then
        return 2
    fi

    local binary_name
    binary_name=$(echo "$tool_def" | cut -d'|' -f2)

    has_cmd "$binary_name"
}

# List all tools with status
list_tools() {
    local filter="${1:-all}"

    header "VOIDWAVE Tool Status"

    echo -e "${BOLD}System:${RESET} $DISTRO_ID ($DISTRO_FAMILY) | ${BOLD}Package Manager:${RESET} $PKG_MANAGER"
    echo -e "${BOLD}Architecture:${RESET} $ARCH | ${BOLD}Go:${RESET} $([[ $HAS_GO -eq 1 ]] && echo "✓" || echo "✗") | ${BOLD}Cargo:${RESET} $([[ $HAS_CARGO -eq 1 ]] && echo "✓" || echo "✗") | ${BOLD}Pipx:${RESET} $([[ $HAS_PIPX -eq 1 ]] && echo "✓" || echo "✗")"
    echo ""

    local total=0 installed=0 missing=0
    local current_category=""

    # Sort tools by category
    while IFS= read -r tool; do
        local tool_def="${TOOLS[$tool]}"
        local category binary_name
        IFS='|' read -r category binary_name _ <<< "$tool_def"

        if [[ "$current_category" != "$category" ]]; then
            echo ""
            echo -e "${BOLD}${CYAN}═══ ${category^^} ═══${RESET}"
            current_category="$category"
        fi

        ((total++))

        if has_cmd "$binary_name"; then
            ((installed++))
            if [[ "$filter" != "missing" ]]; then
                local path version
                path=$(command -v "$binary_name")
                version=$("$binary_name" --version 2>/dev/null | head -1 | cut -c1-40 || echo "")
                echo -e "  ${GREEN}✓${RESET} ${tool} ${DIM}($path)${RESET}"
                [[ -n "$version" ]] && echo -e "    ${DIM}${version}${RESET}"
            fi
        else
            ((missing++))
            if [[ "$filter" != "installed" ]]; then
                echo -e "  ${RED}✗${RESET} ${tool}"
            fi
        fi
    done < <(for t in "${!TOOLS[@]}"; do echo "$t"; done | sort)

    echo ""
    echo -e "${BOLD}Summary:${RESET} $installed/$total installed ($missing missing)"
}

# Install missing tools
install_missing() {
    local category="${1:-}"
    local installed=0 failed=0 skipped=0

    header "Installing Missing Tools"

    local -a tools_to_install

    if [[ -n "$category" ]]; then
        while IFS= read -r tool; do
            tools_to_install+=("$tool")
        done < <(get_tools_by_category "$category")
    else
        for tool in "${!TOOLS[@]}"; do
            tools_to_install+=("$tool")
        done
    fi

    for tool in "${tools_to_install[@]}"; do
        local tool_def="${TOOLS[$tool]}"
        local binary_name
        binary_name=$(echo "$tool_def" | cut -d'|' -f2)

        if has_cmd "$binary_name"; then
            ((skipped++))
            continue
        fi

        if install_tool "$tool"; then
            ((installed++))
        else
            ((failed++))
        fi
    done

    echo ""
    echo -e "${BOLD}Results:${RESET}"
    echo -e "  ${GREEN}Installed:${RESET} $installed"
    echo -e "  ${YELLOW}Skipped:${RESET}   $skipped (already installed)"
    echo -e "  ${RED}Failed:${RESET}    $failed"
}

# Interactive category selection
select_category() {
    header "Select Category"

    local -a categories
    while IFS= read -r cat; do
        categories+=("$cat")
    done < <(get_categories)

    local i=1
    for cat in "${categories[@]}"; do
        local count
        count=$(get_tools_by_category "$cat" | wc -l)
        echo "  [$i] ${cat^} ($count tools)"
        ((i++))
    done
    echo "  [0] All categories"
    echo ""

    local choice
    if [[ $AUTO_YES -eq 1 ]]; then
        log "Auto-selecting all categories (-y flag)"
        choice="0"
    else
        read -rp "Select category [0-$((i-1))]: " choice
    fi

    if [[ "$choice" == "0" ]] || [[ -z "$choice" ]]; then
        install_missing
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -le "${#categories[@]}" ]]; then
        local selected="${categories[$((choice-1))]}"
        install_missing "$selected"
    else
        error "Invalid selection"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# PREREQUISITE INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════════

install_prerequisites() {
    header "Installing Prerequisites"

    local prereqs=(curl wget git)

    for prereq in "${prereqs[@]}"; do
        if ! has_cmd "$prereq"; then
            step "Installing $prereq..."
            install_pkg "$prereq" || warn "Failed to install $prereq"
        fi
    done

    # Install pipx if not present
    if ! has_cmd pipx; then
        step "Installing pipx..."
        if [[ "$PKG_MANAGER" == "apt" ]]; then
            run_privileged apt-get install -y pipx 2>/dev/null || pip3 install --user pipx 2>/dev/null
        elif [[ "$PKG_MANAGER" == "pacman" ]]; then
            run_privileged pacman -S --noconfirm python-pipx 2>/dev/null || pip3 install --user pipx 2>/dev/null
        else
            pip3 install --user pipx 2>/dev/null
        fi

        # Ensure pipx path
        pipx ensurepath 2>/dev/null || true
    fi

    # Install Go if not present (needed for many tools)
    if ! has_cmd go; then
        step "Installing Go..."
        if ! install_pkg "golang" && ! install_pkg "go"; then
            if [[ $HAS_SNAP -eq 1 ]]; then
                run_privileged snap install go --classic 2>/dev/null
            fi
        fi
    fi

    # Re-detect available methods
    detect_system

    success "Prerequisites installed"
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════════════════════

show_help() {
    cat << EOF
${BOLD}VOIDWAVE Universal Tool Installer v${INSTALLER_VERSION}${RESET}

${BOLD}USAGE:${RESET}
    ./install-tools.sh [OPTIONS] [COMMAND]

${BOLD}COMMANDS:${RESET}
    list                    List all tools and their status
    list --installed        List only installed tools
    list --missing          List only missing tools
    install <tool>          Install a specific tool
    install-all             Install all missing tools
    install-category        Interactive category selection
    category <name>         Install all tools in category
    prerequisites           Install prerequisites (curl, wget, git, pipx, go)
    search <query>          Search for tools by name

${BOLD}OPTIONS:${RESET}
    -h, --help              Show this help message
    -v, --version           Show version
    -d, --debug             Enable debug output
    -y, --yes               Auto-confirm all prompts

${BOLD}CATEGORIES:${RESET}
    wireless, scanning, credentials, osint, recon, traffic, exploit, stress, utility

${BOLD}EXAMPLES:${RESET}
    ./install-tools.sh list
    ./install-tools.sh install nmap
    ./install-tools.sh category wireless
    ./install-tools.sh install-all
    sudo ./install-tools.sh prerequisites

EOF
}

main() {
    # Parse global options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "VOIDWAVE Tool Installer v${INSTALLER_VERSION}"
                exit 0
                ;;
            -d|--debug)
                DEBUG=1
                shift
                ;;
            -y|--yes)
                AUTO_YES=1
                shift
                ;;
            -*)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done

    # Ensure local bin in PATH
    ensure_dir "$LOCAL_BIN"
    ensure_path "$LOCAL_BIN"

    # Detect system
    detect_system

    # Handle commands
    local cmd="${1:-}"
    shift 2>/dev/null || true

    case "$cmd" in
        ""|list)
            local filter="${1:-all}"
            [[ "$filter" == "--installed" ]] && filter="installed"
            [[ "$filter" == "--missing" ]] && filter="missing"
            list_tools "$filter"
            ;;
        install)
            if [[ -z "${1:-}" ]]; then
                error "Please specify a tool to install"
                exit 1
            fi
            install_tool "$1"
            ;;
        install-all|all)
            install_missing
            ;;
        install-category|interactive)
            select_category
            ;;
        category|cat)
            if [[ -z "${1:-}" ]]; then
                error "Please specify a category"
                echo "Available: $(get_categories | tr '\n' ' ')"
                exit 1
            fi
            install_missing "$1"
            ;;
        prerequisites|prereqs)
            install_prerequisites
            ;;
        search)
            if [[ -z "${1:-}" ]]; then
                error "Please specify a search query"
                exit 1
            fi
            local query="${1,,}"  # lowercase
            echo "Tools matching '$1':"
            local found=0
            for tool in "${!TOOLS[@]}"; do
                local tool_lower="${tool,,}"
                if [[ "$tool_lower" == *"$query"* ]]; then
                    local tool_def="${TOOLS[$tool]}"
                    local category binary_name
                    IFS='|' read -r category binary_name _ <<< "$tool_def"
                    local status
                    if has_cmd "$binary_name"; then
                        status="${GREEN}✓${RESET}"
                    else
                        status="${RED}✗${RESET}"
                    fi
                    echo "  $status $tool ($category)"
                    ((found++))
                fi
            done
            if [[ $found -eq 0 ]]; then
                echo "  No tools found"
                exit 1
            fi
            ;;
        *)
            error "Unknown command: $cmd"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
