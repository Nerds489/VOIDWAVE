"""Resource cleanup registry for graceful shutdown."""
import asyncio
import signal
import sys
from collections.abc import Callable, Coroutine
from typing import Any

from .logging import get_logger

logger = get_logger(__name__)

CleanupFunc = Callable[[], None] | Callable[[], Coroutine[Any, Any, None]]


class CleanupRegistry:
    """Registry for cleanup functions to run on shutdown."""

    _instance: "CleanupRegistry | None" = None

    def __new__(cls) -> "CleanupRegistry":
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._handlers: list[tuple[int, CleanupFunc]] = []
            cls._instance._installed = False
        return cls._instance

    def register(self, handler: CleanupFunc, priority: int = 50) -> None:
        """Register a cleanup handler with priority (lower = earlier)."""
        self._handlers.append((priority, handler))
        self._handlers.sort(key=lambda x: x[0])

        if not self._installed:
            self._install_signal_handlers()

    def unregister(self, handler: CleanupFunc) -> None:
        """Remove a cleanup handler."""
        self._handlers = [(p, h) for p, h in self._handlers if h != handler]

    def _install_signal_handlers(self) -> None:
        """Install signal handlers for graceful shutdown."""
        for sig in (signal.SIGINT, signal.SIGTERM):
            signal.signal(sig, self._signal_handler)
        self._installed = True

    def _signal_handler(self, signum: int, frame: Any) -> None:
        """Handle shutdown signals."""
        logger.info(f"Received signal {signum}, initiating cleanup...")
        asyncio.get_event_loop().run_until_complete(self.cleanup())
        sys.exit(128 + signum)

    async def cleanup(self) -> None:
        """Execute all registered cleanup handlers."""
        logger.info(f"Running {len(self._handlers)} cleanup handlers...")

        for priority, handler in self._handlers:
            try:
                result = handler()
                if asyncio.iscoroutine(result):
                    await result
            except Exception as e:
                logger.error(f"Cleanup handler failed: {e}")

        self._handlers.clear()
        logger.info("Cleanup complete")


# Singleton instance
cleanup_registry = CleanupRegistry()


def register_cleanup(handler: CleanupFunc, priority: int = 50) -> None:
    """Convenience function to register cleanup handler."""
    cleanup_registry.register(handler, priority)
