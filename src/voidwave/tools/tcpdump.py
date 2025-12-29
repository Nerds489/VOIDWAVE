"""TCPDump packet capture wrapper with output parsing."""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any, ClassVar

from pydantic import BaseModel

from voidwave.core.logging import get_logger
from voidwave.orchestration.events import Events, event_bus
from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper

logger = get_logger(__name__)


class TcpdumpConfig(BaseModel):
    """TCPDump-specific configuration."""

    default_count: int = 100  # Default packet count
    snaplen: int = 65535  # Capture length
    verbose: bool = False
    immediate_mode: bool = True


class TcpdumpTool(BaseToolWrapper):
    """TCPDump packet capture wrapper."""

    TOOL_BINARY: ClassVar[str] = "tcpdump"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="tcpdump",
        version="1.0.0",
        description="Packet capture and analysis",
        author="VOIDWAVE",
        plugin_type=PluginType.TOOL,
        capabilities=[Capability.PACKET_CAPTURE],
        requires_root=True,
        external_tools=["tcpdump"],
        config_schema=TcpdumpConfig,
    )

    # Common BPF filter templates
    FILTER_TEMPLATES = {
        "tcp": "tcp",
        "udp": "udp",
        "icmp": "icmp",
        "arp": "arp",
        "http": "tcp port 80 or tcp port 443",
        "dns": "udp port 53 or tcp port 53",
        "ssh": "tcp port 22",
        "ftp": "tcp port 20 or tcp port 21",
        "smtp": "tcp port 25 or tcp port 587",
        "dhcp": "udp port 67 or udp port 68",
        "ntp": "udp port 123",
    }

    def __init__(self, tcpdump_config: TcpdumpConfig | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self.tcpdump_config = tcpdump_config or TcpdumpConfig()

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build tcpdump command.

        Args:
            target: Network interface to capture on
            options: Command options including:
                - count: Number of packets to capture (-c)
                - output: Output pcap file (-w)
                - filter: BPF filter expression
                - snaplen: Snapshot length (-s)
                - verbose: Verbose output (-v, -vv, -vvv)
                - no_resolve: Don't resolve addresses (-n)
                - immediate: Immediate mode (-l)
                - timestamp: Timestamp format (-t, -tt, -ttt)
                - hex: Show hex dump (-X)
                - ascii: Show ASCII (-A)
                - read_file: Read from pcap file (-r)
        """
        cmd = []

        # Interface
        cmd.extend(["-i", target])

        # Count
        count = options.get("count")
        if count:
            cmd.extend(["-c", str(count)])

        # Output file
        output = options.get("output")
        if output:
            cmd.extend(["-w", str(output)])

        # Snapshot length
        snaplen = options.get("snaplen", self.tcpdump_config.snaplen)
        cmd.extend(["-s", str(snaplen)])

        # Verbose level
        verbose = options.get("verbose", self.tcpdump_config.verbose)
        if verbose:
            if verbose is True or verbose == 1:
                cmd.append("-v")
            elif verbose == 2:
                cmd.append("-vv")
            elif verbose >= 3:
                cmd.append("-vvv")

        # Don't resolve addresses
        if options.get("no_resolve", True):
            cmd.append("-n")

        # Immediate mode (line buffered)
        if options.get("immediate", self.tcpdump_config.immediate_mode):
            cmd.append("-l")

        # Timestamp format
        timestamp = options.get("timestamp")
        if timestamp == "none":
            cmd.append("-t")
        elif timestamp == "unix":
            cmd.append("-tt")
        elif timestamp == "delta":
            cmd.append("-ttt")
        elif timestamp == "date":
            cmd.append("-tttt")

        # Hex dump
        if options.get("hex"):
            cmd.append("-X")

        # ASCII
        if options.get("ascii"):
            cmd.append("-A")

        # Read from file
        read_file = options.get("read_file")
        if read_file:
            cmd.extend(["-r", str(read_file)])

        # BPF filter expression
        filter_expr = options.get("filter")
        if filter_expr:
            # Check if it's a template name
            if filter_expr in self.FILTER_TEMPLATES:
                filter_expr = self.FILTER_TEMPLATES[filter_expr]
            cmd.append(filter_expr)

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse tcpdump output."""
        result = {
            "raw_output": output,
            "packets": [],
            "packet_count": 0,
            "protocols": {},
            "hosts": set(),
            "connections": [],
        }

        lines = output.strip().split('\n')

        for line in lines:
            packet = self._parse_packet_line(line)
            if packet:
                result["packets"].append(packet)
                result["packet_count"] += 1

                # Track protocols
                protocol = packet.get("protocol", "unknown")
                result["protocols"][protocol] = result["protocols"].get(protocol, 0) + 1

                # Track hosts
                if packet.get("src_ip"):
                    result["hosts"].add(packet["src_ip"])
                if packet.get("dst_ip"):
                    result["hosts"].add(packet["dst_ip"])

        # Convert set to list for JSON serialization
        result["hosts"] = list(result["hosts"])

        return result

    def _parse_packet_line(self, line: str) -> dict[str, Any] | None:
        """Parse a single packet line from tcpdump output."""
        if not line.strip():
            return None

        packet = {
            "raw": line,
            "timestamp": None,
            "src_ip": None,
            "src_port": None,
            "dst_ip": None,
            "dst_port": None,
            "protocol": "unknown",
            "flags": [],
            "length": 0,
        }

        # Try to extract timestamp
        timestamp_match = re.match(r'^(\d+:\d+:\d+\.\d+)\s+', line)
        if timestamp_match:
            packet["timestamp"] = timestamp_match.group(1)
            line = line[timestamp_match.end():]

        # IP packet pattern: IP src > dst: protocol
        ip_match = re.search(
            r'IP\s+(\d+\.\d+\.\d+\.\d+)(?:\.(\d+))?\s+>\s+(\d+\.\d+\.\d+\.\d+)(?:\.(\d+))?',
            line
        )
        if ip_match:
            packet["src_ip"] = ip_match.group(1)
            packet["src_port"] = int(ip_match.group(2)) if ip_match.group(2) else None
            packet["dst_ip"] = ip_match.group(3)
            packet["dst_port"] = int(ip_match.group(4)) if ip_match.group(4) else None

        # Detect protocol
        if " ICMP " in line or "icmp" in line.lower():
            packet["protocol"] = "ICMP"
        elif " UDP " in line or "udp" in line.lower():
            packet["protocol"] = "UDP"
        elif " TCP " in line or "Flags [" in line:
            packet["protocol"] = "TCP"

            # Extract TCP flags
            flags_match = re.search(r'Flags \[([^\]]+)\]', line)
            if flags_match:
                flags_str = flags_match.group(1)
                packet["flags"] = [f.strip() for f in flags_str.split(',') if f.strip()]
        elif " ARP " in line or "arp" in line.lower():
            packet["protocol"] = "ARP"

            # ARP specific parsing
            arp_match = re.search(
                r'(\d+\.\d+\.\d+\.\d+).*?(\d+\.\d+\.\d+\.\d+)',
                line
            )
            if arp_match:
                packet["src_ip"] = arp_match.group(1)
                packet["dst_ip"] = arp_match.group(2)

        # Extract length
        length_match = re.search(r'length\s+(\d+)', line)
        if length_match:
            packet["length"] = int(length_match.group(1))

        return packet

    async def capture_packets(
        self,
        interface: str,
        count: int = 100,
        filter_expr: str | None = None,
    ) -> dict[str, Any]:
        """Capture packets from network interface.

        Args:
            interface: Network interface
            count: Number of packets to capture
            filter_expr: BPF filter expression

        Returns:
            Captured packets data
        """
        options = {
            "count": count,
            "no_resolve": True,
        }

        if filter_expr:
            options["filter"] = filter_expr

        result = await self.execute(interface, options)
        return result.data

    async def capture_to_file(
        self,
        interface: str,
        output_file: str,
        count: int | None = None,
        filter_expr: str | None = None,
        duration: int | None = None,
    ) -> dict[str, Any]:
        """Capture packets to pcap file.

        Args:
            interface: Network interface
            output_file: Output pcap file path
            count: Number of packets (None = until stopped)
            filter_expr: BPF filter expression
            duration: Capture duration in seconds

        Returns:
            Capture statistics
        """
        options = {
            "output": output_file,
            "no_resolve": True,
        }

        if count:
            options["count"] = count

        if filter_expr:
            options["filter"] = filter_expr

        if duration:
            options["timeout"] = duration

        result = await self.execute(interface, options)

        # Emit event
        event_bus.emit(Events.CAPTURE_SAVED, {
            "file": output_file,
            "interface": interface,
            "packet_count": result.data.get("packet_count", 0),
        })

        return result.data

    async def read_pcap(
        self,
        pcap_file: str,
        filter_expr: str | None = None,
        count: int | None = None,
    ) -> dict[str, Any]:
        """Read and parse a pcap file.

        Args:
            pcap_file: Path to pcap file
            filter_expr: BPF filter expression
            count: Number of packets to read

        Returns:
            Parsed packet data
        """
        options = {
            "read_file": pcap_file,
            "no_resolve": True,
        }

        if filter_expr:
            options["filter"] = filter_expr

        if count:
            options["count"] = count

        # Use "any" as interface when reading from file
        result = await self.execute("any", options)
        return result.data

    async def capture_http(
        self,
        interface: str,
        count: int = 100,
    ) -> dict[str, Any]:
        """Capture HTTP/HTTPS traffic.

        Args:
            interface: Network interface
            count: Number of packets

        Returns:
            HTTP traffic data
        """
        return await self.capture_packets(
            interface=interface,
            count=count,
            filter_expr="http",
        )

    async def capture_dns(
        self,
        interface: str,
        count: int = 100,
    ) -> dict[str, Any]:
        """Capture DNS traffic.

        Args:
            interface: Network interface
            count: Number of packets

        Returns:
            DNS traffic data
        """
        return await self.capture_packets(
            interface=interface,
            count=count,
            filter_expr="dns",
        )

    async def capture_from_host(
        self,
        interface: str,
        host: str,
        count: int = 100,
    ) -> dict[str, Any]:
        """Capture traffic from/to specific host.

        Args:
            interface: Network interface
            host: Target host IP
            count: Number of packets

        Returns:
            Traffic data for host
        """
        filter_expr = f"host {host}"
        return await self.capture_packets(
            interface=interface,
            count=count,
            filter_expr=filter_expr,
        )
