"""AUTO-* label registry and handler protocol."""

from typing import Protocol, runtime_checkable


@runtime_checkable
class AutoFixHandler(Protocol):
    """Protocol for AUTO-* fix handlers."""

    async def can_fix(self) -> bool:
        """Check if this handler can fix the issue."""
        ...

    async def fix(self) -> bool:
        """Attempt to fix the issue. Returns True on success."""
        ...

    async def get_ui_prompt(self) -> str:
        """Get a user-facing prompt for this fix."""
        ...


class AutoLabelRegistry:
    """Registry of all AUTO-* handlers."""

    def __init__(self) -> None:
        self.handlers: dict[str, type[AutoFixHandler]] = {}

    def register(self, label: str, handler: type[AutoFixHandler]) -> None:
        """Register a handler for a label."""
        self.handlers[label] = handler

    def get(self, label: str) -> type[AutoFixHandler] | None:
        """Get the handler class for a label."""
        return self.handlers.get(label)

    def list_labels(self) -> list[str]:
        """List all registered labels."""
        return list(self.handlers.keys())


# Global registry instance
AUTO_REGISTRY = AutoLabelRegistry()
