"""Core constants for VOIDWAVE framework."""
from enum import IntEnum
from pathlib import Path


class ExitCode(IntEnum):
    """Standard exit codes matching original Bash implementation."""

    SUCCESS = 0
    FAILURE = 1
    INVALID_ARGS = 2
    PERMISSION_DENIED = 3
    NETWORK_ERROR = 4
    TARGET_INVALID = 5
    TOOL_MISSING = 6
    CONFIG_ERROR = 7
    TIMEOUT = 8
    INTERRUPTED = 130


class LogLevel(IntEnum):
    """Logging levels."""

    DEBUG = 10
    INFO = 20
    SUCCESS = 25  # Custom level between INFO and WARNING
    WARNING = 30
    ERROR = 40
    FATAL = 50


# XDG-compliant paths
VOIDWAVE_HOME = Path.home() / ".voidwave"
VOIDWAVE_CONFIG_DIR = VOIDWAVE_HOME / "config"
VOIDWAVE_DATA_DIR = VOIDWAVE_HOME / "data"
VOIDWAVE_LOG_DIR = VOIDWAVE_HOME / "logs"
VOIDWAVE_OUTPUT_DIR = VOIDWAVE_HOME / "output"
VOIDWAVE_CACHE_DIR = VOIDWAVE_HOME / "cache"

# Export/reporting paths
VOIDWAVE_CAPTURES_DIR = VOIDWAVE_OUTPUT_DIR / "captures"
VOIDWAVE_WIFI_CAPTURES_DIR = VOIDWAVE_CAPTURES_DIR / "wifi"
VOIDWAVE_WIRED_CAPTURES_DIR = VOIDWAVE_CAPTURES_DIR / "wired"
VOIDWAVE_SCANS_DIR = VOIDWAVE_OUTPUT_DIR / "scans"
VOIDWAVE_REPORTS_DIR = VOIDWAVE_OUTPUT_DIR / "reports"
VOIDWAVE_LOOT_DIR = VOIDWAVE_OUTPUT_DIR / "loot"
VOIDWAVE_EXPORTS_DIR = VOIDWAVE_OUTPUT_DIR / "exports"

# Asset paths
VOIDWAVE_WORDLISTS_DIR = VOIDWAVE_DATA_DIR / "wordlists"
VOIDWAVE_PORTALS_DIR = VOIDWAVE_DATA_DIR / "portals"
VOIDWAVE_CERTS_DIR = VOIDWAVE_DATA_DIR / "certs"
VOIDWAVE_TEMPLATES_DIR = VOIDWAVE_DATA_DIR / "templates"
VOIDWAVE_SESSIONS_DIR = VOIDWAVE_DATA_DIR / "sessions"
VOIDWAVE_TEMP_DIR = VOIDWAVE_CACHE_DIR / "temp"

# Database
DB_PATH = VOIDWAVE_DATA_DIR / "voidwave.db"

# Concurrency limits by tool category
CONCURRENCY_LIMITS = {
    "network_scanner": 10,
    "web_scanner": 25,
    "password_cracker": 1,  # GPU exclusivity
    "traffic_capture": 5,
    "default": 10,
}

# Subprocess timeouts (seconds)
TIMEOUTS = {
    "quick_scan": 300,
    "full_scan": 3600,
    "password_crack": 86400,
    "default": 600,
}
