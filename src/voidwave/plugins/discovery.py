"""Plugin discovery using entry_points."""
from importlib.metadata import entry_points
from typing import Type

from voidwave.core.exceptions import PluginError
from voidwave.core.logging import get_logger
from voidwave.plugins.base import BasePlugin, PluginMetadata, PluginType

logger = get_logger(__name__)

# Entry point groups
PLUGIN_GROUPS = {
    PluginType.TOOL: "voidwave.tools",
    PluginType.ATTACK: "voidwave.attacks",
    PluginType.SCANNER: "voidwave.scanners",
    PluginType.CRACKER: "voidwave.crackers",
    PluginType.PARSER: "voidwave.parsers",
    PluginType.EXPORTER: "voidwave.exporters",
}


class PluginDiscovery:
    """Discovers and loads plugins from entry_points."""

    def __init__(self) -> None:
        self._discovered: dict[str, dict[str, Type[BasePlugin]]] = {}
        self._loaded: dict[str, BasePlugin] = {}

    def discover_all(self) -> dict[str, dict[str, Type[BasePlugin]]]:
        """Discover all plugins from all groups."""
        for plugin_type, group in PLUGIN_GROUPS.items():
            self._discovered[group] = self._discover_group(group)

        total = sum(len(plugins) for plugins in self._discovered.values())
        logger.info(f"Discovered {total} plugins across {len(PLUGIN_GROUPS)} groups")

        return self._discovered

    def _discover_group(self, group: str) -> dict[str, Type[BasePlugin]]:
        """Discover plugins in a specific entry_points group."""
        plugins = {}

        try:
            eps = entry_points(group=group)
        except TypeError:
            # Python < 3.10 compatibility
            eps = entry_points().get(group, [])

        for ep in eps:
            try:
                plugin_class = ep.load()
                if self._validate_plugin(plugin_class):
                    plugins[ep.name] = plugin_class
                    logger.debug(f"Discovered plugin: {ep.name} from {group}")
                else:
                    logger.warning(f"Invalid plugin: {ep.name}")
            except Exception as e:
                logger.error(f"Failed to load plugin {ep.name}: {e}")

        return plugins

    def _validate_plugin(self, plugin_class: type) -> bool:
        """Validate that a class is a valid plugin."""
        if not isinstance(plugin_class, type):
            return False

        if not issubclass(plugin_class, BasePlugin):
            return False

        if not hasattr(plugin_class, "METADATA"):
            return False

        if not isinstance(plugin_class.METADATA, PluginMetadata):
            return False

        return True

    def get_plugin_class(self, group: str, name: str) -> Type[BasePlugin] | None:
        """Get a specific plugin class."""
        if group not in self._discovered:
            self._discovered[group] = self._discover_group(group)

        return self._discovered.get(group, {}).get(name)

    def get_plugins_by_capability(self, capability: str) -> list[Type[BasePlugin]]:
        """Get all plugins with a specific capability."""
        if not self._discovered:
            self.discover_all()

        matching = []
        for group_plugins in self._discovered.values():
            for plugin_class in group_plugins.values():
                if capability in [c.value for c in plugin_class.METADATA.capabilities]:
                    matching.append(plugin_class)

        return matching

    async def load_plugin(self, group: str, name: str) -> BasePlugin:
        """Load and initialize a plugin instance."""
        cache_key = f"{group}:{name}"

        if cache_key in self._loaded:
            return self._loaded[cache_key]

        plugin_class = self.get_plugin_class(group, name)
        if plugin_class is None:
            raise PluginError(f"Plugin not found: {name} in {group}")

        plugin = plugin_class()
        await plugin.initialize()

        self._loaded[cache_key] = plugin
        logger.info(f"Loaded plugin: {name}")

        return plugin

    async def unload_plugin(self, group: str, name: str) -> None:
        """Unload a plugin and clean up resources."""
        cache_key = f"{group}:{name}"

        if cache_key in self._loaded:
            plugin = self._loaded[cache_key]
            await plugin.cleanup()
            del self._loaded[cache_key]
            logger.info(f"Unloaded plugin: {name}")

    async def unload_all(self) -> None:
        """Unload all loaded plugins."""
        for cache_key in list(self._loaded.keys()):
            plugin = self._loaded[cache_key]
            try:
                await plugin.cleanup()
            except Exception as e:
                logger.error(f"Error cleaning up {cache_key}: {e}")
            del self._loaded[cache_key]


# Singleton discovery instance
plugin_discovery = PluginDiscovery()
