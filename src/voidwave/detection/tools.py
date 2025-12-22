"""Tool availability detection and path resolution."""
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Self

from voidwave.core.exceptions import ToolNotFoundError
from voidwave.core.logging import get_logger

logger = get_logger(__name__)


@dataclass
class ToolInfo:
    """Information about an external tool."""

    name: str
    path: Path | None
    version: str | None
    available: bool

    @classmethod
    def detect(cls, name: str, version_flag: str = "--version") -> Self:
        """Detect tool availability and version."""
        path = shutil.which(name)

        if path is None:
            return cls(name=name, path=None, version=None, available=False)

        # Try to get version
        version = None
        try:
            import subprocess

            result = subprocess.run(
                [path, version_flag],
                capture_output=True,
                text=True,
                timeout=5,
            )
            if result.returncode == 0:
                version = result.stdout.strip().split("\n")[0]
        except Exception:
            pass

        return cls(name=name, path=Path(path), version=version, available=True)


class ToolRegistry:
    """Registry of required and optional tools."""

    # Tool definitions with package names per distro family
    TOOLS = {
        # Wireless
        "aircrack-ng": {
            "debian": "aircrack-ng",
            "redhat": "aircrack-ng",
            "arch": "aircrack-ng",
        },
        "airodump-ng": {
            "debian": "aircrack-ng",
            "redhat": "aircrack-ng",
            "arch": "aircrack-ng",
        },
        "aireplay-ng": {
            "debian": "aircrack-ng",
            "redhat": "aircrack-ng",
            "arch": "aircrack-ng",
        },
        "airmon-ng": {
            "debian": "aircrack-ng",
            "redhat": "aircrack-ng",
            "arch": "aircrack-ng",
        },
        "hostapd": {"debian": "hostapd", "redhat": "hostapd", "arch": "hostapd"},
        "dnsmasq": {"debian": "dnsmasq", "redhat": "dnsmasq", "arch": "dnsmasq"},
        "reaver": {"debian": "reaver", "redhat": "reaver", "arch": "reaver"},
        "bully": {"debian": "bully", "redhat": "bully", "arch": "bully"},
        "hcxdumptool": {
            "debian": "hcxdumptool",
            "redhat": "hcxdumptool",
            "arch": "hcxdumptool",
        },
        "hcxpcapngtool": {
            "debian": "hcxtools",
            "redhat": "hcxtools",
            "arch": "hcxtools",
        },
        # Scanning
        "nmap": {"debian": "nmap", "redhat": "nmap", "arch": "nmap"},
        "masscan": {"debian": "masscan", "redhat": "masscan", "arch": "masscan"},
        "rustscan": {"debian": "rustscan", "redhat": "rustscan", "arch": "rustscan"},
        # Credentials
        "hashcat": {"debian": "hashcat", "redhat": "hashcat", "arch": "hashcat"},
        "john": {"debian": "john", "redhat": "john", "arch": "john"},
        "hydra": {"debian": "hydra", "redhat": "hydra", "arch": "hydra"},
        "medusa": {"debian": "medusa", "redhat": "medusa", "arch": "medusa"},
        # Network
        "tcpdump": {"debian": "tcpdump", "redhat": "tcpdump", "arch": "tcpdump"},
        "tshark": {
            "debian": "tshark",
            "redhat": "wireshark-cli",
            "arch": "wireshark-cli",
        },
        "ettercap": {
            "debian": "ettercap-text-only",
            "redhat": "ettercap",
            "arch": "ettercap",
        },
        "bettercap": {"debian": "bettercap", "redhat": "bettercap", "arch": "bettercap"},
        # OSINT
        "theHarvester": {
            "debian": "theharvester",
            "redhat": "theharvester",
            "arch": "theharvester",
        },
        "whois": {"debian": "whois", "redhat": "whois", "arch": "whois"},
        # Exploitation
        "msfconsole": {
            "debian": "metasploit-framework",
            "redhat": "metasploit",
            "arch": "metasploit",
        },
        "searchsploit": {
            "debian": "exploitdb",
            "redhat": "exploitdb",
            "arch": "exploitdb",
        },
        "sqlmap": {"debian": "sqlmap", "redhat": "sqlmap", "arch": "sqlmap"},
        "nuclei": {"debian": "nuclei", "redhat": "nuclei", "arch": "nuclei"},
        # Stress
        "hping3": {"debian": "hping3", "redhat": "hping3", "arch": "hping"},
        "iperf3": {"debian": "iperf3", "redhat": "iperf3", "arch": "iperf3"},
    }

    def __init__(self) -> None:
        self._cache: dict[str, ToolInfo] = {}

    def check(self, name: str) -> ToolInfo:
        """Check if a tool is available."""
        if name not in self._cache:
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
        for name in self.TOOLS:
            self.check(name)
        return self._cache.copy()


# Singleton
tool_registry = ToolRegistry()
