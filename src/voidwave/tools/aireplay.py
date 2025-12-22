"""Aireplay-ng wireless packet injection wrapper."""
from typing import Any, ClassVar

from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper


class AireplayTool(BaseToolWrapper):
    """Aireplay-ng wireless packet injection wrapper."""

    TOOL_BINARY: ClassVar[str] = "aireplay-ng"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="aireplay-ng",
        version="1.0.0",
        description="Wireless packet injection",
        author="VOIDWAVE",
        plugin_type=PluginType.TOOL,
        capabilities=[Capability.WIRELESS_ATTACK],
        requires_root=True,
        external_tools=["aireplay-ng"],
    )

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build aireplay-ng command."""
        cmd = []

        # Attack mode
        attack = options.get("attack", "deauth")

        if attack == "deauth":
            deauth_count = options.get("count", 10)
            cmd.extend(["--deauth", str(deauth_count)])

        # Access point
        bssid = options.get("bssid")
        if bssid:
            cmd.extend(["-a", bssid])

        # Client
        client = options.get("client")
        if client:
            cmd.extend(["-c", client])

        # Interface (target)
        cmd.append(target)

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse aireplay-ng output."""
        # Stub implementation
        return {"raw_output": output}
