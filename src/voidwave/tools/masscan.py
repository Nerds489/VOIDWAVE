"""Masscan fast port scanner wrapper with JSON parsing."""
from __future__ import annotations

import json
import re
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Any, ClassVar

from pydantic import BaseModel

from voidwave.core.logging import get_logger
from voidwave.orchestration.events import Events, event_bus
from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper

logger = get_logger(__name__)


class MasscanConfig(BaseModel):
    """Masscan-specific configuration."""

    default_rate: int = 1000  # packets per second
    max_rate: int = 100000
    default_ports: str = "1-1000"
    wait: int = 10  # seconds to wait after sending
    retries: int = 0


class MasscanTool(BaseToolWrapper):
    """Masscan fast port scanner wrapper."""

    TOOL_BINARY: ClassVar[str] = "masscan"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="masscan",
        version="1.0.0",
        description="Fast TCP port scanner",
        author="VOIDWAVE",
        plugin_type=PluginType.SCANNER,
        capabilities=[Capability.PORT_SCAN],
        requires_root=True,
        external_tools=["masscan"],
        config_schema=MasscanConfig,
    )

    def __init__(self, masscan_config: MasscanConfig | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self.masscan_config = masscan_config or MasscanConfig()
        self._output_file: Path | None = None

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build masscan command.

        Args:
            target: Target IP, range, or CIDR
            options: Command options including:
                - ports: Port specification (e.g., "22,80,443" or "1-1000")
                - rate: Packets per second
                - banners: Grab banners
                - source_ip: Source IP to use
                - source_port: Source port range
                - interface: Network interface
                - exclude: IPs to exclude
                - exclude_file: File with IPs to exclude
                - wait: Seconds to wait after sending
                - retries: Number of retries
        """
        cmd = []

        # Target
        cmd.append(target)

        # Ports
        ports = options.get("ports", self.masscan_config.default_ports)
        cmd.extend(["-p", ports])

        # Rate
        rate = options.get("rate", self.masscan_config.default_rate)
        cmd.extend(["--rate", str(min(rate, self.masscan_config.max_rate))])

        # Banner grabbing
        if options.get("banners"):
            cmd.append("--banners")

        # Source IP
        source_ip = options.get("source_ip")
        if source_ip:
            cmd.extend(["--source-ip", source_ip])

        # Source port
        source_port = options.get("source_port")
        if source_port:
            cmd.extend(["--source-port", source_port])

        # Interface
        interface = options.get("interface")
        if interface:
            cmd.extend(["-e", interface])

        # Exclude
        exclude = options.get("exclude")
        if exclude:
            cmd.extend(["--exclude", exclude])

        exclude_file = options.get("exclude_file")
        if exclude_file:
            cmd.extend(["--excludefile", str(exclude_file)])

        # Wait time
        wait = options.get("wait", self.masscan_config.wait)
        cmd.extend(["--wait", str(wait)])

        # Retries
        retries = options.get("retries", self.masscan_config.retries)
        if retries > 0:
            cmd.extend(["--retries", str(retries)])

        # JSON output for parsing
        self._output_file = Path(NamedTemporaryFile(suffix=".json", delete=False).name)
        cmd.extend(["-oJ", str(self._output_file)])

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse masscan output (JSON format)."""
        result = {
            "hosts": [],
            "ports_found": 0,
            "scan_info": {},
        }

        # Try JSON file first
        if self._output_file and self._output_file.exists():
            try:
                return self._parse_json_output()
            except Exception as e:
                logger.warning(f"Failed to parse JSON output: {e}")
            finally:
                if self._output_file.exists():
                    self._output_file.unlink()

        # Fallback to text parsing
        return self._parse_text_output(output)

    def _parse_json_output(self) -> dict[str, Any]:
        """Parse masscan JSON output file."""
        content = self._output_file.read_text()

        # Masscan JSON is an array of objects (without proper JSON array syntax)
        # Need to handle the format: {record},{record},...
        # Fix JSON format if needed
        if not content.strip().startswith('['):
            content = '[' + content.rstrip().rstrip(',') + ']'

        try:
            records = json.loads(content)
        except json.JSONDecodeError:
            # Try line-by-line parsing
            records = []
            for line in content.strip().split('\n'):
                line = line.strip().rstrip(',')
                if line.startswith('{'):
                    try:
                        records.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue

        # Group by host
        hosts_dict: dict[str, dict] = {}

        for record in records:
            ip = record.get("ip", "")
            if not ip:
                continue

            if ip not in hosts_dict:
                hosts_dict[ip] = {
                    "ip": ip,
                    "ports": [],
                    "timestamp": record.get("timestamp", ""),
                }

            # Add port info
            ports = record.get("ports", [])
            for port_info in ports:
                port_data = {
                    "port": port_info.get("port", 0),
                    "protocol": port_info.get("proto", "tcp"),
                    "status": port_info.get("status", "open"),
                    "reason": port_info.get("reason", ""),
                    "ttl": port_info.get("ttl", 0),
                }

                # Service info if available
                service = port_info.get("service", {})
                if service:
                    port_data["service"] = service.get("name", "")
                    port_data["banner"] = service.get("banner", "")

                hosts_dict[ip]["ports"].append(port_data)

        hosts = list(hosts_dict.values())

        return {
            "hosts": hosts,
            "ports_found": sum(len(h["ports"]) for h in hosts),
            "hosts_found": len(hosts),
        }

    def _parse_text_output(self, output: str) -> dict[str, Any]:
        """Parse masscan text output."""
        hosts_dict: dict[str, dict] = {}

        for line in output.strip().split('\n'):
            # Pattern: Discovered open port 22/tcp on 192.168.1.1
            match = re.search(
                r'Discovered open port (\d+)/(\w+) on (\d+\.\d+\.\d+\.\d+)',
                line
            )
            if match:
                port = int(match.group(1))
                protocol = match.group(2)
                ip = match.group(3)

                if ip not in hosts_dict:
                    hosts_dict[ip] = {"ip": ip, "ports": []}

                hosts_dict[ip]["ports"].append({
                    "port": port,
                    "protocol": protocol,
                    "status": "open",
                })

        hosts = list(hosts_dict.values())

        return {
            "hosts": hosts,
            "ports_found": sum(len(h["ports"]) for h in hosts),
            "hosts_found": len(hosts),
        }

    async def fast_scan(
        self,
        target: str,
        ports: str = "1-1000",
        rate: int = 10000,
    ) -> dict[str, Any]:
        """Perform a fast port scan.

        Args:
            target: Target IP, range, or CIDR
            ports: Ports to scan
            rate: Packets per second

        Returns:
            Scan results with open ports
        """
        options = {
            "ports": ports,
            "rate": rate,
        }

        result = await self.execute(target, options)

        # Emit events for discovered hosts and ports
        for host in result.data.get("hosts", []):
            await event_bus.emit(Events.HOST_DISCOVERED, {
                "ip": host["ip"],
                "source": "masscan",
            })

            for port in host.get("ports", []):
                await event_bus.emit(Events.SERVICE_DISCOVERED, {
                    "host": host["ip"],
                    "port": port["port"],
                    "protocol": port["protocol"],
                    "state": port["status"],
                })

        return result.data

    async def full_port_scan(
        self,
        target: str,
        rate: int = 10000,
    ) -> dict[str, Any]:
        """Scan all 65535 ports.

        Args:
            target: Target IP, range, or CIDR
            rate: Packets per second

        Returns:
            Scan results
        """
        return await self.fast_scan(
            target=target,
            ports="1-65535",
            rate=rate,
        )

    async def common_ports_scan(
        self,
        target: str,
        rate: int = 10000,
    ) -> dict[str, Any]:
        """Scan common ports only.

        Args:
            target: Target IP, range, or CIDR
            rate: Packets per second

        Returns:
            Scan results
        """
        common_ports = "21,22,23,25,53,80,110,111,135,139,143,443,445,993,995,1723,3306,3389,5900,8080"
        return await self.fast_scan(
            target=target,
            ports=common_ports,
            rate=rate,
        )

    async def banner_grab(
        self,
        target: str,
        ports: str,
        rate: int = 1000,
    ) -> dict[str, Any]:
        """Scan with banner grabbing.

        Args:
            target: Target IP, range, or CIDR
            ports: Ports to scan
            rate: Packets per second

        Returns:
            Scan results with banners
        """
        options = {
            "ports": ports,
            "rate": rate,
            "banners": True,
        }

        result = await self.execute(target, options)
        return result.data
