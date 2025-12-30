"""Subfinder subdomain discovery wrapper."""
import json
import re
from typing import Any, ClassVar

from pydantic import BaseModel

from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper


class SubfinderConfig(BaseModel):
    """Subfinder-specific configuration."""

    threads: int = 10
    timeout: int = 30
    max_time: int = 300
    sources: list[str] = []  # Specific sources to use
    exclude_sources: list[str] = []
    recursive: bool = False
    all_sources: bool = False
    output_format: str = "json"


class SubfinderTool(BaseToolWrapper):
    """Subfinder subdomain discovery wrapper."""

    TOOL_BINARY: ClassVar[str] = "subfinder"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="subfinder",
        version="1.0.0",
        description="Fast passive subdomain enumeration tool",
        author="VOIDWAVE",
        plugin_type=PluginType.SCANNER,
        capabilities=[
            Capability.SUBDOMAIN_ENUM,
            Capability.OSINT,
        ],
        requires_root=False,
        external_tools=["subfinder"],
        config_schema=SubfinderConfig,
    )

    # Available sources
    SOURCES = [
        "alienvault",
        "anubis",
        "bevigil",
        "binaryedge",
        "bufferover",
        "c99",
        "censys",
        "certspotter",
        "chaos",
        "chinaz",
        "crtsh",
        "dnsdumpster",
        "dnsrepo",
        "fofa",
        "fullhunt",
        "github",
        "hackertarget",
        "hunter",
        "intelx",
        "netlas",
        "passivetotal",
        "quake",
        "rapiddns",
        "securitytrails",
        "shodan",
        "sitedossier",
        "threatbook",
        "virustotal",
        "whoisxmlapi",
        "zoomeye",
    ]

    def __init__(self, subfinder_config: SubfinderConfig | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self.subfinder_config = subfinder_config or SubfinderConfig()

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build subfinder command."""
        cmd = ["-d", target]

        # JSON output for parsing
        cmd.append("-json")

        # Threads
        threads = options.get("threads", self.subfinder_config.threads)
        cmd.extend(["-t", str(threads)])

        # Timeout per source
        timeout = options.get("timeout", self.subfinder_config.timeout)
        cmd.extend(["-timeout", str(timeout)])

        # Max enumeration time
        max_time = options.get("max_time", self.subfinder_config.max_time)
        cmd.extend(["-max-time", str(max_time)])

        # Specific sources
        sources = options.get("sources", self.subfinder_config.sources)
        if sources:
            cmd.extend(["-sources", ",".join(sources)])

        # Exclude sources
        exclude_sources = options.get("exclude_sources", self.subfinder_config.exclude_sources)
        if exclude_sources:
            cmd.extend(["-exclude-sources", ",".join(exclude_sources)])

        # All sources (including slow ones)
        if options.get("all_sources", self.subfinder_config.all_sources):
            cmd.append("-all")

        # Recursive enumeration
        if options.get("recursive", self.subfinder_config.recursive):
            cmd.append("-recursive")

        # Silent mode
        if options.get("silent"):
            cmd.append("-silent")

        # No color
        cmd.append("-nc")

        # Config file
        config_file = options.get("config_file")
        if config_file:
            cmd.extend(["-config", config_file])

        # Resolver list
        resolvers = options.get("resolvers")
        if resolvers:
            cmd.extend(["-r", resolvers])

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse subfinder JSON output."""
        results = {
            "subdomains": [],
            "by_source": {},
            "unique_hosts": set(),
        }

        for line in output.splitlines():
            line = line.strip()
            if not line:
                continue

            # Try JSON parsing
            try:
                data = json.loads(line)
                host = data.get("host", "")
                source = data.get("source", "unknown")

                if host:
                    subdomain_info = {
                        "subdomain": host,
                        "source": source,
                    }
                    results["subdomains"].append(subdomain_info)
                    results["unique_hosts"].add(host)

                    # Group by source
                    if source not in results["by_source"]:
                        results["by_source"][source] = []
                    results["by_source"][source].append(host)

            except json.JSONDecodeError:
                # Plain text output (one subdomain per line)
                if "." in line and not line.startswith("["):
                    results["subdomains"].append({
                        "subdomain": line,
                        "source": "unknown",
                    })
                    results["unique_hosts"].add(line)

        # Convert set to list for JSON serialization
        results["unique_hosts"] = sorted(list(results["unique_hosts"]))

        # Summary
        results["summary"] = {
            "total_subdomains": len(results["subdomains"]),
            "unique_subdomains": len(results["unique_hosts"]),
            "sources_used": len(results["by_source"]),
        }

        return results

    async def enumerate(self, domain: str, recursive: bool = False) -> dict[str, Any]:
        """Enumerate subdomains."""
        result = await self.execute(domain, {"recursive": recursive})
        return result.data

    async def quick_enum(self, domain: str) -> dict[str, Any]:
        """Quick subdomain enumeration with fast sources only."""
        fast_sources = ["crtsh", "hackertarget", "rapiddns", "dnsdumpster"]
        result = await self.execute(domain, {"sources": fast_sources})
        return result.data

    async def deep_enum(self, domain: str) -> dict[str, Any]:
        """Deep enumeration with all sources and recursion."""
        result = await self.execute(domain, {
            "all_sources": True,
            "recursive": True,
        })
        return result.data
