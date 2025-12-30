"""Built-in credential attack chains."""

from voidwave.chaining.models import (
    ChainDefinition,
    ChainStep,
    Condition,
    DataBinding,
    OnErrorBehavior,
)
from voidwave.chaining.registry import chain_registry


# SSH Bruteforce Chain
ssh_bruteforce_chain = ChainDefinition(
    id="ssh_bruteforce",
    name="SSH Bruteforce Pipeline",
    description="Discover SSH services and bruteforce credentials",
    target_type="cidr",
    tags=["credentials", "ssh", "bruteforce"],
    steps=[
        ChainStep(
            id="find_ssh",
            tool="nmap",
            description="Find SSH services",
            options={
                "ports": "22,2222",
                "service_detection": True,
            },
            timeout=300,
        ),
        ChainStep(
            id="bruteforce_ssh",
            tool="hydra",
            description="Bruteforce SSH credentials",
            target_binding=DataBinding(
                source_step="find_ssh",
                source_path="hosts",
                target_option="target",
                transform="first_ssh",
            ),
            options={
                "service": "ssh",
                "user_list": "/usr/share/seclists/Usernames/top-usernames-shortlist.txt",
                "pass_list": "/usr/share/wordlists/rockyou.txt",
                "threads": 4,
            },
            depends_on=["find_ssh"],
            condition=Condition(
                source_step="find_ssh",
                check="count_gt",
                path="hosts[*].ports[?service==ssh]",
                value=0,
            ),
            timeout=3600,
        ),
    ],
)


# Web Login Bruteforce Chain
web_bruteforce_chain = ChainDefinition(
    id="web_bruteforce",
    name="Web Login Bruteforce",
    description="Discover web services and bruteforce login forms",
    target_type="ip",
    tags=["credentials", "web", "bruteforce"],
    steps=[
        ChainStep(
            id="find_web",
            tool="nmap",
            description="Find web services",
            options={
                "ports": "80,443,8080,8443",
                "service_detection": True,
            },
            timeout=300,
        ),
        ChainStep(
            id="bruteforce_http",
            tool="hydra",
            description="Bruteforce HTTP basic auth",
            target_binding=DataBinding(
                source_step="find_web",
                source_path="hosts",
                target_option="target",
                transform="first_http",
            ),
            options={
                "service": "http-get",
                "user_list": "/usr/share/seclists/Usernames/top-usernames-shortlist.txt",
                "pass_list": "/usr/share/seclists/Passwords/Common-Credentials/10k-most-common.txt",
                "threads": 4,
            },
            depends_on=["find_web"],
            condition=Condition(
                source_step="find_web",
                check="count_gt",
                path="hosts[*].ports",
                value=0,
            ),
            timeout=1800,
        ),
    ],
)


# Hash Crack Chain
hash_crack_chain = ChainDefinition(
    id="hash_crack",
    name="Hash Cracking Pipeline",
    description="Identify and crack password hashes",
    target_type="file",
    tags=["credentials", "cracking", "hashes"],
    steps=[
        ChainStep(
            id="hashcat_crack",
            tool="hashcat",
            description="GPU-accelerated hash cracking",
            options={
                "attack_mode": "dictionary",
                "wordlist": "/usr/share/wordlists/rockyou.txt",
            },
            on_error=OnErrorBehavior.FALLBACK,
            fallback_tool="john",
            timeout=7200,
        ),
    ],
)


# Credential Spray Chain
credential_spray_chain = ChainDefinition(
    id="credential_spray",
    name="Credential Spraying",
    description="Crack hashes then spray credentials across services",
    target_type="cidr",
    tags=["credentials", "spray", "lateral"],
    steps=[
        ChainStep(
            id="discover_services",
            tool="nmap",
            description="Discover authentication services",
            options={
                "ports": "22,23,21,445,3389,5985,5986",
                "service_detection": True,
            },
            timeout=600,
        ),
        ChainStep(
            id="spray_ssh",
            tool="hydra",
            description="Spray credentials on SSH",
            target_binding=DataBinding(
                source_step="discover_services",
                source_path="hosts",
                target_option="target",
                transform="ssh_hosts_csv",
            ),
            options={
                "service": "ssh",
                "threads": 2,  # Low and slow to avoid lockouts
            },
            depends_on=["discover_services"],
            condition=Condition(
                source_step="discover_services",
                check="count_gt",
                path="hosts[*].ports[?service==ssh]",
                value=0,
            ),
            timeout=1800,
        ),
        ChainStep(
            id="spray_smb",
            tool="hydra",
            description="Spray credentials on SMB",
            target_binding=DataBinding(
                source_step="discover_services",
                source_path="hosts",
                target_option="target",
                transform="smb_hosts_csv",
            ),
            options={
                "service": "smb",
                "threads": 2,
            },
            depends_on=["discover_services"],
            parallel_with=["spray_ssh"],
            condition=Condition(
                source_step="discover_services",
                check="count_gt",
                path="hosts[*].ports[?service==microsoft-ds]",
                value=0,
            ),
            timeout=1800,
        ),
    ],
)


# FTP Bruteforce Chain
ftp_bruteforce_chain = ChainDefinition(
    id="ftp_bruteforce",
    name="FTP Bruteforce Pipeline",
    description="Discover FTP services and bruteforce credentials",
    target_type="cidr",
    tags=["credentials", "ftp", "bruteforce"],
    steps=[
        ChainStep(
            id="find_ftp",
            tool="nmap",
            description="Find FTP services",
            options={
                "ports": "21",
                "service_detection": True,
                "scripts": ["ftp-anon"],  # Check for anonymous access
            },
            timeout=300,
        ),
        ChainStep(
            id="bruteforce_ftp",
            tool="hydra",
            description="Bruteforce FTP credentials",
            target_binding=DataBinding(
                source_step="find_ftp",
                source_path="hosts",
                target_option="target",
                transform="first_ftp",
            ),
            options={
                "service": "ftp",
                "user_list": "/usr/share/seclists/Usernames/top-usernames-shortlist.txt",
                "pass_list": "/usr/share/seclists/Passwords/Common-Credentials/10-million-password-list-top-1000.txt",
                "threads": 4,
            },
            depends_on=["find_ftp"],
            condition=Condition(
                source_step="find_ftp",
                check="count_gt",
                path="hosts[*].ports[?service==ftp]",
                value=0,
            ),
            timeout=1800,
        ),
    ],
)


def register_credential_chains() -> None:
    """Register all credential chains."""
    chain_registry.register(ssh_bruteforce_chain)
    chain_registry.register(web_bruteforce_chain)
    chain_registry.register(hash_crack_chain)
    chain_registry.register(credential_spray_chain)
    chain_registry.register(ftp_bruteforce_chain)
