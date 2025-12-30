"""Built-in web attack chains."""

from voidwave.chaining.models import (
    ChainDefinition,
    ChainStep,
    Condition,
    DataBinding,
    OnErrorBehavior,
)
from voidwave.chaining.registry import chain_registry


# SQL Injection Attack Chain
sqli_attack_chain = ChainDefinition(
    id="sqli_attack",
    name="SQL Injection Pipeline",
    description="Automated SQL injection testing and exploitation",
    target_type="url",
    tags=["web", "sqli", "injection", "exploitation"],
    steps=[
        ChainStep(
            id="sqli_test",
            tool="sqlmap",
            description="Test for SQL injection vulnerabilities",
            options={
                "level": 2,
                "risk": 2,
                "batch": True,
                "threads": 4,
            },
            timeout=1800,
        ),
        ChainStep(
            id="enum_dbs",
            tool="sqlmap",
            description="Enumerate databases",
            options={
                "dbs": True,
                "batch": True,
            },
            depends_on=["sqli_test"],
            condition=Condition(
                source_step="sqli_test",
                check="equals",
                path="data.vulnerable",
                value=True,
            ),
            timeout=600,
        ),
        ChainStep(
            id="enum_tables",
            tool="sqlmap",
            description="Enumerate tables",
            options={
                "tables": True,
                "batch": True,
            },
            depends_on=["enum_dbs"],
            condition=Condition(
                source_step="enum_dbs",
                check="count_gt",
                path="data.databases",
                value=0,
            ),
            timeout=600,
        ),
    ],
)


# Web Fuzzing Pipeline
web_fuzz_chain = ChainDefinition(
    id="web_fuzz",
    name="Web Fuzzing Pipeline",
    description="Comprehensive web fuzzing for directories, parameters, and vulnerabilities",
    target_type="url",
    tags=["web", "fuzz", "discovery", "bruteforce"],
    steps=[
        ChainStep(
            id="dir_fuzz",
            tool="ffuf",
            description="Directory fuzzing",
            options={
                "wordlist": "/usr/share/seclists/Discovery/Web-Content/common.txt",
                "threads": 40,
                "match_status": "200,204,301,302,307,401,403,405",
                "auto_calibrate": True,
            },
            timeout=600,
        ),
        ChainStep(
            id="extension_fuzz",
            tool="ffuf",
            description="File extension fuzzing",
            options={
                "wordlist": "/usr/share/seclists/Discovery/Web-Content/web-extensions.txt",
                "threads": 40,
                "extensions": "php,asp,aspx,jsp,html,js,txt,bak",
            },
            depends_on=["dir_fuzz"],
            timeout=600,
        ),
        ChainStep(
            id="vuln_scan",
            tool="nuclei",
            description="Vulnerability scanning on discovered paths",
            options={
                "severity": ["low", "medium", "high", "critical"],
                "tags": ["xss", "sqli", "lfi", "rce", "ssrf"],
            },
            depends_on=["dir_fuzz"],
            parallel_with=["extension_fuzz"],
            timeout=900,
        ),
    ],
)


# Vulnerability to Exploit Chain
vuln_exploit_chain = ChainDefinition(
    id="vuln_exploit",
    name="Vulnerability Discovery to Exploit",
    description="Find vulnerabilities and map to potential exploits",
    target_type="ip",
    tags=["web", "vuln", "exploit", "cve"],
    steps=[
        ChainStep(
            id="port_scan",
            tool="nmap",
            description="Service version detection",
            options={
                "ports": "80,443,8080,8443",
                "service_detection": True,
                "scripts": ["vuln", "http-enum"],
            },
            timeout=600,
        ),
        ChainStep(
            id="nuclei_cve",
            tool="nuclei",
            description="CVE vulnerability scan",
            target_binding=DataBinding(
                source_step="port_scan",
                source_path="hosts",
                target_option="target",
                transform="first_http_url",
            ),
            options={
                "tags": ["cve"],
                "severity": ["high", "critical"],
            },
            depends_on=["port_scan"],
            condition=Condition(
                source_step="port_scan",
                check="count_gt",
                path="hosts",
                value=0,
            ),
            timeout=900,
        ),
        ChainStep(
            id="nikto_vuln",
            tool="nikto",
            description="Web server vulnerability scan",
            target_binding=DataBinding(
                source_step="port_scan",
                source_path="hosts",
                target_option="target",
                transform="first_http_url",
            ),
            options={
                "tuning": "49",  # Injection, command exec, SQL injection
            },
            depends_on=["port_scan"],
            parallel_with=["nuclei_cve"],
            timeout=600,
        ),
    ],
)


# XSS Testing Chain
xss_test_chain = ChainDefinition(
    id="xss_test",
    name="XSS Testing Pipeline",
    description="Cross-site scripting vulnerability detection",
    target_type="url",
    tags=["web", "xss", "injection"],
    steps=[
        ChainStep(
            id="param_discovery",
            tool="ffuf",
            description="Discover URL parameters",
            options={
                "wordlist": "/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt",
                "threads": 40,
                "auto_calibrate": True,
            },
            timeout=600,
        ),
        ChainStep(
            id="xss_scan",
            tool="nuclei",
            description="XSS vulnerability scan",
            options={
                "tags": ["xss"],
                "severity": ["low", "medium", "high", "critical"],
            },
            depends_on=["param_discovery"],
            timeout=600,
        ),
    ],
)


# API Reconnaissance Chain
api_recon_chain = ChainDefinition(
    id="api_recon",
    name="API Reconnaissance Pipeline",
    description="Discover and enumerate API endpoints",
    target_type="url",
    tags=["web", "api", "recon", "discovery"],
    steps=[
        ChainStep(
            id="api_discovery",
            tool="ffuf",
            description="API endpoint discovery",
            options={
                "wordlist": "/usr/share/seclists/Discovery/Web-Content/api/api-endpoints.txt",
                "threads": 40,
                "match_status": "200,201,204,301,302,307,400,401,403,405",
                "auto_calibrate": True,
            },
            timeout=900,
        ),
        ChainStep(
            id="api_version",
            tool="ffuf",
            description="API version fuzzing",
            options={
                "wordlist": "/usr/share/seclists/Discovery/Web-Content/api/api-seen-in-wild.txt",
                "threads": 20,
            },
            depends_on=["api_discovery"],
            timeout=600,
        ),
        ChainStep(
            id="api_vuln",
            tool="nuclei",
            description="API vulnerability scan",
            options={
                "tags": ["api", "exposure"],
                "severity": ["medium", "high", "critical"],
            },
            depends_on=["api_discovery"],
            parallel_with=["api_version"],
            timeout=600,
        ),
    ],
)


# Full Web Attack Chain
full_web_attack_chain = ChainDefinition(
    id="full_web_attack",
    name="Full Web Attack Pipeline",
    description="Comprehensive web application attack chain",
    target_type="url",
    tags=["web", "comprehensive", "attack"],
    steps=[
        ChainStep(
            id="fingerprint",
            tool="whatweb",
            description="Technology fingerprinting",
            options={
                "aggression": 3,
            },
            timeout=300,
        ),
        ChainStep(
            id="dir_enum",
            tool="gobuster",
            description="Directory enumeration",
            options={
                "mode": "dir",
                "wordlist": "/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-small.txt",
                "threads": 20,
                "extensions": "php,asp,aspx,jsp,html",
            },
            depends_on=["fingerprint"],
            timeout=900,
        ),
        ChainStep(
            id="vuln_scan",
            tool="nikto",
            description="Vulnerability scan",
            options={
                "tuning": "123489",  # Full tuning
            },
            depends_on=["fingerprint"],
            parallel_with=["dir_enum"],
            timeout=900,
        ),
        ChainStep(
            id="nuclei_scan",
            tool="nuclei",
            description="Template-based vulnerability scan",
            options={
                "severity": ["medium", "high", "critical"],
            },
            depends_on=["vuln_scan", "dir_enum"],
            timeout=1200,
        ),
        ChainStep(
            id="sqli_test",
            tool="sqlmap",
            description="SQL injection testing",
            options={
                "level": 2,
                "risk": 2,
                "batch": True,
                "forms": True,
                "crawl": 2,
            },
            depends_on=["nuclei_scan"],
            condition=Condition(
                source_step="nuclei_scan",
                check="count_gt",
                path="data.findings",
                value=0,
            ),
            timeout=1800,
        ),
    ],
)


def register_web_chains() -> None:
    """Register all web attack chains."""
    chain_registry.register(sqli_attack_chain)
    chain_registry.register(web_fuzz_chain)
    chain_registry.register(vuln_exploit_chain)
    chain_registry.register(xss_test_chain)
    chain_registry.register(api_recon_chain)
    chain_registry.register(full_web_attack_chain)
