"""Plugin registry and management."""
from dataclasses import dataclass
from typing import Any, Type

from voidwave.core.logging import get_logger
from voidwave.plugins.base import (
    BasePlugin,
    Capability,
    PluginConfig,
    PluginMetadata,
    PluginType,
)
from voidwave.plugins.discovery import PLUGIN_GROUPS, plugin_discovery

logger = get_logger(__name__)


@dataclass
class RegisteredPlugin:
    """Information about a registered plugin."""

    name: str
    group: str
    plugin_class: Type[BasePlugin]
    metadata: PluginMetadata
    enabled: bool = True


class PluginRegistry:
    """Central registry for all plugins."""

    def __init__(self) -> None:
        self._registry: dict[str, RegisteredPlugin] = {}
        self._by_type: dict[PluginType, list[str]] = {}
        self._by_capability: dict[Capability, list[str]] = {}

    async def initialize(self) -> None:
        """Initialize the registry by discovering all plugins."""
        discovered = plugin_discovery.discover_all()

        for group, plugins in discovered.items():
            for name, plugin_class in plugins.items():
                self._register(name, group, plugin_class)

        logger.info(f"Registry initialized with {len(self._registry)} plugins")

    def _register(
        self, name: str, group: str, plugin_class: Type[BasePlugin]
    ) -> None:
        """Register a plugin in the registry."""
        metadata = plugin_class.METADATA

        registered = RegisteredPlugin(
            name=name,
            group=group,
            plugin_class=plugin_class,
            metadata=metadata,
        )

        self._registry[name] = registered

        # Index by type
        if metadata.plugin_type not in self._by_type:
            self._by_type[metadata.plugin_type] = []
        self._by_type[metadata.plugin_type].append(name)

        # Index by capability
        for capability in metadata.capabilities:
            if capability not in self._by_capability:
                self._by_capability[capability] = []
            self._by_capability[capability].append(name)

    def get(self, name: str) -> RegisteredPlugin | None:
        """Get a registered plugin by name."""
        return self._registry.get(name)

    def get_by_type(self, plugin_type: PluginType) -> list[RegisteredPlugin]:
        """Get all plugins of a specific type."""
        names = self._by_type.get(plugin_type, [])
        return [self._registry[n] for n in names if n in self._registry]

    def get_by_capability(self, capability: Capability) -> list[RegisteredPlugin]:
        """Get all plugins with a specific capability."""
        names = self._by_capability.get(capability, [])
        return [self._registry[n] for n in names if n in self._registry]

    def list_all(self) -> list[RegisteredPlugin]:
        """List all registered plugins."""
        return list(self._registry.values())

    def enable(self, name: str) -> None:
        """Enable a plugin."""
        if name in self._registry:
            self._registry[name].enabled = True

    def disable(self, name: str) -> None:
        """Disable a plugin."""
        if name in self._registry:
            self._registry[name].enabled = False

    async def get_instance(
        self, name: str, config: PluginConfig | None = None
    ) -> BasePlugin:
        """Get an instance of a plugin."""
        if name not in self._registry:
            raise KeyError(f"Plugin not found: {name}")

        registered = self._registry[name]
        return await plugin_discovery.load_plugin(registered.group, name)


# Singleton registry
plugin_registry = PluginRegistry()
