"""Nikto web vulnerability scanner wrapper."""
import re
from typing import Any, ClassVar

from pydantic import BaseModel

from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper


class NiktoConfig(BaseModel):
    """Nikto-specific configuration."""

    timeout: int = 600
    tuning: str = ""  # Scan tuning options
    plugins: list[str] = []
    output_format: str = "txt"  # txt, csv, htm, xml
    ssl: bool = False
    no_ssl: bool = False
    pause: int = 0  # Pause between requests


class NiktoTool(BaseToolWrapper):
    """Nikto web vulnerability scanner wrapper."""

    TOOL_BINARY: ClassVar[str] = "nikto"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="nikto",
        version="1.0.0",
        description="Web server vulnerability scanner",
        author="VOIDWAVE",
        plugin_type=PluginType.SCANNER,
        capabilities=[
            Capability.WEB_SCAN,
            Capability.VULN_SCAN,
            Capability.FINGERPRINT,
        ],
        requires_root=False,
        external_tools=["nikto"],
        config_schema=NiktoConfig,
    )

    # Tuning options
    TUNING_OPTIONS = {
        "1": "Interesting files",
        "2": "Misconfiguration",
        "3": "Information disclosure",
        "4": "Injection (XSS/Script)",
        "5": "Remote file retrieval",
        "6": "Denial of service",
        "7": "Remote file retrieval (server)",
        "8": "Command execution",
        "9": "SQL injection",
        "0": "File upload",
        "a": "Authentication bypass",
        "b": "Software identification",
        "c": "Remote source inclusion",
        "d": "WebService",
        "e": "Administrative console",
        "x": "Reverse tuning (exclude)",
    }

    def __init__(self, nikto_config: NiktoConfig | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self.nikto_config = nikto_config or NiktoConfig()

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build nikto command."""
        cmd = ["-h", target]

        # Port
        port = options.get("port")
        if port:
            cmd.extend(["-p", str(port)])

        # SSL
        if options.get("ssl", self.nikto_config.ssl):
            cmd.append("-ssl")
        elif options.get("no_ssl", self.nikto_config.no_ssl):
            cmd.append("-nossl")

        # Tuning
        tuning = options.get("tuning", self.nikto_config.tuning)
        if tuning:
            cmd.extend(["-Tuning", tuning])

        # Plugins
        plugins = options.get("plugins", self.nikto_config.plugins)
        if plugins:
            cmd.extend(["-Plugins", ",".join(plugins)])

        # Pause between requests
        pause = options.get("pause", self.nikto_config.pause)
        if pause > 0:
            cmd.extend(["-Pause", str(pause)])

        # Root directory
        root = options.get("root")
        if root:
            cmd.extend(["-root", root])

        # Authentication
        auth = options.get("auth")
        if auth:
            cmd.extend(["-id", auth])  # user:pass format

        # User agent
        user_agent = options.get("user_agent")
        if user_agent:
            cmd.extend(["-useragent", user_agent])

        # Disable interactive mode
        cmd.append("-Display")
        cmd.append("1234EP")  # Show redirects, cookies, auth, headers, progress

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse nikto output."""
        results = {
            "target": None,
            "server": None,
            "vulnerabilities": [],
            "findings": [],
            "ssl_info": None,
        }

        for line in output.splitlines():
            line = line.strip()

            # Target info
            target_match = re.match(r"\+ Target IP:\s+(.+)", line)
            if target_match:
                results["target"] = target_match.group(1)
                continue

            # Server info
            server_match = re.match(r"\+ Server:\s+(.+)", line)
            if server_match:
                results["server"] = server_match.group(1)
                continue

            # SSL info
            ssl_match = re.match(r"\+ SSL Info:\s+(.+)", line)
            if ssl_match:
                results["ssl_info"] = ssl_match.group(1)
                continue

            # OSVDB vulnerability
            osvdb_match = re.match(r"\+ (OSVDB-\d+):\s+(.+)", line)
            if osvdb_match:
                results["vulnerabilities"].append({
                    "id": osvdb_match.group(1),
                    "description": osvdb_match.group(2),
                    "type": "osvdb",
                })
                continue

            # Generic findings (+ lines with URLs or paths)
            finding_match = re.match(r"\+ (/\S+):\s+(.+)", line)
            if finding_match:
                results["findings"].append({
                    "path": finding_match.group(1),
                    "description": finding_match.group(2),
                })
                continue

            # Other findings
            if line.startswith("+ ") and ":" in line:
                parts = line[2:].split(":", 1)
                if len(parts) == 2:
                    results["findings"].append({
                        "type": parts[0].strip(),
                        "description": parts[1].strip(),
                    })

        # Summary
        results["summary"] = {
            "total_vulnerabilities": len(results["vulnerabilities"]),
            "total_findings": len(results["findings"]),
        }

        return results

    async def scan(self, target: str, tuning: str | None = None) -> dict[str, Any]:
        """Perform web vulnerability scan."""
        options = {}
        if tuning:
            options["tuning"] = tuning
        result = await self.execute(target, options)
        return result.data

    async def quick_scan(self, target: str) -> dict[str, Any]:
        """Perform quick scan with basic checks."""
        result = await self.execute(target, {"tuning": "12b"})
        return result.data
