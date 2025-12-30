"""Built-in reconnaissance chains."""

from voidwave.chaining.models import (
    ChainDefinition,
    ChainStep,
    Condition,
    DataBinding,
    OnErrorBehavior,
)
from voidwave.chaining.registry import chain_registry


# Web Reconnaissance Chain
web_recon_chain = ChainDefinition(
    id="web_recon",
    name="Web Reconnaissance Pipeline",
    description="Full web server reconnaissance with fingerprinting and directory discovery",
    target_type="ip",
    tags=["recon", "web", "fingerprinting", "discovery"],
    steps=[
        ChainStep(
            id="port_scan",
            tool="nmap",
            description="Find web ports",
            options={
                "ports": "80,443,8080,8443,8000,8888,9000",
                "service_detection": True,
            },
            timeout=300,
        ),
        ChainStep(
            id="fingerprint",
            tool="whatweb",
            description="Technology fingerprinting",
            target_binding=DataBinding(
                source_step="port_scan",
                source_path="hosts",
                target_option="target",
                transform="first_http_url",
            ),
            depends_on=["port_scan"],
            condition=Condition(
                source_step="port_scan",
                check="count_gt",
                path="hosts",
                value=0,
            ),
            timeout=300,
        ),
        ChainStep(
            id="vuln_scan",
            tool="nikto",
            description="Web vulnerability scan",
            target_binding=DataBinding(
                source_step="port_scan",
                source_path="hosts",
                target_option="target",
                transform="first_http_url",
            ),
            options={
                "tuning": "12b",  # Interesting files, misconfig, software ID
            },
            depends_on=["fingerprint"],
            timeout=600,
        ),
        ChainStep(
            id="dir_enum",
            tool="gobuster",
            description="Directory enumeration",
            target_binding=DataBinding(
                source_step="port_scan",
                source_path="hosts",
                target_option="target",
                transform="first_http_url",
            ),
            options={
                "mode": "dir",
                "wordlist": "/usr/share/seclists/Discovery/Web-Content/common.txt",
                "threads": 10,
            },
            depends_on=["fingerprint"],
            parallel_with=["vuln_scan"],
            timeout=900,
        ),
    ],
)


# Subdomain Enumeration Chain
subdomain_enum_chain = ChainDefinition(
    id="subdomain_enum",
    name="Subdomain Enumeration Pipeline",
    description="Discover subdomains and map attack surface",
    target_type="domain",
    tags=["recon", "subdomain", "osint", "discovery"],
    steps=[
        ChainStep(
            id="passive_enum",
            tool="subfinder",
            description="Passive subdomain discovery",
            options={
                "threads": 10,
                "timeout": 30,
            },
            timeout=600,
        ),
        ChainStep(
            id="resolve_dns",
            tool="nmap",
            description="Resolve and scan discovered subdomains",
            target_binding=DataBinding(
                source_step="passive_enum",
                source_path="data",
                target_option="target",
                transform="subdomains_targets",
            ),
            options={
                "ports": "80,443",
                "service_detection": True,
                "skip_discovery": True,
            },
            depends_on=["passive_enum"],
            condition=Condition(
                source_step="passive_enum",
                check="count_gt",
                path="data.unique_hosts",
                value=0,
            ),
            timeout=600,
        ),
        ChainStep(
            id="web_fingerprint",
            tool="whatweb",
            description="Fingerprint discovered web services",
            target_binding=DataBinding(
                source_step="resolve_dns",
                source_path="hosts",
                target_option="target",
                transform="hosts_to_urls",
            ),
            depends_on=["resolve_dns"],
            condition=Condition(
                source_step="resolve_dns",
                check="count_gt",
                path="hosts",
                value=0,
            ),
            timeout=600,
        ),
    ],
)


# CMS Detection Chain
cms_detect_chain = ChainDefinition(
    id="cms_detect",
    name="CMS Detection & Scanning",
    description="Detect CMS installations and run specialized scans",
    target_type="url",
    tags=["recon", "cms", "wordpress", "fingerprinting"],
    steps=[
        ChainStep(
            id="fingerprint",
            tool="whatweb",
            description="Technology fingerprinting",
            options={
                "aggression": 3,  # More aggressive for CMS detection
            },
            timeout=300,
        ),
        ChainStep(
            id="nuclei_tech",
            tool="nuclei",
            description="Technology-based vulnerability scan",
            options={
                "tags": ["tech", "panel", "config"],
                "severity": ["info", "low", "medium", "high", "critical"],
            },
            depends_on=["fingerprint"],
            timeout=600,
        ),
        ChainStep(
            id="dir_enum",
            tool="gobuster",
            description="CMS directory enumeration",
            options={
                "mode": "dir",
                "wordlist": "/usr/share/seclists/Discovery/Web-Content/CMS/wordpress.fuzz.txt",
                "extensions": "php,txt,html,bak",
                "threads": 10,
            },
            depends_on=["fingerprint"],
            parallel_with=["nuclei_tech"],
            timeout=600,
        ),
    ],
)


# Full Recon Chain (comprehensive)
full_recon_chain = ChainDefinition(
    id="full_recon",
    name="Full Reconnaissance Pipeline",
    description="Comprehensive target reconnaissance combining all techniques",
    target_type="ip",
    tags=["recon", "comprehensive", "full"],
    steps=[
        ChainStep(
            id="port_discovery",
            tool="masscan",
            description="Fast port discovery",
            options={
                "ports": "1-65535",
                "rate": 10000,
            },
            on_error=OnErrorBehavior.FALLBACK,
            fallback_tool="nmap",
            timeout=300,
        ),
        ChainStep(
            id="service_enum",
            tool="nmap",
            description="Service enumeration on open ports",
            target_binding=DataBinding(
                source_step="port_discovery",
                source_path="hosts",
                target_option="target",
                transform="hosts_to_ips",
            ),
            option_bindings=[
                DataBinding(
                    source_step="port_discovery",
                    source_path="hosts",
                    target_option="ports",
                    transform="ports_csv",
                    required=False,
                    default="1-1000",
                ),
            ],
            options={
                "service_detection": True,
                "os_detection": True,
            },
            depends_on=["port_discovery"],
            condition=Condition(
                source_step="port_discovery",
                check="count_gt",
                path="hosts",
                value=0,
            ),
            timeout=600,
        ),
        ChainStep(
            id="web_fingerprint",
            tool="whatweb",
            description="Web technology fingerprinting",
            target_binding=DataBinding(
                source_step="service_enum",
                source_path="hosts",
                target_option="target",
                transform="first_http_url",
            ),
            depends_on=["service_enum"],
            condition=Condition(
                source_step="service_enum",
                check="exists",
                path="hosts[*].ports[?service==http]",
            ),
            timeout=300,
        ),
        ChainStep(
            id="vuln_scan",
            tool="nuclei",
            description="Vulnerability scanning",
            target_binding=DataBinding(
                source_step="service_enum",
                source_path="hosts",
                target_option="target",
                transform="first_http_url",
            ),
            options={
                "severity": ["medium", "high", "critical"],
                "tags": ["cve", "vuln"],
            },
            depends_on=["web_fingerprint"],
            timeout=900,
        ),
        ChainStep(
            id="dir_enum",
            tool="gobuster",
            description="Directory enumeration",
            target_binding=DataBinding(
                source_step="service_enum",
                source_path="hosts",
                target_option="target",
                transform="first_http_url",
            ),
            options={
                "mode": "dir",
                "wordlist": "/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt",
                "threads": 20,
            },
            depends_on=["web_fingerprint"],
            parallel_with=["vuln_scan"],
            timeout=1200,
        ),
    ],
)


def register_recon_chains() -> None:
    """Register all reconnaissance chains."""
    chain_registry.register(web_recon_chain)
    chain_registry.register(subdomain_enum_chain)
    chain_registry.register(cms_detect_chain)
    chain_registry.register(full_recon_chain)
