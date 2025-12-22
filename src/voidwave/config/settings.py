"""Configuration management with Pydantic Settings."""
from pathlib import Path
from typing import Any, Self

from pydantic import BaseModel, Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

from voidwave.core.constants import (
    VOIDWAVE_CONFIG_DIR,
    VOIDWAVE_LOG_DIR,
    VOIDWAVE_OUTPUT_DIR,
    LogLevel,
)


class DatabaseConfig(BaseModel):
    """Database configuration."""

    path: Path = Field(default=Path("~/.voidwave/data/voidwave.db"))
    wal_mode: bool = True
    busy_timeout: int = 5000  # milliseconds

    @field_validator("path", mode="before")
    @classmethod
    def expand_path(cls, v: Any) -> Path:
        if isinstance(v, str):
            return Path(v).expanduser()
        return v


class LoggingConfig(BaseModel):
    """Logging configuration."""

    level: LogLevel = LogLevel.INFO
    file_logging: bool = True
    log_dir: Path = VOIDWAVE_LOG_DIR
    max_file_size: int = 10_000_000  # 10MB
    backup_count: int = 5


class WirelessConfig(BaseModel):
    """Wireless operation configuration."""

    default_interface: str | None = None
    monitor_interface_prefix: str = "wmon"
    deauth_count: int = 10
    deauth_delay: float = 0.1
    channel_hop_interval: float = 0.5
    handshake_timeout: int = 300


class ScanningConfig(BaseModel):
    """Scanning configuration."""

    default_scan_type: str = "standard"  # quick, standard, full, stealth
    default_ports: str = "1-1000"
    timing_template: int = 3  # nmap -T<n>
    max_concurrent_hosts: int = 10


class CredentialsConfig(BaseModel):
    """Credential cracking configuration."""

    default_wordlist: Path = Path("/usr/share/wordlists/rockyou.txt")
    hashcat_workload: int = 3  # 1-4
    john_format: str | None = None


class SafetyConfig(BaseModel):
    """Safety and authorization configuration."""

    confirm_dangerous: bool = True
    warn_public_ip: bool = True
    require_authorization: bool = True
    dry_run: bool = False
    unsafe_mode: bool = False


class UIConfig(BaseModel):
    """User interface configuration."""

    theme: str = "cyberpunk"
    show_banner: bool = True
    animation_speed: float = 1.0
    vim_bindings: bool = True


class Settings(BaseSettings):
    """Main application settings."""

    model_config = SettingsConfigDict(
        env_prefix="VOIDWAVE_",
        env_nested_delimiter="__",
        toml_file=str(VOIDWAVE_CONFIG_DIR / "config.toml"),
        extra="ignore",
    )

    # Sub-configurations
    database: DatabaseConfig = Field(default_factory=DatabaseConfig)
    logging: LoggingConfig = Field(default_factory=LoggingConfig)
    wireless: WirelessConfig = Field(default_factory=WirelessConfig)
    scanning: ScanningConfig = Field(default_factory=ScanningConfig)
    credentials: CredentialsConfig = Field(default_factory=CredentialsConfig)
    safety: SafetyConfig = Field(default_factory=SafetyConfig)
    ui: UIConfig = Field(default_factory=UIConfig)

    # Top-level settings
    output_dir: Path = VOIDWAVE_OUTPUT_DIR
    non_interactive: bool = False
    debug: bool = False

    def save(self, path: Path | None = None) -> None:
        """Save current settings to TOML file."""
        import tomli_w

        path = path or (VOIDWAVE_CONFIG_DIR / "config.toml")
        path.parent.mkdir(parents=True, exist_ok=True)

        with open(path, "wb") as f:
            tomli_w.dump(self.model_dump(mode="json"), f)

    @classmethod
    def load(cls, path: Path | None = None) -> Self:
        """Load settings from TOML file with environment override."""
        import tomllib

        path = path or (VOIDWAVE_CONFIG_DIR / "config.toml")

        file_settings = {}
        if path.exists():
            with open(path, "rb") as f:
                file_settings = tomllib.load(f)

        return cls(**file_settings)


# Singleton settings instance
_settings: Settings | None = None


def get_settings() -> Settings:
    """Get application settings (cached)."""
    global _settings
    if _settings is None:
        _settings = Settings.load()
    return _settings


def reload_settings() -> Settings:
    """Force reload settings from file."""
    global _settings
    _settings = Settings.load()
    return _settings
