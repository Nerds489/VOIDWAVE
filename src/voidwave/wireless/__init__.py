"""VOIDWAVE wireless module."""
from voidwave.wireless.channels import CHANNELS_2GHZ, CHANNELS_5GHZ, ChannelHopper
from voidwave.wireless.mac import change_mac, generate_mac, get_current_mac, validate_mac
from voidwave.wireless.monitor import (
    disable_monitor_mode,
    enable_monitor_mode,
    get_monitor_status,
)

__all__ = [
    # Monitor mode
    "enable_monitor_mode",
    "disable_monitor_mode",
    "get_monitor_status",
    # Channel management
    "ChannelHopper",
    "CHANNELS_2GHZ",
    "CHANNELS_5GHZ",
    # MAC address
    "generate_mac",
    "validate_mac",
    "get_current_mac",
    "change_mac",
]
