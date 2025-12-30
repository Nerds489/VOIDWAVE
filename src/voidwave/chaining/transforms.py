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


# Web/URL transforms

def hosts_to_urls(hosts: list[dict[str, Any]], scheme: str = "http") -> list[str]:
    """Convert hosts to URLs.

    Args:
        hosts: List of host dicts with 'ip' and optional 'ports'
        scheme: URL scheme (http or https)

    Returns:
        List of URL strings
    """
    urls = []
    for host in hosts:
        ip = host.get("ip")
        if not ip:
            continue
        for port in host.get("ports", []):
            if port.get("state") != "open":
                continue
            port_num = port.get("port")
            service = port.get("service", "")
            if service in ("http", "http-alt") or port_num in (80, 8080, 8000):
                urls.append(f"http://{ip}:{port_num}")
            elif service in ("https", "ssl/http") or port_num in (443, 8443):
                urls.append(f"https://{ip}:{port_num}")
        if not host.get("ports"):
            urls.append(f"{scheme}://{ip}")
    return urls if urls else [f"{scheme}://{hosts[0].get('ip')}"] if hosts else []


def first_http_url(hosts: list[dict[str, Any]]) -> str | None:
    """Get first HTTP URL from hosts."""
    urls = hosts_to_urls(hosts)
    return urls[0] if urls else None


def filter_web_ports(hosts: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Filter hosts to only include web ports.

    Args:
        hosts: List of host dicts

    Returns:
        Hosts with only web ports
    """
    web_ports = {80, 443, 8080, 8443, 8000, 8888, 9000}
    result = []
    for host in hosts:
        web_host_ports = [
            p for p in host.get("ports", [])
            if p.get("port") in web_ports or p.get("service") in ("http", "https", "http-alt", "ssl/http")
        ]
        if web_host_ports:
            result.append({**host, "ports": web_host_ports})
    return result


def extract_subdomains(subdomain_data: dict[str, Any]) -> list[str]:
    """Extract subdomain list from subfinder results.

    Args:
        subdomain_data: Subfinder result dict

    Returns:
        List of subdomain strings
    """
    if isinstance(subdomain_data, dict):
        return subdomain_data.get("unique_hosts", [])
    return []


def subdomains_to_targets(subdomain_data: dict[str, Any]) -> str:
    """Convert subdomains to comma-separated target list.

    Args:
        subdomain_data: Subfinder result dict

    Returns:
        Comma-separated subdomain string
    """
    subs = extract_subdomains(subdomain_data)
    return ",".join(subs) if subs else ""


def first_subdomain(subdomain_data: dict[str, Any]) -> str | None:
    """Get first subdomain from results."""
    subs = extract_subdomains(subdomain_data)
    return subs[0] if subs else None


def extract_vulns_by_severity(
    nuclei_data: dict[str, Any],
    min_severity: str = "medium"
) -> list[dict[str, Any]]:
    """Extract vulnerabilities above minimum severity.

    Args:
        nuclei_data: Nuclei result dict
        min_severity: Minimum severity level

    Returns:
        List of vulnerability findings
    """
    severity_order = ["info", "low", "medium", "high", "critical"]
    min_idx = severity_order.index(min_severity.lower()) if min_severity.lower() in severity_order else 2

    findings = nuclei_data.get("findings", [])
    return [
        f for f in findings
        if severity_order.index(f.get("severity", "info").lower()) >= min_idx
    ]


def extract_directories(gobuster_data: dict[str, Any]) -> list[str]:
    """Extract discovered directories from gobuster results.

    Args:
        gobuster_data: Gobuster result dict

    Returns:
        List of directory paths
    """
    dirs = gobuster_data.get("directories", [])
    return [d.get("path") or d.get("url", "") for d in dirs]


def extract_technologies(whatweb_data: dict[str, Any]) -> list[str]:
    """Extract technology names from whatweb results.

    Args:
        whatweb_data: WhatWeb result dict

    Returns:
        List of technology names
    """
    techs = whatweb_data.get("technologies", [])
    return [t.get("name", "") for t in techs if t.get("name")]


def detect_cms(whatweb_data: dict[str, Any]) -> str | None:
    """Detect CMS from whatweb fingerprint.

    Args:
        whatweb_data: WhatWeb result dict

    Returns:
        CMS name if detected
    """
    cms_keywords = {
        "wordpress": "WordPress",
        "joomla": "Joomla",
        "drupal": "Drupal",
        "magento": "Magento",
        "shopify": "Shopify",
        "woocommerce": "WooCommerce",
        "prestashop": "PrestaShop",
        "typo3": "TYPO3",
    }
    techs = extract_technologies(whatweb_data)
    for tech in techs:
        tech_lower = tech.lower()
        for keyword, cms_name in cms_keywords.items():
            if keyword in tech_lower:
                return cms_name
    return None


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
    # Web/URL transforms
    "hosts_to_urls": hosts_to_urls,
    "first_http_url": first_http_url,
    "filter_web_ports": filter_web_ports,
    # Subdomain transforms
    "extract_subdomains": extract_subdomains,
    "subdomains_targets": subdomains_to_targets,
    "first_subdomain": first_subdomain,
    # Vulnerability transforms
    "critical_vulns": lambda d: extract_vulns_by_severity(d, "critical"),
    "high_vulns": lambda d: extract_vulns_by_severity(d, "high"),
    "medium_vulns": lambda d: extract_vulns_by_severity(d, "medium"),
    # Web discovery transforms
    "extract_directories": extract_directories,
    "extract_technologies": extract_technologies,
    "detect_cms": detect_cms,
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
