"""Secure API key storage using system keyring."""
from __future__ import annotations

import asyncio
from dataclasses import dataclass
from enum import Enum
from typing import Any

from voidwave.core.logging import get_logger

logger = get_logger(__name__)

# Service name for keyring
KEYRING_SERVICE = "voidwave"


class APIService(str, Enum):
    """Supported API services that require keys."""

    SHODAN = "shodan"
    CENSYS = "censys"
    VIRUSTOTAL = "virustotal"
    HUNTER = "hunter"  # Hunter.io
    SECURITYTRAILS = "securitytrails"
    WHOISXML = "whoisxml"
    WPSCAN = "wpscan"
    OPENAI = "openai"
    ANTHROPIC = "anthropic"


@dataclass
class APIKeyInfo:
    """Information about an API key."""

    service: APIService
    display_name: str
    description: str
    url: str
    key_format: str = "API Key"
    has_secret: bool = False  # Some services have key + secret
    test_endpoint: str | None = None


# API service definitions
API_SERVICES: dict[APIService, APIKeyInfo] = {
    APIService.SHODAN: APIKeyInfo(
        service=APIService.SHODAN,
        display_name="Shodan",
        description="Internet device search engine",
        url="https://account.shodan.io/",
        test_endpoint="https://api.shodan.io/api-info?key={key}",
    ),
    APIService.CENSYS: APIKeyInfo(
        service=APIService.CENSYS,
        display_name="Censys",
        description="Internet search and attack surface monitoring",
        url="https://search.censys.io/account/api",
        has_secret=True,
    ),
    APIService.VIRUSTOTAL: APIKeyInfo(
        service=APIService.VIRUSTOTAL,
        display_name="VirusTotal",
        description="Malware and URL scanning",
        url="https://www.virustotal.com/gui/my-apikey",
    ),
    APIService.HUNTER: APIKeyInfo(
        service=APIService.HUNTER,
        display_name="Hunter.io",
        description="Email finder and verifier",
        url="https://hunter.io/api_keys",
        test_endpoint="https://api.hunter.io/v2/account?api_key={key}",
    ),
    APIService.SECURITYTRAILS: APIKeyInfo(
        service=APIService.SECURITYTRAILS,
        display_name="SecurityTrails",
        description="DNS and domain intelligence",
        url="https://securitytrails.com/app/account",
    ),
    APIService.WHOISXML: APIKeyInfo(
        service=APIService.WHOISXML,
        display_name="WhoisXML API",
        description="WHOIS and DNS lookup",
        url="https://whoisxmlapi.com/",
    ),
    APIService.WPSCAN: APIKeyInfo(
        service=APIService.WPSCAN,
        display_name="WPScan",
        description="WordPress vulnerability database",
        url="https://wpscan.com/api",
    ),
    APIService.OPENAI: APIKeyInfo(
        service=APIService.OPENAI,
        display_name="OpenAI",
        description="GPT models for AI assistance",
        url="https://platform.openai.com/api-keys",
    ),
    APIService.ANTHROPIC: APIKeyInfo(
        service=APIService.ANTHROPIC,
        display_name="Anthropic",
        description="Claude models for AI assistance",
        url="https://console.anthropic.com/settings/keys",
    ),
}


class KeyringNotAvailableError(Exception):
    """Raised when keyring is not available."""

    pass


class APIKeyManager:
    """Manages API keys using system keyring."""

    def __init__(self) -> None:
        self._keyring_available: bool | None = None
        self._fallback_cache: dict[str, str] = {}

    def _check_keyring(self) -> bool:
        """Check if keyring is available."""
        if self._keyring_available is not None:
            return self._keyring_available

        try:
            import keyring
            from keyring.backends import fail

            # Check if we have a real backend (not the fail backend)
            backend = keyring.get_keyring()
            self._keyring_available = not isinstance(backend, fail.Keyring)

            if self._keyring_available:
                logger.debug(f"Using keyring backend: {backend.name}")
            else:
                logger.warning("No secure keyring backend available")

        except ImportError:
            logger.warning("keyring module not installed")
            self._keyring_available = False
        except Exception as e:
            logger.warning(f"Keyring check failed: {e}")
            self._keyring_available = False

        return self._keyring_available

    def _get_key_name(self, service: APIService, is_secret: bool = False) -> str:
        """Get the keyring key name for a service."""
        suffix = "_secret" if is_secret else "_key"
        return f"{service.value}{suffix}"

    def get_key(self, service: APIService) -> str | None:
        """Get API key for a service.

        Args:
            service: The API service

        Returns:
            The API key or None if not set
        """
        key_name = self._get_key_name(service)

        if self._check_keyring():
            try:
                import keyring

                return keyring.get_password(KEYRING_SERVICE, key_name)
            except Exception as e:
                logger.warning(f"Failed to get key from keyring: {e}")

        # Fallback to in-memory cache
        return self._fallback_cache.get(key_name)

    def get_secret(self, service: APIService) -> str | None:
        """Get API secret for a service (if applicable).

        Args:
            service: The API service

        Returns:
            The API secret or None if not set
        """
        key_name = self._get_key_name(service, is_secret=True)

        if self._check_keyring():
            try:
                import keyring

                return keyring.get_password(KEYRING_SERVICE, key_name)
            except Exception as e:
                logger.warning(f"Failed to get secret from keyring: {e}")

        return self._fallback_cache.get(key_name)

    def set_key(self, service: APIService, key: str) -> bool:
        """Set API key for a service.

        Args:
            service: The API service
            key: The API key value

        Returns:
            True if successfully stored
        """
        key_name = self._get_key_name(service)

        if self._check_keyring():
            try:
                import keyring

                keyring.set_password(KEYRING_SERVICE, key_name, key)
                logger.info(f"Stored API key for {service.value} in keyring")
                return True
            except Exception as e:
                logger.warning(f"Failed to store key in keyring: {e}")

        # Fallback to in-memory cache (not persistent)
        self._fallback_cache[key_name] = key
        logger.warning(f"Stored API key for {service.value} in memory (not persistent)")
        return True

    def set_secret(self, service: APIService, secret: str) -> bool:
        """Set API secret for a service.

        Args:
            service: The API service
            secret: The API secret value

        Returns:
            True if successfully stored
        """
        key_name = self._get_key_name(service, is_secret=True)

        if self._check_keyring():
            try:
                import keyring

                keyring.set_password(KEYRING_SERVICE, key_name, secret)
                logger.info(f"Stored API secret for {service.value} in keyring")
                return True
            except Exception as e:
                logger.warning(f"Failed to store secret in keyring: {e}")

        self._fallback_cache[key_name] = secret
        return True

    def delete_key(self, service: APIService) -> bool:
        """Delete API key for a service.

        Args:
            service: The API service

        Returns:
            True if successfully deleted
        """
        key_name = self._get_key_name(service)

        if self._check_keyring():
            try:
                import keyring

                keyring.delete_password(KEYRING_SERVICE, key_name)
                logger.info(f"Deleted API key for {service.value}")
            except Exception as e:
                logger.debug(f"Key may not exist: {e}")

        # Also clear from fallback cache
        self._fallback_cache.pop(key_name, None)

        # Also delete secret if applicable
        info = API_SERVICES.get(service)
        if info and info.has_secret:
            self.delete_secret(service)

        return True

    def delete_secret(self, service: APIService) -> bool:
        """Delete API secret for a service.

        Args:
            service: The API service

        Returns:
            True if successfully deleted
        """
        key_name = self._get_key_name(service, is_secret=True)

        if self._check_keyring():
            try:
                import keyring

                keyring.delete_password(KEYRING_SERVICE, key_name)
            except Exception:
                pass

        self._fallback_cache.pop(key_name, None)
        return True

    def has_key(self, service: APIService) -> bool:
        """Check if an API key is set for a service.

        Args:
            service: The API service

        Returns:
            True if key is set
        """
        return self.get_key(service) is not None

    def get_all_services(self) -> list[APIKeyInfo]:
        """Get all available API services."""
        return list(API_SERVICES.values())

    def get_configured_services(self) -> list[APIService]:
        """Get list of services that have keys configured."""
        return [service for service in APIService if self.has_key(service)]

    def get_unconfigured_services(self) -> list[APIService]:
        """Get list of services that don't have keys configured."""
        return [service for service in APIService if not self.has_key(service)]

    def get_status(self) -> dict[str, Any]:
        """Get status of all API key configurations.

        Returns:
            Dict with service status information
        """
        status = {
            "keyring_available": self._check_keyring(),
            "services": {},
        }

        for service in APIService:
            info = API_SERVICES.get(service)
            has_key = self.has_key(service)
            has_secret = False

            if info and info.has_secret:
                has_secret = self.get_secret(service) is not None

            status["services"][service.value] = {
                "configured": has_key,
                "has_secret": has_secret if info and info.has_secret else None,
                "display_name": info.display_name if info else service.value,
            }

        return status

    async def test_key(self, service: APIService) -> tuple[bool, str]:
        """Test if an API key is valid.

        Args:
            service: The API service

        Returns:
            Tuple of (success, message)
        """
        key = self.get_key(service)
        if not key:
            return False, "No API key configured"

        info = API_SERVICES.get(service)
        if not info or not info.test_endpoint:
            return True, "No test endpoint available (key stored)"

        try:
            import aiohttp

            url = info.test_endpoint.format(key=key)

            async with aiohttp.ClientSession() as session:
                async with session.get(url, timeout=10) as response:
                    if response.status == 200:
                        return True, "API key is valid"
                    elif response.status == 401:
                        return False, "Invalid API key"
                    elif response.status == 403:
                        return False, "API key forbidden (may be rate limited)"
                    else:
                        return False, f"Unexpected response: {response.status}"

        except ImportError:
            return True, "aiohttp not available for testing (key stored)"
        except asyncio.TimeoutError:
            return False, "Connection timeout"
        except Exception as e:
            return False, f"Test failed: {e}"


# Singleton instance
api_key_manager = APIKeyManager()


def get_api_key(service: APIService) -> str | None:
    """Convenience function to get an API key."""
    return api_key_manager.get_key(service)


def set_api_key(service: APIService, key: str) -> bool:
    """Convenience function to set an API key."""
    return api_key_manager.set_key(service, key)
