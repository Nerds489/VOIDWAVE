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

[![Version](https://img.shields.io/badge/version-10.0.0-ff0040?style=flat-square&logo=v&logoColor=white)](https://github.com/YOURUSER/voidwave/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue?style=flat-square)](LICENSE)
[![Shell](https://img.shields.io/badge/bash-4.0+-4EAA25?style=flat-square&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/linux-kernel%204.x+-FCC624?style=flat-square&logo=linux&logoColor=black)](https://kernel.org)

<sub>v10.0.0 marks the NETREAPER evolution — rebuilt architecture, expanded arsenal</sub>

</div>

---

**VOIDWAVE** is an offensive security framework for penetration testers and red teams. 70+ integrated tools across network recon, wireless attacks, credential cracking, and exploitation — unified under one interface.

---

## Quick Start

```bash
# Install
git clone https://github.com/Nerds489/voidwave.git && cd voidwave && sudo ./install.sh

# Install tools
sudo voidwave-install essentials    # Core tools
sudo voidwave-install all           # Full arsenal

# Launch
voidwave                            # Interactive mode
voidwave scan nmap 192.168.1.0/24   # Direct CLI
```

---

## Modules

| Module | Purpose | Key Tools |
|:-------|:--------|:----------|
| `wireless` | WiFi attacks, monitoring, handshake/PMKID capture | aircrack-ng, bettercap, hcxtools, wifite |
| `scanning` | Port scanning, service enumeration | nmap, masscan, rustscan, zmap |
| `recon` | Network discovery, host identification | netdiscover, arp-scan, fping |
| `osint` | Open source intelligence gathering | theHarvester, recon-ng, shodan, amass |
| `credentials` | Password cracking, brute force | hashcat (GPU), john, hydra, medusa |
| `exploit` | Vulnerability exploitation | metasploit, searchsploit, sqlmap, nuclei |
| `traffic` | Packet capture, MITM attacks | tcpdump, wireshark, ettercap, bettercap |
| `stress` | Load testing, availability testing | hping3, iperf3, siege |

---

## Usage

```bash
# Wireless
voidwave wireless scan                     # Discover networks
voidwave wireless capture <BSSID> <CH>     # Capture handshake
voidwave wireless deauth <BSSID>           # Deauthentication

# Scanning
voidwave scan nmap -sV target.com          # Service detection
voidwave scan masscan 10.0.0.0/8 -p80,443  # Fast port scan

# Credentials
voidwave creds hashcat hash.txt rockyou.txt
voidwave creds hydra ssh://target -l root -P wordlist.txt

# OSINT
voidwave osint theharvester -d target.com
voidwave osint shodan search "port:22"

# Session management
voidwave session new engagement-01
voidwave memory show
```

<details>
<summary><b>Wireless Attack Capabilities</b></summary>

| Attack Type | Methods |
|:------------|:--------|
| **WPS** | Pixie-Dust, PIN brute force, null PIN, known PINs database, algorithm-based |
| **WPA/WPA2** | Handshake capture, PMKID capture, dictionary attack |
| **WPA3** | Transition mode downgrade, DragonBlood |
| **Evil Twin** | Captive portal (13 languages), WPA honeypot, credential harvesting |
| **DoS** | Deauth, beacon flood, auth flood, TKIP Michael, pursuit mode |
| **WEP** | ARP replay, ChopChop, fragmentation, Caffe-Latte, Hirte |
| **Enterprise** | hostapd-wpe, RADIUS credential capture, Karma |

</details>

<details>
<summary><b>Session Memory System</b></summary>

VOIDWAVE tracks discovered targets across your engagement:

```bash
voidwave memory show              # View all remembered items
voidwave memory show wireless     # View discovered APs
voidwave memory add host 10.0.0.5 "Domain Controller"
voidwave memory clear
```

Memory types: `network`, `host`, `interface`, `wireless`

When selecting targets, the system offers:
- Recent items from memory
- Auto-scan to discover new targets
- Manual input

</details>

---

## Supported Distributions

| Family | Distributions |
|:-------|:--------------|
| **Debian** | Debian, Ubuntu, Kali, Parrot, Linux Mint, Pop!_OS |
| **Red Hat** | Fedora, RHEL, Rocky Linux, AlmaLinux, CentOS |
| **Arch** | Arch, Manjaro, BlackArch, EndeavourOS, Garuda |
| **SUSE** | openSUSE Leap, openSUSE Tumbleweed |
| **Other** | Alpine, Void Linux, Gentoo, NixOS |

The installer auto-detects your distribution and handles package name differences.

---

## Requirements

| Requirement | Details |
|:------------|:--------|
| **OS** | Linux (kernel 4.x+) |
| **Shell** | Bash 4.0+ |
| **Privileges** | Root for wireless/packet capture |
| **WiFi Adapter** | Monitor mode + packet injection support |

<details>
<summary><b>Recommended Wireless Adapters</b></summary>

| Chipset | Monitor | Injection | Band | Rating |
|:--------|:-------:|:---------:|:----:|:------:|
| Atheros AR9271 | ✓ | ✓ | 2.4 | Best |
| MediaTek MT7612U | ✓ | ✓ | Dual | Best |
| Ralink RT3070 | ✓ | ✓ | 2.4 | Good |
| Realtek RTL8812AU | ✓ | ✓ | Dual | Good |

</details>

---

## Structure

```
voidwave/
├── bin/            # CLI executables
├── lib/            # Core libraries
│   ├── attacks/    # Attack implementations
│   ├── menus/      # Interactive menus
│   └── wireless/   # Adapter & session management
├── modules/        # High-level module interfaces
├── data/           # Databases (WPS pins, OUI)
└── completions/    # Shell completions
```

---

## Legal

> **Authorized testing only.** Unauthorized access to computer systems is illegal. Users are solely responsible for compliance with applicable laws. The authors assume no liability for misuse.

---

## Credits

VOIDWAVE continues the work started as NETREAPER (v1-9). Version 10.0.0 marks the complete rebuild — new architecture, expanded toolset, unified interface.

Thanks to the security community and the developers behind aircrack-ng, hashcat, nmap, metasploit, and the dozens of other tools integrated into this framework.

---

<div align="center">
<sub><b>VOIDWAVE</b> v10.0.0 • Apache-2.0 • For those who operate in the void</sub>
</div>
