"""Plugin lifecycle management."""
from enum import Enum
from typing import Any

from voidwave.core.logging import get_logger
from voidwave.plugins.base import BasePlugin

logger = get_logger(__name__)


class PluginState(Enum):
    """Plugin lifecycle states."""

    UNINITIALIZED = "uninitialized"
    INITIALIZING = "initializing"
    READY = "ready"
    EXECUTING = "executing"
    ERROR = "error"
    CLEANING_UP = "cleaning_up"
    TERMINATED = "terminated"


class PluginLifecycleManager:
    """Manages plugin lifecycle and state transitions."""

    def __init__(self) -> None:
        self._states: dict[str, PluginState] = {}
        self._errors: dict[str, list[str]] = {}

    def get_state(self, plugin: BasePlugin) -> PluginState:
        """Get current state of a plugin."""
        plugin_id = id(plugin)
        return self._states.get(plugin_id, PluginState.UNINITIALIZED)

    def set_state(self, plugin: BasePlugin, state: PluginState) -> None:
        """Set plugin state."""
        plugin_id = id(plugin)
        old_state = self._states.get(plugin_id, PluginState.UNINITIALIZED)
        self._states[plugin_id] = state
        logger.debug(f"Plugin {plugin.name} state: {old_state.value} -> {state.value}")

    async def initialize_plugin(self, plugin: BasePlugin) -> bool:
        """Initialize a plugin with state management."""
        if self.get_state(plugin) != PluginState.UNINITIALIZED:
            logger.warning(f"Plugin {plugin.name} already initialized")
            return True

        self.set_state(plugin, PluginState.INITIALIZING)

        try:
            await plugin.initialize()
            self.set_state(plugin, PluginState.READY)
            return True
        except Exception as e:
            logger.error(f"Plugin initialization failed: {e}")
            self.set_state(plugin, PluginState.ERROR)
            self._record_error(plugin, str(e))
            return False

    async def execute_plugin(
        self, plugin: BasePlugin, target: str, options: dict[str, Any]
    ) -> Any:
        """Execute a plugin with state management."""
        current_state = self.get_state(plugin)

        if current_state == PluginState.UNINITIALIZED:
            if not await self.initialize_plugin(plugin):
                raise RuntimeError(f"Plugin {plugin.name} failed to initialize")

        if current_state == PluginState.ERROR:
            raise RuntimeError(f"Plugin {plugin.name} is in error state")

        self.set_state(plugin, PluginState.EXECUTING)

        try:
            result = await plugin.execute(target, options)
            self.set_state(plugin, PluginState.READY)
            return result
        except Exception as e:
            logger.error(f"Plugin execution failed: {e}")
            self.set_state(plugin, PluginState.ERROR)
            self._record_error(plugin, str(e))
            raise

    async def cleanup_plugin(self, plugin: BasePlugin) -> None:
        """Clean up a plugin with state management."""
        self.set_state(plugin, PluginState.CLEANING_UP)

        try:
            await plugin.cleanup()
        except Exception as e:
            logger.error(f"Plugin cleanup failed: {e}")
            self._record_error(plugin, str(e))
        finally:
            self.set_state(plugin, PluginState.TERMINATED)

    def _record_error(self, plugin: BasePlugin, error: str) -> None:
        """Record an error for a plugin."""
        plugin_id = id(plugin)
        if plugin_id not in self._errors:
            self._errors[plugin_id] = []
        self._errors[plugin_id].append(error)

    def get_errors(self, plugin: BasePlugin) -> list[str]:
        """Get all errors for a plugin."""
        plugin_id = id(plugin)
        return self._errors.get(plugin_id, [])


# Singleton lifecycle manager
lifecycle_manager = PluginLifecycleManager()
