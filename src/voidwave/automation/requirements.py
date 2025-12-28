"""Attack requirements definitions ported from preflight.sh."""

import os
import shutil
from pathlib import Path
from typing import Any

from voidwave.automation.engine import Requirement, RequirementType


def _check_root() -> bool:
    """Check if running as root."""
    return os.geteuid() == 0


def _check_tool(name: str) -> bool:
    """Check if a tool is available."""
    return shutil.which(name) is not None


def _check_wordlist() -> bool:
    """Check if default wordlist exists."""
    paths = [
        Path("/usr/share/wordlists/rockyou.txt"),
        Path("/usr/share/seclists/Passwords/rockyou.txt"),
        Path.home() / ".voidwave/wordlists/rockyou.txt",
        Path("/voidwave/wordlists/rockyou.txt"),
    ]
    return any(p.exists() for p in paths)


# Check functions - will be populated by session at runtime
_session_checks: dict[str, Any] = {}


def _check_interface() -> bool:
    """Check if interface is selected."""
    return _session_checks.get("interface", False)


def _check_monitor_mode() -> bool:
    """Check if monitor mode is enabled."""
    return _session_checks.get("monitor_mode", False)


def _check_target() -> bool:
    """Check if target is selected."""
    return _session_checks.get("target", False)


def _check_capture_file() -> bool:
    """Check if capture file exists."""
    return _session_checks.get("capture_file", False)


def _check_hash_file() -> bool:
    """Check if hash file exists."""
    return _session_checks.get("hash_file", False)


def _check_handshake() -> bool:
    """Check if handshake is captured."""
    return _session_checks.get("handshake", False)


def set_session_check(name: str, value: bool) -> None:
    """Set a session check value."""
    _session_checks[name] = value


def clear_session_checks() -> None:
    """Clear all session checks."""
    _session_checks.clear()


# Standard requirements that are reused
ROOT_REQ = Requirement(
    type=RequirementType.PRIVILEGE,
    name="root",
    description="Root privileges required",
    check=_check_root,
    auto_label="AUTO-PRIV",
)

INTERFACE_REQ = Requirement(
    type=RequirementType.INTERFACE,
    name="interface",
    description="Wireless interface selected",
    check=_check_interface,
    auto_label="AUTO-IFACE",
)

MONITOR_REQ = Requirement(
    type=RequirementType.INTERFACE,
    name="monitor_mode",
    description="Monitor mode enabled",
    check=_check_monitor_mode,
    auto_label="AUTO-MON",
)

TARGET_REQ = Requirement(
    type=RequirementType.INPUT,
    name="target",
    description="Target network/host selected",
    check=_check_target,
    auto_label="AUTO-ACQUIRE",
)

WORDLIST_REQ = Requirement(
    type=RequirementType.DATA,
    name="wordlist",
    description="Wordlist file available",
    check=_check_wordlist,
    auto_label="AUTO-DATA",
)


def tool_req(
    name: str, description: str = "", alternatives: list[str] | None = None
) -> Requirement:
    """Create a tool requirement."""
    return Requirement(
        type=RequirementType.TOOL,
        name=name,
        description=description or f"{name} tool required",
        check=lambda n=name: _check_tool(n),
        alternatives=alternatives or [],
        auto_label="AUTO-INSTALL",
    )


# Complete attack requirements dictionary
ATTACK_REQUIREMENTS: dict[str, list[Requirement]] = {
    # =========================================================================
    # WPS ATTACKS
    # =========================================================================
    "wps_pixie": [
        ROOT_REQ,
        MONITOR_REQ,
        tool_req("reaver", "Reaver WPS attack tool", ["bully"]),
        tool_req("pixiewps", "Pixie-Dust offline attack"),
        TARGET_REQ,
    ],
    "wps_bruteforce": [
        ROOT_REQ,
        MONITOR_REQ,
        tool_req("reaver", "Reaver WPS attack tool", ["bully"]),
        TARGET_REQ,
    ],
    "wps_known": [
        ROOT_REQ,
        MONITOR_REQ,
        tool_req("reaver", "Reaver WPS attack tool", ["bully"]),
        TARGET_REQ,
    ],
    "wps_algorithm": [
        ROOT_REQ,
        MONITOR_REQ,
        tool_req("reaver", "Reaver WPS attack tool", ["bully"]),
        TARGET_REQ,
    ],
    "wps_scan": [
        ROOT_REQ,
        MONITOR_REQ,
        tool_req("wash", "WPS-enabled network scanner"),
    ],
    # =========================================================================
    # WPA ATTACKS
    # =========================================================================
    "pmkid": [
        ROOT_REQ,
        MONITOR_REQ,
        tool_req("hcxdumptool", "PMKID capture tool"),
        TARGET_REQ,
    ],
    "handshake": [
        ROOT_REQ,
        MONITOR_REQ,
        tool_req("airodump-ng", "Wireless packet capture"),
        tool_req("aireplay-ng", "Wireless packet injection"),
        TARGET_REQ,
    ],
    "crack_aircrack": [
        tool_req("aircrack-ng", "WPA/WPA2 cracker"),
        Requirement(
            type=RequirementType.INPUT,
            name="capture_file",
            description="Capture file selected",
            check=_check_capture_file,
            auto_label="AUTO-ACQUIRE",
        ),
        WORDLIST_REQ,
    ],
    "crack_hashcat": [
        tool_req("hashcat", "GPU-accelerated password cracker"),
        Requirement(
            type=RequirementType.INPUT,
            name="hash_file",
            description="Hash file selected",
            check=_check_hash_file,
            auto_label="AUTO-ACQUIRE",
        ),
        WORDLIST_REQ,
    ],
    # =========================================================================
    # EVIL TWIN
    # =========================================================================
    "eviltwin": [
        ROOT_REQ,
        INTERFACE_REQ,
        tool_req("hostapd", "Access point daemon"),
        tool_req("dnsmasq", "DNS/DHCP server"),
    ],
    "eviltwin_full": [
        ROOT_REQ,
        INTERFACE_REQ,
        tool_req("hostapd", "Access point daemon"),
        tool_req("dnsmasq", "DNS/DHCP server"),
        tool_req("lighttpd", "Web server"),
        Requirement(
            type=RequirementType.INPUT,
            name="handshake",
            description="Handshake file captured",
            check=_check_handshake,
            auto_label="AUTO-ACQUIRE",
        ),
    ],
    # =========================================================================
    # DoS ATTACKS
    # =========================================================================
    "deauth": [
        ROOT_REQ,
        MONITOR_REQ,
        tool_req("aireplay-ng", "Wireless packet injection"),
        TARGET_REQ,
    ],
    "amok": [
        ROOT_REQ,
        MONITOR_REQ,
        tool_req("mdk4", "Wireless attack tool"),
    ],
    "beacon_flood": [
        ROOT_REQ,
        MONITOR_REQ,
        tool_req("mdk4", "Wireless attack tool"),
    ],
    # =========================================================================
    # OTHER WIRELESS
    # =========================================================================
    "wep": [
        ROOT_REQ,
        MONITOR_REQ,
        tool_req("aircrack-ng", "WEP cracker"),
        tool_req("aireplay-ng", "Wireless packet injection"),
        TARGET_REQ,
    ],
    "enterprise": [
        ROOT_REQ,
        MONITOR_REQ,
        tool_req("hostapd", "Access point daemon", ["hostapd-wpe"]),
    ],
    "scan": [
        ROOT_REQ,
        INTERFACE_REQ,
        tool_req("airodump-ng", "Wireless packet capture"),
    ],
    # =========================================================================
    # RECON
    # =========================================================================
    "recon_dns": [
        tool_req("dig", "DNS lookup utility", ["host"]),
    ],
    "recon_subdomain": [
        tool_req("subfinder", "Subdomain discovery", ["amass", "host"]),
    ],
    "recon_whois": [
        tool_req("whois", "WHOIS lookup"),
    ],
    "recon_email": [
        tool_req("theHarvester", "Email harvester", ["theharvester"]),
    ],
    "recon_tech": [
        tool_req("whatweb", "Web technology detector", ["curl"]),
    ],
    "recon_full": [
        tool_req("dig", "DNS lookup utility"),
        tool_req("whois", "WHOIS lookup"),
        tool_req("curl", "HTTP client"),
    ],
    # =========================================================================
    # SCANNING
    # =========================================================================
    "scan_quick": [
        tool_req("nmap", "Network scanner"),
        TARGET_REQ,
    ],
    "scan_full": [
        tool_req("nmap", "Network scanner"),
        TARGET_REQ,
    ],
    "scan_version": [
        tool_req("nmap", "Network scanner"),
        TARGET_REQ,
    ],
    "scan_os": [
        ROOT_REQ,
        tool_req("nmap", "Network scanner"),
        TARGET_REQ,
    ],
    "scan_vuln": [
        tool_req("nmap", "Network scanner"),
        TARGET_REQ,
    ],
    "scan_stealth": [
        ROOT_REQ,
        tool_req("nmap", "Network scanner"),
        TARGET_REQ,
    ],
    "scan_udp": [
        ROOT_REQ,
        tool_req("nmap", "Network scanner"),
        TARGET_REQ,
    ],
    "scan_custom": [
        tool_req("nmap", "Network scanner"),
        TARGET_REQ,
    ],
    # =========================================================================
    # CREDENTIALS
    # =========================================================================
    "creds_hydra": [
        tool_req("hydra", "Network login cracker"),
        TARGET_REQ,
    ],
    "creds_hashcat": [
        tool_req("hashcat", "GPU-accelerated password cracker"),
        WORDLIST_REQ,
    ],
    "creds_john": [
        tool_req("john", "Password cracker"),
        WORDLIST_REQ,
    ],
    "creds_identify": [],
    "creds_wordlist": [],
    "creds_extract": [],
    # =========================================================================
    # OSINT
    # =========================================================================
    "osint_harvester": [
        tool_req("theHarvester", "Email/subdomain harvester", ["theharvester"]),
    ],
    "osint_shodan": [
        tool_req("curl", "HTTP client"),
        Requirement(
            type=RequirementType.API_KEY,
            name="shodan_api_key",
            description="Shodan API key",
            check=lambda: bool(os.environ.get("SHODAN_API_KEY")),
            auto_label="AUTO-KEYS",
        ),
    ],
    "osint_dorks": [],
    "osint_social": [
        tool_req("curl", "HTTP client"),
    ],
    "osint_reputation": [
        tool_req("whois", "WHOIS lookup", ["curl"]),
    ],
    "osint_domain": [
        tool_req("whois", "WHOIS lookup"),
        tool_req("dig", "DNS lookup utility"),
        tool_req("curl", "HTTP client"),
    ],
    "osint_full": [
        tool_req("whois", "WHOIS lookup"),
        tool_req("dig", "DNS lookup utility"),
        tool_req("curl", "HTTP client"),
    ],
    # =========================================================================
    # TRAFFIC
    # =========================================================================
    "traffic_tcpdump": [
        ROOT_REQ,
        tool_req("tcpdump", "Packet capture"),
    ],
    "traffic_wireshark": [
        tool_req("wireshark", "GUI packet analyzer"),
    ],
    "traffic_arpspoof": [
        ROOT_REQ,
        tool_req("arpspoof", "ARP spoofing tool"),
    ],
    "traffic_dnsspoof": [
        ROOT_REQ,
        tool_req("dnsspoof", "DNS spoofing tool"),
    ],
    "traffic_sniff": [
        ROOT_REQ,
        tool_req("tcpdump", "Packet capture"),
    ],
    "traffic_pcap": [
        tool_req("tcpdump", "Packet capture", ["tshark"]),
    ],
    # =========================================================================
    # EXPLOIT
    # =========================================================================
    "exploit_msf": [
        tool_req("msfconsole", "Metasploit Framework"),
    ],
    "exploit_searchsploit": [
        tool_req("searchsploit", "Exploit database search"),
    ],
    "exploit_sqlmap": [
        tool_req("sqlmap", "SQL injection tool"),
        TARGET_REQ,
    ],
    "exploit_revshell": [],
    "exploit_payload": [
        tool_req("msfvenom", "Payload generator"),
    ],
    "exploit_nikto": [
        tool_req("nikto", "Web server scanner"),
        TARGET_REQ,
    ],
    # =========================================================================
    # STRESS TESTING
    # =========================================================================
    "stress_http": [
        ROOT_REQ,
        tool_req("hping3", "Packet generator", ["curl"]),
        TARGET_REQ,
    ],
    "stress_syn": [
        ROOT_REQ,
        tool_req("hping3", "Packet generator"),
        TARGET_REQ,
    ],
    "stress_udp": [
        ROOT_REQ,
        tool_req("hping3", "Packet generator"),
        TARGET_REQ,
    ],
    "stress_icmp": [
        ROOT_REQ,
        tool_req("hping3", "Packet generator", ["ping"]),
        TARGET_REQ,
    ],
    "stress_conn": [
        TARGET_REQ,
    ],
    "stress_bandwidth": [
        tool_req("iperf3", "Network bandwidth tester"),
        TARGET_REQ,
    ],
}


def get_requirements(action: str) -> list[Requirement]:
    """Get requirements for an action."""
    return ATTACK_REQUIREMENTS.get(action, [])


def list_actions() -> list[str]:
    """List all defined actions."""
    return list(ATTACK_REQUIREMENTS.keys())
