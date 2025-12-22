"""VOIDWAVE - Offensive Security Framework with Modern TUI."""

__version__ = "2.0.0"
__author__ = "VOIDWAVE Team"
__license__ = "Apache-2.0"

from . import config, core, db, detection, safety

__all__ = [
    "__version__",
    "__author__",
    "__license__",
    "core",
    "config",
    "detection",
    "safety",
    "db",
]
