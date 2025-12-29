"""Tool availability detection and path resolution."""
from __future__ import annotations

import asyncio
import shutil
import subprocess
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Self

from voidwave.core.exceptions import ToolNotFoundError
from voidwave.core.logging import get_logger

logger = get_logger(__name__)


class ToolCategory(str, Enum):
    """Tool categories for organization."""

    WIRELESS = "wireless"
    SCANNING = "scanning"
    CREDENTIALS = "credentials"
    OSINT = "osint"
    RECON = "recon"
    TRAFFIC = "traffic"
    EXPLOIT = "exploit"
    STRESS = "stress"
    UTILITY = "utility"


class DistroFamily(str, Enum):
    """Linux distribution families."""

    DEBIAN = "debian"
    REDHAT = "redhat"
    ARCH = "arch"
    FEDORA = "fedora"
    SUSE = "suse"
    UNKNOWN = "unknown"


class PackageManager(str, Enum):
    """Package manager types."""

    APT = "apt"
    DNF = "dnf"
    YUM = "yum"
    PACMAN = "pacman"
    ZYPPER = "zypper"
    UNKNOWN = "unknown"


def detect_distro() -> DistroFamily:
    """Detect the Linux distribution family."""
    try:
        # Check /etc/os-release first
        os_release = Path("/etc/os-release")
        if os_release.exists():
            content = os_release.read_text().lower()
            if "debian" in content or "ubuntu" in content or "kali" in content:
                return DistroFamily.DEBIAN
            elif "fedora" in content:
                return DistroFamily.FEDORA
            elif "rhel" in content or "centos" in content or "rocky" in content:
                return DistroFamily.REDHAT
            elif "arch" in content or "manjaro" in content:
                return DistroFamily.ARCH
            elif "suse" in content or "opensuse" in content:
                return DistroFamily.SUSE

        # Fallback checks
        if Path("/etc/debian_version").exists():
            return DistroFamily.DEBIAN
        elif Path("/etc/redhat-release").exists():
            return DistroFamily.REDHAT
        elif Path("/etc/arch-release").exists():
            return DistroFamily.ARCH

    except Exception as e:
        logger.warning(f"Failed to detect distro: {e}")

    return DistroFamily.UNKNOWN


def detect_package_manager() -> PackageManager:
    """Detect the system's package manager."""
    managers = [
        ("apt", PackageManager.APT),
        ("dnf", PackageManager.DNF),
        ("yum", PackageManager.YUM),
        ("pacman", PackageManager.PACMAN),
        ("zypper", PackageManager.ZYPPER),
    ]

    for cmd, pm in managers:
        if shutil.which(cmd):
            return pm

    return PackageManager.UNKNOWN


@dataclass
class ToolDefinition:
    """Definition of a tool with package mappings."""

    name: str
    category: ToolCategory
    description: str = ""
    version_flag: str = "--version"
    packages: dict[str, str] = field(default_factory=dict)
    requires_root: bool = False
    url: str = ""
    pip_package: str = ""  # pip install name (e.g., "theHarvester")
    binary_names: list[str] = field(default_factory=list)  # Alternative binary names to check


@dataclass
class ToolInfo:
    """Information about an external tool."""

    name: str
    path: Path | None
    version: str | None
    available: bool
    category: ToolCategory | None = None
    description: str = ""
    requires_root: bool = False

    @classmethod
    def detect(
        cls,
        name: str,
        version_flag: str = "--version",
        category: ToolCategory | None = None,
        description: str = "",
        requires_root: bool = False,
        binary_names: list[str] | None = None,
    ) -> Self:
        """Detect tool availability and version."""
        # Check primary name first, then alternatives
        names_to_check = [name]
        if binary_names:
            names_to_check.extend(n for n in binary_names if n != name)

        path = None
        for check_name in names_to_check:
            path = shutil.which(check_name)
            if path:
                break

        if path is None:
            return cls(
                name=name,
                path=None,
                version=None,
                available=False,
                category=category,
                description=description,
                requires_root=requires_root,
            )

        # Try to get version
        version = None
        try:
            result = subprocess.run(
                [path, version_flag],
                capture_output=True,
                text=True,
                timeout=5,
            )
            if result.returncode == 0:
                version = result.stdout.strip().split("\n")[0]
            else:
                # Some tools output version to stderr
                version = result.stderr.strip().split("\n")[0] if result.stderr else None
        except Exception:
            pass

        return cls(
            name=name,
            path=Path(path),
            version=version,
            available=True,
            category=category,
            description=description,
            requires_root=requires_root,
        )


class ToolRegistry:
    """Registry of required and optional tools."""

    # Comprehensive tool definitions with categories and package mappings
    TOOL_DEFINITIONS: dict[str, ToolDefinition] = {
        # ========== WIRELESS ==========
        "aircrack-ng": ToolDefinition(
            name="aircrack-ng",
            category=ToolCategory.WIRELESS,
            description="WPA/WPA2 key cracking",
            packages={"debian": "aircrack-ng", "redhat": "aircrack-ng", "arch": "aircrack-ng", "fedora": "aircrack-ng"},
        ),
        "airodump-ng": ToolDefinition(
            name="airodump-ng",
            category=ToolCategory.WIRELESS,
            description="Wireless network packet capture",
            packages={"debian": "aircrack-ng", "redhat": "aircrack-ng", "arch": "aircrack-ng", "fedora": "aircrack-ng"},
            requires_root=True,
        ),
        "aireplay-ng": ToolDefinition(
            name="aireplay-ng",
            category=ToolCategory.WIRELESS,
            description="Wireless packet injection",
            packages={"debian": "aircrack-ng", "redhat": "aircrack-ng", "arch": "aircrack-ng", "fedora": "aircrack-ng"},
            requires_root=True,
        ),
        "airmon-ng": ToolDefinition(
            name="airmon-ng",
            category=ToolCategory.WIRELESS,
            description="Monitor mode interface management",
            packages={"debian": "aircrack-ng", "redhat": "aircrack-ng", "arch": "aircrack-ng", "fedora": "aircrack-ng"},
            requires_root=True,
        ),
        "hostapd": ToolDefinition(
            name="hostapd",
            category=ToolCategory.WIRELESS,
            description="Rogue AP / Evil Twin attacks",
            packages={"debian": "hostapd", "redhat": "hostapd", "arch": "hostapd", "fedora": "hostapd"},
            requires_root=True,
        ),
        "dnsmasq": ToolDefinition(
            name="dnsmasq",
            category=ToolCategory.WIRELESS,
            description="DNS/DHCP for captive portals",
            packages={"debian": "dnsmasq", "redhat": "dnsmasq", "arch": "dnsmasq", "fedora": "dnsmasq"},
            requires_root=True,
        ),
        "reaver": ToolDefinition(
            name="reaver",
            category=ToolCategory.WIRELESS,
            description="WPS brute force attacks",
            packages={"debian": "reaver", "redhat": "reaver", "arch": "reaver", "fedora": "reaver"},
            requires_root=True,
        ),
        "bully": ToolDefinition(
            name="bully",
            category=ToolCategory.WIRELESS,
            description="WPS pixie dust attacks",
            packages={"debian": "bully", "redhat": "bully", "arch": "bully", "fedora": "bully"},
            requires_root=True,
        ),
        "wash": ToolDefinition(
            name="wash",
            category=ToolCategory.WIRELESS,
            description="WPS-enabled AP scanner",
            packages={"debian": "reaver", "redhat": "reaver", "arch": "reaver", "fedora": "reaver"},
            requires_root=True,
        ),
        "wifite": ToolDefinition(
            name="wifite",
            category=ToolCategory.WIRELESS,
            description="Automated wireless auditing",
            packages={"debian": "wifite", "redhat": "wifite", "arch": "wifite", "fedora": "wifite"},
            requires_root=True,
        ),
        "hcxdumptool": ToolDefinition(
            name="hcxdumptool",
            category=ToolCategory.WIRELESS,
            description="PMKID capture tool",
            packages={"debian": "hcxdumptool", "redhat": "hcxdumptool", "arch": "hcxdumptool", "fedora": "hcxdumptool"},
            requires_root=True,
        ),
        "hcxpcapngtool": ToolDefinition(
            name="hcxpcapngtool",
            category=ToolCategory.WIRELESS,
            description="Convert captures for hashcat",
            packages={"debian": "hcxtools", "redhat": "hcxtools", "arch": "hcxtools", "fedora": "hcxtools"},
        ),
        "mdk4": ToolDefinition(
            name="mdk4",
            category=ToolCategory.WIRELESS,
            description="Wireless attack tool",
            packages={"debian": "mdk4", "redhat": "mdk4", "arch": "mdk4", "fedora": "mdk4"},
            requires_root=True,
        ),
        "fern-wifi-cracker": ToolDefinition(
            name="fern-wifi-cracker",
            category=ToolCategory.WIRELESS,
            description="GUI wireless security auditing",
            packages={"debian": "fern-wifi-cracker", "arch": "fern-wifi-cracker"},
        ),
        "kismet": ToolDefinition(
            name="kismet",
            category=ToolCategory.WIRELESS,
            description="Wireless network detector",
            packages={"debian": "kismet", "redhat": "kismet", "arch": "kismet", "fedora": "kismet"},
            requires_root=True,
        ),
        "iw": ToolDefinition(
            name="iw",
            category=ToolCategory.WIRELESS,
            description="Wireless device configuration",
            packages={"debian": "iw", "redhat": "iw", "arch": "iw", "fedora": "iw"},
        ),
        "macchanger": ToolDefinition(
            name="macchanger",
            category=ToolCategory.WIRELESS,
            description="MAC address manipulation",
            packages={"debian": "macchanger", "redhat": "macchanger", "arch": "macchanger", "fedora": "macchanger"},
            requires_root=True,
        ),

        # ========== SCANNING ==========
        "nmap": ToolDefinition(
            name="nmap",
            category=ToolCategory.SCANNING,
            description="Network exploration and security auditing",
            packages={"debian": "nmap", "redhat": "nmap", "arch": "nmap", "fedora": "nmap"},
        ),
        "masscan": ToolDefinition(
            name="masscan",
            category=ToolCategory.SCANNING,
            description="Fast port scanner",
            packages={"debian": "masscan", "redhat": "masscan", "arch": "masscan", "fedora": "masscan"},
            requires_root=True,
        ),
        "rustscan": ToolDefinition(
            name="rustscan",
            category=ToolCategory.SCANNING,
            description="Fast port scanner with nmap integration",
            packages={"arch": "rustscan"},
            url="https://github.com/RustScan/RustScan",
        ),
        "netdiscover": ToolDefinition(
            name="netdiscover",
            category=ToolCategory.SCANNING,
            description="Active/passive ARP reconnaissance",
            packages={"debian": "netdiscover", "redhat": "netdiscover", "arch": "netdiscover", "fedora": "netdiscover"},
            requires_root=True,
        ),
        "arp-scan": ToolDefinition(
            name="arp-scan",
            category=ToolCategory.SCANNING,
            description="ARP network scanner",
            packages={"debian": "arp-scan", "redhat": "arp-scan", "arch": "arp-scan", "fedora": "arp-scan"},
            requires_root=True,
        ),
        "unicornscan": ToolDefinition(
            name="unicornscan",
            category=ToolCategory.SCANNING,
            description="Asynchronous stateless TCP scanner",
            packages={"debian": "unicornscan", "arch": "unicornscan"},
        ),
        "nbtscan": ToolDefinition(
            name="nbtscan",
            category=ToolCategory.SCANNING,
            description="NetBIOS name scanner",
            packages={"debian": "nbtscan", "redhat": "nbtscan", "arch": "nbtscan", "fedora": "nbtscan"},
        ),
        "enum4linux": ToolDefinition(
            name="enum4linux",
            category=ToolCategory.SCANNING,
            description="Windows/Samba enumeration",
            packages={"debian": "enum4linux", "arch": "enum4linux"},
        ),
        "smbclient": ToolDefinition(
            name="smbclient",
            category=ToolCategory.SCANNING,
            description="SMB/CIFS client",
            packages={"debian": "smbclient", "redhat": "samba-client", "arch": "smbclient", "fedora": "samba-client"},
        ),
        "onesixtyone": ToolDefinition(
            name="onesixtyone",
            category=ToolCategory.SCANNING,
            description="SNMP scanner",
            packages={"debian": "onesixtyone", "arch": "onesixtyone"},
        ),

        # ========== CREDENTIALS ==========
        "hashcat": ToolDefinition(
            name="hashcat",
            category=ToolCategory.CREDENTIALS,
            description="Advanced password recovery",
            packages={"debian": "hashcat", "redhat": "hashcat", "arch": "hashcat", "fedora": "hashcat"},
        ),
        "john": ToolDefinition(
            name="john",
            category=ToolCategory.CREDENTIALS,
            description="John the Ripper password cracker",
            packages={"debian": "john", "redhat": "john", "arch": "john", "fedora": "john"},
        ),
        "hydra": ToolDefinition(
            name="hydra",
            category=ToolCategory.CREDENTIALS,
            description="Network login cracker",
            packages={"debian": "hydra", "redhat": "hydra", "arch": "hydra", "fedora": "hydra"},
        ),
        "medusa": ToolDefinition(
            name="medusa",
            category=ToolCategory.CREDENTIALS,
            description="Parallel password cracker",
            packages={"debian": "medusa", "redhat": "medusa", "arch": "medusa", "fedora": "medusa"},
        ),
        "ncrack": ToolDefinition(
            name="ncrack",
            category=ToolCategory.CREDENTIALS,
            description="Network authentication cracker",
            packages={"debian": "ncrack", "arch": "ncrack"},
        ),
        "cewl": ToolDefinition(
            name="cewl",
            category=ToolCategory.CREDENTIALS,
            description="Custom wordlist generator",
            packages={"debian": "cewl", "arch": "cewl"},
        ),
        "crunch": ToolDefinition(
            name="crunch",
            category=ToolCategory.CREDENTIALS,
            description="Wordlist generator",
            packages={"debian": "crunch", "arch": "crunch"},
        ),
        "ophcrack": ToolDefinition(
            name="ophcrack",
            category=ToolCategory.CREDENTIALS,
            description="Windows password cracker",
            packages={"debian": "ophcrack", "arch": "ophcrack"},
        ),
        "mimikatz": ToolDefinition(
            name="mimikatz",
            category=ToolCategory.CREDENTIALS,
            description="Windows credential extraction",
            packages={},
            url="https://github.com/gentilkiwi/mimikatz",
        ),
        "responder": ToolDefinition(
            name="responder",
            category=ToolCategory.CREDENTIALS,
            description="LLMNR/NBT-NS/mDNS poisoner",
            packages={"debian": "responder", "arch": "responder"},
            requires_root=True,
        ),
        "secretsdump.py": ToolDefinition(
            name="secretsdump.py",
            category=ToolCategory.CREDENTIALS,
            description="SAM/NTDS.dit extraction",
            packages={"debian": "impacket-scripts", "arch": "impacket"},
        ),

        # ========== OSINT ==========
        "theHarvester": ToolDefinition(
            name="theHarvester",
            category=ToolCategory.OSINT,
            description="Email and subdomain harvester",
            packages={"debian": "theharvester", "arch": "theharvester"},
            pip_package="theHarvester",
            binary_names=["theHarvester", "theharvester", "theHarvester.py"],
        ),
        "whois": ToolDefinition(
            name="whois",
            category=ToolCategory.OSINT,
            description="Domain registration lookup",
            packages={"debian": "whois", "redhat": "whois", "arch": "whois", "fedora": "whois"},
        ),
        "dnsrecon": ToolDefinition(
            name="dnsrecon",
            category=ToolCategory.OSINT,
            description="DNS enumeration",
            packages={"debian": "dnsrecon", "arch": "dnsrecon"},
        ),
        "dnsenum": ToolDefinition(
            name="dnsenum",
            category=ToolCategory.OSINT,
            description="DNS enumeration tool",
            packages={"debian": "dnsenum", "arch": "dnsenum"},
        ),
        "sublist3r": ToolDefinition(
            name="sublist3r",
            category=ToolCategory.OSINT,
            description="Subdomain enumeration",
            packages={"debian": "sublist3r", "arch": "sublist3r"},
        ),
        "amass": ToolDefinition(
            name="amass",
            category=ToolCategory.OSINT,
            description="Attack surface mapping",
            packages={"debian": "amass", "arch": "amass"},
        ),
        "maltego": ToolDefinition(
            name="maltego",
            category=ToolCategory.OSINT,
            description="Interactive data mining",
            packages={"debian": "maltego"},
        ),
        "spiderfoot": ToolDefinition(
            name="spiderfoot",
            category=ToolCategory.OSINT,
            description="OSINT automation",
            packages={"debian": "spiderfoot", "arch": "spiderfoot"},
        ),
        "shodan": ToolDefinition(
            name="shodan",
            category=ToolCategory.OSINT,
            description="Shodan CLI",
            packages={"debian": "shodan"},
            pip_package="shodan",
        ),
        "recon-ng": ToolDefinition(
            name="recon-ng",
            category=ToolCategory.OSINT,
            description="Web reconnaissance framework",
            packages={"debian": "recon-ng", "arch": "recon-ng"},
        ),
        "exiftool": ToolDefinition(
            name="exiftool",
            category=ToolCategory.OSINT,
            description="Metadata extraction",
            packages={"debian": "libimage-exiftool-perl", "redhat": "perl-Image-ExifTool", "arch": "perl-image-exiftool", "fedora": "perl-Image-ExifTool"},
        ),
        "metagoofil": ToolDefinition(
            name="metagoofil",
            category=ToolCategory.OSINT,
            description="Metadata extractor",
            packages={"debian": "metagoofil", "arch": "metagoofil"},
        ),

        # ========== RECON ==========
        "nikto": ToolDefinition(
            name="nikto",
            category=ToolCategory.RECON,
            description="Web server scanner",
            packages={"debian": "nikto", "redhat": "nikto", "arch": "nikto", "fedora": "nikto"},
        ),
        "whatweb": ToolDefinition(
            name="whatweb",
            category=ToolCategory.RECON,
            description="Web technology fingerprinting",
            packages={"debian": "whatweb", "arch": "whatweb"},
        ),
        "dirb": ToolDefinition(
            name="dirb",
            category=ToolCategory.RECON,
            description="Web content scanner",
            packages={"debian": "dirb", "arch": "dirb"},
        ),
        "gobuster": ToolDefinition(
            name="gobuster",
            category=ToolCategory.RECON,
            description="Directory/DNS/VHost busting",
            packages={"debian": "gobuster", "arch": "gobuster"},
        ),
        "feroxbuster": ToolDefinition(
            name="feroxbuster",
            category=ToolCategory.RECON,
            description="Fast content discovery",
            packages={"arch": "feroxbuster"},
            url="https://github.com/epi052/feroxbuster",
        ),
        "ffuf": ToolDefinition(
            name="ffuf",
            category=ToolCategory.RECON,
            description="Fast web fuzzer",
            packages={"debian": "ffuf", "arch": "ffuf"},
        ),
        "wfuzz": ToolDefinition(
            name="wfuzz",
            category=ToolCategory.RECON,
            description="Web application fuzzer",
            packages={"debian": "wfuzz", "arch": "wfuzz"},
        ),
        "wpscan": ToolDefinition(
            name="wpscan",
            category=ToolCategory.RECON,
            description="WordPress vulnerability scanner",
            packages={"debian": "wpscan", "arch": "wpscan"},
        ),
        "joomscan": ToolDefinition(
            name="joomscan",
            category=ToolCategory.RECON,
            description="Joomla vulnerability scanner",
            packages={"debian": "joomscan", "arch": "joomscan"},
        ),
        "wafw00f": ToolDefinition(
            name="wafw00f",
            category=ToolCategory.RECON,
            description="WAF fingerprinting",
            packages={"debian": "wafw00f", "arch": "wafw00f"},
        ),
        "sslyze": ToolDefinition(
            name="sslyze",
            category=ToolCategory.RECON,
            description="SSL/TLS scanner",
            packages={"debian": "sslyze", "arch": "sslyze"},
        ),
        "sslscan": ToolDefinition(
            name="sslscan",
            category=ToolCategory.RECON,
            description="SSL cipher scanner",
            packages={"debian": "sslscan", "redhat": "sslscan", "arch": "sslscan", "fedora": "sslscan"},
        ),

        # ========== TRAFFIC ==========
        "tcpdump": ToolDefinition(
            name="tcpdump",
            category=ToolCategory.TRAFFIC,
            description="Command-line packet analyzer",
            packages={"debian": "tcpdump", "redhat": "tcpdump", "arch": "tcpdump", "fedora": "tcpdump"},
            requires_root=True,
        ),
        "tshark": ToolDefinition(
            name="tshark",
            category=ToolCategory.TRAFFIC,
            description="Terminal-based Wireshark",
            packages={"debian": "tshark", "redhat": "wireshark-cli", "arch": "wireshark-cli", "fedora": "wireshark-cli"},
            requires_root=True,
        ),
        "wireshark": ToolDefinition(
            name="wireshark",
            category=ToolCategory.TRAFFIC,
            description="Network protocol analyzer",
            packages={"debian": "wireshark", "redhat": "wireshark", "arch": "wireshark-qt", "fedora": "wireshark"},
        ),
        "ettercap": ToolDefinition(
            name="ettercap",
            category=ToolCategory.TRAFFIC,
            description="MITM attack suite",
            packages={"debian": "ettercap-text-only", "redhat": "ettercap", "arch": "ettercap", "fedora": "ettercap"},
            requires_root=True,
        ),
        "bettercap": ToolDefinition(
            name="bettercap",
            category=ToolCategory.TRAFFIC,
            description="Swiss army knife for network attacks",
            packages={"debian": "bettercap", "arch": "bettercap"},
            requires_root=True,
        ),
        "arpspoof": ToolDefinition(
            name="arpspoof",
            category=ToolCategory.TRAFFIC,
            description="ARP spoofing",
            packages={"debian": "dsniff", "arch": "dsniff"},
            requires_root=True,
        ),
        "mitmproxy": ToolDefinition(
            name="mitmproxy",
            category=ToolCategory.TRAFFIC,
            description="Interactive HTTPS proxy",
            packages={"debian": "mitmproxy", "arch": "mitmproxy"},
        ),
        "dnsspoof": ToolDefinition(
            name="dnsspoof",
            category=ToolCategory.TRAFFIC,
            description="DNS spoofing",
            packages={"debian": "dsniff", "arch": "dsniff"},
            requires_root=True,
        ),
        "sslstrip": ToolDefinition(
            name="sslstrip",
            category=ToolCategory.TRAFFIC,
            description="HTTPS downgrade attacks",
            packages={"debian": "sslstrip", "arch": "sslstrip"},
            requires_root=True,
        ),
        "scapy": ToolDefinition(
            name="scapy",
            category=ToolCategory.TRAFFIC,
            description="Packet manipulation library",
            packages={"debian": "python3-scapy", "redhat": "python3-scapy", "arch": "scapy", "fedora": "python3-scapy"},
        ),
        "netcat": ToolDefinition(
            name="nc",
            category=ToolCategory.TRAFFIC,
            description="Network utility",
            packages={"debian": "netcat-traditional", "redhat": "nmap-ncat", "arch": "gnu-netcat", "fedora": "nmap-ncat"},
        ),
        "socat": ToolDefinition(
            name="socat",
            category=ToolCategory.TRAFFIC,
            description="Multipurpose relay",
            packages={"debian": "socat", "redhat": "socat", "arch": "socat", "fedora": "socat"},
        ),

        # ========== EXPLOIT ==========
        "msfconsole": ToolDefinition(
            name="msfconsole",
            category=ToolCategory.EXPLOIT,
            description="Metasploit Framework",
            packages={"debian": "metasploit-framework", "arch": "metasploit"},
        ),
        "searchsploit": ToolDefinition(
            name="searchsploit",
            category=ToolCategory.EXPLOIT,
            description="Exploit-DB search",
            packages={"debian": "exploitdb", "arch": "exploitdb"},
        ),
        "sqlmap": ToolDefinition(
            name="sqlmap",
            category=ToolCategory.EXPLOIT,
            description="SQL injection automation",
            packages={"debian": "sqlmap", "redhat": "sqlmap", "arch": "sqlmap", "fedora": "sqlmap"},
        ),
        "nuclei": ToolDefinition(
            name="nuclei",
            category=ToolCategory.EXPLOIT,
            description="Vulnerability scanner",
            packages={"arch": "nuclei"},
            url="https://github.com/projectdiscovery/nuclei",
        ),
        "commix": ToolDefinition(
            name="commix",
            category=ToolCategory.EXPLOIT,
            description="Command injection exploiter",
            packages={"debian": "commix", "arch": "commix"},
        ),
        "beef-xss": ToolDefinition(
            name="beef-xss",
            category=ToolCategory.EXPLOIT,
            description="Browser exploitation framework",
            packages={"debian": "beef-xss", "arch": "beef"},
        ),
        "evil-winrm": ToolDefinition(
            name="evil-winrm",
            category=ToolCategory.EXPLOIT,
            description="Windows Remote Management shell",
            packages={"debian": "evil-winrm", "arch": "evil-winrm"},
        ),
        "crackmapexec": ToolDefinition(
            name="crackmapexec",
            category=ToolCategory.EXPLOIT,
            description="Network protocol attack tool",
            packages={"debian": "crackmapexec", "arch": "crackmapexec"},
        ),
        "empire": ToolDefinition(
            name="empire",
            category=ToolCategory.EXPLOIT,
            description="Post-exploitation framework",
            packages={},
            url="https://github.com/BC-SECURITY/Empire",
        ),
        "covenant": ToolDefinition(
            name="covenant",
            category=ToolCategory.EXPLOIT,
            description=".NET C2 framework",
            packages={},
            url="https://github.com/cobbr/Covenant",
        ),

        # ========== STRESS ==========
        "hping3": ToolDefinition(
            name="hping3",
            category=ToolCategory.STRESS,
            description="TCP/IP packet assembler",
            packages={"debian": "hping3", "redhat": "hping3", "arch": "hping", "fedora": "hping3"},
            requires_root=True,
        ),
        "iperf3": ToolDefinition(
            name="iperf3",
            category=ToolCategory.STRESS,
            description="Network bandwidth testing",
            packages={"debian": "iperf3", "redhat": "iperf3", "arch": "iperf3", "fedora": "iperf3"},
        ),
        "slowloris": ToolDefinition(
            name="slowloris",
            category=ToolCategory.STRESS,
            description="Low bandwidth DoS tool",
            packages={"debian": "slowloris", "arch": "slowloris"},
        ),
        "siege": ToolDefinition(
            name="siege",
            category=ToolCategory.STRESS,
            description="HTTP load testing",
            packages={"debian": "siege", "redhat": "siege", "arch": "siege", "fedora": "siege"},
        ),
        "ab": ToolDefinition(
            name="ab",
            category=ToolCategory.STRESS,
            description="Apache benchmark",
            packages={"debian": "apache2-utils", "redhat": "httpd-tools", "arch": "apache", "fedora": "httpd-tools"},
        ),

        # ========== UTILITY ==========
        "curl": ToolDefinition(
            name="curl",
            category=ToolCategory.UTILITY,
            description="URL transfer tool",
            packages={"debian": "curl", "redhat": "curl", "arch": "curl", "fedora": "curl"},
        ),
        "wget": ToolDefinition(
            name="wget",
            category=ToolCategory.UTILITY,
            description="Non-interactive downloader",
            packages={"debian": "wget", "redhat": "wget", "arch": "wget", "fedora": "wget"},
        ),
        "git": ToolDefinition(
            name="git",
            category=ToolCategory.UTILITY,
            description="Version control",
            packages={"debian": "git", "redhat": "git", "arch": "git", "fedora": "git"},
        ),
        "python3": ToolDefinition(
            name="python3",
            category=ToolCategory.UTILITY,
            description="Python interpreter",
            packages={"debian": "python3", "redhat": "python3", "arch": "python", "fedora": "python3"},
        ),
        "pip3": ToolDefinition(
            name="pip3",
            category=ToolCategory.UTILITY,
            description="Python package manager",
            packages={"debian": "python3-pip", "redhat": "python3-pip", "arch": "python-pip", "fedora": "python3-pip"},
        ),
        "proxychains": ToolDefinition(
            name="proxychains",
            category=ToolCategory.UTILITY,
            description="Proxy chain redirector",
            packages={"debian": "proxychains4", "redhat": "proxychains-ng", "arch": "proxychains-ng", "fedora": "proxychains-ng"},
        ),
        "tor": ToolDefinition(
            name="tor",
            category=ToolCategory.UTILITY,
            description="Anonymity network",
            packages={"debian": "tor", "redhat": "tor", "arch": "tor", "fedora": "tor"},
        ),
        "openvpn": ToolDefinition(
            name="openvpn",
            category=ToolCategory.UTILITY,
            description="VPN client",
            packages={"debian": "openvpn", "redhat": "openvpn", "arch": "openvpn", "fedora": "openvpn"},
        ),
        "tmux": ToolDefinition(
            name="tmux",
            category=ToolCategory.UTILITY,
            description="Terminal multiplexer",
            packages={"debian": "tmux", "redhat": "tmux", "arch": "tmux", "fedora": "tmux"},
        ),
        "screen": ToolDefinition(
            name="screen",
            category=ToolCategory.UTILITY,
            description="Terminal multiplexer",
            packages={"debian": "screen", "redhat": "screen", "arch": "screen", "fedora": "screen"},
        ),
    }

    # Legacy format for backwards compatibility
    TOOLS = {
        name: defn.packages
        for name, defn in TOOL_DEFINITIONS.items()
    }

    def __init__(self) -> None:
        self._cache: dict[str, ToolInfo] = {}
        self._distro: DistroFamily | None = None
        self._package_manager: PackageManager | None = None

    @property
    def distro(self) -> DistroFamily:
        """Get detected distro (cached)."""
        if self._distro is None:
            self._distro = detect_distro()
        return self._distro

    @property
    def package_manager(self) -> PackageManager:
        """Get detected package manager (cached)."""
        if self._package_manager is None:
            self._package_manager = detect_package_manager()
        return self._package_manager

    def check(self, name: str) -> ToolInfo:
        """Check if a tool is available."""
        if name not in self._cache:
            defn = self.TOOL_DEFINITIONS.get(name)
            if defn:
                # Use the binary name from definition, not the registry key
                self._cache[name] = ToolInfo.detect(
                    defn.name,
                    version_flag=defn.version_flag,
                    category=defn.category,
                    description=defn.description,
                    requires_root=defn.requires_root,
                    binary_names=defn.binary_names if defn.binary_names else None,
                )
            else:
                self._cache[name] = ToolInfo.detect(name)
        return self._cache[name]

    def require(self, *names: str) -> dict[str, ToolInfo]:
        """Require multiple tools, raising if any missing."""
        results = {}
        missing = []

        for name in names:
            info = self.check(name)
            results[name] = info
            if not info.available:
                missing.append(name)

        if missing:
            raise ToolNotFoundError(
                f"Required tools not found: {', '.join(missing)}",
                details={"missing": missing},
            )

        return results

    def get_path(self, name: str) -> Path:
        """Get path to tool, raising if not found."""
        info = self.check(name)
        if not info.available or info.path is None:
            raise ToolNotFoundError(f"Tool not found: {name}")
        return info.path

    def check_all(self) -> dict[str, ToolInfo]:
        """Check all registered tools."""
        for name in self.TOOL_DEFINITIONS:
            self.check(name)
        return self._cache.copy()

    def clear_cache(self) -> None:
        """Clear the detection cache."""
        self._cache.clear()

    # --------------------------------------------------------------------------
    # Category Methods
    # --------------------------------------------------------------------------

    def get_categories(self) -> list[ToolCategory]:
        """Get all tool categories."""
        return list(ToolCategory)

    def get_tools_in_category(self, category: ToolCategory) -> list[str]:
        """Get all tool names in a category."""
        return [
            name
            for name, defn in self.TOOL_DEFINITIONS.items()
            if defn.category == category
        ]

    def get_category_status(self, category: ToolCategory) -> dict:
        """Get status summary for a category.

        Returns:
            Dict with installed, missing, and total counts
        """
        tools = self.get_tools_in_category(category)
        installed = 0
        missing = 0

        for name in tools:
            info = self.check(name)
            if info.available:
                installed += 1
            else:
                missing += 1

        return {
            "category": category.value,
            "installed": installed,
            "missing": missing,
            "total": len(tools),
        }

    def get_all_category_status(self) -> list[dict]:
        """Get status for all categories."""
        return [self.get_category_status(cat) for cat in ToolCategory]

    def get_missing_tools(self, category: ToolCategory | None = None) -> list[str]:
        """Get list of missing tools.

        Args:
            category: Optional category filter

        Returns:
            List of tool names that are not installed
        """
        if category:
            tools = self.get_tools_in_category(category)
        else:
            tools = list(self.TOOL_DEFINITIONS.keys())

        return [name for name in tools if not self.check(name).available]

    def get_installed_tools(self, category: ToolCategory | None = None) -> list[str]:
        """Get list of installed tools.

        Args:
            category: Optional category filter

        Returns:
            List of tool names that are installed
        """
        if category:
            tools = self.get_tools_in_category(category)
        else:
            tools = list(self.TOOL_DEFINITIONS.keys())

        return [name for name in tools if self.check(name).available]

    # --------------------------------------------------------------------------
    # Installation Methods
    # --------------------------------------------------------------------------

    def get_package_name(self, tool_name: str) -> str | None:
        """Get the package name for a tool on the current distro.

        Args:
            tool_name: Name of the tool

        Returns:
            Package name or None if not available for this distro
        """
        defn = self.TOOL_DEFINITIONS.get(tool_name)
        if not defn:
            return None

        # Try distro-specific package
        distro_key = self.distro.value
        if distro_key in defn.packages:
            return defn.packages[distro_key]

        # Fedora falls back to redhat
        if self.distro == DistroFamily.FEDORA and "redhat" in defn.packages:
            return defn.packages["redhat"]

        # Try debian as fallback (Kali, Ubuntu, etc.)
        if "debian" in defn.packages:
            return defn.packages["debian"]

        return None

    def get_install_command(self, tool_name: str) -> list[str] | None:
        """Get the install command for a tool.

        Args:
            tool_name: Name of the tool

        Returns:
            Command list or None if not installable via package manager
        """
        package = self.get_package_name(tool_name)
        if not package:
            return None

        pm = self.package_manager

        if pm == PackageManager.APT:
            return ["sudo", "apt-get", "install", "-y", package]
        elif pm == PackageManager.DNF:
            return ["sudo", "dnf", "install", "-y", package]
        elif pm == PackageManager.YUM:
            return ["sudo", "yum", "install", "-y", package]
        elif pm == PackageManager.PACMAN:
            return ["sudo", "pacman", "-S", "--noconfirm", package]
        elif pm == PackageManager.ZYPPER:
            return ["sudo", "zypper", "install", "-y", package]

        return None

    async def install_tool(
        self,
        tool_name: str,
        callback: callable | None = None,
    ) -> tuple[bool, str]:
        """Install a tool using the system package manager or pip.

        Args:
            tool_name: Name of the tool to install
            callback: Optional callback for progress updates (line: str)

        Returns:
            Tuple of (success, message)
        """
        defn = self.TOOL_DEFINITIONS.get(tool_name)

        # Try package manager first
        cmd = self.get_install_command(tool_name)
        if cmd:
            logger.info(f"Installing {tool_name} via package manager: {' '.join(cmd)}")
            success, msg = await self._run_install_cmd(cmd, tool_name, callback)
            if success:
                return success, msg
            # Package manager failed, try pip fallback if available
            logger.warning(f"Package manager install failed for {tool_name}, trying pip...")

        # Try pip installation if pip_package is defined
        if defn and defn.pip_package:
            pip_cmd = await self._get_pip_install_command(defn.pip_package)
            if pip_cmd:
                logger.info(f"Installing {tool_name} via pip: {' '.join(pip_cmd)}")
                success, msg = await self._run_install_cmd(pip_cmd, tool_name, callback)
                if success:
                    return success, msg

        # No install method available
        if defn and defn.url:
            return False, f"Manual install required: {defn.url}"
        return False, f"No package available for {tool_name} on {self.distro.value}"

    async def _get_pip_install_command(self, package: str) -> list[str] | None:
        """Get pip/pipx install command for a package.

        Prefers pipx for CLI tools (isolated environments), falls back to pip.
        """
        # Prefer pipx for CLI tools
        pipx_cmd = shutil.which("pipx")
        if pipx_cmd:
            return [pipx_cmd, "install", package]

        # Fall back to pip
        pip_cmd = shutil.which("pip3") or shutil.which("pip")
        if pip_cmd:
            return [pip_cmd, "install", "--user", package]

        return None

    async def _run_install_cmd(
        self,
        cmd: list[str],
        tool_name: str,
        callback: callable | None = None,
    ) -> tuple[bool, str]:
        """Run an install command and verify success."""
        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
            )

            # Stream output
            while True:
                line = await process.stdout.readline()
                if not line:
                    break
                decoded = line.decode().strip()
                if callback:
                    callback(decoded)
                logger.debug(f"Install output: {decoded}")

            await process.wait()

            # Clear cache and recheck
            if tool_name in self._cache:
                del self._cache[tool_name]

            info = self.check(tool_name)

            if info.available:
                logger.info(f"Successfully installed {tool_name}")
                return True, f"Successfully installed {tool_name}"
            else:
                return False, f"Installation completed but {tool_name} not found in PATH"

        except Exception as e:
            logger.error(f"Failed to install {tool_name}: {e}")
            return False, f"Installation failed: {e}"

    async def install_tools(
        self,
        tool_names: list[str],
        callback: callable | None = None,
    ) -> dict[str, tuple[bool, str]]:
        """Install multiple tools.

        Args:
            tool_names: List of tools to install
            callback: Optional callback for progress (tool: str, line: str)

        Returns:
            Dict mapping tool name to (success, message)
        """
        results = {}
        for name in tool_names:
            if callback:
                callback(name, f"Installing {name}...")

            success, msg = await self.install_tool(
                name,
                callback=lambda line: callback(name, line) if callback else None,
            )
            results[name] = (success, msg)

        return results

    # --------------------------------------------------------------------------
    # Summary Methods
    # --------------------------------------------------------------------------

    def get_summary(self) -> dict:
        """Get overall tool availability summary.

        Returns:
            Dict with total, installed, missing counts and category breakdown
        """
        self.check_all()

        total = len(self.TOOL_DEFINITIONS)
        installed = sum(1 for info in self._cache.values() if info.available)
        missing = total - installed

        return {
            "total": total,
            "installed": installed,
            "missing": missing,
            "distro": self.distro.value,
            "package_manager": self.package_manager.value,
            "categories": self.get_all_category_status(),
        }

    def get_tool_info(self, name: str) -> dict | None:
        """Get detailed info about a tool.

        Args:
            name: Tool name

        Returns:
            Dict with tool details or None if not registered
        """
        defn = self.TOOL_DEFINITIONS.get(name)
        if not defn:
            return None

        info = self.check(name)

        return {
            "name": name,
            "category": defn.category.value,
            "description": defn.description,
            "requires_root": defn.requires_root,
            "available": info.available,
            "path": str(info.path) if info.path else None,
            "version": info.version,
            "package": self.get_package_name(name),
            "url": defn.url or None,
        }


# Singleton
tool_registry = ToolRegistry()
