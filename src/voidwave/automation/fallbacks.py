"""Tool fallback management."""

import shutil
from typing import Any


# If primary fails, try these in order
FALLBACK_CHAINS: dict[str, list[str]] = {
    "nmap": ["rustscan", "masscan"],
    "aircrack-ng": ["cowpatty", "hashcat"],
    "reaver": ["bully"],
    "hashcat": ["john"],
    "wireshark": ["tshark", "tcpdump"],
    "enum4linux-ng": ["enum4linux", "smbclient"],
    "dnsenum": ["dnsrecon", "dig"],
    "sslscan": ["sslyze", "openssl"],
    "gobuster": ["ffuf", "dirsearch"],
    "subfinder": ["amass", "sublist3r"],
    "theHarvester": ["theharvester"],  # Different casing
    "nikto": ["whatweb"],
    "wpscan": ["nuclei"],
}


class FallbackManager:
    """Manages tool fallbacks when primary tools are unavailable."""

    def __init__(self) -> None:
        self.chains = FALLBACK_CHAINS.copy()

    def get_available_tool(self, primary: str) -> str | None:
        """Get the first available tool from the chain."""
        if shutil.which(primary):
            return primary

        for fallback in self.chains.get(primary, []):
            if shutil.which(fallback):
                return fallback

        return None

    def get_fallback_info(self, primary: str) -> dict[str, Any]:
        """Get detailed info about fallback capability."""
        available = self.get_available_tool(primary)
        return {
            "primary": primary,
            "primary_available": shutil.which(primary) is not None,
            "using": available,
            "is_fallback": available != primary if available else False,
            "chain": self.chains.get(primary, []),
        }

    def add_chain(self, primary: str, fallbacks: list[str]) -> None:
        """Add or update a fallback chain."""
        self.chains[primary] = fallbacks

    def get_chain(self, primary: str) -> list[str]:
        """Get the fallback chain for a tool."""
        return self.chains.get(primary, [])
