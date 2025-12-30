"""Gobuster directory/DNS bruteforce wrapper."""
import re
from typing import Any, ClassVar

from pydantic import BaseModel

from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper


class GobusterConfig(BaseModel):
    """Gobuster-specific configuration."""

    mode: str = "dir"  # dir, dns, vhost, fuzz
    wordlist: str = "/usr/share/seclists/Discovery/Web-Content/common.txt"
    threads: int = 10
    timeout: int = 10
    follow_redirects: bool = False
    expanded: bool = False  # Show full URLs
    no_error: bool = True  # Don't show errors


class GobusterTool(BaseToolWrapper):
    """Gobuster directory/DNS bruteforce wrapper."""

    TOOL_BINARY: ClassVar[str] = "gobuster"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="gobuster",
        version="1.0.0",
        description="Directory/file & DNS busting tool",
        author="VOIDWAVE",
        plugin_type=PluginType.SCANNER,
        capabilities=[
            Capability.DIR_ENUM,
            Capability.WEB_SCAN,
            Capability.SUBDOMAIN_ENUM,
        ],
        requires_root=False,
        external_tools=["gobuster"],
        config_schema=GobusterConfig,
    )

    def __init__(self, gobuster_config: GobusterConfig | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self.gobuster_config = gobuster_config or GobusterConfig()

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build gobuster command."""
        mode = options.get("mode", self.gobuster_config.mode)
        cmd = [mode]

        # URL for dir/vhost modes
        if mode in ("dir", "vhost", "fuzz"):
            cmd.extend(["-u", target])
        elif mode == "dns":
            cmd.extend(["-d", target])

        # Wordlist
        wordlist = options.get("wordlist", self.gobuster_config.wordlist)
        cmd.extend(["-w", wordlist])

        # Threads
        threads = options.get("threads", self.gobuster_config.threads)
        cmd.extend(["-t", str(threads)])

        # Extensions for dir mode
        if mode == "dir":
            extensions = options.get("extensions")
            if extensions:
                cmd.extend(["-x", extensions])

        # Status codes to include
        status_codes = options.get("status_codes")
        if status_codes:
            cmd.extend(["-s", status_codes])

        # Follow redirects
        if options.get("follow_redirects", self.gobuster_config.follow_redirects):
            cmd.append("-r")

        # Expanded output (full URLs)
        if options.get("expanded", self.gobuster_config.expanded):
            cmd.append("-e")

        # No error output
        if options.get("no_error", self.gobuster_config.no_error):
            cmd.append("--no-error")

        # Quiet mode (less verbose)
        if options.get("quiet"):
            cmd.append("-q")

        # Pattern for fuzz mode
        if mode == "fuzz":
            pattern = options.get("pattern")
            if pattern:
                cmd.extend(["-p", pattern])

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse gobuster output."""
        results = {
            "directories": [],
            "files": [],
            "subdomains": [],
            "vhosts": [],
        }

        for line in output.splitlines():
            line = line.strip()
            if not line or line.startswith("="):
                continue

            # Directory/file results: /path (Status: 200) [Size: 1234]
            dir_match = re.match(
                r"(/\S+)\s+\(Status:\s*(\d+)\)(?:\s+\[Size:\s*(\d+)\])?",
                line,
            )
            if dir_match:
                entry = {
                    "path": dir_match.group(1),
                    "status": int(dir_match.group(2)),
                }
                if dir_match.group(3):
                    entry["size"] = int(dir_match.group(3))

                # Classify as file or directory
                if "." in dir_match.group(1).split("/")[-1]:
                    results["files"].append(entry)
                else:
                    results["directories"].append(entry)
                continue

            # Full URL results: http://example.com/path (Status: 200)
            url_match = re.match(
                r"(https?://\S+)\s+\(Status:\s*(\d+)\)(?:\s+\[Size:\s*(\d+)\])?",
                line,
            )
            if url_match:
                entry = {
                    "url": url_match.group(1),
                    "status": int(url_match.group(2)),
                }
                if url_match.group(3):
                    entry["size"] = int(url_match.group(3))
                results["directories"].append(entry)
                continue

            # DNS results: Found: subdomain.example.com
            dns_match = re.match(r"Found:\s*(\S+)", line)
            if dns_match:
                results["subdomains"].append({"subdomain": dns_match.group(1)})
                continue

            # Vhost results: Found: vhost.example.com (Status: 200)
            vhost_match = re.match(r"Found:\s*(\S+)\s+\(Status:\s*(\d+)\)", line)
            if vhost_match:
                results["vhosts"].append({
                    "vhost": vhost_match.group(1),
                    "status": int(vhost_match.group(2)),
                })

        # Summary
        results["summary"] = {
            "total_directories": len(results["directories"]),
            "total_files": len(results["files"]),
            "total_subdomains": len(results["subdomains"]),
            "total_vhosts": len(results["vhosts"]),
        }

        return results

    async def dir_scan(self, target: str, wordlist: str | None = None) -> dict[str, Any]:
        """Perform directory enumeration."""
        options = {"mode": "dir"}
        if wordlist:
            options["wordlist"] = wordlist
        result = await self.execute(target, options)
        return result.data

    async def dns_scan(self, domain: str, wordlist: str | None = None) -> dict[str, Any]:
        """Perform DNS subdomain enumeration."""
        options = {"mode": "dns"}
        if wordlist:
            options["wordlist"] = wordlist
        result = await self.execute(domain, options)
        return result.data
