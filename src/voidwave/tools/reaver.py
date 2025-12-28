"""Reaver WPS attack tool wrapper with output parsing."""
from __future__ import annotations

import re
from typing import Any, ClassVar

from pydantic import BaseModel

from voidwave.core.logging import get_logger
from voidwave.orchestration.events import Events, event_bus
from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper

logger = get_logger(__name__)


class ReaverConfig(BaseModel):
    """Reaver-specific configuration."""

    delay: int = 1  # Delay between PIN attempts
    lock_delay: int = 60  # Delay when AP locks
    max_attempts: int = 0  # 0 = unlimited
    timeout: int = 5  # Receive timeout
    verbose: bool = True


class ReaverTool(BaseToolWrapper):
    """Reaver WPS attack tool wrapper."""

    TOOL_BINARY: ClassVar[str] = "reaver"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="reaver",
        version="1.0.0",
        description="WPS PIN recovery tool",
        author="VOIDWAVE",
        plugin_type=PluginType.TOOL,
        capabilities=[Capability.WIRELESS_ATTACK],
        requires_root=True,
        external_tools=["reaver"],
        config_schema=ReaverConfig,
    )

    def __init__(self, reaver_config: ReaverConfig | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self.reaver_config = reaver_config or ReaverConfig()

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build reaver command.

        Args:
            target: Target BSSID
            options: Command options including:
                - interface: Monitor mode interface (-i)
                - channel: Target channel (-c)
                - essid: Target ESSID (-e)
                - pixiedust: Use Pixie Dust attack (-K)
                - delay: Delay between attempts (-d)
                - lock_delay: Delay when locked (-l)
                - max_attempts: Max PIN attempts (-g)
                - timeout: Receive timeout (-t)
                - pin: Known PIN to use (-p)
                - no_nacks: Ignore NACK messages (-N)
                - dh_small: Use small DH keys (-S)
                - no_associate: Don't auto-associate (-A)
                - output: Session file (-s)
        """
        cmd = []

        # Interface (required)
        interface = options.get("interface")
        if interface:
            cmd.extend(["-i", interface])

        # Target BSSID
        cmd.extend(["-b", target])

        # Channel
        channel = options.get("channel")
        if channel:
            cmd.extend(["-c", str(channel)])

        # ESSID
        essid = options.get("essid")
        if essid:
            cmd.extend(["-e", essid])

        # Pixie Dust attack (faster, uses implementation flaw)
        if options.get("pixiedust"):
            cmd.append("-K")
            cmd.append("1")  # Pixie Dust mode 1

        # Delay between attempts
        delay = options.get("delay", self.reaver_config.delay)
        cmd.extend(["-d", str(delay)])

        # Lock delay
        lock_delay = options.get("lock_delay", self.reaver_config.lock_delay)
        cmd.extend(["-l", str(lock_delay)])

        # Max attempts
        max_attempts = options.get("max_attempts", self.reaver_config.max_attempts)
        if max_attempts > 0:
            cmd.extend(["-g", str(max_attempts)])

        # Timeout
        timeout = options.get("timeout", self.reaver_config.timeout)
        cmd.extend(["-t", str(timeout)])

        # Known PIN
        pin = options.get("pin")
        if pin:
            cmd.extend(["-p", pin])

        # No NACKs
        if options.get("no_nacks"):
            cmd.append("-N")

        # Small DH keys
        if options.get("dh_small"):
            cmd.append("-S")

        # Don't auto-associate
        if options.get("no_associate"):
            cmd.append("-A")

        # Session file
        output = options.get("output")
        if output:
            cmd.extend(["-s", str(output)])

        # Verbosity
        if options.get("verbose", self.reaver_config.verbose):
            cmd.append("-vv")

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse reaver output."""
        result = {
            "raw_output": output,
            "pin": None,
            "psk": None,
            "ssid": None,
            "bssid": None,
            "progress": 0.0,
            "status": "running",
            "attempts": 0,
            "locked": False,
            "errors": [],
        }

        lines = output.strip().split('\n')

        for line in lines:
            # WPS PIN found
            pin_match = re.search(r'WPS PIN:\s*[\'"]?(\d{8})[\'"]?', line, re.IGNORECASE)
            if pin_match:
                result["pin"] = pin_match.group(1)
                result["status"] = "success"
                continue

            # Alternative PIN format
            alt_pin = re.search(r'Pin found:\s*(\d{8})', line, re.IGNORECASE)
            if alt_pin:
                result["pin"] = alt_pin.group(1)
                result["status"] = "success"
                continue

            # WPA PSK found
            psk_match = re.search(r'WPA PSK:\s*[\'"]?(.+?)[\'"]?\s*$', line, re.IGNORECASE)
            if psk_match:
                result["psk"] = psk_match.group(1).strip("'\"")
                continue

            # Alternative PSK format
            alt_psk = re.search(r'PSK:\s*(.+)', line, re.IGNORECASE)
            if alt_psk:
                result["psk"] = alt_psk.group(1).strip("'\"")
                continue

            # SSID/ESSID
            ssid_match = re.search(r'(?:ESSID|AP SSID):\s*[\'"]?(.+?)[\'"]?\s*$', line, re.IGNORECASE)
            if ssid_match:
                result["ssid"] = ssid_match.group(1).strip("'\"")
                continue

            # Progress/Attempts
            progress_match = re.search(r'(\d+\.?\d*)%\s+complete', line, re.IGNORECASE)
            if progress_match:
                result["progress"] = float(progress_match.group(1))
                continue

            # Attempt count
            attempt_match = re.search(r'Trying pin:?\s*(\d+)', line, re.IGNORECASE)
            if attempt_match:
                result["attempts"] += 1
                continue

            # Pixie Dust success
            if "WPS pin:" in line.lower() or "pin found" in line.lower():
                result["status"] = "success"
                continue

            # AP Locked
            if "WARNING" in line and "locked" in line.lower():
                result["locked"] = True
                result["errors"].append("AP rate limiting detected")
                continue

            # Timeout
            if "timeout" in line.lower():
                result["errors"].append(line.strip())
                continue

            # Authentication failure
            if "authentication" in line.lower() and "fail" in line.lower():
                result["errors"].append(line.strip())
                continue

            # Session complete
            if "session saved" in line.lower():
                result["status"] = "saved"
                continue

        return result

    async def wps_attack(
        self,
        bssid: str,
        interface: str,
        channel: int,
        pixiedust: bool = True,
        essid: str | None = None,
    ) -> dict[str, Any]:
        """Perform WPS PIN attack.

        Args:
            bssid: Target access point BSSID
            interface: Monitor mode interface
            channel: Target channel
            pixiedust: Use Pixie Dust attack (faster)
            essid: Target network name (optional)

        Returns:
            Attack results including PIN and PSK if found
        """
        options = {
            "interface": interface,
            "channel": channel,
            "pixiedust": pixiedust,
        }

        if essid:
            options["essid"] = essid

        result = await self.execute(bssid, options)

        # Emit event if PIN found
        if result.data.get("pin"):
            await event_bus.emit(Events.WPS_PIN_FOUND, {
                "bssid": bssid,
                "pin": result.data["pin"],
                "psk": result.data.get("psk"),
            })

        # Emit event if PSK found
        if result.data.get("psk"):
            await event_bus.emit(Events.CREDENTIAL_CRACKED, {
                "type": "wps",
                "bssid": bssid,
                "password": result.data["psk"],
            })

        return result.data

    async def pixie_dust(
        self,
        bssid: str,
        interface: str,
        channel: int,
    ) -> dict[str, Any]:
        """Perform Pixie Dust attack (fast WPS attack).

        Args:
            bssid: Target BSSID
            interface: Monitor mode interface
            channel: Target channel

        Returns:
            Attack results
        """
        return await self.wps_attack(
            bssid=bssid,
            interface=interface,
            channel=channel,
            pixiedust=True,
        )

    async def bruteforce_pin(
        self,
        bssid: str,
        interface: str,
        channel: int,
        delay: int = 1,
    ) -> dict[str, Any]:
        """Perform WPS PIN brute force attack.

        Args:
            bssid: Target BSSID
            interface: Monitor mode interface
            channel: Target channel
            delay: Delay between attempts

        Returns:
            Attack results
        """
        options = {
            "interface": interface,
            "channel": channel,
            "pixiedust": False,
            "delay": delay,
        }

        result = await self.execute(bssid, options)
        return result.data
