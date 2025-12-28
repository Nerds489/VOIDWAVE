"""AUTO-DATA handler for downloading data files."""

import asyncio
from pathlib import Path
from typing import Any

from voidwave.automation.labels import AUTO_REGISTRY


# Default data sources
DATA_SOURCES: dict[str, dict[str, Any]] = {
    "rockyou": {
        "url": "https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt",
        "dest": "/voidwave/wordlists/rockyou.txt",
        "size": "14M",
        "description": "Common password wordlist",
    },
    "common": {
        "url": "https://raw.githubusercontent.com/v0re/dirb/master/wordlists/common.txt",
        "dest": "/voidwave/wordlists/common.txt",
        "size": "4K",
        "description": "Common directory names",
    },
    "subdomains": {
        "url": "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-5000.txt",
        "dest": "/voidwave/wordlists/subdomains.txt",
        "size": "33K",
        "description": "Common subdomain names",
    },
}


class AutoDataHandler:
    """Handles AUTO-DATA for downloading data files."""

    def __init__(self, data_type: str = "", source_url: str = "") -> None:
        self.data_type = data_type
        self.source_url = source_url
        self.dest_path: Path | None = None

    async def can_fix(self) -> bool:
        """Check if we can download the data."""
        # Need curl or wget
        import shutil

        return shutil.which("curl") is not None or shutil.which("wget") is not None

    async def fix(self) -> bool:
        """Download the data file."""
        source = DATA_SOURCES.get(self.data_type)
        if source:
            url = source["url"]
            dest = Path(source["dest"])
        elif self.source_url:
            url = self.source_url
            dest = Path(f"/voidwave/data/{self.data_type}")
        else:
            return False

        # Create destination directory
        dest.parent.mkdir(parents=True, exist_ok=True)

        # Download
        import shutil

        if shutil.which("curl"):
            cmd = f"curl -L -o {dest} {url}"
        else:
            cmd = f"wget -O {dest} {url}"

        proc = await asyncio.create_subprocess_shell(
            cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        await proc.wait()

        if proc.returncode == 0 and dest.exists():
            self.dest_path = dest
            return True

        return False

    async def get_ui_prompt(self) -> str:
        """Get the UI prompt for this fix."""
        source = DATA_SOURCES.get(self.data_type)
        if source:
            return f"Download {self.data_type} ({source['size']}) - {source['description']}?"
        return f"Download {self.data_type}?"

    @staticmethod
    def list_available_data() -> list[dict[str, Any]]:
        """List available data sources for download."""
        result = []
        for key, source in DATA_SOURCES.items():
            result.append(
                {
                    "name": key,
                    "url": source["url"],
                    "dest": source["dest"],
                    "size": source["size"],
                    "description": source["description"],
                    "exists": Path(source["dest"]).exists(),
                }
            )
        return result


# Register the handler
AUTO_REGISTRY.register("AUTO-DATA", AutoDataHandler)
