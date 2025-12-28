"""AUTO-GUIDE handler for displaying manual steps."""

from typing import Any

from voidwave.automation.labels import AUTO_REGISTRY


# Guidance for common issues
GUIDES: dict[str, dict[str, Any]] = {
    "wireless_adapter": {
        "title": "Wireless Adapter Required",
        "steps": [
            "Connect a monitor-mode capable USB WiFi adapter",
            "Recommended: Alfa AWUS036ACH (dual-band)",
            "Alternative: Alfa AWUS036AXML (WiFi 6E)",
            "Install drivers if required (rtl8812au, rtl8814au)",
            "Click Rescan to detect the adapter",
        ],
        "links": [
            ("Driver installation guide", "https://github.com/aircrack-ng/rtl8812au"),
            ("Recommended adapters", "https://www.aircrack-ng.org/doku.php?id=compatible_cards"),
        ],
    },
    "gpu_hashcat": {
        "title": "GPU Required for Hashcat",
        "steps": [
            "Install GPU drivers (NVIDIA: CUDA, AMD: ROCm)",
            "For NVIDIA: sudo apt install nvidia-cuda-toolkit",
            "For AMD: Follow ROCm installation guide",
            "Verify with: hashcat -I",
        ],
        "links": [
            ("NVIDIA CUDA installation", "https://developer.nvidia.com/cuda-downloads"),
            ("AMD ROCm installation", "https://rocm.docs.amd.com/"),
        ],
    },
    "metasploit_db": {
        "title": "Metasploit Database Setup",
        "steps": [
            "Initialize database: msfdb init",
            "Start PostgreSQL: sudo systemctl start postgresql",
            "Connect in msfconsole: db_connect",
        ],
        "links": [],
    },
    "gui_tool": {
        "title": "GUI Tool Required",
        "steps": [
            "This tool requires a graphical interface",
            "Connect via VNC or X11 forwarding if remote",
            "Or use the CLI alternative if available",
        ],
        "links": [],
    },
    "hostapd_wpe": {
        "title": "hostapd-wpe Installation",
        "steps": [
            "Clone the repository: git clone https://github.com/aircrack-ng/hostapd-wpe",
            "Install dependencies: sudo apt install libssl-dev libnl-3-dev",
            "Build: cd hostapd-wpe && make",
            "Install: sudo make install",
        ],
        "links": [
            ("hostapd-wpe GitHub", "https://github.com/aircrack-ng/hostapd-wpe"),
        ],
    },
}


class AutoGuideHandler:
    """Handles AUTO-GUIDE for displaying manual steps."""

    def __init__(self, guide_type: str = "", custom_steps: list[str] | None = None) -> None:
        self.guide_type = guide_type
        self.custom_steps = custom_steps or []
        self.guide = GUIDES.get(guide_type, {})

    async def can_fix(self) -> bool:
        """Guidance is always available but doesn't fix anything."""
        return False  # Manual action required

    async def fix(self) -> bool:
        """Show guidance. Returns False as user must complete steps."""
        return False

    async def get_ui_prompt(self) -> str:
        """Get the UI prompt for this guide."""
        if self.guide:
            return self.guide.get("title", "Manual Steps Required")
        return "Manual configuration required."

    def get_steps(self) -> list[str]:
        """Get the guidance steps."""
        if self.custom_steps:
            return self.custom_steps
        return self.guide.get("steps", [])

    def get_links(self) -> list[tuple[str, str]]:
        """Get related documentation links."""
        return self.guide.get("links", [])

    def get_title(self) -> str:
        """Get the guide title."""
        return self.guide.get("title", "Manual Configuration")

    @staticmethod
    def list_guides() -> list[str]:
        """List available guide types."""
        return list(GUIDES.keys())


# Register the handler
AUTO_REGISTRY.register("AUTO-GUIDE", AutoGuideHandler)
