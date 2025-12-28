"""Wash WPS network scanner wrapper with output parsing."""
from __future__ import annotations

import re
from typing import Any, ClassVar

from pydantic import BaseModel

from voidwave.core.logging import get_logger
from voidwave.orchestration.events import Events, event_bus
from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper

logger = get_logger(__name__)


class WashConfig(BaseModel):
    """Wash-specific configuration."""

    scan_duration: int = 30  # Default scan time
    all_channels: bool = True


class WashTool(BaseToolWrapper):
    """Wash WPS network scanner wrapper."""

    TOOL_BINARY: ClassVar[str] = "wash"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="wash",
        version="1.0.0",
        description="WPS-enabled network scanner",
        author="VOIDWAVE",
        plugin_type=PluginType.SCANNER,
        capabilities=[Capability.WIRELESS_SCAN],
        requires_root=True,
        external_tools=["wash"],
        config_schema=WashConfig,
    )

    def __init__(self, wash_config: WashConfig | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self.wash_config = wash_config or WashConfig()

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build wash command.

        Args:
            target: Monitor mode interface
            options: Command options including:
                - channel: Specific channel to scan (-c)
                - scan_5ghz: Include 5GHz channels (-5)
                - all: Show all APs including locked (-a)
                - file: Read from pcap file (-f)
                - json: Output in JSON format (-j)
                - ignore_fcs: Ignore FCS errors (-C)
        """
        cmd = []

        # Interface
        cmd.extend(["-i", target])

        # Channel
        channel = options.get("channel")
        if channel:
            cmd.extend(["-c", str(channel)])

        # 5GHz scanning
        if options.get("scan_5ghz"):
            cmd.append("-5")

        # Show all (including locked)
        if options.get("all", True):
            cmd.append("-a")

        # Read from pcap
        pcap_file = options.get("file")
        if pcap_file:
            cmd.extend(["-f", str(pcap_file)])

        # JSON output
        if options.get("json"):
            cmd.append("-j")

        # Ignore FCS errors
        if options.get("ignore_fcs"):
            cmd.append("-C")

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse wash output."""
        result = {
            "raw_output": output,
            "networks": [],
            "total_wps_networks": 0,
            "locked_networks": 0,
        }

        lines = output.strip().split('\n')

        # Skip header lines
        data_started = False

        for line in lines:
            line = line.strip()

            # Skip empty lines and headers
            if not line:
                continue

            if "BSSID" in line and "Channel" in line:
                data_started = True
                continue

            if line.startswith("-"):
                continue

            if not data_started:
                continue

            # Parse network line
            # Format: BSSID  Channel  RSSI  WPS Version  WPS Locked  ESSID
            network = self._parse_network_line(line)
            if network:
                result["networks"].append(network)
                result["total_wps_networks"] += 1
                if network.get("wps_locked"):
                    result["locked_networks"] += 1

        return result

    def _parse_network_line(self, line: str) -> dict[str, Any] | None:
        """Parse a single network line from wash output."""
        # Typical format:
        # AA:BB:CC:DD:EE:FF    1  -50  1.0  No   MyNetwork
        # or
        # AA:BB:CC:DD:EE:FF    11  -65  2.0  Yes  LockedNetwork

        # Pattern to match wash output
        pattern = r'([0-9A-Fa-f:]{17})\s+(\d+)\s+(-?\d+)\s+([\d.]+)\s+(Yes|No)\s*(.*)'
        match = re.match(pattern, line)

        if not match:
            # Try alternative pattern with different spacing
            parts = line.split()
            if len(parts) >= 5:
                try:
                    bssid = parts[0]
                    if not re.match(r'[0-9A-Fa-f:]{17}', bssid):
                        return None

                    return {
                        "bssid": bssid,
                        "channel": int(parts[1]),
                        "rssi": int(parts[2]),
                        "wps_version": parts[3],
                        "wps_locked": parts[4].lower() == "yes",
                        "essid": " ".join(parts[5:]) if len(parts) > 5 else "",
                    }
                except (ValueError, IndexError):
                    return None
            return None

        try:
            return {
                "bssid": match.group(1),
                "channel": int(match.group(2)),
                "rssi": int(match.group(3)),
                "wps_version": match.group(4),
                "wps_locked": match.group(5).lower() == "yes",
                "essid": match.group(6).strip(),
            }
        except (ValueError, IndexError):
            return None

    async def scan_wps_networks(
        self,
        interface: str,
        channel: int | None = None,
        scan_5ghz: bool = False,
        duration: int = 30,
    ) -> dict[str, Any]:
        """Scan for WPS-enabled networks.

        Args:
            interface: Monitor mode interface
            channel: Specific channel to scan
            scan_5ghz: Include 5GHz channels
            duration: Scan duration in seconds

        Returns:
            Scan results with WPS-enabled networks
        """
        options = {
            "all": True,
            "scan_5ghz": scan_5ghz,
            "timeout": duration,
        }

        if channel:
            options["channel"] = channel

        result = await self.execute(interface, options)

        # Emit events for found WPS networks
        for network in result.data.get("networks", []):
            await event_bus.emit(Events.WPS_NETWORK_FOUND, {
                "bssid": network["bssid"],
                "essid": network.get("essid", ""),
                "channel": network["channel"],
                "wps_version": network["wps_version"],
                "wps_locked": network["wps_locked"],
            })

        return result.data

    async def find_unlocked_targets(
        self,
        interface: str,
        duration: int = 30,
    ) -> list[dict[str, Any]]:
        """Find WPS networks that are not locked.

        Args:
            interface: Monitor mode interface
            duration: Scan duration

        Returns:
            List of unlocked WPS-enabled networks
        """
        result = await self.scan_wps_networks(
            interface=interface,
            duration=duration,
        )

        return [
            network for network in result.get("networks", [])
            if not network.get("wps_locked")
        ]
