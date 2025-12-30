"""Base classes for VOIDWAVE plugins."""
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, ClassVar

from pydantic import BaseModel


class PluginType(Enum):
    """Types of plugins."""

    TOOL = "tool"  # External tool wrapper
    ATTACK = "attack"  # Attack workflow
    SCANNER = "scanner"  # Network scanner
    CRACKER = "cracker"  # Password cracker
    PARSER = "parser"  # Output parser
    EXPORTER = "exporter"  # Report exporter


class Capability(Enum):
    """Plugin capabilities."""

    NETWORK_SCAN = "network_scan"
    PORT_SCAN = "port_scan"
    SERVICE_ENUM = "service_enum"
    VULN_SCAN = "vuln_scan"
    WIRELESS_SCAN = "wireless_scan"
    WIRELESS_ATTACK = "wireless_attack"
    PASSWORD_CRACK = "password_crack"
    PACKET_CAPTURE = "packet_capture"
    MITM = "mitm"
    OSINT = "osint"
    EXPLOITATION = "exploitation"
    WEB_SCAN = "web_scan"
    WEB_FUZZ = "web_fuzz"
    SUBDOMAIN_ENUM = "subdomain_enum"
    SQL_INJECTION = "sql_injection"
    DIR_ENUM = "dir_enum"
    FINGERPRINT = "fingerprint"


@dataclass
class PluginMetadata:
    """Plugin metadata."""

    name: str
    version: str
    description: str
    author: str
    plugin_type: PluginType
    capabilities: list[Capability]
    requires_root: bool = False
    external_tools: list[str] = field(default_factory=list)
    config_schema: type[BaseModel] | None = None


class PluginConfig(BaseModel):
    """Base configuration for plugins."""

    enabled: bool = True
    timeout: int = 600
    options: dict[str, Any] = {}


@dataclass
class PluginResult:
    """Result from plugin execution."""

    success: bool
    data: dict[str, Any]
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    artifacts: list[str] = field(default_factory=list)  # File paths


class BasePlugin(ABC):
    """Base class for all VOIDWAVE plugins."""

    # Subclasses must define metadata
    METADATA: ClassVar[PluginMetadata]

    def __init__(self, config: PluginConfig | None = None) -> None:
        self.config = config or PluginConfig()
        self._initialized = False

    @property
    def name(self) -> str:
        return self.METADATA.name

    @property
    def capabilities(self) -> list[Capability]:
        return self.METADATA.capabilities

    @abstractmethod
    async def initialize(self) -> None:
        """Initialize the plugin (check dependencies, etc.)."""
        ...

    @abstractmethod
    async def execute(self, target: str, options: dict[str, Any]) -> PluginResult:
        """Execute the plugin's main functionality."""
        ...

    @abstractmethod
    async def cleanup(self) -> None:
        """Clean up resources."""
        ...

    async def validate_target(self, target: str) -> bool:
        """Validate that target is appropriate for this plugin."""
        return True

    def get_config_schema(self) -> type[BaseModel] | None:
        """Get the configuration schema for this plugin."""
        return self.METADATA.config_schema


class ToolPlugin(BasePlugin):
    """Base class for external tool wrappers."""

    @property
    @abstractmethod
    def tool_name(self) -> str:
        """Name of the external tool."""
        ...

    @abstractmethod
    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build the command line for the tool."""
        ...

    @abstractmethod
    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse the tool's output."""
        ...


class AttackPlugin(BasePlugin):
    """Base class for attack workflows."""

    @property
    @abstractmethod
    def attack_phases(self) -> list[str]:
        """List of attack phases."""
        ...

    @abstractmethod
    async def execute_phase(self, phase: str, context: dict[str, Any]) -> PluginResult:
        """Execute a specific attack phase."""
        ...


class ScannerPlugin(ToolPlugin):
    """Base class for network scanners."""

    @abstractmethod
    async def scan(self, target: str, scan_type: str = "standard") -> PluginResult:
        """Perform a scan."""
        ...
