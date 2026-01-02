<div align="center">

```
 ▄█    █▄   ▄██████▄   ▄█  ████████▄   ▄█     █▄     ▄████████  ▄█    █▄     ▄████████
███    ███ ███    ███ ███  ███   ▀███ ███     ███   ███    ███ ███    ███   ███    ███
███    ███ ███    ███ ███▌ ███    ███ ███     ███   ███    ███ ███    ███   ███    █▀
███    ███ ███    ███ ███▌ ███    ███ ███     ███   ███    ███ ███    ███  ▄███▄▄▄
███    ███ ███    ███ ███▌ ███    ███ ███     ███ ▀███████████ ███    ███ ▀▀███▀▀▀
███    ███ ███    ███ ███  ███    ███ ███     ███   ███    ███ ███    ███   ███    █▄
███    ███ ███    ███ ███  ███   ▄███ ███ ▄█▄ ███   ███    ███ ███    ███   ███    ███
 ▀██████▀   ▀██████▀  █▀   ████████▀   ▀███▀███▀    ███    █▀   ▀██████▀    ██████████

                    ░▒▓█ THE AIRWAVES BELONG TO THOSE WHO LISTEN █▓▒░
```

[![Version](https://img.shields.io/badge/version-10.1.0-ff0040?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Nerds489/VOIDWAVE/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue?style=for-the-badge)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![Bash](https://img.shields.io/badge/bash-5.0+-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://kernel.org)

**Offensive Security Framework** | **124 Integrated Tools** | **Intelligent Auto-Detection** | **Multi-Distro Support**

[Installation](#-installation) • [Quick Start](#-quick-start) • [Features](#-features) • [Tools](#-tool-arsenal) • [Documentation](#-documentation)

</div>

---

## What is VOIDWAVE?

**VOIDWAVE** is an offensive security framework that unifies 124 security tools under an intelligent interface with automatic detection of interfaces, targets, and attack requirements. Built for penetration testers, red teamers, and security researchers who need tools that **just work**.

### Two Interfaces, One Framework

| Interface | Description | Best For |
|:----------|:------------|:---------|
| **Python TUI** | Modern terminal UI built with Textual | Visual operation, status monitoring |
| **Bash CLI** | Full-featured command-line with interactive menus | Scripting, automation, quick attacks |

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  WIRELESS     │  WPA/WPA2/WPA3, WPS attacks, Evil Twin, deauth, PMKID      │
│  SCANNING     │  Port scanning, service enumeration, host discovery        │
│  CREDENTIALS  │  Password cracking, brute force, hash attacks, responder   │
│  OSINT        │  Email harvesting, subdomain enum, social reconnaissance   │
│  RECON        │  Web fuzzing, directory brute force, CMS scanning          │
│  TRAFFIC      │  Packet capture, MITM attacks, ARP spoofing, sniffing      │
│  EXPLOIT      │  Metasploit, SQLMap, searchsploit, payload generation      │
│  STRESS       │  Load testing, SYN floods, network impairment              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Intelligent Auto-Detection

VOIDWAVE's intelligence system eliminates manual configuration. The framework automatically:

| Feature | What It Does |
|:--------|:-------------|
| **Interface Detection** | Finds wireless adapters, scores by driver capability (ath9k_htc, rtl8187 ranked highest) |
| **Monitor Mode** | Auto-enables monitor mode when attacks require it |
| **Target Selection** | Scans networks, scores by signal strength, encryption, and client count |
| **Client Detection** | Discovers connected clients for targeted deauth attacks |
| **Network Discovery** | Detects local IP, gateway, and subnet for non-wireless operations |
| **Preflight Checks** | Validates all requirements before attacks, offers auto-fix for missing components |

```bash
# Old way: Manual everything
airmon-ng start wlan0
airodump-ng wlan0mon
# Copy BSSID, channel, select target manually...

# VOIDWAVE way: Just run the attack
voidwave   # Select WPS Pixie → Auto-detects interface → Auto-scans → Auto-selects best target → Attack
```

---

## Installation

### Quick Install

```bash
# Clone the repository
git clone https://github.com/Nerds489/VOIDWAVE.git
cd VOIDWAVE

# Install VOIDWAVE (uses pipx for isolation)
./install.sh

# Install all security tools (124 tools with multi-method fallback)
./install-tools.sh install-all
```

### Launch VOIDWAVE

```bash
# Interactive bash menu (recommended for attacks)
sudo ./bin/voidwave

# Or from system path after install
sudo voidwave

# Python TUI (modern visual interface)
sudo $(which voidwave) tui
```

### Prerequisites

The installer handles prerequisites automatically, but you can install them manually:

```bash
sudo ./install-tools.sh prerequisites
```

This installs: `curl`, `wget`, `git`, `python3-pip`, `pipx`, `golang-go`, `cargo`

---

## Quick Start

### Interactive Mode (Recommended)

```bash
sudo voidwave
```

Navigate with arrow keys, select attacks, and let the intelligence system handle the rest.

### CLI Mode

```bash
# Quick network scan
voidwave scan -t 192.168.1.0/24

# Enable monitor mode
voidwave wifi monitor on wlan0

# Show system status
voidwave status

# Configuration
voidwave config show
voidwave config set log_level DEBUG
```

### Common Workflows

```bash
# WiFi assessment
sudo voidwave           # Interactive menu → Wireless → Select attack type

# Network reconnaissance
voidwave scan -t 10.0.0.1
voidwave --json scan -t 192.168.1.0/24 > results.json

# First-time setup wizard
voidwave wizard first
```

---

## Features

### Intelligence System

- **Auto-Interface** — Ranks adapters by chipset/driver for attack suitability
- **Auto-Monitor** — Enables monitor mode transparently when needed
- **Auto-Target** — Scans and selects optimal targets based on signal/encryption/clients
- **Auto-Client** — Detects clients for targeted attacks
- **Auto-Network** — Discovers network topology for non-wireless operations
- **Preflight Validation** — Checks all requirements before attacks with auto-fix capability

### Modern Architecture

- **Dual Interface** — Python TUI (Textual) + Bash CLI with shared libraries
- **Event-Driven** — Async architecture for real-time updates
- **Plugin System** — Extensible tool and attack registration
- **Session Memory** — Remembers targets, interfaces, and networks across sessions

### Export & Reporting

- **Multiple Formats** — JSON, CSV, HTML, PDF, Markdown
- **Secure Storage** — Encrypted loot storage for captured credentials
- **API Key Management** — System keyring integration for secure key storage

---

## Tool Arsenal

VOIDWAVE integrates **124 security tools** across 9 categories:

### Wireless (18 tools)
| Tool | Purpose |
|:-----|:--------|
| aircrack-ng suite | WPA/WPA2/WEP cracking, packet capture, injection |
| reaver / bully | WPS PIN attacks, Pixie-Dust |
| wifite | Automated wireless auditing |
| hcxdumptool / hcxtools | PMKID capture and conversion |
| mdk4 | Deauth, beacon flood, authentication attacks |
| hostapd / dnsmasq | Evil Twin, rogue AP attacks |
| kismet | Wireless network detection |

### Scanning (12 tools)
| Tool | Purpose |
|:-----|:--------|
| nmap | Port scanning, service/OS detection |
| masscan | High-speed port scanning |
| rustscan | Fast port discovery with nmap integration |
| zmap | Internet-scale scanning |
| enum4linux | SMB/NetBIOS enumeration |

### Credentials (13 tools)
| Tool | Purpose |
|:-----|:--------|
| hashcat | GPU-accelerated password cracking |
| john | CPU password cracking |
| hydra / medusa | Network service brute forcing |
| responder | LLMNR/NBT-NS/MDNS poisoning |
| impacket | Windows credential extraction |

### OSINT (15 tools)
| Tool | Purpose |
|:-----|:--------|
| theHarvester | Email, subdomain, host discovery |
| subfinder / amass | Subdomain enumeration |
| recon-ng | OSINT framework |
| sherlock / holehe | Username/email reconnaissance |
| shodan | Internet device search |

### Recon (16 tools)
| Tool | Purpose |
|:-----|:--------|
| gobuster / ffuf / feroxbuster | Directory/file brute forcing |
| nikto | Web server scanning |
| nuclei | Vulnerability scanning |
| wpscan | WordPress vulnerability scanning |
| whatweb | Web technology identification |

### Traffic (10 tools)
| Tool | Purpose |
|:-----|:--------|
| tcpdump / wireshark | Packet capture and analysis |
| ettercap / bettercap | MITM attacks |
| mitmproxy | HTTP/HTTPS interception |
| arpspoof / dnsspoof | Traffic redirection |

### Exploit (12 tools)
| Tool | Purpose |
|:-----|:--------|
| metasploit | Exploitation framework |
| sqlmap | SQL injection |
| searchsploit | Exploit database search |
| evil-winrm | Windows remote management |
| chisel | TCP/UDP tunneling |

### Stress (8 tools)
| Tool | Purpose |
|:-----|:--------|
| hping3 | Packet crafting, SYN floods |
| slowloris | HTTP DoS |
| siege | HTTP load testing |
| iperf3 | Bandwidth testing |

### Utility (20 tools)
Core utilities: `curl`, `wget`, `git`, `proxychains`, `tor`, `tmux`, `jq`, `netcat`, and more.

---

## Tool Installer

The universal tool installer supports 9 installation methods with automatic fallback:

```bash
# List all tools and their installation status
./install-tools.sh list

# Install everything
./install-tools.sh install-all

# Install by category
./install-tools.sh category wireless
./install-tools.sh category osint

# Install specific tool
./install-tools.sh install nmap

# Search tools
./install-tools.sh search harvest

# Interactive category selection
./install-tools.sh install-category
```

### Installation Methods

| Method | Description |
|:-------|:------------|
| `pkg:` | System packages (apt, dnf, pacman, zypper, apk) |
| `pipx:` / `pip:` | Python packages with isolated environments |
| `pygithub:` | Python tools from GitHub (clone + venv + wrapper) |
| `github:` | Binary releases from GitHub |
| `go:` | Go install |
| `cargo:` | Rust cargo install |
| `snap:` / `flatpak:` | Universal Linux packages |
| `gem:` | Ruby gems |
| `git:` | Clone and build from source |

---

## Wireless Capabilities

### Attack Types

| Attack | Methods |
|:-------|:--------|
| **WPS** | Pixie-Dust, PIN brute force, null PIN, known PINs database |
| **WPA/WPA2** | Handshake capture, PMKID capture, dictionary attack |
| **WPA3** | Transition mode downgrade attacks |
| **Evil Twin** | Captive portal, WPA honeypot, credential harvesting |
| **DoS** | Deauthentication, beacon flood, authentication flood |
| **WEP** | ARP replay, ChopChop, fragmentation |

### Recommended Adapters

| Chipset | Driver | Monitor | Injection | Band |
|:--------|:-------|:-------:|:---------:|:----:|
| Atheros AR9271 | ath9k_htc | ✓ | ✓ | 2.4 GHz |
| Ralink RT3070 | rt2800usb | ✓ | ✓ | 2.4 GHz |
| Realtek RTL8812AU | rtl8812au | ✓ | ✓ | Dual-band |
| MediaTek MT7612U | mt76x2u | ✓ | ✓ | Dual-band |

---

## Supported Distributions

| Family | Distributions | Package Manager |
|:-------|:--------------|:----------------|
| **Debian** | Debian, Ubuntu, Kali, Parrot, Linux Mint | apt |
| **Red Hat** | Fedora, RHEL, Rocky, AlmaLinux, CentOS | dnf/yum |
| **Arch** | Arch, Manjaro, BlackArch, EndeavourOS | pacman |
| **SUSE** | openSUSE Leap, Tumbleweed | zypper |
| **Alpine** | Alpine Linux | apk |
| **Void** | Void Linux | xbps |

The installer automatically detects your distribution and maps package names accordingly.

---

## Requirements

| Requirement | Details |
|:------------|:--------|
| **OS** | Linux (kernel 4.x+) |
| **Python** | 3.11+ (for TUI) |
| **Bash** | 5.0+ (for CLI) |
| **Privileges** | Root for wireless/packet capture operations |
| **WiFi Adapter** | Monitor mode + packet injection support (for wireless attacks) |

---

## Configuration

### CLI Configuration

```bash
voidwave config show                    # Show all settings
voidwave config get log_level           # Get specific value
voidwave config set log_level DEBUG     # Set value
voidwave config edit                    # Open in editor
voidwave config reset                   # Reset to defaults
```

### Key Settings

| Setting | Description | Default |
|:--------|:------------|:--------|
| `log_level` | DEBUG, INFO, WARNING, ERROR | INFO |
| `file_logging` | Write logs to file | true |
| `confirm_dangerous` | Prompt before dangerous ops | true |
| `warn_public_ip` | Warn if targeting public IPs | true |

### API Keys (Optional)

For enhanced OSINT functionality:

| Service | Purpose |
|:--------|:--------|
| Shodan | Internet device search |
| Censys | Attack surface monitoring |
| VirusTotal | Malware/URL scanning |
| WPScan | WordPress vulnerability database |
| Hunter.io | Email discovery |
| SecurityTrails | DNS intelligence |

---

## Project Structure

```
VOIDWAVE/
├── src/voidwave/           # Python TUI application
│   ├── tui/                # Textual screens (wireless, scan, osint, etc.)
│   ├── automation/         # AUTO-* handlers
│   ├── orchestration/      # Event bus & workflow control
│   ├── detection/          # Tool detection
│   ├── tools/              # Tool wrappers with output parsing
│   ├── export/             # Multi-format report generation
│   ├── db/                 # SQLite persistence
│   ├── loot/               # Encrypted credential storage
│   └── config/             # Settings & API key management
├── lib/                    # Bash CLI libraries
│   ├── intelligence/       # Auto-detection system
│   │   ├── auto.sh         # Interface/target/client auto-detection
│   │   ├── preflight.sh    # Requirement validation
│   │   └── targeting.sh    # Network scanning & selection
│   ├── core.sh             # Core functions
│   ├── ui.sh               # Terminal UI helpers
│   ├── config.sh           # Configuration management
│   ├── detection.sh        # System/tool detection
│   ├── wireless/           # Wireless attack modules
│   ├── attacks/            # Attack implementations
│   └── menus/              # Interactive menus
├── bin/voidwave            # Main CLI entry point
├── install.sh              # VOIDWAVE installer
├── install-tools.sh        # Universal tool installer (124 tools)
└── tests/                  # Test suite
```

---

## Documentation

| Document | Description |
|:---------|:------------|
| [CHANGELOG.md](CHANGELOG.md) | Version history and release notes |
| [TUI_QUICK_REFERENCE.md](TUI_QUICK_REFERENCE.md) | TUI keyboard shortcuts |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guidelines |
| [SECURITY.md](SECURITY.md) | Security policy and reporting |
| [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) | Community guidelines |

---

## Legal Disclaimer

> **For authorized security testing only.**
>
> Unauthorized access to computer systems is illegal. Users are solely responsible for ensuring they have proper authorization before using this tool. The authors assume no liability for misuse or damage caused by this software.
>
> By using VOIDWAVE, you agree to use it only for:
> - Authorized penetration testing engagements
> - Security research on systems you own or have permission to test
> - Educational purposes in controlled environments
> - Capture The Flag (CTF) competitions

---

## Credits

VOIDWAVE evolved from NETREAPER, representing a complete architectural rewrite combining a modern Python TUI with a battle-tested Bash CLI. Thanks to the security community and the developers behind aircrack-ng, hashcat, nmap, metasploit, and the 120+ other tools integrated into this framework.

---

<div align="center">

**VOIDWAVE** v10.1.0 • Apache-2.0 License

*The airwaves belong to those who listen*

[![GitHub Stars](https://img.shields.io/github/stars/Nerds489/VOIDWAVE?style=social)](https://github.com/Nerds489/VOIDWAVE)

</div>
