"""John the Ripper password cracker wrapper."""
from typing import Any, ClassVar

from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper


class JohnTool(BaseToolWrapper):
    """John the Ripper password cracker wrapper."""

    TOOL_BINARY: ClassVar[str] = "john"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="john",
        version="1.0.0",
        description="Password cracker",
        author="VOIDWAVE",
        plugin_type=PluginType.CRACKER,
        capabilities=[Capability.PASSWORD_CRACK],
        requires_root=False,
        external_tools=["john"],
    )

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build john command."""
        cmd = []

        # Wordlist
        wordlist = options.get("wordlist")
        if wordlist:
            cmd.extend(["--wordlist=" + str(wordlist)])

        # Format
        format_type = options.get("format")
        if format_type:
            cmd.extend(["--format=" + format_type])

        # Rules
        rules = options.get("rules")
        if rules:
            cmd.extend(["--rules=" + rules])

        # Target file
        cmd.append(target)

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse john output."""
        # Stub implementation
        return {"raw_output": output, "cracked": []}
