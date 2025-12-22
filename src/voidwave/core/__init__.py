"""Core functionality for VOIDWAVE framework."""
from .cleanup import CleanupRegistry, cleanup_registry, register_cleanup
from .constants import (
    CONCURRENCY_LIMITS,
    DB_PATH,
    TIMEOUTS,
    VOIDWAVE_CACHE_DIR,
    VOIDWAVE_CONFIG_DIR,
    VOIDWAVE_DATA_DIR,
    VOIDWAVE_HOME,
    VOIDWAVE_LOG_DIR,
    VOIDWAVE_OUTPUT_DIR,
    ExitCode,
    LogLevel,
)
from .exceptions import (
    ConfigurationError,
    NetworkError,
    PermissionError,
    PluginError,
    SubprocessError,
    TargetValidationError,
    TimeoutError,
    ToolNotFoundError,
    VoidwaveError,
)
from .logging import VoidwaveLogger, get_logger, setup_logging

__all__ = [
    # Constants
    "ExitCode",
    "LogLevel",
    "VOIDWAVE_HOME",
    "VOIDWAVE_CONFIG_DIR",
    "VOIDWAVE_DATA_DIR",
    "VOIDWAVE_LOG_DIR",
    "VOIDWAVE_OUTPUT_DIR",
    "VOIDWAVE_CACHE_DIR",
    "DB_PATH",
    "CONCURRENCY_LIMITS",
    "TIMEOUTS",
    # Exceptions
    "VoidwaveError",
    "ConfigurationError",
    "ToolNotFoundError",
    "PermissionError",
    "TargetValidationError",
    "NetworkError",
    "TimeoutError",
    "PluginError",
    "SubprocessError",
    # Logging
    "VoidwaveLogger",
    "setup_logging",
    "get_logger",
    # Cleanup
    "CleanupRegistry",
    "cleanup_registry",
    "register_cleanup",
]
