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
[![Platform](https://img.shields.io/badge/platform-Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://kernel.org)

**Offensive Security Framework** | **100+ Tools** | **Modern TUI** | **Multi-Distro Support**

[Installation](#installation) • [Features](#features) • [Usage](#usage) • [Tool Installer](#universal-tool-installer) • [Documentation](#documentation)

</div>

---

## What is VOIDWAVE?

**VOIDWAVE** is a comprehensive offensive security framework that unifies 100+ security tools under a modern Python-based terminal interface. Built for penetration testers, red teamers, and security researchers.

```
┌─────────────────────────────────────────────────────────────────────┐
│  WIRELESS    │  WiFi attacks, WPA/WPA2/WPS cracking, Evil Twin     │
│  SCANNING    │  Port scanning, service enumeration, host discovery │
│  CREDENTIALS │  Password cracking, brute force, hash attacks       │
│  OSINT       │  Email harvesting, subdomain enum, social recon     │
│  RECON       │  Web fuzzing, directory brute force, CMS scanning   │
│  TRAFFIC     │  Packet capture, MITM attacks, protocol analysis    │
│  EXPLOIT     │  Vulnerability exploitation, payload delivery       │
│  STRESS      │  Load testing, availability testing                 │
└─────────────────────────────────────────────────────────────────────┘
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

# Install security tools (comprehensive multi-method installer)
./install-tools.sh install-all
```

### Launch VOIDWAVE

```bash
# Run the TUI (requires sudo for most operations)
sudo $(which voidwave)

# Or from anywhere except the VOIDWAVE directory
sudo voidwave
```

> **Note:** Running `sudo voidwave` from within the VOIDWAVE directory launches the legacy bash version. Use `sudo $(which voidwave)` to ensure the Python TUI runs.

---

## Features

### Modern Terminal UI
- **10 Functional Screens** — Wireless, Scanning, Credentials, OSINT, Recon, Traffic, Exploit, Stress, Status, Settings
- **Real-time Updates** — Async event-driven architecture
- **Rich Interface** — Built with Textual for a modern terminal experience

### Tool Management
- **100+ Integrated Tools** — Unified interface for all major security tools
- **Smart Detection** — Auto-detects installed tools and their versions
- **Multi-Method Installation** — Package managers, pip, GitHub, cargo, go, and more

### Automation
- **13 AUTO-* Handlers** — Automated tool setup and configuration
- **First-Run Wizard** — 9-step bootstrap for new installations
- **Session Memory** — Remembers targets, interfaces, and networks across sessions

### Export & Reporting
- **Multiple Formats** — JSON, CSV, HTML, PDF, Markdown
- **Secure Storage** — Encrypted loot storage for captured credentials
- **API Key Management** — System keyring integration for secure key storage

---

## Universal Tool Installer

VOIDWAVE includes a powerful standalone tool installer with multi-method fallback support.

### Installation Methods

| Method | Description |
|:-------|:------------|
| `pkg:` | System packages (apt, dnf, pacman, zypper, apk) |
| `pipx:` / `pip:` | Python packages with isolated environments |
| `pygithub:` | Python tools from GitHub (clone + virtualenv + wrapper) |
| `github:` | Binary releases from GitHub |
| `go:` | Go install for Go-based tools |
| `cargo:` | Rust cargo install |
| `snap:` / `flatpak:` | Universal Linux packages |
| `gem:` | Ruby gems |
| `git:` | Clone and build from source |

### Usage

```bash
# List all tools and their status
./install-tools.sh list

# Install a specific tool
./install-tools.sh install nmap

# Install all missing tools
./install-tools.sh install-all

# Install tools by category
./install-tools.sh category wireless
./install-tools.sh category osint

# Search for tools
./install-tools.sh search harvest

# Interactive category selection
./install-tools.sh install-category

# Install prerequisites (curl, wget, git, pipx, go)
sudo ./install-tools.sh prerequisites
```

### Supported Categories

| Category | Tools |
|:---------|:------|
| **wireless** | aircrack-ng, reaver, bully, wifite, hcxtools, mdk4, kismet |
| **scanning** | nmap, masscan, rustscan, netdiscover, arp-scan, zmap |
| **credentials** | hashcat, john, hydra, medusa, responder, mimikatz |
| **osint** | theHarvester, subfinder, amass, shodan, sherlock, holehe |
| **recon** | gobuster, ffuf, feroxbuster, nikto, nuclei, wpscan |
| **traffic** | tcpdump, wireshark, ettercap, bettercap, mitmproxy |
| **exploit** | metasploit, sqlmap, searchsploit, evil-winrm, chisel |
| **stress** | hping3, iperf3, slowloris, siege |
| **utility** | curl, wget, git, proxychains, tor, tmux, jq |

---

## Wireless Capabilities

| Attack Type | Methods |
|:------------|:--------|
| **WPS** | Pixie-Dust, PIN brute force, null PIN, known PINs database |
| **WPA/WPA2** | Handshake capture, PMKID capture, dictionary attack |
| **WPA3** | Transition mode downgrade attacks |
| **Evil Twin** | Captive portal, WPA honeypot, credential harvesting |
| **DoS** | Deauthentication, beacon flood, authentication flood |
| **WEP** | ARP replay, ChopChop, fragmentation |

### Recommended Wireless Adapters

| Chipset | Monitor | Injection | Band |
|:--------|:-------:|:---------:|:----:|
| Atheros AR9271 | ✓ | ✓ | 2.4 GHz |
| MediaTek MT7612U | ✓ | ✓ | Dual-band |
| Ralink RT3070 | ✓ | ✓ | 2.4 GHz |
| Realtek RTL8812AU | ✓ | ✓ | Dual-band |

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

The tool installer automatically detects your distribution and handles package name differences.

---

## Requirements

| Requirement | Details |
|:------------|:--------|
| **OS** | Linux (kernel 4.x+) |
| **Python** | 3.11+ |
| **Privileges** | Root for wireless/packet capture operations |
| **WiFi Adapter** | Monitor mode + packet injection (for wireless attacks) |

---

## API Keys (Optional)

For enhanced OSINT functionality, configure API keys in Settings:

| Service | Purpose |
|:--------|:--------|
| **Shodan** | Internet device search |
| **Censys** | Attack surface monitoring |
| **VirusTotal** | Malware/URL scanning |
| **WPScan** | WordPress vulnerability database |
| **Hunter.io** | Email discovery |
| **SecurityTrails** | DNS intelligence |

Keys are stored securely in your system keyring.

---

## Project Structure

```
VOIDWAVE/
├── src/voidwave/           # Python TUI application
│   ├── tui/                # Textual TUI screens and widgets
│   ├── automation/         # AUTO-* handlers & preflight
│   ├── orchestration/      # Event bus & workflow control
│   ├── detection/          # Tool detection & installation
│   ├── tools/              # Tool wrappers with output parsing
│   ├── export/             # Multi-format report generation
│   ├── db/                 # SQLite persistence
│   ├── loot/               # Encrypted credential storage
│   └── config/             # Settings & API key management
├── lib/                    # Legacy bash modules
├── install.sh              # VOIDWAVE installer (pipx-based)
├── install-tools.sh        # Universal tool installer
└── tests/                  # Test suite
```

---

## Documentation

| Document | Description |
|:---------|:------------|
| [CHANGELOG.md](CHANGELOG.md) | Version history and release notes |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guidelines |
| [SECURITY.md](SECURITY.md) | Security policy and reporting |
| [TUI_QUICK_REFERENCE.md](TUI_QUICK_REFERENCE.md) | TUI keyboard shortcuts and navigation |
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

---

## Credits

VOIDWAVE evolved from NETREAPER, representing a complete architectural rewrite from bash scripts to a modern Python TUI framework. Thanks to the security community and the developers behind aircrack-ng, hashcat, nmap, metasploit, and the dozens of other tools integrated into this framework.

---

<div align="center">

**VOIDWAVE** v10.1.0 • Apache-2.0 License

*For those who operate in the void*

[![GitHub Stars](https://img.shields.io/github/stars/Nerds489/VOIDWAVE?style=social)](https://github.com/Nerds489/VOIDWAVE)

</div>
