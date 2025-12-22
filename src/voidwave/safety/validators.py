"""Input validation functions for security and safety."""
import ipaddress
import re
from typing import Any


def validate_ip(ip: str) -> str:
    """Validate IP address (IPv4 or IPv6).

    Args:
        ip: IP address string to validate

    Returns:
        Validated IP address string

    Raises:
        ValueError: If IP is invalid
    """
    try:
        ipaddress.ip_address(ip)
        return ip
    except ValueError as e:
        raise ValueError(f"Invalid IP address: {ip}") from e


def validate_cidr(cidr: str) -> str:
    """Validate CIDR notation (e.g., 192.168.1.0/24).

    Args:
        cidr: CIDR string to validate

    Returns:
        Validated CIDR string

    Raises:
        ValueError: If CIDR is invalid
    """
    try:
        ipaddress.ip_network(cidr, strict=False)
        return cidr
    except ValueError as e:
        raise ValueError(f"Invalid CIDR notation: {cidr}") from e


def validate_port(port: int | str) -> int:
    """Validate port number (1-65535).

    Args:
        port: Port number to validate

    Returns:
        Validated port number

    Raises:
        ValueError: If port is invalid
    """
    try:
        port_int = int(port)
        if not 1 <= port_int <= 65535:
            raise ValueError(f"Port must be between 1 and 65535: {port}")
        return port_int
    except (ValueError, TypeError) as e:
        raise ValueError(f"Invalid port: {port}") from e


def validate_mac(mac: str) -> str:
    """Validate MAC address.

    Args:
        mac: MAC address string to validate

    Returns:
        Validated MAC address string (normalized to lowercase with colons)

    Raises:
        ValueError: If MAC is invalid
    """
    # Remove separators and convert to lowercase
    mac_clean = mac.lower().replace(":", "").replace("-", "").replace(".", "")

    if len(mac_clean) != 12 or not all(c in "0123456789abcdef" for c in mac_clean):
        raise ValueError(f"Invalid MAC address: {mac}")

    # Format with colons
    return ":".join(mac_clean[i : i + 2] for i in range(0, 12, 2))


def validate_hostname(hostname: str) -> str:
    """Validate hostname.

    Args:
        hostname: Hostname to validate

    Returns:
        Validated hostname

    Raises:
        ValueError: If hostname is invalid
    """
    # RFC 1123 hostname validation
    if len(hostname) > 253:
        raise ValueError(f"Hostname too long: {hostname}")

    # Split into labels
    labels = hostname.split(".")
    for label in labels:
        if not label or len(label) > 63:
            raise ValueError(f"Invalid hostname label: {label}")
        if not re.match(r"^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$", label):
            raise ValueError(f"Invalid hostname label: {label}")

    return hostname


def validate_url(url: str) -> str:
    """Validate URL.

    Args:
        url: URL to validate

    Returns:
        Validated URL

    Raises:
        ValueError: If URL is invalid
    """
    # Basic URL validation
    url_pattern = re.compile(
        r"^https?://"  # http:// or https://
        r"(?:(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+[A-Z]{2,6}\.?|"  # domain
        r"localhost|"  # localhost
        r"\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"  # IP
        r"(?::\d+)?"  # optional port
        r"(?:/?|[/?]\S+)$",
        re.IGNORECASE,
    )

    if not url_pattern.match(url):
        raise ValueError(f"Invalid URL: {url}")

    return url


def validate_domain(domain: str) -> str:
    """Validate domain name.

    Args:
        domain: Domain to validate

    Returns:
        Validated domain

    Raises:
        ValueError: If domain is invalid
    """
    # Domain validation (similar to hostname but requires TLD)
    if len(domain) > 253:
        raise ValueError(f"Domain too long: {domain}")

    labels = domain.split(".")
    if len(labels) < 2:
        raise ValueError(f"Domain must have at least 2 labels: {domain}")

    for label in labels:
        if not label or len(label) > 63:
            raise ValueError(f"Invalid domain label: {label}")
        if not re.match(r"^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$", label):
            raise ValueError(f"Invalid domain label: {label}")

    # TLD should be at least 2 characters
    if len(labels[-1]) < 2:
        raise ValueError(f"Invalid TLD: {labels[-1]}")

    return domain


def validate_target(target: str) -> tuple[str, str]:
    """Validate and classify target (IP, CIDR, hostname, URL, or domain).

    Args:
        target: Target to validate

    Returns:
        Tuple of (validated_target, target_type)

    Raises:
        ValueError: If target is invalid or unsupported
    """
    # Try IP
    try:
        validate_ip(target)
        return target, "ip"
    except ValueError:
        pass

    # Try CIDR
    try:
        validate_cidr(target)
        return target, "cidr"
    except ValueError:
        pass

    # Try URL
    try:
        validate_url(target)
        return target, "url"
    except ValueError:
        pass

    # Try hostname
    try:
        validate_hostname(target)
        return target, "hostname"
    except ValueError:
        pass

    # Try domain
    try:
        validate_domain(target)
        return target, "domain"
    except ValueError:
        pass

    # If nothing matches, raise error
    raise ValueError(f"Invalid target: {target}")
