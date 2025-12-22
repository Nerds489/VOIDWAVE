"""TCPDump packet capture wrapper."""
from typing import Any, ClassVar

from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper


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
    )

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build tcpdump command."""
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

        # Filter
        filter_expr = options.get("filter")
        if filter_expr:
            cmd.append(filter_expr)

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse tcpdump output."""
        # Stub implementation
        return {"raw_output": output, "packets": []}
