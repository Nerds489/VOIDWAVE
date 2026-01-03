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

[![Version](https://img.shields.io/badge/version-10.2.1-ff0040?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Nerds489/VOIDWAVE/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue?style=for-the-badge)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-5.0+-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://kernel.org)

**Offensive Security Framework** | **124 Tools** | **Zero Configuration** | **Just Works**

[Installation](#installation) • [Quick Start](#quick-start) • [Commands](#commands) • [Tools](#tool-arsenal)

</div>

---

## What is VOIDWAVE?

VOIDWAVE is an offensive security framework that **does the thinking for you**. No more manually enabling monitor mode, finding interfaces, scanning for targets, or hunting for clients. Just run the attack — VOIDWAVE handles the rest.

```bash
# Old way
airmon-ng check kill
airmon-ng start wlan0
airodump-ng wlan0mon          # wait, watch, copy BSSID...
airodump-ng -c 6 --bssid AA:BB:CC:DD:EE:FF wlan0mon  # find clients...
aireplay-ng --deauth 0 -a AA:BB:CC:DD:EE:FF -c 11:22:33:44:55:66 wlan0mon

# VOIDWAVE way
voidwave wifi deauth          # done
```

---

## Installation

```bash
git clone https://github.com/Nerds489/VOIDWAVE.git
cd VOIDWAVE

# Install VOIDWAVE
./install.sh

# Install security tools (124 tools)
./install-tools.sh install-all
```

---

## Quick Start

```bash
# Launch interactive menu
sudo voidwave

# Or use direct commands with auto-everything
sudo voidwave wifi deauth     # auto: interface, monitor, AP, client
sudo voidwave wifi capture    # auto: interface, monitor, AP selection
sudo voidwave scan            # auto: discovers local network
```

---

## Automation

VOIDWAVE automatically handles requirements. No arguments needed — it figures it out:

| What You Run | What VOIDWAVE Does |
|:-------------|:-------------------|
| `voidwave scan` | Detects local network, runs nmap scan |
| `voidwave wifi status` | Finds wireless interface, shows mode |
| `voidwave wifi monitor on` | Selects interface, enables monitor mode |
| `voidwave wifi scan` | Selects interface, enables monitor, scans APs |
| `voidwave wifi deauth` | All above + selects AP + finds clients + attacks |
| `voidwave wifi capture` | All above + captures handshakes to file |

### How It Works

```
┌─────────────────────────────────────────────────────────────────────┐
│  1. AUTO-INTERFACE    Find wireless adapters, pick the best one    │
│  2. AUTO-MONITOR      Enable monitor mode if not already on        │
│  3. AUTO-NETWORK      Detect local network for scanning            │
│  4. AUTO-TARGET       Scan and select targets interactively        │
│  5. AUTO-AP           Scan for access points, let you pick         │
│  6. AUTO-CLIENT       Find connected clients on selected AP        │
│  7. AUTO-INSTALL      Install missing tools on the fly             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Commands

### Network Scanning

```bash
voidwave scan                     # auto-detect network, scan it
voidwave scan 192.168.1.0/24      # scan specific target
voidwave scan -t 10.0.0.1         # scan single host
```

### WiFi Operations

```bash
voidwave wifi list                # list wireless interfaces
voidwave wifi status              # show interface mode (auto-select)
voidwave wifi monitor on          # enable monitor mode (auto-select)
voidwave wifi monitor off         # disable monitor mode
voidwave wifi scan                # scan for access points
voidwave wifi deauth              # deauth attack (fully automated)
voidwave wifi capture             # capture handshakes
```

### System

```bash
voidwave status                   # show system info and tool status
voidwave config show              # show configuration
voidwave config set log_level DEBUG
voidwave wizard first             # first-time setup
```

### Flags

```bash
voidwave --help                   # show all commands
voidwave --version                # show version
voidwave --dry-run <cmd>          # preview without executing
voidwave --quiet <cmd>            # suppress output
voidwave --verbose <cmd>          # debug output
voidwave --target <IP> scan       # specify target
```

---

## Interactive Mode

Launch without arguments for the full menu system:

```bash
sudo voidwave
```

```
┌─────────────────────────────────────────────────────────────────────┐
│  [1] WIRELESS      WPA/WPA2/WPS/Evil Twin/Deauth/PMKID             │
│  [2] SCANNING      Port scans, service detection, host discovery   │
│  [3] CREDENTIALS   Password cracking, brute force, responder       │
│  [4] OSINT         Email harvesting, subdomain enum, recon         │
│  [5] RECON         Web fuzzing, directory brute force, CMS scans   │
│  [6] TRAFFIC       Packet capture, MITM, ARP spoofing              │
│  [7] EXPLOIT       Metasploit, SQLMap, searchsploit                │
│  [8] STRESS        Load testing, SYN floods                        │
│  [9] STATUS        System info, tool status                        │
│  [0] EXIT                                                          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Tool Arsenal

124 security tools across 9 categories:

### Wireless
`aircrack-ng` `airmon-ng` `airodump-ng` `aireplay-ng` `reaver` `bully` `wifite` `hcxdumptool` `hcxtools` `mdk4` `hostapd` `dnsmasq` `kismet` `pixiewps` `cowpatty` `wash` `macchanger` `iw`

### Scanning
`nmap` `masscan` `rustscan` `zmap` `enum4linux` `nbtscan` `onesixtyone` `smbclient` `smbmap` `ldapsearch` `snmpwalk` `nfs-utils`

### Credentials
`hashcat` `john` `hydra` `medusa` `responder` `impacket` `crackmapexec` `evil-winrm` `kerbrute` `patator` `crowbar` `thc-pptp-bruter` `hash-identifier`

### OSINT
`theHarvester` `subfinder` `amass` `recon-ng` `sherlock` `holehe` `spiderfoot` `maltego` `shodan` `censys` `emailharvester` `whois` `dnsrecon` `fierce` `dmitry`

### Recon
`gobuster` `ffuf` `feroxbuster` `dirb` `dirbuster` `nikto` `nuclei` `wpscan` `whatweb` `wafw00f` `httpx` `httprobe` `aquatone` `eyewitness` `gowitness` `arjun`

### Traffic
`tcpdump` `wireshark` `tshark` `ettercap` `bettercap` `mitmproxy` `arpspoof` `dnsspoof` `sslstrip` `netsniff-ng`

### Exploit
`metasploit` `sqlmap` `searchsploit` `commix` `xsser` `beef-xss` `social-engineer-toolkit` `veil` `empire` `covenant` `chisel` `ligolo-ng`

### Stress
`hping3` `slowloris` `siege` `ab` `wrk` `iperf3` `stress-ng` `t50`

### Utility
`curl` `wget` `git` `proxychains` `tor` `socat` `netcat` `tmux` `screen` `jq` `yq` `xxd` `binwalk` `foremost` `steghide` `exiftool` `pwncat` `rlwrap` `sshpass` `fcrackzip`

---

## Tool Installer

```bash
./install-tools.sh list              # show all tools and status
./install-tools.sh install-all       # install everything
./install-tools.sh category wireless # install by category
./install-tools.sh install nmap      # install specific tool
./install-tools.sh search wifi       # search tools
```

Installation methods: `apt` `dnf` `pacman` `zypper` `apk` `pipx` `pip` `go` `cargo` `gem` `snap` `flatpak` `github releases` `git clone`

---

## Supported Distros

| Family | Distributions |
|:-------|:--------------|
| **Debian** | Debian, Ubuntu, Kali, Parrot, Linux Mint |
| **Red Hat** | Fedora, RHEL, Rocky, AlmaLinux, CentOS |
| **Arch** | Arch, Manjaro, BlackArch, EndeavourOS |
| **SUSE** | openSUSE Leap, Tumbleweed |
| **Alpine** | Alpine Linux |
| **Void** | Void Linux |

---

## Wireless Attacks

| Attack | Description |
|:-------|:------------|
| **WPS Pixie-Dust** | Offline WPS PIN recovery |
| **WPS Brute Force** | Online PIN enumeration |
| **WPA Handshake** | 4-way handshake capture + crack |
| **PMKID** | Clientless WPA attack |
| **Deauth** | Client disconnection |
| **Evil Twin** | Rogue AP with captive portal |
| **Beacon Flood** | Fake network spam |
| **WEP** | Legacy encryption attacks |

### Recommended Adapters

| Chipset | Driver | Injection |
|:--------|:-------|:---------:|
| Atheros AR9271 | ath9k_htc | ✓ |
| Ralink RT3070 | rt2800usb | ✓ |
| Realtek RTL8812AU | rtl8812au | ✓ |
| MediaTek MT7612U | mt76x2u | ✓ |

---

## Configuration

```bash
voidwave config show              # all settings
voidwave config get log_level     # get value
voidwave config set key value     # set value
voidwave config reset             # restore defaults
```

| Setting | Default | Description |
|:--------|:--------|:------------|
| `log_level` | INFO | DEBUG, INFO, WARNING, ERROR |
| `file_logging` | true | Write logs to file |
| `confirm_dangerous` | true | Prompt before dangerous ops |
| `warn_public_ip` | true | Warn on public IP targets |

---

## Requirements

| Requirement | Details |
|:------------|:--------|
| **OS** | Linux (kernel 4.x+) |
| **Shell** | Bash 5.0+ |
| **Privileges** | Root for wireless/packet capture |
| **WiFi Adapter** | Monitor mode + injection (for wireless attacks) |

---

## Project Structure

```
VOIDWAVE/
├── bin/voidwave          # CLI entry point
├── voidwave              # Launcher wrapper
├── lib/                  # Bash libraries
│   ├── automation.sh     # Auto-* functions
│   ├── core.sh           # Core utilities
│   ├── wireless.sh       # Wireless operations
│   ├── detection.sh      # System detection
│   ├── config.sh         # Configuration
│   ├── ui.sh             # Terminal UI
│   ├── menus/            # Interactive menus
│   ├── attacks/          # Attack modules
│   └── intelligence/     # Smart targeting
├── install.sh            # VOIDWAVE installer
├── install-tools.sh      # Tool installer (124 tools)
└── src/voidwave/         # Python TUI (optional)
```

---

## Legal

> **For authorized security testing only.**
>
> Unauthorized access to computer systems is illegal. You are responsible for ensuring proper authorization before use.
>
> Authorized uses:
> - Penetration testing with written permission
> - Security research on systems you own
> - Educational environments
> - CTF competitions

---

<div align="center">

**VOIDWAVE** v10.2.1 • Apache-2.0

*The airwaves belong to those who listen*

</div>
