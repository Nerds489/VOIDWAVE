"""AUTO-ACQUIRE handler for acquiring missing inputs."""

from typing import Any

from voidwave.automation.labels import AUTO_REGISTRY
from voidwave.automation.subflows import SubflowManager, SubflowType


class AutoAcquireHandler:
    """Handles AUTO-ACQUIRE for acquiring missing inputs through subflows."""

    def __init__(self, input_type: str = "", session: Any = None) -> None:
        self.input_type = input_type
        self.session = session
        self.subflow_manager = SubflowManager(session) if session else None

    async def can_fix(self) -> bool:
        """Acquisition subflows are always available."""
        return True

    async def fix(self) -> bool:
        """Launch acquisition subflow.

        Note: This returns False because the actual acquisition
        happens in the TUI through a subflow screen.
        """
        if self.subflow_manager:
            await self.subflow_manager.acquire(
                self.input_type,
                parent_action="",  # Set by caller
            )
        return False  # Requires TUI interaction

    async def get_ui_prompt(self) -> str:
        """Get the UI prompt for this fix."""
        prompts = {
            "target": "No target selected. Scan for networks?",
            "target_wifi": "No WiFi target selected. Scan for networks?",
            "target_host": "No host target specified. Enter target IP/hostname?",
            "client": "No client selected. Scan for clients?",
            "handshake": "No handshake captured. Capture now?",
            "pmkid": "No PMKID captured. Capture now?",
            "wordlist": "No wordlist selected. Download default?",
            "portal": "No portal assets. Generate defaults?",
            "certs": "No certificates found. Generate self-signed?",
            "capture_file": "No capture file selected. Browse for file?",
            "hash_file": "No hash file selected. Browse for file?",
        }
        return prompts.get(self.input_type, f"Acquire {self.input_type}?")

    def get_subflow_type(self) -> SubflowType:
        """Get the subflow type for this input."""
        mapping = {
            "target": SubflowType.SCAN_NETWORKS,
            "target_wifi": SubflowType.SCAN_NETWORKS,
            "target_host": SubflowType.ENTER_TARGET,
            "client": SubflowType.SCAN_CLIENTS,
            "handshake": SubflowType.CAPTURE_HANDSHAKE,
            "pmkid": SubflowType.CAPTURE_PMKID,
            "wordlist": SubflowType.DOWNLOAD_WORDLIST,
            "portal": SubflowType.GENERATE_PORTAL,
            "certs": SubflowType.GENERATE_CERTS,
        }
        return mapping.get(self.input_type, SubflowType.ENTER_TARGET)


# Register the handler
AUTO_REGISTRY.register("AUTO-ACQUIRE", AutoAcquireHandler)
