"""Nuclei template-based vulnerability scanner wrapper."""
import json
import re
from typing import Any, ClassVar

from pydantic import BaseModel

from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper


class NucleiConfig(BaseModel):
    """Nuclei-specific configuration."""

    templates_dir: str = ""  # Custom templates directory
    severity: list[str] = ["critical", "high", "medium"]
    tags: list[str] = []
    exclude_tags: list[str] = []
    rate_limit: int = 150
    bulk_size: int = 25
    concurrency: int = 25
    timeout: int = 5
    retries: int = 1
    output_format: str = "jsonl"


class NucleiTool(BaseToolWrapper):
    """Nuclei template-based vulnerability scanner wrapper."""

    TOOL_BINARY: ClassVar[str] = "nuclei"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="nuclei",
        version="1.0.0",
        description="Fast and customizable vulnerability scanner",
        author="VOIDWAVE",
        plugin_type=PluginType.SCANNER,
        capabilities=[
            Capability.VULN_SCAN,
            Capability.WEB_SCAN,
            Capability.SERVICE_ENUM,
        ],
        requires_root=False,
        external_tools=["nuclei"],
        config_schema=NucleiConfig,
    )

    # Severity levels
    SEVERITIES = ["info", "low", "medium", "high", "critical", "unknown"]

    # Common template tags
    TEMPLATE_TAGS = {
        "cve": "CVE vulnerabilities",
        "panel": "Admin panels",
        "exposure": "Sensitive data exposure",
        "xss": "Cross-site scripting",
        "sqli": "SQL injection",
        "rce": "Remote code execution",
        "lfi": "Local file inclusion",
        "ssrf": "Server-side request forgery",
        "redirect": "Open redirect",
        "takeover": "Subdomain takeover",
        "tech": "Technology detection",
        "config": "Misconfigurations",
    }

    def __init__(self, nuclei_config: NucleiConfig | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self.nuclei_config = nuclei_config or NucleiConfig()

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build nuclei command."""
        cmd = ["-target", target]

        # Output format (JSON lines for parsing)
        cmd.extend(["-jsonl"])

        # Severity filter
        severity = options.get("severity", self.nuclei_config.severity)
        if severity:
            cmd.extend(["-severity", ",".join(severity)])

        # Tags filter
        tags = options.get("tags", self.nuclei_config.tags)
        if tags:
            cmd.extend(["-tags", ",".join(tags)])

        # Exclude tags
        exclude_tags = options.get("exclude_tags", self.nuclei_config.exclude_tags)
        if exclude_tags:
            cmd.extend(["-exclude-tags", ",".join(exclude_tags)])

        # Templates directory
        templates_dir = options.get("templates_dir", self.nuclei_config.templates_dir)
        if templates_dir:
            cmd.extend(["-t", templates_dir])

        # Specific templates
        templates = options.get("templates")
        if templates:
            for template in templates:
                cmd.extend(["-t", template])

        # Rate limiting
        rate_limit = options.get("rate_limit", self.nuclei_config.rate_limit)
        cmd.extend(["-rate-limit", str(rate_limit)])

        # Bulk size
        bulk_size = options.get("bulk_size", self.nuclei_config.bulk_size)
        cmd.extend(["-bulk-size", str(bulk_size)])

        # Concurrency
        concurrency = options.get("concurrency", self.nuclei_config.concurrency)
        cmd.extend(["-c", str(concurrency)])

        # Timeout
        timeout = options.get("request_timeout", self.nuclei_config.timeout)
        cmd.extend(["-timeout", str(timeout)])

        # Retries
        retries = options.get("retries", self.nuclei_config.retries)
        cmd.extend(["-retries", str(retries)])

        # Silent mode (less verbose)
        if options.get("silent"):
            cmd.append("-silent")

        # Update templates
        if options.get("update_templates"):
            cmd.append("-update-templates")

        # HTTP proxy
        proxy = options.get("proxy")
        if proxy:
            cmd.extend(["-proxy", proxy])

        # Headers
        headers = options.get("headers")
        if headers:
            for header in headers:
                cmd.extend(["-H", header])

        # Follow redirects
        if options.get("follow_redirects", True):
            cmd.append("-follow-redirects")

        # No color
        cmd.append("-no-color")

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse nuclei JSONL output."""
        results = {
            "findings": [],
            "by_severity": {sev: [] for sev in self.SEVERITIES},
            "by_template": {},
            "by_tag": {},
        }

        for line in output.splitlines():
            line = line.strip()
            if not line:
                continue

            # Try JSON parsing
            try:
                data = json.loads(line)

                finding = {
                    "template_id": data.get("template-id", ""),
                    "template_name": data.get("info", {}).get("name", ""),
                    "severity": data.get("info", {}).get("severity", "unknown"),
                    "type": data.get("type", ""),
                    "host": data.get("host", ""),
                    "matched_at": data.get("matched-at", ""),
                    "extracted_results": data.get("extracted-results", []),
                    "description": data.get("info", {}).get("description", ""),
                    "tags": data.get("info", {}).get("tags", []),
                    "reference": data.get("info", {}).get("reference", []),
                    "matcher_name": data.get("matcher-name", ""),
                }

                results["findings"].append(finding)

                # Categorize by severity
                severity = finding["severity"].lower()
                if severity in results["by_severity"]:
                    results["by_severity"][severity].append(finding)

                # Categorize by template
                template_id = finding["template_id"]
                if template_id not in results["by_template"]:
                    results["by_template"][template_id] = []
                results["by_template"][template_id].append(finding)

                # Categorize by tags
                for tag in finding["tags"]:
                    if tag not in results["by_tag"]:
                        results["by_tag"][tag] = []
                    results["by_tag"][tag].append(finding)

            except json.JSONDecodeError:
                # Fallback: parse text output
                # Format: [severity] [template-id] [type] matched-at
                text_match = re.match(
                    r"\[(\w+)\]\s+\[([^\]]+)\]\s+\[([^\]]+)\]\s+(.+)",
                    line,
                )
                if text_match:
                    finding = {
                        "severity": text_match.group(1).lower(),
                        "template_id": text_match.group(2),
                        "type": text_match.group(3),
                        "matched_at": text_match.group(4),
                    }
                    results["findings"].append(finding)

        # Summary
        results["summary"] = {
            "total_findings": len(results["findings"]),
            "critical": len(results["by_severity"]["critical"]),
            "high": len(results["by_severity"]["high"]),
            "medium": len(results["by_severity"]["medium"]),
            "low": len(results["by_severity"]["low"]),
            "info": len(results["by_severity"]["info"]),
        }

        return results

    async def scan(
        self,
        target: str,
        severity: list[str] | None = None,
        tags: list[str] | None = None,
    ) -> dict[str, Any]:
        """Perform vulnerability scan."""
        options = {}
        if severity:
            options["severity"] = severity
        if tags:
            options["tags"] = tags
        result = await self.execute(target, options)
        return result.data

    async def cve_scan(self, target: str) -> dict[str, Any]:
        """Scan for CVE vulnerabilities."""
        result = await self.execute(target, {"tags": ["cve"]})
        return result.data

    async def tech_detect(self, target: str) -> dict[str, Any]:
        """Detect technologies."""
        result = await self.execute(target, {
            "tags": ["tech"],
            "severity": ["info"],
        })
        return result.data
