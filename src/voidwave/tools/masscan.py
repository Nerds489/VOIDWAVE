"""Masscan fast port scanner wrapper."""
from typing import Any, ClassVar

from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper


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
    )

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build masscan command."""
        cmd = []

        # Ports
        ports = options.get("ports", "1-1000")
        cmd.extend(["-p", ports])

        # Rate
        rate = options.get("rate", 1000)
        cmd.extend(["--rate", str(rate)])

        # Target
        cmd.append(target)

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse masscan output."""
        # Stub implementation
        return {"raw_output": output, "hosts": []}
