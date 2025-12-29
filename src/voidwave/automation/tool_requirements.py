"""Tool requirements configuration - defines what each tool needs to run."""

from dataclasses import dataclass, field
from typing import Any

from voidwave.automation.fallbacks import FALLBACK_CHAINS


@dataclass
class ToolRequirement:
    """Requirements for a specific tool."""

    # Tool binary name
    tool: str

    # Whether root is required
    needs_root: bool = False

    # Package name (if different from tool name)
    package: str = ""

    # What the tool needs as input
    needs_target: bool = False
    target_type: str = "ip"  # ip, cidr, url, domain, bssid, mac

    # Interface requirements
    needs_interface: bool = False
    interface_type: str = ""  # wireless, monitor, wired

    # API key requirements
    needs_api_key: str = ""  # Service name like "shodan", "censys"

    # File requirements
    needs_wordlist: bool = False
    needs_capture_file: bool = False

    # Other requirements
    needs_network: bool = True  # Most tools need network
    needs_gpu: bool = False  # For hashcat

    # Fallback tools if this one isn't available
    fallbacks: list[str] = field(default_factory=list)

    # Description for UI
    description: str = ""


# Tool requirements registry
TOOL_REQUIREMENTS: dict[str, ToolRequirement] = {
    # === SCANNING TOOLS ===
    "nmap": ToolRequirement(
        tool="nmap",
        needs_root=True,  # For SYN scans, OS detection
        needs_target=True,
        target_type="cidr",
        fallbacks=["rustscan", "masscan"],
        description="Network scanner",
    ),
    "rustscan": ToolRequirement(
        tool="rustscan",
        needs_target=True,
        target_type="cidr",
        fallbacks=["nmap", "masscan"],
        description="Fast port scanner",
    ),
    "masscan": ToolRequirement(
        tool="masscan",
        needs_root=True,
        needs_target=True,
        target_type="cidr",
        fallbacks=["nmap", "rustscan"],
        description="Mass IP port scanner",
    ),

    # === WIRELESS TOOLS ===
    "airodump-ng": ToolRequirement(
        tool="airodump-ng",
        package="aircrack-ng",
        needs_root=True,
        needs_interface=True,
        interface_type="monitor",
        description="Wireless network scanner",
    ),
    "aireplay-ng": ToolRequirement(
        tool="aireplay-ng",
        package="aircrack-ng",
        needs_root=True,
        needs_interface=True,
        interface_type="monitor",
        needs_target=True,
        target_type="bssid",
        description="Wireless packet injector",
    ),
    "aircrack-ng": ToolRequirement(
        tool="aircrack-ng",
        needs_capture_file=True,
        needs_wordlist=True,
        description="WPA/WPA2 password cracker",
    ),
    "airmon-ng": ToolRequirement(
        tool="airmon-ng",
        package="aircrack-ng",
        needs_root=True,
        needs_interface=True,
        interface_type="wireless",
        description="Monitor mode manager",
    ),
    "reaver": ToolRequirement(
        tool="reaver",
        needs_root=True,
        needs_interface=True,
        interface_type="monitor",
        needs_target=True,
        target_type="bssid",
        fallbacks=["bully"],
        description="WPS attack tool",
    ),
    "bully": ToolRequirement(
        tool="bully",
        needs_root=True,
        needs_interface=True,
        interface_type="monitor",
        needs_target=True,
        target_type="bssid",
        fallbacks=["reaver"],
        description="WPS brute force",
    ),
    "hcxdumptool": ToolRequirement(
        tool="hcxdumptool",
        needs_root=True,
        needs_interface=True,
        interface_type="monitor",
        description="PMKID capture tool",
    ),
    "wash": ToolRequirement(
        tool="wash",
        package="reaver",
        needs_root=True,
        needs_interface=True,
        interface_type="monitor",
        description="WPS-enabled network scanner",
    ),

    # === CREDENTIAL ATTACKS ===
    "hashcat": ToolRequirement(
        tool="hashcat",
        needs_wordlist=True,
        needs_gpu=True,
        fallbacks=["john"],
        description="GPU password cracker",
    ),
    "john": ToolRequirement(
        tool="john",
        package="john-the-ripper",
        needs_wordlist=True,
        fallbacks=["hashcat"],
        description="Password cracker",
    ),
    "hydra": ToolRequirement(
        tool="hydra",
        needs_target=True,
        target_type="ip",
        needs_wordlist=True,
        description="Network login cracker",
    ),
    "medusa": ToolRequirement(
        tool="medusa",
        needs_target=True,
        target_type="ip",
        needs_wordlist=True,
        fallbacks=["hydra"],
        description="Network authentication cracker",
    ),

    # === RECON TOOLS ===
    "subfinder": ToolRequirement(
        tool="subfinder",
        needs_target=True,
        target_type="domain",
        fallbacks=["amass", "sublist3r"],
        description="Subdomain finder",
    ),
    "amass": ToolRequirement(
        tool="amass",
        needs_target=True,
        target_type="domain",
        fallbacks=["subfinder"],
        description="Attack surface mapper",
    ),
    "theHarvester": ToolRequirement(
        tool="theHarvester",
        needs_target=True,
        target_type="domain",
        description="Email and subdomain harvester",
    ),
    "dnsenum": ToolRequirement(
        tool="dnsenum",
        needs_target=True,
        target_type="domain",
        fallbacks=["dnsrecon", "dig"],
        description="DNS enumeration",
    ),

    # === WEB TOOLS ===
    "gobuster": ToolRequirement(
        tool="gobuster",
        needs_target=True,
        target_type="url",
        needs_wordlist=True,
        fallbacks=["ffuf", "dirsearch"],
        description="Directory/file brute forcer",
    ),
    "ffuf": ToolRequirement(
        tool="ffuf",
        needs_target=True,
        target_type="url",
        needs_wordlist=True,
        fallbacks=["gobuster"],
        description="Fast web fuzzer",
    ),
    "nikto": ToolRequirement(
        tool="nikto",
        needs_target=True,
        target_type="url",
        description="Web server scanner",
    ),
    "wpscan": ToolRequirement(
        tool="wpscan",
        needs_target=True,
        target_type="url",
        needs_api_key="wpscan",
        description="WordPress vulnerability scanner",
    ),
    "sqlmap": ToolRequirement(
        tool="sqlmap",
        needs_target=True,
        target_type="url",
        description="SQL injection tool",
    ),
    "nuclei": ToolRequirement(
        tool="nuclei",
        needs_target=True,
        target_type="url",
        description="Vulnerability scanner",
    ),

    # === EXPLOITATION ===
    "msfconsole": ToolRequirement(
        tool="msfconsole",
        package="metasploit-framework",
        needs_target=True,
        target_type="ip",
        description="Metasploit Framework",
    ),
    "searchsploit": ToolRequirement(
        tool="searchsploit",
        package="exploitdb",
        description="Exploit database search",
    ),

    # === TRAFFIC ANALYSIS ===
    "tcpdump": ToolRequirement(
        tool="tcpdump",
        needs_root=True,
        needs_interface=True,
        interface_type="all",
        fallbacks=["tshark"],
        description="Packet capture",
    ),
    "tshark": ToolRequirement(
        tool="tshark",
        package="wireshark",
        needs_root=True,
        needs_interface=True,
        interface_type="all",
        fallbacks=["tcpdump"],
        description="Terminal Wireshark",
    ),
    "wireshark": ToolRequirement(
        tool="wireshark",
        needs_root=True,
        description="Network protocol analyzer",
    ),

    # === OSINT ===
    "shodan": ToolRequirement(
        tool="shodan",
        needs_api_key="shodan",
        needs_target=True,
        target_type="ip",
        description="Shodan search",
    ),

    # === STRESS TESTING ===
    "hping3": ToolRequirement(
        tool="hping3",
        needs_root=True,
        needs_target=True,
        target_type="ip",
        description="Packet crafting tool",
    ),

    # === ENUMERATION ===
    "enum4linux-ng": ToolRequirement(
        tool="enum4linux-ng",
        needs_target=True,
        target_type="ip",
        fallbacks=["enum4linux", "smbclient"],
        description="Windows/Samba enumeration",
    ),
    "smbclient": ToolRequirement(
        tool="smbclient",
        needs_target=True,
        target_type="ip",
        description="SMB/CIFS client",
    ),
}


def get_tool_requirements(tool: str) -> ToolRequirement | None:
    """Get requirements for a tool."""
    return TOOL_REQUIREMENTS.get(tool)


def get_fallback_tool(tool: str) -> str | None:
    """Get first available fallback for a tool."""
    import shutil

    req = TOOL_REQUIREMENTS.get(tool)
    if not req:
        return None

    for fallback in req.fallbacks:
        if shutil.which(fallback):
            return fallback

    return None
