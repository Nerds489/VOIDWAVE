"""System, tool, and interface detection for VOIDWAVE."""
from .distro import (
    DistroFamily,
    PackageManager,
    SystemInfo,
    get_system_info,
)
from .interfaces import (
    NetworkInterface,
    get_all_interfaces,
    get_wireless_interfaces,
    validate_wireless_interface,
)
from .tools import ToolInfo, ToolRegistry, tool_registry

__all__ = [
    # Distro
    "DistroFamily",
    "PackageManager",
    "SystemInfo",
    "get_system_info",
    # Tools
    "ToolInfo",
    "ToolRegistry",
    "tool_registry",
    # Interfaces
    "NetworkInterface",
    "get_all_interfaces",
    "get_wireless_interfaces",
    "validate_wireless_interface",
]
