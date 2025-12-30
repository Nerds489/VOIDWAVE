"""Built-in scanning chains."""

from voidwave.chaining.models import (
    ChainDefinition,
    ChainStep,
    Condition,
    DataBinding,
    OnErrorBehavior,
)
from voidwave.chaining.registry import chain_registry
from voidwave.chaining.transforms import flatten_ips, to_port_list


# Fast-to-Detailed Scan Chain
fast_to_detailed_chain = ChainDefinition(
    id="fast_to_detailed",
    name="Fast Scan → Detailed Scan",
    description="Fast port discovery with masscan, then detailed service enumeration with nmap",
    target_type="cidr",
    tags=["scanning", "network", "recon"],
    steps=[
        ChainStep(
            id="fast_scan",
            tool="masscan",
            description="Fast TCP port discovery",
            options={
                "ports": "1-65535",
                "rate": 10000,
            },
            on_error=OnErrorBehavior.FALLBACK,
            fallback_tool="nmap",
            timeout=300,
        ),
        ChainStep(
            id="detailed_scan",
            tool="nmap",
            description="Detailed service enumeration",
            target_binding=DataBinding(
                source_step="fast_scan",
                source_path="hosts[*].ip",
                target_option="target",
                transform=lambda ips: ",".join(ips) if ips else None,
            ),
            option_bindings=[
                DataBinding(
                    source_step="fast_scan",
                    source_path="hosts[*].ports[*].port",
                    target_option="ports",
                    transform=lambda ports: ",".join(str(p) for p in set(ports)) if ports else "1-1000",
                    required=False,
                    default="1-1000",
                ),
            ],
            options={
                "service_detection": True,
                "os_detection": True,
            },
            depends_on=["fast_scan"],
            condition=Condition(
                source_step="fast_scan",
                check="count_gt",
                path="hosts",
                value=0,
            ),
            timeout=600,
        ),
    ],
)


# Vulnerability Scan Chain
vuln_scan_chain = ChainDefinition(
    id="vuln_scan",
    name="Vulnerability Scan Pipeline",
    description="Port scan → Service detection → Vulnerability scan",
    target_type="ip",
    tags=["scanning", "vulnerability", "security"],
    steps=[
        ChainStep(
            id="port_scan",
            tool="nmap",
            description="Initial port scan",
            options={
                "scan_type": "standard",
                "top_ports": 1000,
            },
            timeout=300,
        ),
        ChainStep(
            id="service_scan",
            tool="nmap",
            description="Service version detection",
            target_binding=DataBinding(
                source_step="port_scan",
                source_path="hosts[?state==up].ip",
                target_option="target",
                transform=lambda ips: ",".join(ips) if ips else None,
            ),
            option_bindings=[
                DataBinding(
                    source_step="port_scan",
                    source_path="hosts[*].ports[?state==open].port",
                    target_option="ports",
                    transform=lambda ports: ",".join(str(p) for p in set(ports)) if ports else None,
                ),
            ],
            options={
                "service_detection": True,
            },
            depends_on=["port_scan"],
            condition=Condition(
                source_step="port_scan",
                check="count_gt",
                path="hosts",
                value=0,
            ),
            timeout=600,
        ),
        ChainStep(
            id="vuln_check",
            tool="nmap",
            description="Vulnerability scanning",
            target_binding=DataBinding(
                source_step="service_scan",
                source_path="hosts[*].ip",
                target_option="target",
                transform=lambda ips: ",".join(ips) if ips else None,
            ),
            options={
                "scan_type": "vuln",
                "scripts": ["vuln"],
            },
            depends_on=["service_scan"],
            condition=Condition(
                source_step="service_scan",
                check="count_gt",
                path="hosts",
                value=0,
            ),
            timeout=900,
        ),
    ],
)


# Quick Recon Chain
quick_recon_chain = ChainDefinition(
    id="quick_recon",
    name="Quick Reconnaissance",
    description="Fast reconnaissance with top ports and basic service detection",
    target_type="ip",
    tags=["scanning", "recon", "quick"],
    steps=[
        ChainStep(
            id="quick_scan",
            tool="nmap",
            description="Quick top-ports scan",
            options={
                "scan_type": "quick",
                "top_ports": 100,
            },
            timeout=120,
        ),
        ChainStep(
            id="service_detect",
            tool="nmap",
            description="Service detection on open ports",
            target_binding=DataBinding(
                source_step="quick_scan",
                source_path="hosts[*].ip",
                target_option="target",
                transform=lambda ips: ",".join(ips) if ips else None,
            ),
            option_bindings=[
                DataBinding(
                    source_step="quick_scan",
                    source_path="hosts[*].ports[?state==open].port",
                    target_option="ports",
                    transform=lambda ports: ",".join(str(p) for p in set(ports)) if ports else None,
                ),
            ],
            options={
                "service_detection": True,
            },
            depends_on=["quick_scan"],
            condition=Condition(
                source_step="quick_scan",
                check="count_gt",
                path="hosts[*].ports",
                value=0,
            ),
            timeout=300,
        ),
    ],
)


# Stealth Scan Chain
stealth_scan_chain = ChainDefinition(
    id="stealth_scan",
    name="Stealth Scan Pipeline",
    description="Low and slow scanning to avoid detection",
    target_type="ip",
    tags=["scanning", "stealth", "evasion"],
    steps=[
        ChainStep(
            id="stealth_discovery",
            tool="nmap",
            description="Stealthy host discovery",
            options={
                "scan_type": "stealth",
                "timing": 2,  # T2 - polite
                "top_ports": 100,
            },
            timeout=600,
        ),
        ChainStep(
            id="stealth_service",
            tool="nmap",
            description="Stealthy service detection",
            target_binding=DataBinding(
                source_step="stealth_discovery",
                source_path="hosts[?state==up].ip",
                target_option="target",
                transform=lambda ips: ",".join(ips) if ips else None,
            ),
            options={
                "scan_type": "stealth",
                "service_detection": True,
                "timing": 2,
            },
            depends_on=["stealth_discovery"],
            condition=Condition(
                source_step="stealth_discovery",
                check="count_gt",
                path="hosts",
                value=0,
            ),
            timeout=900,
        ),
    ],
)


def register_scanning_chains() -> None:
    """Register all scanning chains."""
    chain_registry.register(fast_to_detailed_chain)
    chain_registry.register(vuln_scan_chain)
    chain_registry.register(quick_recon_chain)
    chain_registry.register(stealth_scan_chain)
