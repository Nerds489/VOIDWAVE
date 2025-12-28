"""AUTO-KEYS handler for API key configuration."""

import os
from pathlib import Path
from typing import Any

from voidwave.automation.labels import AUTO_REGISTRY


# API key configuration
API_KEYS: dict[str, dict[str, Any]] = {
    "shodan": {
        "env_var": "SHODAN_API_KEY",
        "url": "https://account.shodan.io/",
        "description": "Shodan search engine API",
    },
    "censys": {
        "env_var": "CENSYS_API_ID",
        "env_var_secret": "CENSYS_API_SECRET",
        "url": "https://censys.io/account/api",
        "description": "Censys search engine API",
    },
    "virustotal": {
        "env_var": "VT_API_KEY",
        "url": "https://www.virustotal.com/gui/user/apikey",
        "description": "VirusTotal API",
    },
    "wpscan": {
        "env_var": "WPSCAN_API_TOKEN",
        "url": "https://wpscan.com/api",
        "description": "WPScan WordPress vulnerability database",
    },
    "projectdiscovery": {
        "env_var": "PDCP_API_KEY",
        "url": "https://cloud.projectdiscovery.io/",
        "description": "ProjectDiscovery cloud platform",
    },
    "securitytrails": {
        "env_var": "ST_API_KEY",
        "url": "https://securitytrails.com/",
        "description": "SecurityTrails domain data",
    },
    "hunter": {
        "env_var": "HUNTER_API_KEY",
        "url": "https://hunter.io/api",
        "description": "Hunter.io email finder",
    },
}


class AutoKeysHandler:
    """Handles AUTO-KEYS for API key configuration."""

    def __init__(self, service: str = "") -> None:
        self.service = service
        self.config = API_KEYS.get(service, {})

    async def can_fix(self) -> bool:
        """Check if we can configure this key."""
        return self.service in API_KEYS

    async def fix(self) -> bool:
        """Store the API key.

        Note: This returns False because actual key entry
        requires TUI interaction.
        """
        return False  # Requires TUI interaction

    async def get_ui_prompt(self) -> str:
        """Get the UI prompt for this fix."""
        if self.service in API_KEYS:
            config = API_KEYS[self.service]
            return f"Configure {self.service} API key ({config['description']})?"
        return f"Configure {self.service} API key?"

    def is_configured(self) -> bool:
        """Check if this service's API key is configured."""
        if not self.config:
            return False

        env_var = self.config.get("env_var")
        if not env_var:
            return False

        # Check environment variable
        if os.environ.get(env_var):
            return True

        # Check stored keys
        key_path = Path.home() / ".voidwave" / "keys" / f"{self.service}.key"
        return key_path.exists()

    def get_key(self) -> str | None:
        """Get the API key for this service."""
        if not self.config:
            return None

        env_var = self.config.get("env_var")

        # Check environment first
        if env_var and os.environ.get(env_var):
            return os.environ[env_var]

        # Check stored keys
        key_path = Path.home() / ".voidwave" / "keys" / f"{self.service}.key"
        if key_path.exists():
            return key_path.read_text().strip()

        return None

    def save_key(self, key: str) -> bool:
        """Save an API key."""
        key_dir = Path.home() / ".voidwave" / "keys"
        key_dir.mkdir(parents=True, exist_ok=True)

        # Set restrictive permissions on directory
        key_dir.chmod(0o700)

        key_path = key_dir / f"{self.service}.key"
        key_path.write_text(key)

        # Set restrictive permissions on key file
        key_path.chmod(0o600)

        return True

    def get_registration_url(self) -> str | None:
        """Get the URL to register for this API key."""
        if self.config:
            return self.config.get("url")
        return None

    @staticmethod
    def list_services() -> list[dict[str, Any]]:
        """List all configurable API services."""
        result = []
        for name, config in API_KEYS.items():
            handler = AutoKeysHandler(name)
            result.append(
                {
                    "name": name,
                    "description": config["description"],
                    "url": config["url"],
                    "configured": handler.is_configured(),
                }
            )
        return result


# Register the handler
AUTO_REGISTRY.register("AUTO-KEYS", AutoKeysHandler)
