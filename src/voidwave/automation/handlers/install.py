"""AUTO-INSTALL handler for installing missing tools."""

import asyncio
import shutil
from pathlib import Path

from voidwave.automation.labels import AUTO_REGISTRY


# Package name mapping for different distributions
PACKAGE_MAP: dict[str, dict[str, str]] = {
    "reaver": {"debian": "reaver", "arch": "reaver", "fedora": "reaver"},
    "bully": {"debian": "bully", "arch": "bully", "fedora": "bully"},
    "pixiewps": {"debian": "pixiewps", "arch": "pixiewps", "fedora": "pixiewps"},
    "wash": {"debian": "reaver", "arch": "reaver", "fedora": "reaver"},
    "hcxdumptool": {"debian": "hcxdumptool", "arch": "hcxdumptool", "fedora": "hcxdumptool"},
    "hcxtools": {"debian": "hcxtools", "arch": "hcxtools", "fedora": "hcxtools"},
    "aircrack-ng": {"debian": "aircrack-ng", "arch": "aircrack-ng", "fedora": "aircrack-ng"},
    "airodump-ng": {"debian": "aircrack-ng", "arch": "aircrack-ng", "fedora": "aircrack-ng"},
    "aireplay-ng": {"debian": "aircrack-ng", "arch": "aircrack-ng", "fedora": "aircrack-ng"},
    "hashcat": {"debian": "hashcat", "arch": "hashcat", "fedora": "hashcat"},
    "john": {"debian": "john", "arch": "john", "fedora": "john"},
    "hydra": {"debian": "hydra", "arch": "hydra", "fedora": "hydra"},
    "nmap": {"debian": "nmap", "arch": "nmap", "fedora": "nmap"},
    "masscan": {"debian": "masscan", "arch": "masscan", "fedora": "masscan"},
    "tcpdump": {"debian": "tcpdump", "arch": "tcpdump", "fedora": "tcpdump"},
    "wireshark": {"debian": "wireshark", "arch": "wireshark-qt", "fedora": "wireshark"},
    "tshark": {"debian": "tshark", "arch": "wireshark-cli", "fedora": "wireshark-cli"},
    "mdk4": {"debian": "mdk4", "arch": "mdk4", "fedora": "mdk4"},
    "hostapd": {"debian": "hostapd", "arch": "hostapd", "fedora": "hostapd"},
    "dnsmasq": {"debian": "dnsmasq", "arch": "dnsmasq", "fedora": "dnsmasq"},
    "lighttpd": {"debian": "lighttpd", "arch": "lighttpd", "fedora": "lighttpd"},
    "msfconsole": {"debian": "metasploit-framework", "arch": "metasploit", "fedora": "metasploit-framework"},
    "sqlmap": {"debian": "sqlmap", "arch": "sqlmap", "fedora": "sqlmap"},
    "nikto": {"debian": "nikto", "arch": "nikto", "fedora": "nikto"},
    "gobuster": {"debian": "gobuster", "arch": "gobuster", "fedora": "gobuster"},
    "ffuf": {"debian": "ffuf", "arch": "ffuf", "fedora": "ffuf"},
    "subfinder": {"debian": "subfinder", "arch": "subfinder", "fedora": "subfinder"},
    "amass": {"debian": "amass", "arch": "amass", "fedora": "amass"},
    "theHarvester": {"debian": "theharvester", "arch": "theharvester", "fedora": "theharvester"},
    "whatweb": {"debian": "whatweb", "arch": "whatweb", "fedora": "whatweb"},
    "whois": {"debian": "whois", "arch": "whois", "fedora": "whois"},
    "dig": {"debian": "dnsutils", "arch": "bind-tools", "fedora": "bind-utils"},
    "curl": {"debian": "curl", "arch": "curl", "fedora": "curl"},
    "hping3": {"debian": "hping3", "arch": "hping", "fedora": "hping3"},
    "iperf3": {"debian": "iperf3", "arch": "iperf3", "fedora": "iperf3"},
    "arpspoof": {"debian": "dsniff", "arch": "dsniff", "fedora": "dsniff"},
    "dnsspoof": {"debian": "dsniff", "arch": "dsniff", "fedora": "dsniff"},
    "searchsploit": {"debian": "exploitdb", "arch": "exploitdb", "fedora": "exploitdb"},
}


def _detect_distro() -> str:
    """Detect the Linux distribution family."""
    os_release = Path("/etc/os-release")
    if os_release.exists():
        content = os_release.read_text()
        content_lower = content.lower()
        if "arch" in content_lower or "manjaro" in content_lower:
            return "arch"
        elif "fedora" in content_lower or "rhel" in content_lower or "centos" in content_lower:
            return "fedora"
    return "debian"  # Default to Debian-based


def _get_package_manager() -> str | None:
    """Get the system package manager."""
    managers = ["apt", "dnf", "pacman", "zypper", "apk"]
    for pm in managers:
        if shutil.which(pm):
            return pm
    return None


class AutoInstallHandler:
    """Handles AUTO-INSTALL for missing tools."""

    def __init__(self, tool_name: str = "") -> None:
        self.tool_name = tool_name
        self.distro = _detect_distro()
        self.package_manager = _get_package_manager()

    async def can_fix(self) -> bool:
        """Check if we can install this tool."""
        return self.package_manager is not None

    async def fix(self) -> bool:
        """Install the tool."""
        if not self.tool_name:
            return False

        pkg_name = self._get_package_name()
        cmd = self._build_install_cmd(pkg_name)

        if not cmd:
            return False

        proc = await asyncio.create_subprocess_shell(
            cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        await proc.wait()

        # Verify installation
        return shutil.which(self.tool_name) is not None

    async def get_ui_prompt(self) -> str:
        """Get the UI prompt for this fix."""
        pkg_name = self._get_package_name()
        return f"Install {self.tool_name} ({pkg_name})?"

    def _get_package_name(self) -> str:
        """Get the package name for this distro."""
        tool_map = PACKAGE_MAP.get(self.tool_name, {})
        return tool_map.get(self.distro, self.tool_name)

    def _build_install_cmd(self, pkg: str) -> str | None:
        """Build the install command."""
        commands = {
            "apt": f"sudo apt-get install -y {pkg}",
            "dnf": f"sudo dnf install -y {pkg}",
            "pacman": f"sudo pacman -S --noconfirm {pkg}",
            "zypper": f"sudo zypper install -y {pkg}",
            "apk": f"sudo apk add {pkg}",
        }
        return commands.get(self.package_manager)


# Register the handler
AUTO_REGISTRY.register("AUTO-INSTALL", AutoInstallHandler)
