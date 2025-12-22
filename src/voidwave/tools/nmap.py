"""Nmap network scanner wrapper."""
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Any, ClassVar

from pydantic import BaseModel

from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper


class NmapConfig(BaseModel):
    """Nmap-specific configuration."""

    timing_template: int = 3  # -T0 to -T5
    default_ports: str = "1-1000"
    service_detection: bool = True
    os_detection: bool = False
    script_scan: bool = False
    scripts: list[str] = []
    output_format: str = "xml"  # xml, normal, greppable


@dataclass
class NmapHost:
    """Parsed Nmap host result."""

    ip: str
    hostname: str | None
    state: str
    ports: list[dict]
    os_matches: list[dict]
    scripts: list[dict]


class NmapTool(BaseToolWrapper):
    """Nmap network scanner wrapper."""

    TOOL_BINARY: ClassVar[str] = "nmap"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="nmap",
        version="1.0.0",
        description="Network exploration and security auditing tool",
        author="VOIDWAVE",
        plugin_type=PluginType.SCANNER,
        capabilities=[
            Capability.NETWORK_SCAN,
            Capability.PORT_SCAN,
            Capability.SERVICE_ENUM,
            Capability.VULN_SCAN,
        ],
        requires_root=True,  # For some scan types
        external_tools=["nmap"],
        config_schema=NmapConfig,
    )

    # Scan type presets
    SCAN_TYPES = {
        "quick": ["-T4", "-F"],
        "standard": ["-T3", "-sV"],
        "full": ["-T4", "-A", "-p-"],
        "stealth": ["-T2", "-sS", "-Pn"],
        "udp": ["-sU", "--top-ports", "100"],
        "vuln": ["--script", "vuln"],
    }

    def __init__(self, nmap_config: NmapConfig | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self.nmap_config = nmap_config or NmapConfig()
        self._output_file: Path | None = None

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build nmap command."""
        cmd = []

        # Scan type preset
        scan_type = options.get("scan_type", "standard")
        if scan_type in self.SCAN_TYPES:
            cmd.extend(self.SCAN_TYPES[scan_type])

        # Timing template
        timing = options.get("timing", self.nmap_config.timing_template)
        if f"-T{timing}" not in cmd:
            cmd.append(f"-T{timing}")

        # Port specification
        ports = options.get("ports", self.nmap_config.default_ports)
        if ports and "-p" not in " ".join(cmd):
            cmd.extend(["-p", ports])

        # Service detection
        if options.get("service_detection", self.nmap_config.service_detection):
            if "-sV" not in cmd and "-A" not in cmd:
                cmd.append("-sV")

        # OS detection (requires root)
        if options.get("os_detection", self.nmap_config.os_detection):
            if "-O" not in cmd and "-A" not in cmd:
                cmd.append("-O")

        # Script scanning
        scripts = options.get("scripts", self.nmap_config.scripts)
        if scripts:
            cmd.extend(["--script", ",".join(scripts)])

        # XML output for parsing
        self._output_file = Path(NamedTemporaryFile(suffix=".xml", delete=False).name)
        cmd.extend(["-oX", str(self._output_file)])

        # Target
        cmd.append(target)

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse nmap XML output."""
        if self._output_file is None or not self._output_file.exists():
            return self._parse_text_output(output)

        try:
            return self._parse_xml_output()
        except Exception as e:
            # Fallback to text parsing
            return self._parse_text_output(output)
        finally:
            # Cleanup temp file
            if self._output_file and self._output_file.exists():
                self._output_file.unlink()

    def _parse_xml_output(self) -> dict[str, Any]:
        """Parse nmap XML output file."""
        tree = ET.parse(self._output_file)
        root = tree.getroot()

        hosts = []

        for host_elem in root.findall(".//host"):
            # Get IP address
            addr_elem = host_elem.find("address[@addrtype='ipv4']")
            if addr_elem is None:
                continue
            ip = addr_elem.get("addr", "")

            # Get hostname
            hostname = None
            hostname_elem = host_elem.find(".//hostname")
            if hostname_elem is not None:
                hostname = hostname_elem.get("name")

            # Get state
            status_elem = host_elem.find("status")
            state = (
                status_elem.get("state", "unknown")
                if status_elem is not None
                else "unknown"
            )

            # Get ports
            ports = []
            for port_elem in host_elem.findall(".//port"):
                port_info = {
                    "port": int(port_elem.get("portid", 0)),
                    "protocol": port_elem.get("protocol", "tcp"),
                    "state": "unknown",
                    "service": "unknown",
                    "version": None,
                }

                state_elem = port_elem.find("state")
                if state_elem is not None:
                    port_info["state"] = state_elem.get("state", "unknown")

                service_elem = port_elem.find("service")
                if service_elem is not None:
                    port_info["service"] = service_elem.get("name", "unknown")
                    port_info["version"] = service_elem.get("version")
                    port_info["product"] = service_elem.get("product")

                ports.append(port_info)

            # Get OS matches
            os_matches = []
            for os_elem in host_elem.findall(".//osmatch"):
                os_matches.append(
                    {
                        "name": os_elem.get("name"),
                        "accuracy": int(os_elem.get("accuracy", 0)),
                    }
                )

            # Get script results
            scripts = []
            for script_elem in host_elem.findall(".//script"):
                scripts.append(
                    {
                        "id": script_elem.get("id"),
                        "output": script_elem.get("output"),
                    }
                )

            hosts.append(
                {
                    "ip": ip,
                    "hostname": hostname,
                    "state": state,
                    "ports": ports,
                    "os_matches": os_matches,
                    "scripts": scripts,
                }
            )

        # Get scan info
        scaninfo = root.find("scaninfo")
        run_stats = root.find("runstats/finished")

        return {
            "hosts": hosts,
            "scan_info": {
                "type": scaninfo.get("type") if scaninfo is not None else None,
                "protocol": scaninfo.get("protocol") if scaninfo is not None else None,
                "elapsed": run_stats.get("elapsed") if run_stats is not None else None,
            },
            "summary": {
                "total_hosts": len(hosts),
                "up_hosts": sum(1 for h in hosts if h["state"] == "up"),
                "total_ports": sum(len(h["ports"]) for h in hosts),
                "open_ports": sum(
                    sum(1 for p in h["ports"] if p["state"] == "open") for h in hosts
                ),
            },
        }

    def _parse_text_output(self, output: str) -> dict[str, Any]:
        """Fallback text output parsing."""
        hosts = []
        current_host = None

        for line in output.splitlines():
            # Host discovery
            host_match = re.match(r"Nmap scan report for (\S+)", line)
            if host_match:
                if current_host:
                    hosts.append(current_host)
                current_host = {
                    "ip": host_match.group(1),
                    "ports": [],
                }
                continue

            # Port line
            port_match = re.match(r"(\d+)/(tcp|udp)\s+(\w+)\s+(\S+)", line)
            if port_match and current_host:
                current_host["ports"].append(
                    {
                        "port": int(port_match.group(1)),
                        "protocol": port_match.group(2),
                        "state": port_match.group(3),
                        "service": port_match.group(4),
                    }
                )

        if current_host:
            hosts.append(current_host)

        return {"hosts": hosts}

    async def quick_scan(self, target: str) -> dict[str, Any]:
        """Perform a quick scan."""
        result = await self.execute(target, {"scan_type": "quick"})
        return result.data

    async def full_scan(self, target: str) -> dict[str, Any]:
        """Perform a comprehensive scan."""
        result = await self.execute(target, {"scan_type": "full"})
        return result.data

    async def vuln_scan(self, target: str) -> dict[str, Any]:
        """Perform vulnerability scan."""
        result = await self.execute(target, {"scan_type": "vuln"})
        return result.data
