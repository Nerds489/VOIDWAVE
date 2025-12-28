"""AUTO-VALIDATE handler for input validation."""

import re
import ipaddress
from typing import Any

from voidwave.automation.labels import AUTO_REGISTRY


class AutoValidateHandler:
    """Handles AUTO-VALIDATE for input validation and safety checks."""

    def __init__(self, input_type: str = "", value: str = "") -> None:
        self.input_type = input_type
        self.value = value
        self.error: str | None = None
        self.warning: str | None = None

    async def can_fix(self) -> bool:
        """Validation doesn't fix, it validates."""
        return False

    async def fix(self) -> bool:
        """Validate the input. Returns True if valid."""
        return self.validate()

    async def get_ui_prompt(self) -> str:
        """Get the validation result message."""
        if self.error:
            return f"Invalid {self.input_type}: {self.error}"
        if self.warning:
            return f"Warning for {self.input_type}: {self.warning}"
        return f"{self.input_type} is valid."

    def validate(self) -> bool:
        """Validate the input based on type."""
        validators = {
            "ip": self._validate_ip,
            "ip_address": self._validate_ip,
            "cidr": self._validate_cidr,
            "bssid": self._validate_bssid,
            "mac": self._validate_mac,
            "url": self._validate_url,
            "domain": self._validate_domain,
            "port": self._validate_port,
            "port_range": self._validate_port_range,
            "hash": self._validate_hash,
        }

        validator = validators.get(self.input_type)
        if validator:
            return validator()

        return True  # Unknown type, assume valid

    def _validate_ip(self) -> bool:
        """Validate IP address."""
        try:
            ipaddress.ip_address(self.value)
            return True
        except ValueError:
            self.error = "Invalid IP address format"
            return False

    def _validate_cidr(self) -> bool:
        """Validate CIDR notation."""
        try:
            network = ipaddress.ip_network(self.value, strict=False)

            # Check for overly broad scope
            if network.num_addresses > 65536:
                self.warning = f"Very broad scope: {network.num_addresses:,} addresses"

            if str(network) in ["0.0.0.0/0", "::/0"]:
                self.error = "Cannot target entire internet"
                return False

            return True
        except ValueError:
            self.error = "Invalid CIDR notation"
            return False

    def _validate_bssid(self) -> bool:
        """Validate BSSID (MAC address)."""
        return self._validate_mac()

    def _validate_mac(self) -> bool:
        """Validate MAC address."""
        pattern = r"^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"
        if re.match(pattern, self.value):
            return True
        self.error = "Invalid MAC address format (expected XX:XX:XX:XX:XX:XX)"
        return False

    def _validate_url(self) -> bool:
        """Validate URL."""
        pattern = r"^https?://[^\s/$.?#].[^\s]*$"
        if re.match(pattern, self.value, re.IGNORECASE):
            return True
        self.error = "Invalid URL format"
        return False

    def _validate_domain(self) -> bool:
        """Validate domain name."""
        pattern = r"^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+$"
        if re.match(pattern, self.value):
            return True
        self.error = "Invalid domain format"
        return False

    def _validate_port(self) -> bool:
        """Validate port number."""
        try:
            port = int(self.value)
            if 1 <= port <= 65535:
                return True
            self.error = "Port must be between 1 and 65535"
            return False
        except ValueError:
            self.error = "Port must be a number"
            return False

    def _validate_port_range(self) -> bool:
        """Validate port range."""
        # Format: 1-1000 or 22,80,443
        if "-" in self.value:
            try:
                start, end = self.value.split("-")
                start, end = int(start), int(end)
                if 1 <= start <= 65535 and 1 <= end <= 65535 and start <= end:
                    return True
                self.error = "Invalid port range"
                return False
            except ValueError:
                self.error = "Invalid port range format"
                return False
        elif "," in self.value:
            try:
                ports = [int(p.strip()) for p in self.value.split(",")]
                if all(1 <= p <= 65535 for p in ports):
                    return True
                self.error = "All ports must be between 1 and 65535"
                return False
            except ValueError:
                self.error = "Invalid port list format"
                return False
        else:
            return self._validate_port()

    def _validate_hash(self) -> bool:
        """Validate hash format."""
        value = self.value.lower()
        hash_patterns = {
            "md5": (32, r"^[a-f0-9]{32}$"),
            "sha1": (40, r"^[a-f0-9]{40}$"),
            "sha256": (64, r"^[a-f0-9]{64}$"),
            "sha512": (128, r"^[a-f0-9]{128}$"),
            "ntlm": (32, r"^[a-f0-9]{32}$"),
            "bcrypt": (60, r"^\$2[aby]?\$[0-9]{2}\$.{53}$"),
        }

        for hash_type, (length, pattern) in hash_patterns.items():
            if len(value) == length or re.match(pattern, value):
                return True

        self.warning = "Unknown hash format"
        return True  # Allow unknown formats

    @staticmethod
    def validate_input(input_type: str, value: str) -> tuple[bool, str | None]:
        """Static method to validate input."""
        handler = AutoValidateHandler(input_type, value)
        is_valid = handler.validate()
        return is_valid, handler.error or handler.warning


# Register the handler
AUTO_REGISTRY.register("AUTO-VALIDATE", AutoValidateHandler)
