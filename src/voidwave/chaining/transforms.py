"""Built-in data transformers for tool chaining."""

from typing import Any, Callable


def flatten_ips(hosts: list[dict[str, Any]]) -> list[str]:
    """Extract IP addresses from host list.

    Args:
        hosts: List of host dicts with 'ip' key

    Returns:
        List of IP strings
    """
    return [h.get("ip") for h in hosts if h.get("ip")]


def filter_open_ports(hosts: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Keep only hosts with open ports.

    Args:
        hosts: List of host dicts with 'ports' key

    Returns:
        Filtered list of hosts
    """
    return [
        h
        for h in hosts
        if any(p.get("state") == "open" for p in h.get("ports", []))
    ]


def filter_by_state(hosts: list[dict[str, Any]], state: str = "up") -> list[dict[str, Any]]:
    """Filter hosts by state.

    Args:
        hosts: List of host dicts
        state: State to filter by (default: "up")

    Returns:
        Filtered list of hosts
    """
    return [h for h in hosts if h.get("state") == state]


def extract_services(hosts: list[dict[str, Any]], service: str) -> list[str]:
    """Extract hosts running a specific service.

    Args:
        hosts: List of host dicts with ports
        service: Service name to filter by

    Returns:
        List of "ip:port" strings
    """
    result = []
    for host in hosts:
        ip = host.get("ip", "")
        for port in host.get("ports", []):
            if port.get("service") == service and port.get("state") == "open":
                result.append(f"{ip}:{port.get('port', '')}")
    return result


def extract_ports(hosts: list[dict[str, Any]], state: str = "open") -> list[int]:
    """Extract unique port numbers from hosts.

    Args:
        hosts: List of host dicts with ports
        state: Port state to filter by

    Returns:
        Sorted list of unique port numbers
    """
    ports = set()
    for host in hosts:
        for port in host.get("ports", []):
            if port.get("state") == state:
                ports.add(port.get("port"))
    return sorted(p for p in ports if p is not None)


def networks_to_bssids(networks: list[dict[str, Any]]) -> list[str]:
    """Extract BSSIDs from network scan results.

    Args:
        networks: List of network dicts

    Returns:
        List of BSSID strings
    """
    return [n.get("bssid") for n in networks if n.get("bssid")]


def networks_by_encryption(
    networks: list[dict[str, Any]], encryption: str
) -> list[dict[str, Any]]:
    """Filter networks by encryption type.

    Args:
        networks: List of network dicts
        encryption: Encryption type (WPA, WPA2, WEP, OPN)

    Returns:
        Filtered list of networks
    """
    return [
        n
        for n in networks
        if encryption.upper() in (n.get("encryption", "") or "").upper()
    ]


def credentials_to_targets(credentials: list[dict[str, Any]]) -> list[str]:
    """Convert cracked credentials to host targets.

    Args:
        credentials: List of credential dicts

    Returns:
        List of "host:port" strings
    """
    return [
        f"{c['host']}:{c['port']}"
        for c in credentials
        if c.get("host") and c.get("port")
    ]


def credentials_to_userpass(credentials: list[dict[str, Any]]) -> list[str]:
    """Convert credentials to user:pass format.

    Args:
        credentials: List of credential dicts

    Returns:
        List of "username:password" strings
    """
    return [
        f"{c.get('username', '')}:{c.get('password', '')}"
        for c in credentials
        if c.get("password")
    ]


def first(items: list[Any]) -> Any:
    """Get first item from list.

    Args:
        items: List of items

    Returns:
        First item or None
    """
    return items[0] if items else None


def last(items: list[Any]) -> Any:
    """Get last item from list.

    Args:
        items: List of items

    Returns:
        Last item or None
    """
    return items[-1] if items else None


def join(items: list[Any], separator: str = ",") -> str:
    """Join list items into string.

    Args:
        items: List of items
        separator: Join separator

    Returns:
        Joined string
    """
    return separator.join(str(i) for i in items if i is not None)


def unique(items: list[Any]) -> list[Any]:
    """Get unique items preserving order.

    Args:
        items: List of items

    Returns:
        List with duplicates removed
    """
    seen = set()
    result = []
    for item in items:
        key = str(item)
        if key not in seen:
            seen.add(key)
            result.append(item)
    return result


def count(items: list[Any]) -> int:
    """Count items in list.

    Args:
        items: List of items

    Returns:
        Count
    """
    return len(items) if items else 0


def to_cidr(hosts: list[dict[str, Any]]) -> str:
    """Convert host list to CIDR notation target.

    Args:
        hosts: List of host dicts with 'ip' key

    Returns:
        Comma-separated IP list for tool input
    """
    ips = flatten_ips(hosts)
    return ",".join(unique(ips))


def to_port_list(ports: list[int]) -> str:
    """Convert port list to comma-separated string.

    Args:
        ports: List of port numbers

    Returns:
        Comma-separated port string
    """
    return ",".join(str(p) for p in sorted(set(ports)))


# Additional transforms for chain bindings

def first_ssh_host(hosts: list[dict[str, Any]]) -> str | None:
    """Get first SSH host as ip:port string."""
    ssh_hosts = extract_services(hosts, "ssh")
    return ssh_hosts[0] if ssh_hosts else None


def first_http_host(hosts: list[dict[str, Any]]) -> str | None:
    """Get first HTTP host as ip:port string."""
    http_hosts = extract_services(hosts, "http")
    return http_hosts[0] if http_hosts else None


def first_ftp_host(hosts: list[dict[str, Any]]) -> str | None:
    """Get first FTP host as ip:port string."""
    ftp_hosts = extract_services(hosts, "ftp")
    return ftp_hosts[0] if ftp_hosts else None


def first_network_bssid(networks: list[dict[str, Any]]) -> str | None:
    """Get BSSID of first network."""
    return networks[0].get("bssid") if networks else None


def first_network_channel(networks: list[dict[str, Any]]) -> int | None:
    """Get channel of first network."""
    return networks[0].get("channel") if networks else None


def ports_to_comma_list(hosts: list[dict[str, Any]]) -> str:
    """Extract open ports from hosts and return comma-separated string."""
    ports = extract_ports(hosts)
    return ",".join(str(p) for p in ports) if ports else "1-1000"


def hosts_to_comma_ips(hosts: list[dict[str, Any]]) -> str | None:
    """Extract IPs from hosts and return comma-separated string."""
    ips = flatten_ips(hosts)
    return ",".join(ips) if ips else None


def smb_hosts_joined(hosts: list[dict[str, Any]]) -> str | None:
    """Get SMB hosts as comma-separated string."""
    smb = extract_services(hosts, "microsoft-ds")
    return ",".join(smb) if smb else None


def ssh_hosts_joined(hosts: list[dict[str, Any]]) -> str | None:
    """Get SSH hosts as comma-separated string."""
    ssh = extract_services(hosts, "ssh")
    return ",".join(ssh) if ssh else None


# Registry of named transforms for use in DataBinding
TRANSFORMS: dict[str, Callable[..., Any]] = {
    "flatten_ips": flatten_ips,
    "filter_open": filter_open_ports,
    "filter_up": lambda h: filter_by_state(h, "up"),
    "first": first,
    "last": last,
    "join": join,
    "join_newline": lambda items: join(items, "\n"),
    "unique": unique,
    "count": count,
    "to_cidr": to_cidr,
    "to_port_list": to_port_list,
    # Host/IP transforms
    "hosts_to_ips": hosts_to_comma_ips,
    "ports_csv": ports_to_comma_list,
    # Service extractors (return list)
    "ssh_hosts": lambda h: extract_services(h, "ssh"),
    "http_hosts": lambda h: extract_services(h, "http"),
    "https_hosts": lambda h: extract_services(h, "https"),
    "ftp_hosts": lambda h: extract_services(h, "ftp"),
    "smb_hosts": lambda h: extract_services(h, "smb"),
    "rdp_hosts": lambda h: extract_services(h, "ms-wbt-server"),
    # First service host (return single string)
    "first_ssh": first_ssh_host,
    "first_http": first_http_host,
    "first_ftp": first_ftp_host,
    # Joined service hosts
    "ssh_hosts_csv": ssh_hosts_joined,
    "smb_hosts_csv": smb_hosts_joined,
    # Wireless
    "networks_bssids": networks_to_bssids,
    "first_bssid": first_network_bssid,
    "first_channel": first_network_channel,
    "wpa_networks": lambda n: networks_by_encryption(n, "WPA"),
    "wep_networks": lambda n: networks_by_encryption(n, "WEP"),
    "open_networks": lambda n: networks_by_encryption(n, "OPN"),
    # Credentials
    "creds_targets": credentials_to_targets,
    "creds_userpass": credentials_to_userpass,
    # Port extraction
    "extract_ports": extract_ports,
}


def get_transform(name: str) -> Callable[..., Any] | None:
    """Get a transform by name.

    Args:
        name: Transform name

    Returns:
        Transform function or None
    """
    return TRANSFORMS.get(name)


def apply_transform(name: str, data: Any) -> Any:
    """Apply a named transform to data.

    Args:
        name: Transform name
        data: Data to transform

    Returns:
        Transformed data or original if transform not found
    """
    transform = get_transform(name)
    if transform:
        return transform(data)
    return data
