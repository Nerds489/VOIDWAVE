"""Protected IP ranges and target safety checks."""
import ipaddress
from typing import Any

from voidwave.core.exceptions import TargetValidationError

# RFC 1918 private IP ranges
PRIVATE_RANGES = [
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
]

# Loopback and link-local
LOOPBACK_RANGES = [
    ipaddress.ip_network("127.0.0.0/8"),
    ipaddress.ip_network("::1/128"),
]

LINK_LOCAL_RANGES = [
    ipaddress.ip_network("169.254.0.0/16"),
    ipaddress.ip_network("fe80::/10"),
]

# Special purpose ranges (IANA reserved)
RESERVED_RANGES = [
    ipaddress.ip_network("0.0.0.0/8"),  # Current network
    ipaddress.ip_network("100.64.0.0/10"),  # Shared address space
    ipaddress.ip_network("192.0.0.0/24"),  # IETF protocol assignments
    ipaddress.ip_network("192.0.2.0/24"),  # Documentation (TEST-NET-1)
    ipaddress.ip_network("198.18.0.0/15"),  # Benchmarking
    ipaddress.ip_network("198.51.100.0/24"),  # Documentation (TEST-NET-2)
    ipaddress.ip_network("203.0.113.0/24"),  # Documentation (TEST-NET-3)
    ipaddress.ip_network("224.0.0.0/4"),  # Multicast
    ipaddress.ip_network("240.0.0.0/4"),  # Reserved for future use
    ipaddress.ip_network("255.255.255.255/32"),  # Limited broadcast
]

# Multicast ranges
MULTICAST_RANGES = [
    ipaddress.ip_network("224.0.0.0/4"),
    ipaddress.ip_network("ff00::/8"),
]

# Critical infrastructure (examples - should be configurable)
PROTECTED_RANGES = [
    # DNS root servers
    ipaddress.ip_network("192.5.5.241/32"),  # F root
    ipaddress.ip_network("192.33.4.12/32"),  # C root
    ipaddress.ip_network("192.36.148.17/32"),  # I root
    ipaddress.ip_network("192.58.128.30/32"),  # J root
    ipaddress.ip_network("193.0.14.129/32"),  # K root
    ipaddress.ip_network("199.7.83.42/32"),  # L root
    ipaddress.ip_network("199.7.91.13/32"),  # D root
    ipaddress.ip_network("199.9.14.201/32"),  # B root
    ipaddress.ip_network("202.12.27.33/32"),  # M root
    # Can add government, financial, healthcare IPs here
]


def is_private_ip(ip: str | ipaddress.IPv4Address | ipaddress.IPv6Address) -> bool:
    """Check if IP is in private range (RFC 1918).

    Args:
        ip: IP address to check

    Returns:
        True if IP is private, False otherwise
    """
    if isinstance(ip, str):
        ip = ipaddress.ip_address(ip)

    return any(ip in net for net in PRIVATE_RANGES)


def is_loopback_ip(ip: str | ipaddress.IPv4Address | ipaddress.IPv6Address) -> bool:
    """Check if IP is loopback.

    Args:
        ip: IP address to check

    Returns:
        True if IP is loopback, False otherwise
    """
    if isinstance(ip, str):
        ip = ipaddress.ip_address(ip)

    return any(ip in net for net in LOOPBACK_RANGES)


def is_link_local_ip(ip: str | ipaddress.IPv4Address | ipaddress.IPv6Address) -> bool:
    """Check if IP is link-local.

    Args:
        ip: IP address to check

    Returns:
        True if IP is link-local, False otherwise
    """
    if isinstance(ip, str):
        ip = ipaddress.ip_address(ip)

    return any(ip in net for net in LINK_LOCAL_RANGES)


def is_reserved_ip(ip: str | ipaddress.IPv4Address | ipaddress.IPv6Address) -> bool:
    """Check if IP is in reserved range.

    Args:
        ip: IP address to check

    Returns:
        True if IP is reserved, False otherwise
    """
    if isinstance(ip, str):
        ip = ipaddress.ip_address(ip)

    return any(ip in net for net in RESERVED_RANGES)


def is_multicast_ip(ip: str | ipaddress.IPv4Address | ipaddress.IPv6Address) -> bool:
    """Check if IP is multicast.

    Args:
        ip: IP address to check

    Returns:
        True if IP is multicast, False otherwise
    """
    if isinstance(ip, str):
        ip = ipaddress.ip_address(ip)

    return any(ip in net for net in MULTICAST_RANGES)


def is_protected_ip(ip: str | ipaddress.IPv4Address | ipaddress.IPv6Address) -> bool:
    """Check if IP is in protected range (critical infrastructure).

    Args:
        ip: IP address to check

    Returns:
        True if IP is protected, False otherwise
    """
    if isinstance(ip, str):
        ip = ipaddress.ip_address(ip)

    return any(ip in net for net in PROTECTED_RANGES)


def is_public_ip(ip: str | ipaddress.IPv4Address | ipaddress.IPv6Address) -> bool:
    """Check if IP is public (not private, loopback, link-local, or reserved).

    Args:
        ip: IP address to check

    Returns:
        True if IP is public, False otherwise
    """
    if isinstance(ip, str):
        ip = ipaddress.ip_address(ip)

    return not (
        is_private_ip(ip)
        or is_loopback_ip(ip)
        or is_link_local_ip(ip)
        or is_reserved_ip(ip)
        or is_multicast_ip(ip)
    )


def check_target_safety(
    target: str,
    allow_private: bool = True,
    allow_loopback: bool = False,
    allow_public: bool = False,
    allow_protected: bool = False,
) -> None:
    """Check if target is safe to scan/attack based on safety settings.

    Args:
        target: Target IP, CIDR, or hostname
        allow_private: Allow private IPs (default: True)
        allow_loopback: Allow loopback IPs (default: False)
        allow_public: Allow public IPs (default: False - requires explicit opt-in)
        allow_protected: Allow protected IPs (default: False)

    Raises:
        TargetValidationError: If target is not allowed based on safety settings
    """
    # Parse IP or network
    try:
        # Try as single IP
        ip = ipaddress.ip_address(target)
        ips = [ip]
    except ValueError:
        try:
            # Try as network
            network = ipaddress.ip_network(target, strict=False)
            ips = list(network.hosts()) if network.num_addresses > 1 else [network.network_address]
        except ValueError:
            # Not an IP or network, assume hostname (skip IP checks)
            return

    # Check each IP in range
    for ip in ips:
        # Check protected first (strictest)
        if is_protected_ip(ip) and not allow_protected:
            raise TargetValidationError(
                f"Target {ip} is in protected range (critical infrastructure)",
                details={"ip": str(ip), "reason": "protected"},
            )

        # Check loopback
        if is_loopback_ip(ip) and not allow_loopback:
            raise TargetValidationError(
                f"Target {ip} is loopback address",
                details={"ip": str(ip), "reason": "loopback"},
            )

        # Check reserved
        if is_reserved_ip(ip):
            raise TargetValidationError(
                f"Target {ip} is in reserved range",
                details={"ip": str(ip), "reason": "reserved"},
            )

        # Check multicast
        if is_multicast_ip(ip):
            raise TargetValidationError(
                f"Target {ip} is multicast address",
                details={"ip": str(ip), "reason": "multicast"},
            )

        # Check public
        if is_public_ip(ip) and not allow_public:
            raise TargetValidationError(
                f"Target {ip} is public IP (requires explicit authorization)",
                details={"ip": str(ip), "reason": "public"},
            )

        # Check private
        if is_private_ip(ip) and not allow_private:
            raise TargetValidationError(
                f"Target {ip} is private IP",
                details={"ip": str(ip), "reason": "private"},
            )
