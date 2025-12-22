"""Structured logging with Rich integration."""
import logging
from datetime import datetime
from pathlib import Path
from typing import Any

from rich.console import Console
from rich.logging import RichHandler
from rich.theme import Theme

from .constants import VOIDWAVE_LOG_DIR, LogLevel

# Cyberpunk color theme for console output
CYBERPUNK_THEME = Theme(
    {
        "info": "cyan",
        "success": "#00FF41",
        "warning": "#FF9A00",
        "error": "#FF0040",
        "debug": "dim cyan",
        "fatal": "bold red on #1A1A2E",
    }
)

# Add custom SUCCESS level
logging.addLevelName(LogLevel.SUCCESS, "SUCCESS")


class VoidwaveLogger(logging.Logger):
    """Custom logger with SUCCESS level."""

    def success(self, msg: str, *args: Any, **kwargs: Any) -> None:
        if self.isEnabledFor(LogLevel.SUCCESS):
            self._log(LogLevel.SUCCESS, msg, args, **kwargs)


def setup_logging(
    level: LogLevel = LogLevel.INFO,
    file_logging: bool = True,
    log_dir: Path = VOIDWAVE_LOG_DIR,
) -> logging.Logger:
    """Configure logging with Rich console and optional file output."""

    # Use custom logger class
    logging.setLoggerClass(VoidwaveLogger)
    logger = logging.getLogger("voidwave")
    logger.setLevel(level)

    # Clear existing handlers
    logger.handlers.clear()

    # Rich console handler
    console = Console(theme=CYBERPUNK_THEME, stderr=True)
    console_handler = RichHandler(
        console=console,
        show_time=True,
        show_path=False,
        rich_tracebacks=True,
        tracebacks_show_locals=True,
    )
    console_handler.setLevel(level)
    logger.addHandler(console_handler)

    # File handler (if enabled)
    if file_logging:
        log_dir.mkdir(parents=True, exist_ok=True)
        log_file = log_dir / f"voidwave_{datetime.now():%Y%m%d}.log"

        file_handler = logging.FileHandler(log_file, encoding="utf-8")
        file_handler.setLevel(logging.DEBUG)  # Always log debug to file
        file_formatter = logging.Formatter(
            "%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
        file_handler.setFormatter(file_formatter)
        logger.addHandler(file_handler)

    return logger


def get_logger(name: str = "voidwave") -> VoidwaveLogger:
    """Get a logger instance."""
    return logging.getLogger(name)  # type: ignore[return-value]
