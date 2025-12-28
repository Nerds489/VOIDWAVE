"""AUTO-IFACE handler for interface selection."""

import asyncio
from pathlib import Path
from dataclasses import dataclass

from voidwave.automation.labels import AUTO_REGISTRY


@dataclass
class InterfaceInfo:
    """Information about a network interface."""

    name: str
    type: str  # wireless, wired, monitor
    driver: str
    mac: str
    state: str  # up, down


class AutoIfaceHandler:
    """Handles AUTO-IFACE for interface selection."""

    def __init__(self, required_type: str = "wireless") -> None:
        self.required_type = required_type
        self.selected_interface: str | None = None

    async def can_fix(self) -> bool:
        """Check if we can select an interface."""
        interfaces = await self.get_interfaces(self.required_type)
        return len(interfaces) > 0

    async def fix(self) -> bool:
        """Auto-select an interface if only one is available."""
        interfaces = await self.get_interfaces(self.required_type)

        if len(interfaces) == 0:
            return False

        if len(interfaces) == 1:
            self.selected_interface = interfaces[0].name
            return True

        # Multiple interfaces - need user selection
        # Return the first one for now
        self.selected_interface = interfaces[0].name
        return True

    async def get_ui_prompt(self) -> str:
        """Get the UI prompt for this fix."""
        interfaces = await self.get_interfaces(self.required_type)
        if len(interfaces) == 0:
            return f"No {self.required_type} interfaces found."
        elif len(interfaces) == 1:
            return f"Use {interfaces[0].name} for this operation?"
        else:
            names = ", ".join(i.name for i in interfaces)
            return f"Select interface: {names}"

    async def get_interfaces(self, iface_type: str = "all") -> list[InterfaceInfo]:
        """Get available network interfaces."""
        interfaces = []
        net_path = Path("/sys/class/net")

        if not net_path.exists():
            return interfaces

        for iface_path in net_path.iterdir():
            name = iface_path.name

            # Skip loopback
            if name == "lo":
                continue

            # Determine type
            is_wireless = (iface_path / "wireless").exists()
            is_monitor = await self._is_monitor_mode(name)

            if is_monitor:
                interface_type = "monitor"
            elif is_wireless:
                interface_type = "wireless"
            else:
                interface_type = "wired"

            # Filter by type
            if iface_type != "all" and interface_type != iface_type:
                if not (iface_type == "wireless" and interface_type == "monitor"):
                    continue

            # Get additional info
            driver = await self._get_driver(iface_path)
            mac = await self._get_mac(iface_path)
            state = await self._get_state(iface_path)

            interfaces.append(
                InterfaceInfo(
                    name=name,
                    type=interface_type,
                    driver=driver,
                    mac=mac,
                    state=state,
                )
            )

        return interfaces

    async def _is_monitor_mode(self, interface: str) -> bool:
        """Check if interface is in monitor mode."""
        proc = await asyncio.create_subprocess_shell(
            f"iw dev {interface} info 2>/dev/null | grep -q 'type monitor'",
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
        )
        await proc.wait()
        return proc.returncode == 0

    async def _get_driver(self, iface_path: Path) -> str:
        """Get the driver for an interface."""
        driver_link = iface_path / "device" / "driver"
        try:
            if driver_link.exists():
                return driver_link.resolve().name
        except Exception:
            pass
        return "unknown"

    async def _get_mac(self, iface_path: Path) -> str:
        """Get the MAC address for an interface."""
        address_file = iface_path / "address"
        try:
            if address_file.exists():
                return address_file.read_text().strip()
        except Exception:
            pass
        return "00:00:00:00:00:00"

    async def _get_state(self, iface_path: Path) -> str:
        """Get the operational state of an interface."""
        operstate_file = iface_path / "operstate"
        try:
            if operstate_file.exists():
                return operstate_file.read_text().strip()
        except Exception:
            pass
        return "unknown"


# Register the handler
AUTO_REGISTRY.register("AUTO-IFACE", AutoIfaceHandler)
