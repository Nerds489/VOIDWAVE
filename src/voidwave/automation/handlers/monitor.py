"""AUTO-MON handler for monitor mode management."""

import asyncio
import shutil
from pathlib import Path
from typing import Any

from voidwave.automation.labels import AUTO_REGISTRY


class AutoMonHandler:
    """Handles AUTO-MON for enabling monitor mode."""

    def __init__(self, interface: str = "") -> None:
        self.interface = interface
        self.monitor_interface: str | None = None

    async def can_fix(self) -> bool:
        """Check if we can enable monitor mode."""
        # Need airmon-ng or iw
        has_airmon = shutil.which("airmon-ng") is not None
        has_iw = shutil.which("iw") is not None

        if not (has_airmon or has_iw):
            return False

        # Need an interface
        if not self.interface:
            interfaces = await self._get_wireless_interfaces()
            return len(interfaces) > 0

        return True

    async def fix(self) -> bool:
        """Enable monitor mode on the interface."""
        if not self.interface:
            interfaces = await self._get_wireless_interfaces()
            if not interfaces:
                return False
            self.interface = interfaces[0]

        # Try airmon-ng first
        if shutil.which("airmon-ng"):
            return await self._enable_with_airmon()
        elif shutil.which("iw"):
            return await self._enable_with_iw()

        return False

    async def get_ui_prompt(self) -> str:
        """Get the UI prompt for this fix."""
        if self.interface:
            return f"Enable monitor mode on {self.interface}?"
        return "Enable monitor mode on wireless interface?"

    async def _get_wireless_interfaces(self) -> list[str]:
        """Get list of wireless interfaces."""
        interfaces = []
        wireless_path = Path("/sys/class/net")

        if wireless_path.exists():
            for iface_path in wireless_path.iterdir():
                wireless_dir = iface_path / "wireless"
                if wireless_dir.exists():
                    interfaces.append(iface_path.name)

        return interfaces

    async def _enable_with_airmon(self) -> bool:
        """Enable monitor mode using airmon-ng."""
        # Kill interfering processes
        await asyncio.create_subprocess_shell(
            "airmon-ng check kill",
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
        )

        # Enable monitor mode
        proc = await asyncio.create_subprocess_shell(
            f"airmon-ng start {self.interface}",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        await proc.wait()

        # Find the new monitor interface
        await asyncio.sleep(1)
        self.monitor_interface = await self._find_monitor_interface()

        return self.monitor_interface is not None

    async def _enable_with_iw(self) -> bool:
        """Enable monitor mode using iw."""
        # Bring interface down
        await asyncio.create_subprocess_shell(
            f"ip link set {self.interface} down",
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
        )

        # Set monitor mode
        proc = await asyncio.create_subprocess_shell(
            f"iw dev {self.interface} set type monitor",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        await proc.wait()

        # Bring interface up
        await asyncio.create_subprocess_shell(
            f"ip link set {self.interface} up",
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
        )

        if proc.returncode == 0:
            self.monitor_interface = self.interface
            return True

        return False

    async def _find_monitor_interface(self) -> str | None:
        """Find the monitor mode interface."""
        # Check for common naming patterns
        patterns = [
            f"{self.interface}mon",
            f"mon{self.interface[-1]}",
            "wlan0mon",
            "wlan1mon",
        ]

        for pattern in patterns:
            iface_path = Path(f"/sys/class/net/{pattern}")
            if iface_path.exists():
                return pattern

        # Fall back to original interface
        return self.interface

    async def disable_monitor_mode(self) -> bool:
        """Disable monitor mode and restore managed mode."""
        if not self.monitor_interface:
            return False

        if shutil.which("airmon-ng"):
            proc = await asyncio.create_subprocess_shell(
                f"airmon-ng stop {self.monitor_interface}",
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL,
            )
            await proc.wait()

            # Restart network manager
            await asyncio.create_subprocess_shell(
                "systemctl start NetworkManager",
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL,
            )

            return proc.returncode == 0

        elif shutil.which("iw"):
            await asyncio.create_subprocess_shell(
                f"ip link set {self.monitor_interface} down",
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL,
            )

            proc = await asyncio.create_subprocess_shell(
                f"iw dev {self.monitor_interface} set type managed",
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL,
            )
            await proc.wait()

            await asyncio.create_subprocess_shell(
                f"ip link set {self.monitor_interface} up",
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL,
            )

            return proc.returncode == 0

        return False


# Register the handler
AUTO_REGISTRY.register("AUTO-MON", AutoMonHandler)
