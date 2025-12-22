"""Network interface detection and validation."""
from dataclasses import dataclass
from pathlib import Path
from typing import Self

from voidwave.core.logging import get_logger

logger = get_logger(__name__)


@dataclass
class NetworkInterface:
    """Network interface information."""

    name: str
    is_wireless: bool
    is_up: bool
    mac_address: str | None
    driver: str | None
    chipset: str | None
    supports_monitor: bool
    supports_injection: bool
    supports_vif: bool
    current_mode: str  # managed, monitor, etc.

    @classmethod
    def from_name(cls, name: str) -> Self | None:
        """Create interface info from name."""
        sys_path = Path(f"/sys/class/net/{name}")

        if not sys_path.exists():
            return None

        # Check if wireless
        wireless_path = sys_path / "wireless"
        phy_path = sys_path / "phy80211"
        is_wireless = wireless_path.exists() or phy_path.exists()

        # Get operational state
        operstate_path = sys_path / "operstate"
        is_up = operstate_path.exists() and operstate_path.read_text().strip() == "up"

        # Get MAC address
        address_path = sys_path / "address"
        mac_address = address_path.read_text().strip() if address_path.exists() else None

        # Get driver info
        driver = None
        driver_link = sys_path / "device" / "driver"
        if driver_link.exists():
            driver = driver_link.resolve().name

        # Determine capabilities (simplified - full impl would use iw)
        supports_monitor = is_wireless
        supports_injection = is_wireless
        supports_vif = is_wireless and driver in cls._VIF_WHITELIST

        # Get current mode
        current_mode = "managed"
        if is_wireless and (name.startswith("wmon") or name.endswith("mon")):
            current_mode = "monitor"

        return cls(
            name=name,
            is_wireless=is_wireless,
            is_up=is_up,
            mac_address=mac_address,
            driver=driver,
            chipset=None,  # Would need lsusb/lspci parsing
            supports_monitor=supports_monitor,
            supports_injection=supports_injection,
            supports_vif=supports_vif,
            current_mode=current_mode,
        )

    # Drivers known to support VIF (for Evil Twin)
    _VIF_WHITELIST = {
        "mt76x2u",
        "mt7921u",  # MediaTek
        "ath9k_htc",
        "ath9k",  # Atheros
        "rt2800usb",
        "rt73usb",  # Ralink
        "rtl8187",  # Realtek (limited)
    }


def get_all_interfaces() -> list[NetworkInterface]:
    """Get all network interfaces."""
    interfaces = []
    net_path = Path("/sys/class/net")

    if net_path.exists():
        for iface_path in net_path.iterdir():
            if iface := NetworkInterface.from_name(iface_path.name):
                interfaces.append(iface)

    return interfaces


def get_wireless_interfaces() -> list[NetworkInterface]:
    """Get only wireless interfaces."""
    return [iface for iface in get_all_interfaces() if iface.is_wireless]


def validate_wireless_interface(name: str) -> NetworkInterface:
    """Validate that interface exists and is wireless."""
    iface = NetworkInterface.from_name(name)

    if iface is None:
        raise ValueError(f"Interface not found: {name}")

    if not iface.is_wireless:
        raise ValueError(f"Interface is not wireless: {name}")

    return iface
