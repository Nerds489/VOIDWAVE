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

[![Version](https://img.shields.io/badge/version-2.0.0-ff0040?style=flat-square&logo=python&logoColor=white)](https://github.com/Nerds489/VOIDWAVE/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue?style=flat-square)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.11+-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![Platform](https://img.shields.io/badge/linux-kernel%204.x+-FCC624?style=flat-square&logo=linux&logoColor=black)](https://kernel.org)

<sub>v2.0.0 — Complete TUI rewrite with Python/Textual, automation framework, 100+ tool integrations</sub>

</div>

---

**VOIDWAVE** is an offensive security framework with a modern terminal UI (TUI). 100+ integrated tools across network recon, wireless attacks, credential cracking, OSINT, and exploitation — unified under a powerful Python-based interface.

---

## Features

- **Modern TUI** — Built with Textual for a rich terminal experience
- **10 Functional Screens** — Wireless, Scanning, Credentials, OSINT, Recon, Traffic, Exploit, Stress, Status, Settings
- **Automation Framework** — 13 AUTO-* handlers for seamless tool setup
- **100+ Tool Detection** — Distro-aware package management (apt, dnf, pacman, etc.)
- **First-Run Wizard** — 9-step bootstrap for new installations
- **Export System** — JSON, CSV, HTML, PDF, Markdown reports
- **Secure Storage** — Encrypted loot storage, system keyring for API keys
- **Event-Driven Architecture** — Real-time updates via async event bus

---

## Quick Start

```bash
# Clone and install
git clone https://github.com/Nerds489/VOIDWAVE.git
cd VOIDWAVE
pip install -e .

# Launch TUI
voidwave

# Or run with sudo for full functionality
sudo voidwave
```

---

## Screens

| Screen | Purpose | Key Tools |
|:-------|:--------|:----------|
| **Wireless** | WiFi attacks, monitoring, handshake/PMKID capture | aircrack-ng, hcxtools, reaver, mdk4 |
| **Scanning** | Port scanning, service enumeration | nmap, masscan, rustscan |
| **Credentials** | Password cracking, brute force | hashcat (GPU), john, hydra |
| **OSINT** | Open source intelligence | theHarvester, subfinder, amass, shodan |
| **Recon** | Web reconnaissance | gobuster, ffuf, nikto, nuclei, wpscan |
| **Traffic** | Packet capture, MITM | tcpdump, tshark, wireshark, ettercap |
| **Exploit** | Vulnerability exploitation | metasploit, sqlmap, searchsploit |
| **Stress** | Load/availability testing | hping3, iperf3, slowloris |
| **Status** | Tool detection & installation | 100+ tools with auto-install |
| **Settings** | Configuration & API keys | Secure keyring storage |

---

## Architecture

```
voidwave/
├── src/voidwave/
│   ├── tui/              # Textual TUI application
│   │   ├── app.py        # Main application
│   │   ├── screens/      # 10 functional screens
│   │   └── widgets/      # Custom TUI components
│   ├── automation/       # AUTO-* handlers & preflight
│   ├── orchestration/    # Event bus & workflow control
│   ├── detection/        # Tool detection & installation
│   ├── tools/            # Tool wrappers with output parsing
│   ├── export/           # Multi-format report generation
│   ├── db/               # SQLite persistence
│   ├── loot/             # Encrypted credential storage
│   └── config/           # Settings & API key management
├── lib/                  # Legacy bash modules
└── tests/                # Test suite
```

---

## Wireless Capabilities

| Attack Type | Methods |
|:------------|:--------|
| **WPS** | Pixie-Dust, PIN brute force, null PIN, known PINs database |
| **WPA/WPA2** | Handshake capture, PMKID capture, dictionary attack |
| **WPA3** | Transition mode downgrade |
| **Evil Twin** | Captive portal, WPA honeypot, credential harvesting |
| **DoS** | Deauth, beacon flood, authentication flood |
| **WEP** | ARP replay, ChopChop, fragmentation |

---

## Supported Distributions

| Family | Distributions | Package Manager |
|:-------|:--------------|:----------------|
| **Debian** | Debian, Ubuntu, Kali, Parrot | apt |
| **Red Hat** | Fedora, RHEL, Rocky, AlmaLinux | dnf |
| **Arch** | Arch, Manjaro, BlackArch | pacman |
| **SUSE** | openSUSE Leap, Tumbleweed | zypper |

Tool detection auto-detects your distribution and handles package name differences.

---

## Requirements

| Requirement | Details |
|:------------|:--------|
| **OS** | Linux (kernel 4.x+) |
| **Python** | 3.11+ |
| **Privileges** | Root for wireless/packet capture |
| **WiFi Adapter** | Monitor mode + packet injection support |

### Recommended Wireless Adapters

| Chipset | Monitor | Injection | Band |
|:--------|:-------:|:---------:|:----:|
| Atheros AR9271 | ✓ | ✓ | 2.4 GHz |
| MediaTek MT7612U | ✓ | ✓ | Dual-band |
| Ralink RT3070 | ✓ | ✓ | 2.4 GHz |
| Realtek RTL8812AU | ✓ | ✓ | Dual-band |

---

## API Keys (Optional)

For enhanced functionality, configure API keys in Settings:

| Service | Purpose |
|:--------|:--------|
| Shodan | Internet device search |
| Censys | Attack surface monitoring |
| VirusTotal | Malware scanning |
| WPScan | WordPress vulnerability DB |
| Hunter.io | Email discovery |
| SecurityTrails | DNS intelligence |

Keys are stored securely in your system keyring.

---

## Legal

> **Authorized testing only.** Unauthorized access to computer systems is illegal. Users are solely responsible for compliance with applicable laws. The authors assume no liability for misuse.

---

## Credits

VOIDWAVE v2.0.0 represents a complete architectural rewrite — from bash scripts to a modern Python TUI framework. Thanks to the security community and the developers behind aircrack-ng, hashcat, nmap, metasploit, and the dozens of other tools integrated into this framework.

---

<div align="center">
<sub><b>VOIDWAVE</b> v2.0.0 • Apache-2.0 • For those who operate in the void</sub>
</div>
