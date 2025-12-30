"""WhatWeb web fingerprinting wrapper."""
import json
import re
from typing import Any, ClassVar

from pydantic import BaseModel

from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper


class WhatWebConfig(BaseModel):
    """WhatWeb-specific configuration."""

    aggression: int = 1  # 1=stealthy, 3=aggressive, 4=heavy
    color: str = "never"
    log_format: str = "json"
    max_redirects: int = 5
    user_agent: str = ""
    plugins: list[str] = []


class WhatWebTool(BaseToolWrapper):
    """WhatWeb web fingerprinting wrapper."""

    TOOL_BINARY: ClassVar[str] = "whatweb"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="whatweb",
        version="1.0.0",
        description="Web technology fingerprinting tool",
        author="VOIDWAVE",
        plugin_type=PluginType.SCANNER,
        capabilities=[
            Capability.FINGERPRINT,
            Capability.WEB_SCAN,
            Capability.SERVICE_ENUM,
        ],
        requires_root=False,
        external_tools=["whatweb"],
        config_schema=WhatWebConfig,
    )

    def __init__(self, whatweb_config: WhatWebConfig | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self.whatweb_config = whatweb_config or WhatWebConfig()

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build whatweb command."""
        cmd = []

        # Aggression level
        aggression = options.get("aggression", self.whatweb_config.aggression)
        cmd.extend(["-a", str(aggression)])

        # JSON output for parsing
        cmd.extend(["--log-json=-"])

        # No color
        cmd.extend(["--color", "never"])

        # Max redirects
        max_redirects = options.get("max_redirects", self.whatweb_config.max_redirects)
        cmd.extend(["--max-redirects", str(max_redirects)])

        # User agent
        user_agent = options.get("user_agent", self.whatweb_config.user_agent)
        if user_agent:
            cmd.extend(["-U", user_agent])

        # Specific plugins
        plugins = options.get("plugins", self.whatweb_config.plugins)
        if plugins:
            cmd.extend(["-p", ",".join(plugins)])

        # Proxy
        proxy = options.get("proxy")
        if proxy:
            cmd.extend(["--proxy", proxy])

        # Cookies
        cookies = options.get("cookies")
        if cookies:
            cmd.extend(["--cookie", cookies])

        # HTTP auth
        auth = options.get("auth")
        if auth:
            cmd.extend(["-u", auth])  # user:pass format

        # Target
        cmd.append(target)

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse whatweb JSON output."""
        results = {
            "targets": [],
            "technologies": [],
            "headers": {},
            "plugins_detected": [],
        }

        # Try JSON parsing first
        for line in output.splitlines():
            line = line.strip()
            if not line or not line.startswith("{"):
                continue

            try:
                data = json.loads(line)
                target_info = {
                    "target": data.get("target", ""),
                    "http_status": data.get("http_status"),
                    "request_config": data.get("request_config", {}),
                }

                # Extract plugins (technologies)
                plugins = data.get("plugins", {})
                techs = []

                for plugin_name, plugin_data in plugins.items():
                    tech = {"name": plugin_name}

                    if isinstance(plugin_data, dict):
                        # Version info
                        if "version" in plugin_data:
                            versions = plugin_data["version"]
                            if versions:
                                tech["version"] = versions[0] if isinstance(versions, list) else versions

                        # String patterns found
                        if "string" in plugin_data:
                            strings = plugin_data["string"]
                            if strings:
                                tech["details"] = strings[0] if isinstance(strings, list) else strings

                    techs.append(tech)
                    results["plugins_detected"].append(plugin_name)

                target_info["technologies"] = techs
                results["targets"].append(target_info)

                # Aggregate unique technologies
                for tech in techs:
                    if tech not in results["technologies"]:
                        results["technologies"].append(tech)

            except json.JSONDecodeError:
                continue

        # Fallback to text parsing if no JSON
        if not results["targets"]:
            results = self._parse_text_output(output)

        # Summary
        results["summary"] = {
            "total_targets": len(results["targets"]),
            "total_technologies": len(results["technologies"]),
        }

        return results

    def _parse_text_output(self, output: str) -> dict[str, Any]:
        """Fallback text output parsing."""
        results = {
            "targets": [],
            "technologies": [],
            "headers": {},
            "plugins_detected": [],
        }

        for line in output.splitlines():
            line = line.strip()
            if not line:
                continue

            # URL line: http://example.com [200 OK] ...
            url_match = re.match(r"(https?://\S+)\s+\[(\d+[^\]]*)\](.+)?", line)
            if url_match:
                target_info = {
                    "target": url_match.group(1),
                    "http_status": url_match.group(2),
                    "technologies": [],
                }

                # Parse technology tags: [Apache] [PHP/7.4]
                if url_match.group(3):
                    tech_matches = re.findall(r"\[([^\]]+)\]", url_match.group(3))
                    for tech in tech_matches:
                        tech_info = {"name": tech}
                        # Check for version
                        version_match = re.match(r"(.+)/(.+)", tech)
                        if version_match:
                            tech_info["name"] = version_match.group(1)
                            tech_info["version"] = version_match.group(2)

                        target_info["technologies"].append(tech_info)
                        if tech_info not in results["technologies"]:
                            results["technologies"].append(tech_info)
                        results["plugins_detected"].append(tech_info["name"])

                results["targets"].append(target_info)

        return results

    async def fingerprint(self, target: str) -> dict[str, Any]:
        """Perform web fingerprinting."""
        result = await self.execute(target, {})
        return result.data

    async def aggressive_scan(self, target: str) -> dict[str, Any]:
        """Perform aggressive fingerprinting."""
        result = await self.execute(target, {"aggression": 4})
        return result.data
