"""Hydra network authentication cracker wrapper."""
from typing import Any, ClassVar

from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper


class HydraTool(BaseToolWrapper):
    """Hydra network authentication cracker wrapper."""

    TOOL_BINARY: ClassVar[str] = "hydra"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="hydra",
        version="1.0.0",
        description="Network authentication cracker",
        author="VOIDWAVE",
        plugin_type=PluginType.CRACKER,
        capabilities=[Capability.PASSWORD_CRACK],
        requires_root=False,
        external_tools=["hydra"],
    )

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build hydra command."""
        cmd = []

        # Service
        service = options.get("service", "ssh")

        # Username/wordlists
        username = options.get("username")
        if username:
            cmd.extend(["-l", username])

        user_list = options.get("user_list")
        if user_list:
            cmd.extend(["-L", str(user_list)])

        password = options.get("password")
        if password:
            cmd.extend(["-p", password])

        pass_list = options.get("pass_list")
        if pass_list:
            cmd.extend(["-P", str(pass_list)])

        # Threads
        threads = options.get("threads", 16)
        cmd.extend(["-t", str(threads)])

        # Target and service
        cmd.extend([target, service])

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse hydra output."""
        # Stub implementation
        return {"raw_output": output, "credentials": []}
