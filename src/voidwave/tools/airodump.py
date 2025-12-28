"""Airodump-ng wireless packet capture wrapper with CSV parsing."""
from __future__ import annotations

import csv
import re
from io import StringIO
from pathlib import Path
from typing import Any, ClassVar

from pydantic import BaseModel

from voidwave.core.logging import get_logger
from voidwave.orchestration.events import Events, event_bus
from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper

logger = get_logger(__name__)


class AirodumpConfig(BaseModel):
    """Airodump-ng specific configuration."""

    output_format: str = "csv"
    band: str = "abg"  # 802.11 bands to scan
    manufacturer_lookup: bool = True
    gps: bool = False
    update_interval: int = 1  # seconds


class AirodumpTool(BaseToolWrapper):
    """Airodump-ng wireless packet capture wrapper with full CSV parsing."""

    TOOL_BINARY: ClassVar[str] = "airodump-ng"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="airodump-ng",
        version="1.0.0",
        description="Wireless packet capture and analysis",
        author="VOIDWAVE",
        plugin_type=PluginType.TOOL,
        capabilities=[Capability.WIRELESS_SCAN, Capability.PACKET_CAPTURE],
        requires_root=True,
        external_tools=["airodump-ng"],
        config_schema=AirodumpConfig,
    )

    def __init__(self, airodump_config: AirodumpConfig | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self.airodump_config = airodump_config or AirodumpConfig()
        self._csv_file: Path | None = None

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build airodump-ng command.

        Args:
            target: The wireless interface (e.g., wlan0mon)
            options: Command options including:
                - channel: Specific channel to scan
                - bssid: Filter by BSSID
                - essid: Filter by ESSID
                - output: Output file prefix
                - band: Bands to scan (a, b, g, n, ac)
                - write_interval: Seconds between file writes
                - berlin: Time before removing AP from display
        """
        cmd = []

        # Channel hopping or specific channel
        channel = options.get("channel")
        if channel:
            cmd.extend(["--channel", str(channel)])

        # BSSID filter
        bssid = options.get("bssid")
        if bssid:
            cmd.extend(["--bssid", bssid])

        # ESSID filter
        essid = options.get("essid")
        if essid:
            cmd.extend(["--essid", essid])

        # Output file prefix for CSV/XML/etc
        output = options.get("output")
        if output:
            self._csv_file = Path(str(output) + "-01.csv")
            cmd.extend(["--write", str(output)])
            cmd.extend(["--output-format", "csv"])

        # Band selection
        band = options.get("band", self.airodump_config.band)
        if band:
            cmd.extend(["--band", band])

        # Write interval
        write_interval = options.get("write_interval", 1)
        cmd.extend(["--write-interval", str(write_interval)])

        # Berlin timeout (remove inactive APs)
        berlin = options.get("berlin")
        if berlin:
            cmd.extend(["--berlin", str(berlin)])

        # Show manufacturer
        if options.get("manufacturer", self.airodump_config.manufacturer_lookup):
            cmd.append("--manufacturer")

        # WPS information
        if options.get("wps"):
            cmd.append("--wps")

        # Uptime information
        if options.get("uptime"):
            cmd.append("--uptime")

        # Interface (target)
        cmd.append(target)

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse airodump-ng output.

        Parses both live terminal output and CSV file output.
        """
        result = {
            "networks": [],
            "clients": [],
            "raw_output": output,
        }

        # Try to parse CSV file if available
        if self._csv_file and self._csv_file.exists():
            try:
                csv_result = self._parse_csv_file(self._csv_file)
                result.update(csv_result)
                return result
            except Exception as e:
                logger.warning(f"Failed to parse CSV file: {e}")

        # Fallback to parsing terminal output
        result.update(self._parse_terminal_output(output))
        return result

    def _parse_csv_file(self, csv_path: Path) -> dict[str, Any]:
        """Parse airodump-ng CSV output file.

        Airodump CSV format has two sections separated by blank lines:
        1. Access Points section
        2. Clients section
        """
        content = csv_path.read_text()
        networks = []
        clients = []

        # Split by the blank line that separates APs from clients
        sections = re.split(r'\n\s*\n', content.strip())

        if len(sections) >= 1:
            # Parse networks section
            networks = self._parse_networks_section(sections[0])

        if len(sections) >= 2:
            # Parse clients section
            clients = self._parse_clients_section(sections[1])

        return {"networks": networks, "clients": clients}

    def _parse_networks_section(self, section: str) -> list[dict[str, Any]]:
        """Parse the networks/APs section of CSV."""
        networks = []
        lines = section.strip().split('\n')

        if len(lines) < 2:
            return networks

        # Skip header line (first line)
        reader = csv.reader(StringIO('\n'.join(lines[1:])))

        for row in reader:
            if len(row) < 14:
                continue

            try:
                network = {
                    "bssid": row[0].strip(),
                    "first_seen": row[1].strip(),
                    "last_seen": row[2].strip(),
                    "channel": self._safe_int(row[3]),
                    "speed": self._safe_int(row[4]),
                    "privacy": row[5].strip(),
                    "cipher": row[6].strip(),
                    "authentication": row[7].strip(),
                    "power": self._safe_int(row[8]),
                    "beacons": self._safe_int(row[9]),
                    "iv": self._safe_int(row[10]),
                    "lan_ip": row[11].strip() if len(row) > 11 else "",
                    "id_length": self._safe_int(row[12]) if len(row) > 12 else 0,
                    "essid": row[13].strip() if len(row) > 13 else "",
                    "key": row[14].strip() if len(row) > 14 else "",
                }

                # Parse encryption details
                network["encryption"] = self._parse_encryption(
                    network["privacy"],
                    network["cipher"],
                    network["authentication"]
                )

                # Signal strength quality
                network["signal_quality"] = self._calculate_signal_quality(network["power"])

                networks.append(network)

            except (IndexError, ValueError) as e:
                logger.debug(f"Failed to parse network row: {e}")
                continue

        return networks

    def _parse_clients_section(self, section: str) -> list[dict[str, Any]]:
        """Parse the clients section of CSV."""
        clients = []
        lines = section.strip().split('\n')

        if len(lines) < 2:
            return clients

        # Skip header line
        reader = csv.reader(StringIO('\n'.join(lines[1:])))

        for row in reader:
            if len(row) < 6:
                continue

            try:
                client = {
                    "station_mac": row[0].strip(),
                    "first_seen": row[1].strip(),
                    "last_seen": row[2].strip(),
                    "power": self._safe_int(row[3]),
                    "packets": self._safe_int(row[4]),
                    "bssid": row[5].strip(),
                    "probed_essids": [],
                }

                # Parse probed ESSIDs if available
                if len(row) > 6 and row[6].strip():
                    probes = row[6].strip()
                    client["probed_essids"] = [p.strip() for p in probes.split(',') if p.strip()]

                # Associated or probing
                client["associated"] = client["bssid"] != "(not associated)"

                clients.append(client)

            except (IndexError, ValueError) as e:
                logger.debug(f"Failed to parse client row: {e}")
                continue

        return clients

    def _parse_terminal_output(self, output: str) -> dict[str, Any]:
        """Parse live terminal output from airodump-ng."""
        networks = []
        clients = []

        in_client_section = False
        lines = output.strip().split('\n')

        for line in lines:
            line = line.strip()

            # Detect section switch
            if "BSSID" in line and "STATION" in line:
                in_client_section = True
                continue
            elif "BSSID" in line and "PWR" in line and "Beacons" in line:
                in_client_section = False
                continue

            # Skip headers and empty lines
            if not line or line.startswith("BSSID") or line.startswith("CH"):
                continue

            if in_client_section:
                # Parse client line
                client = self._parse_client_line(line)
                if client:
                    clients.append(client)
            else:
                # Parse network line
                network = self._parse_network_line(line)
                if network:
                    networks.append(network)

        return {"networks": networks, "clients": clients}

    def _parse_network_line(self, line: str) -> dict[str, Any] | None:
        """Parse a single network line from terminal output."""
        # Pattern: BSSID  PWR  Beacons  #Data  #/s  CH  MB  ENC  CIPHER  AUTH  ESSID
        pattern = r'([0-9A-Fa-f:]{17})\s+(-?\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+e?)\s+(\S+)\s+(\S+)\s+(\S+)\s*(.*)'
        match = re.match(pattern, line)

        if not match:
            return None

        try:
            return {
                "bssid": match.group(1),
                "power": int(match.group(2)),
                "beacons": int(match.group(3)),
                "data": int(match.group(4)),
                "per_second": int(match.group(5)),
                "channel": int(match.group(6)),
                "speed": match.group(7),
                "privacy": match.group(8),
                "cipher": match.group(9),
                "authentication": match.group(10),
                "essid": match.group(11).strip(),
                "encryption": self._parse_encryption(
                    match.group(8), match.group(9), match.group(10)
                ),
                "signal_quality": self._calculate_signal_quality(int(match.group(2))),
            }
        except (ValueError, IndexError):
            return None

    def _parse_client_line(self, line: str) -> dict[str, Any] | None:
        """Parse a single client line from terminal output."""
        # Pattern: BSSID  STATION  PWR  Rate  Lost  Frames  Notes  Probes
        pattern = r'([0-9A-Fa-f:]{17}|[\(\)a-z ]+)\s+([0-9A-Fa-f:]{17})\s+(-?\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s*(.*)'
        match = re.match(pattern, line)

        if not match:
            return None

        try:
            bssid = match.group(1).strip()
            probes = match.group(7).strip() if match.group(7) else ""

            return {
                "bssid": bssid,
                "station_mac": match.group(2),
                "power": int(match.group(3)),
                "rate": match.group(4),
                "lost": int(match.group(5)),
                "frames": int(match.group(6)),
                "probed_essids": [p.strip() for p in probes.split(',') if p.strip()],
                "associated": bssid != "(not associated)",
            }
        except (ValueError, IndexError):
            return None

    def _parse_encryption(self, privacy: str, cipher: str, auth: str) -> str:
        """Generate human-readable encryption string."""
        if "WPA3" in privacy:
            return "WPA3"
        elif "WPA2" in privacy:
            if "SAE" in auth:
                return "WPA3"
            return f"WPA2-{cipher}"
        elif "WPA" in privacy:
            return f"WPA-{cipher}"
        elif "WEP" in privacy:
            return "WEP"
        elif "OPN" in privacy:
            return "Open"
        return privacy

    def _calculate_signal_quality(self, power: int) -> str:
        """Convert power level to signal quality descriptor."""
        if power >= -50:
            return "Excellent"
        elif power >= -60:
            return "Good"
        elif power >= -70:
            return "Fair"
        elif power >= -80:
            return "Weak"
        else:
            return "Very Weak"

    def _safe_int(self, value: str) -> int:
        """Safely convert string to int."""
        try:
            return int(value.strip())
        except (ValueError, AttributeError):
            return 0

    async def scan_networks(
        self,
        interface: str,
        channel: int | None = None,
        duration: int = 30,
    ) -> dict[str, Any]:
        """Perform a wireless network scan.

        Args:
            interface: Monitor mode interface
            channel: Specific channel or None for hopping
            duration: Scan duration in seconds

        Returns:
            Dict with networks and clients found
        """
        import tempfile

        with tempfile.NamedTemporaryFile(prefix="airodump_", delete=False) as f:
            output_prefix = f.name

        options = {
            "output": output_prefix,
            "write_interval": 1,
        }

        if channel:
            options["channel"] = channel

        # Set timeout for scan duration
        options["timeout"] = duration

        result = await self.execute(interface, options)
        return result.data

    async def capture_for_target(
        self,
        interface: str,
        bssid: str,
        channel: int,
        output: str,
        duration: int = 60,
    ) -> dict[str, Any]:
        """Capture packets for a specific target AP.

        Args:
            interface: Monitor mode interface
            bssid: Target access point BSSID
            channel: Target channel
            output: Output file prefix
            duration: Capture duration

        Returns:
            Capture statistics
        """
        options = {
            "bssid": bssid,
            "channel": channel,
            "output": output,
            "write_interval": 1,
            "timeout": duration,
        }

        result = await self.execute(interface, options)

        # Emit events for discovered items
        for network in result.data.get("networks", []):
            await event_bus.emit(Events.NETWORK_FOUND, network)

        for client in result.data.get("clients", []):
            await event_bus.emit(Events.CLIENT_FOUND, {
                "client": client,
                "bssid": bssid,
            })

        return result.data
