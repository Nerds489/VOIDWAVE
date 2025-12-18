# VOIDWAVE Tool Reference (v6.3.4)

VOIDWAVE wraps 70+ tools behind one interface. Run it via `./voidwave` inside the repo (wrapper) or `voidwave` after installing system-wide; both call the executable under `bin/`. Use the interactive menu for guided flows. CLI shortcuts available:
- `voidwave scan <target> (--quick|--full|--vuln|--stealth)`
- `voidwave wifi --monitor <iface>`
- `voidwave crack <capture> --hashcat`
- `voidwave session start|resume <name>|export`
- `voidwave status`, `voidwave install`, `voidwave help`, `voidwave --version`

Install tooling with `sudo voidwave-install essentials|all|<category>` and confirm with `voidwave status`.

## Recon & Discovery
| Tool | Purpose | Access in VOIDWAVE |
|------|---------|----------------------|
| nmap | TCP/UDP scans, service/vuln scripts | CLI: `voidwave scan ...`; Menu: Recon -> nmap (quick/full/stealth/UDP/vuln) |
| masscan | Fast port sweeps | Menu: Recon -> Masscan |
| rustscan | Rapid discovery feeding nmap | Menu: Recon -> Rustscan |
| netdiscover | ARP live host discovery | Menu: Recon -> Netdiscover |
| dnsenum | DNS/WHOIS/bruteforce | Menu: Recon -> DNSenum |
| sslscan | SSL/TLS cipher/protocol analysis | Menu: Recon -> SSLScan |
| enum4linux | SMB enumeration | Menu: Recon -> enum4linux |

## Wireless
| Tool | Purpose | Access in VOIDWAVE |
|------|---------|----------------------|
| aircrack-ng suite (airodump/aireplay) | Capture handshakes, deauth, crack WPA/WPA2 | CLI: `voidwave wifi --monitor <iface>` to start capture; Menu: Wireless -> Capture/Deauth |
| reaver | WPS exploitation | Menu: Wireless -> Reaver |
| bettercap | MITM and wireless attacks | Menu: Wireless -> Bettercap |
| wifite | Automated WiFi audit | Menu: Wireless -> Wifite |
| hostapd | Evil twin access point | Menu: Wireless -> Evil Twin |

## Web & Exploit
| Tool | Purpose | Access in VOIDWAVE |
|------|---------|----------------------|
| metasploit | Exploitation framework | Menu: Exploit -> Metasploit |
| sqlmap | Automated SQL injection | Menu: Exploit -> SQLMap |
| gobuster | Directory brute force | Menu: Exploit -> Gobuster |
| nikto | Web server vuln scan | Menu: Exploit -> Nikto |
| wpscan | WordPress security scan | Menu: Exploit -> WPScan |
| nuclei | Template-based scanning | Menu: Exploit -> Nuclei |
| searchsploit | Local exploit DB search | Menu: Exploit -> Searchsploit |

## Credentials & Access
| Tool | Purpose | Access in VOIDWAVE |
|------|---------|----------------------|
| hashcat | GPU hash cracking | CLI: `voidwave crack <capture_or_hashfile> --hashcat` |
| john | CPU hash cracking | Menu: Credentials -> John |
| hydra | Online brute force (SSH/HTTP/DB) | Menu: Credentials -> Hydra |
| medusa | Parallel brute force | Menu: Credentials -> Medusa |
| crackmapexec | SMB/WinRM/LDAP abuse | Menu: Credentials -> CrackMapExec |
| impacket suite | Windows protocols, secrets, tickets | Menu: Post-Exploit -> Impacket |

## Intel & OSINT
| Tool | Purpose | Access in VOIDWAVE |
|------|---------|----------------------|
| theHarvester | Email/host OSINT collection | Menu: Intel -> theHarvester |
| recon-ng | Modular recon framework | Menu: Intel -> Recon-NG |
| shodan CLI | Internet search engine interface | Menu: Intel -> Shodan |
| tcpdump | Packet capture | Menu: Intel -> Packet Capture |
| wireshark | GUI traffic analysis | Menu: Intel -> Wireshark |

## Stress & Network Performance
| Tool | Purpose | Access in VOIDWAVE |
|------|---------|----------------------|
| hping3 | Packet flooding/firewall testing | Menu: Stress -> hping3 |
| iperf3 | Throughput testing | Menu: Stress -> iperf3 |
| ab (ApacheBench) | HTTP load testing | Menu: Stress -> HTTP Load |
| tc/netem | Latency/loss/jitter impairment | Menu: Stress -> Netem (add/remove qdisc) |

## Utilities & Post-Exploitation
| Tool | Purpose | Access in VOIDWAVE |
|------|---------|----------------------|
| ssh/socat/nc | Connectivity checks, tunnels, pivots | Menu: Post-Exploit -> Tunnels/Utilities |
| mimikatz (helpers) | Credential extraction on Windows targets | Menu: Post-Exploit -> Mimikatz helpers |
| loot manager | View/export captured credentials/artifacts | Menu: Sessions/Loot -> View/Export |

Notes:
- Outputs are stored under `~/.voidwave/output/` per session; loot under `~/.voidwave/loot/`.
- Many actions provide previews/logs before execution; review them in `~/.voidwave/logs/` if something fails.
- Keep tools fresh with `sudo voidwave-install all` after pulling new versions of VOIDWAVE.
