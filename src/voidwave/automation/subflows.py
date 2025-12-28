"""Subflow acquisition system for acquiring missing inputs."""

from dataclasses import dataclass, field
from enum import Enum
from typing import Any, TYPE_CHECKING

if TYPE_CHECKING:
    from voidwave.core.session import Session


class SubflowType(Enum):
    """Types of acquisition subflows."""

    SCAN_NETWORKS = "scan_networks"
    SCAN_CLIENTS = "scan_clients"
    CAPTURE_HANDSHAKE = "capture_handshake"
    CAPTURE_PMKID = "capture_pmkid"
    CAPTURE_PIXIE = "capture_pixie"
    GENERATE_PORTAL = "generate_portal"
    GENERATE_CERTS = "generate_certs"
    DOWNLOAD_WORDLIST = "download_wordlist"
    ENTER_TARGET = "enter_target"
    ENTER_API_KEY = "enter_api_key"


@dataclass
class SubflowContext:
    """Context passed to and from subflows."""

    subflow_type: SubflowType
    parent_action: str
    params: dict[str, Any] = field(default_factory=dict)
    result: Any = None
    success: bool = False


class SubflowManager:
    """Manages subflow execution and return."""

    def __init__(self, session: "Session") -> None:
        self.session = session
        self.stack: list[SubflowContext] = []

    async def acquire(self, input_type: str, parent_action: str) -> SubflowContext:
        """Start an acquisition subflow."""
        subflow_type = self._map_input_to_subflow(input_type)
        ctx = SubflowContext(
            subflow_type=subflow_type,
            parent_action=parent_action,
        )
        self.stack.append(ctx)
        return ctx

    async def complete(self, result: Any) -> SubflowContext | None:
        """Complete current subflow and return."""
        if not self.stack:
            return None

        ctx = self.stack.pop()
        ctx.result = result
        ctx.success = result is not None

        # Store result in session
        self._store_result(ctx)

        return ctx

    def current_context(self) -> SubflowContext | None:
        """Get the current subflow context."""
        return self.stack[-1] if self.stack else None

    def has_active_subflow(self) -> bool:
        """Check if there's an active subflow."""
        return len(self.stack) > 0

    def _map_input_to_subflow(self, input_type: str) -> SubflowType:
        """Map input type to subflow type."""
        mapping = {
            "target": SubflowType.SCAN_NETWORKS,
            "target_wifi": SubflowType.SCAN_NETWORKS,
            "target_host": SubflowType.ENTER_TARGET,
            "client": SubflowType.SCAN_CLIENTS,
            "handshake": SubflowType.CAPTURE_HANDSHAKE,
            "pmkid": SubflowType.CAPTURE_PMKID,
            "pixie": SubflowType.CAPTURE_PIXIE,
            "portal": SubflowType.GENERATE_PORTAL,
            "certs": SubflowType.GENERATE_CERTS,
            "wordlist": SubflowType.DOWNLOAD_WORDLIST,
            "target_ip": SubflowType.ENTER_TARGET,
            "target_url": SubflowType.ENTER_TARGET,
            "api_key": SubflowType.ENTER_API_KEY,
        }
        return mapping.get(input_type, SubflowType.ENTER_TARGET)

    def _store_result(self, ctx: SubflowContext) -> None:
        """Store subflow result in session."""
        if not ctx.success or ctx.result is None:
            return

        # Map results to session attributes
        if ctx.subflow_type == SubflowType.SCAN_NETWORKS:
            if hasattr(self.session, "selected_target"):
                self.session.selected_target = ctx.result
        elif ctx.subflow_type == SubflowType.SCAN_CLIENTS:
            if hasattr(self.session, "selected_client"):
                self.session.selected_client = ctx.result
        elif ctx.subflow_type in (
            SubflowType.CAPTURE_HANDSHAKE,
            SubflowType.CAPTURE_PMKID,
        ):
            if hasattr(self.session, "capture_file"):
                self.session.capture_file = ctx.result
        elif ctx.subflow_type == SubflowType.DOWNLOAD_WORDLIST:
            if hasattr(self.session, "wordlist"):
                self.session.wordlist = ctx.result
        elif ctx.subflow_type == SubflowType.ENTER_TARGET:
            if hasattr(self.session, "target"):
                self.session.target = ctx.result
