"""AUTO-PRIV handler for privilege escalation."""

import asyncio
import os
import shutil

from voidwave.automation.labels import AUTO_REGISTRY


class AutoPrivHandler:
    """Handles AUTO-PRIV for privilege escalation."""

    def __init__(self) -> None:
        self.elevation_method: str | None = None

    async def can_fix(self) -> bool:
        """Check if we can escalate privileges."""
        # Already root
        if os.geteuid() == 0:
            return False

        # Check for elevation methods
        return shutil.which("pkexec") is not None or shutil.which("sudo") is not None

    async def fix(self) -> bool:
        """Request privilege escalation.

        Note: This typically requires re-launching the app or using
        polkit for specific actions. Returns False as we can't
        directly escalate the running process.
        """
        # For now, we inform that elevation is needed but can't
        # actually elevate the running process
        if shutil.which("pkexec"):
            self.elevation_method = "pkexec"
            return False  # Requires re-launch
        elif shutil.which("sudo"):
            self.elevation_method = "sudo"
            return False  # Requires re-launch

        return False

    async def get_ui_prompt(self) -> str:
        """Get the UI prompt for this fix."""
        if os.geteuid() == 0:
            return "Already running as root."

        method = "pkexec" if shutil.which("pkexec") else "sudo"
        return f"This action requires root privileges. Re-launch with {method}?"

    @staticmethod
    def get_relaunch_command() -> str:
        """Get the command to re-launch as root."""
        import sys

        if shutil.which("pkexec"):
            return f"pkexec {sys.executable} -m voidwave"
        elif shutil.which("sudo"):
            return f"sudo {sys.executable} -m voidwave"
        return ""

    @staticmethod
    async def run_privileged(command: str) -> tuple[int, str, str]:
        """Run a single command with elevated privileges."""
        if os.geteuid() == 0:
            # Already root
            cmd = command
        elif shutil.which("pkexec"):
            cmd = f"pkexec {command}"
        elif shutil.which("sudo"):
            cmd = f"sudo {command}"
        else:
            return (1, "", "No privilege escalation method available")

        proc = await asyncio.create_subprocess_shell(
            cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await proc.communicate()
        return (proc.returncode or 0, stdout.decode(), stderr.decode())


# Register the handler
AUTO_REGISTRY.register("AUTO-PRIV", AutoPrivHandler)
