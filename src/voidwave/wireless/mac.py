"""MAC address spoofing utilities."""
import asyncio
import random
import re
from pathlib import Path

from voidwave.core.logging import get_logger

logger = get_logger(__name__)

# OUI prefixes for common vendors (for generating realistic MACs)
VENDOR_OUIS = {
    "apple": ["00:03:93", "00:05:02", "00:0A:27", "00:0A:95", "00:0D:93"],
    "samsung": ["00:00:F0", "00:02:78", "00:09:18", "00:12:47", "00:12:FB"],
    "intel": ["00:02:B3", "00:03:47", "00:04:23", "00:07:E9", "00:0C:F1"],
    "realtek": ["00:0A:CD", "00:0C:E7", "00:E0:4C", "00:E0:66", "52:54:00"],
    "random": [],  # Will generate fully random
}


def generate_mac(vendor: str = "random") -> str:
    """Generate a MAC address."""
    if vendor in VENDOR_OUIS and VENDOR_OUIS[vendor]:
        oui = random.choice(VENDOR_OUIS[vendor])
        suffix = ":".join(f"{random.randint(0, 255):02x}" for _ in range(3))
        return f"{oui}:{suffix}"
    else:
        # Fully random (ensure locally administered bit)
        first_byte = random.randint(0, 255) | 0x02  # Set locally administered bit
        first_byte &= 0xFE  # Clear multicast bit
        rest = [random.randint(0, 255) for _ in range(5)]
        return ":".join(f"{b:02x}" for b in [first_byte] + rest)


def validate_mac(mac: str) -> bool:
    """Validate MAC address format."""
    pattern = r"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$"
    return bool(re.match(pattern, mac))


async def get_current_mac(interface: str) -> str | None:
    """Get current MAC address of interface."""
    try:
        address_path = Path(f"/sys/class/net/{interface}/address")
        if address_path.exists():
            return address_path.read_text().strip()
    except Exception:
        pass

    # Fallback to ip command
    try:
        process = await asyncio.create_subprocess_exec(
            "ip",
            "link",
            "show",
            interface,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await process.communicate()

        match = re.search(r"link/ether\s+([0-9a-f:]{17})", stdout.decode())
        if match:
            return match.group(1)
    except Exception:
        pass

    return None


async def get_permanent_mac(interface: str) -> str | None:
    """Get permanent (hardware) MAC address."""
    try:
        process = await asyncio.create_subprocess_exec(
            "ethtool",
            "-P",
            interface,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await process.communicate()

        match = re.search(r"Permanent address:\s+([0-9a-f:]{17})", stdout.decode())
        if match:
            return match.group(1)
    except Exception:
        pass

    return None


async def change_mac(
    interface: str, new_mac: str | None = None, vendor: str = "random"
) -> str:
    """
    Change MAC address of interface.

    If new_mac is None, generates a random one.
    Returns the new MAC address.
    """
    if new_mac is None:
        new_mac = generate_mac(vendor)

    if not validate_mac(new_mac):
        raise ValueError(f"Invalid MAC address: {new_mac}")

    # Store original MAC
    original_mac = await get_current_mac(interface)

    try:
        # Bring interface down
        await _run_ip_command(["link", "set", interface, "down"])

        # Change MAC
        await _run_ip_command(["link", "set", interface, "address", new_mac])

        # Bring interface up
        await _run_ip_command(["link", "set", interface, "up"])

        logger.info(f"MAC changed: {interface} {original_mac} -> {new_mac}")
        return new_mac

    except Exception as e:
        # Try to restore original MAC
        if original_mac:
            try:
                await _run_ip_command(["link", "set", interface, "address", original_mac])
                await _run_ip_command(["link", "set", interface, "up"])
            except Exception:
                pass
        raise


async def restore_mac(interface: str) -> str | None:
    """Restore permanent MAC address."""
    permanent_mac = await get_permanent_mac(interface)
    if permanent_mac:
        await change_mac(interface, permanent_mac)
        logger.info(f"MAC restored: {interface} -> {permanent_mac}")
        return permanent_mac
    return None


async def _run_ip_command(args: list[str]) -> None:
    """Run ip command."""
    process = await asyncio.create_subprocess_exec(
        "ip",
        *args,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    _, stderr = await process.communicate()

    if process.returncode != 0:
        raise RuntimeError(f"ip command failed: {stderr.decode()}")
