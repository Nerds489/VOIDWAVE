"""VOIDWAVE safety and validation system."""
from voidwave.safety.protected import check_target_safety, is_protected_ip, is_public_ip
from voidwave.safety.validators import (
    validate_bssid,
    validate_cidr,
    validate_domain,
    validate_hostname,
    validate_ip,
    validate_mac,
    validate_port,
    validate_port_range,
    validate_target,
    validate_url,
)

__all__ = [
    # Validators
    "validate_ip",
    "validate_cidr",
    "validate_port",
    "validate_port_range",
    "validate_mac",
    "validate_bssid",
    "validate_hostname",
    "validate_domain",
    "validate_url",
    "validate_target",
    # Protection
    "is_protected_ip",
    "is_public_ip",
    "check_target_safety",
]
