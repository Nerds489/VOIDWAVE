"""Event bus for tool coordination and UI updates."""
from enum import Enum
from typing import Any, Callable, Coroutine

from pyee.asyncio import AsyncIOEventEmitter

from voidwave.core.logging import get_logger

logger = get_logger(__name__)


class Events(str, Enum):
    """Standard event types."""

    # Tool lifecycle
    TOOL_STARTED = "tool.started"
    TOOL_OUTPUT = "tool.output"
    TOOL_PROGRESS = "tool.progress"
    TOOL_COMPLETED = "tool.completed"
    TOOL_FAILED = "tool.failed"
    STOP_ALL_TOOLS = "tool.stop_all"

    # Task management
    TASK_STARTED = "task.started"
    TASK_PROGRESS = "task.progress"
    TASK_COMPLETED = "task.completed"

    # Discovery
    HOST_DISCOVERED = "discovery.host"
    SERVICE_DISCOVERED = "discovery.service"
    VULNERABILITY_FOUND = "discovery.vulnerability"

    # Wireless
    NETWORK_FOUND = "wireless.network"
    HANDSHAKE_CAPTURED = "wireless.handshake"
    PMKID_CAPTURED = "wireless.pmkid"
    CREDENTIAL_CRACKED = "wireless.cracked"

    # Session
    SESSION_STARTED = "session.started"
    SESSION_UPDATED = "session.updated"
    SESSION_ENDED = "session.ended"

    # UI
    STATUS_UPDATE = "ui.status"
    NOTIFICATION = "ui.notification"


EventHandler = Callable[[dict[str, Any]], Coroutine[Any, Any, None]]


class VoidwaveEventBus(AsyncIOEventEmitter):
    """Event bus with typed events and logging."""

    def __init__(self) -> None:
        super().__init__()
        self._event_history: list[tuple[str, dict]] = []
        self._max_history = 1000

    async def emit(self, event: Events | str, data: dict[str, Any] | None = None) -> None:
        """Emit an event."""
        event_name = event.value if isinstance(event, Events) else event
        data = data or {}

        # Log event
        logger.debug(f"Event: {event_name} - {data}")

        # Store in history
        self._event_history.append((event_name, data))
        if len(self._event_history) > self._max_history:
            self._event_history.pop(0)

        # Emit to listeners
        super().emit(event_name, data)

    def on(self, event: Events | str, handler: EventHandler) -> None:
        """Register an event handler."""
        event_name = event.value if isinstance(event, Events) else event
        super().on(event_name, handler)

    def off(self, event: Events | str, handler: EventHandler) -> None:
        """Remove an event handler."""
        event_name = event.value if isinstance(event, Events) else event
        super().remove_listener(event_name, handler)

    def get_history(
        self, event: Events | str | None = None, limit: int = 100
    ) -> list[tuple[str, dict]]:
        """Get event history, optionally filtered by event type."""
        history = self._event_history[-limit:]

        if event is not None:
            event_name = event.value if isinstance(event, Events) else event
            history = [(e, d) for e, d in history if e == event_name]

        return history


# Singleton event bus
event_bus = VoidwaveEventBus()
