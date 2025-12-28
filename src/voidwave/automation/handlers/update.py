"""AUTO-UPDATE handler for refreshing data sources."""

import asyncio
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

from voidwave.automation.labels import AUTO_REGISTRY


# Update sources configuration
UPDATE_SOURCES: dict[str, dict[str, Any]] = {
    "nuclei-templates": {
        "command": "nuclei -update-templates",
        "check_cmd": "nuclei -version",
        "frequency_days": 7,
        "last_update_file": "/voidwave/data/.nuclei_updated",
        "description": "Nuclei vulnerability templates",
    },
    "exploitdb": {
        "command": "searchsploit -u",
        "check_cmd": "searchsploit -v",
        "frequency_days": 7,
        "last_update_file": "/voidwave/data/.exploitdb_updated",
        "description": "Exploit database",
    },
    "nmap-scripts": {
        "command": "nmap --script-updatedb",
        "check_cmd": "nmap --version",
        "frequency_days": 30,
        "last_update_file": "/voidwave/data/.nmap_scripts_updated",
        "description": "Nmap NSE scripts database",
    },
    "wpscan-db": {
        "command": "wpscan --update",
        "check_cmd": "wpscan --version",
        "frequency_days": 1,
        "last_update_file": "/voidwave/data/.wpscan_updated",
        "description": "WPScan vulnerability database",
    },
}


class AutoUpdateHandler:
    """Handles AUTO-UPDATE for refreshing data sources."""

    def __init__(self, source: str = "") -> None:
        self.source = source
        self.config = UPDATE_SOURCES.get(source, {})

    async def can_fix(self) -> bool:
        """Check if this source can be updated."""
        if not self.config:
            return False

        # Check if the tool exists
        import shutil

        check_cmd = self.config.get("check_cmd", "").split()[0]
        return shutil.which(check_cmd) is not None

    async def fix(self) -> bool:
        """Update the data source."""
        if not self.config:
            return False

        command = self.config.get("command")
        if not command:
            return False

        proc = await asyncio.create_subprocess_shell(
            command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        await proc.wait()

        if proc.returncode == 0:
            # Record update time
            self._record_update()
            return True

        return False

    async def get_ui_prompt(self) -> str:
        """Get the UI prompt for this update."""
        if self.config:
            desc = self.config.get("description", self.source)
            age = self._get_age_string()
            return f"Update {desc}? ({age})"
        return f"Update {self.source}?"

    def needs_update(self) -> bool:
        """Check if this source needs updating."""
        if not self.config:
            return False

        last_update = self._get_last_update()
        if last_update is None:
            return True

        frequency = self.config.get("frequency_days", 7)
        threshold = datetime.now() - timedelta(days=frequency)

        return last_update < threshold

    def _get_last_update(self) -> datetime | None:
        """Get the last update time."""
        update_file = self.config.get("last_update_file")
        if not update_file:
            return None

        path = Path(update_file)
        if path.exists():
            try:
                timestamp = float(path.read_text().strip())
                return datetime.fromtimestamp(timestamp)
            except Exception:
                pass

        return None

    def _record_update(self) -> None:
        """Record the current update time."""
        update_file = self.config.get("last_update_file")
        if not update_file:
            return

        path = Path(update_file)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(str(datetime.now().timestamp()))

    def _get_age_string(self) -> str:
        """Get a human-readable age string."""
        last_update = self._get_last_update()
        if last_update is None:
            return "never updated"

        age = datetime.now() - last_update
        if age.days > 0:
            return f"{age.days} days old"
        elif age.seconds > 3600:
            return f"{age.seconds // 3600} hours old"
        else:
            return "recent"

    @staticmethod
    def list_sources() -> list[dict[str, Any]]:
        """List all update sources and their status."""
        result = []
        for name, config in UPDATE_SOURCES.items():
            handler = AutoUpdateHandler(name)
            result.append(
                {
                    "name": name,
                    "description": config.get("description", name),
                    "frequency_days": config.get("frequency_days", 7),
                    "needs_update": handler.needs_update(),
                    "last_update": handler._get_last_update(),
                    "age": handler._get_age_string(),
                }
            )
        return result

    @staticmethod
    async def update_all_stale() -> dict[str, bool]:
        """Update all stale sources."""
        results = {}
        for name in UPDATE_SOURCES:
            handler = AutoUpdateHandler(name)
            if handler.needs_update() and await handler.can_fix():
                results[name] = await handler.fix()
        return results


# Register the handler
AUTO_REGISTRY.register("AUTO-UPDATE", AutoUpdateHandler)
