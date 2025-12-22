"""Monitor mode management for wireless interfaces."""
import asyncio
import re
from pathlib import Path

from voidwave.core.exceptions import PermissionError, VoidwaveError
from voidwave.core.logging import get_logger
from voidwave.detection.interfaces import NetworkInterface, validate_wireless_interface

logger = get_logger(__name__)


class MonitorModeError(VoidwaveError):
    """Monitor mode operation failed."""

    pass


async def enable_monitor_mode(interface: str, kill_processes: bool = True) -> str:
    """
    Enable monitor mode on a wireless interface.

    Returns the monitor interface name (may differ from input).
    """
    # Validate interface
    iface = validate_wireless_interface(interface)

    if iface.current_mode == "monitor":
        logger.info(f"Interface {interface} already in monitor mode")
        return interface

    # Kill interfering processes
    if kill_processes:
        await _kill_interfering_processes()

    # Try airmon-ng first
    try:
        return await _enable_with_airmon(interface)
    except Exception as e:
        logger.warning(f"airmon-ng failed: {e}, trying iw")

    # Fallback to iw
    try:
        return await _enable_with_iw(interface)
    except Exception as e:
        logger.error(f"iw failed: {e}")
        raise MonitorModeError(f"Failed to enable monitor mode on {interface}")


async def disable_monitor_mode(interface: str) -> str:
    """
    Disable monitor mode on a wireless interface.

    Returns the managed interface name.
    """
    # Try airmon-ng first
    try:
        return await _disable_with_airmon(interface)
    except Exception:
        pass

    # Fallback to iw
    try:
        return await _disable_with_iw(interface)
    except Exception as e:
        raise MonitorModeError(f"Failed to disable monitor mode: {e}")


async def _kill_interfering_processes() -> None:
    """Kill processes that interfere with monitor mode."""
    process = await asyncio.create_subprocess_exec(
        "airmon-ng",
        "check",
        "kill",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    await process.wait()
    logger.debug("Killed interfering processes")


async def _enable_with_airmon(interface: str) -> str:
    """Enable monitor mode using airmon-ng."""
    process = await asyncio.create_subprocess_exec(
        "airmon-ng",
        "start",
        interface,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await process.communicate()

    if process.returncode != 0:
        raise MonitorModeError(f"airmon-ng failed: {stderr.decode()}")

    output = stdout.decode()

    # Parse output for new interface name
    # Patterns: "monitor mode vif enabled for [phy0]wlan0 on [phy0]wlan0mon"
    match = re.search(r"monitor mode.*enabled.*on.*\](\w+)", output)
    if match:
        monitor_iface = match.group(1)
        logger.info(f"Monitor mode enabled: {interface} -> {monitor_iface}")
        return monitor_iface

    # Sometimes airmon-ng renames to wlan0mon
    potential_names = [f"{interface}mon", interface.replace("wlan", "wmon")]
    for name in potential_names:
        if Path(f"/sys/class/net/{name}").exists():
            logger.info(f"Monitor mode enabled: {interface} -> {name}")
            return name

    raise MonitorModeError("Could not determine monitor interface name")


async def _enable_with_iw(interface: str) -> str:
    """Enable monitor mode using iw."""
    # Bring interface down
    await _run_command(["ip", "link", "set", interface, "down"])

    # Set monitor mode
    await _run_command(["iw", interface, "set", "type", "monitor"])

    # Bring interface up
    await _run_command(["ip", "link", "set", interface, "up"])

    logger.info(f"Monitor mode enabled on {interface} using iw")
    return interface


async def _disable_with_airmon(interface: str) -> str:
    """Disable monitor mode using airmon-ng."""
    process = await asyncio.create_subprocess_exec(
        "airmon-ng",
        "stop",
        interface,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await process.communicate()

    if process.returncode != 0:
        raise MonitorModeError(f"airmon-ng stop failed: {stderr.decode()}")

    # Determine managed interface name
    if interface.endswith("mon"):
        managed = interface[:-3]
    else:
        managed = interface.replace("wmon", "wlan")

    if Path(f"/sys/class/net/{managed}").exists():
        logger.info(f"Monitor mode disabled: {interface} -> {managed}")
        return managed

    return interface


async def _disable_with_iw(interface: str) -> str:
    """Disable monitor mode using iw."""
    await _run_command(["ip", "link", "set", interface, "down"])
    await _run_command(["iw", interface, "set", "type", "managed"])
    await _run_command(["ip", "link", "set", interface, "up"])

    logger.info(f"Monitor mode disabled on {interface}")
    return interface


async def _run_command(cmd: list[str]) -> None:
    """Run a command and raise on failure."""
    process = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await process.communicate()

    if process.returncode != 0:
        raise MonitorModeError(f"Command failed: {' '.join(cmd)} - {stderr.decode()}")


async def get_monitor_status(interface: str) -> dict:
    """Get current monitor mode status of an interface."""
    iface = NetworkInterface.from_name(interface)

    if iface is None:
        return {"exists": False}

    return {
        "exists": True,
        "interface": interface,
        "is_wireless": iface.is_wireless,
        "current_mode": iface.current_mode,
        "is_monitor": iface.current_mode == "monitor",
        "driver": iface.driver,
        "supports_monitor": iface.supports_monitor,
        "supports_injection": iface.supports_injection,
    }
