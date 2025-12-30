"""FFUF web fuzzer wrapper."""
import json
import re
from typing import Any, ClassVar

from pydantic import BaseModel

from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper


class FfufConfig(BaseModel):
    """FFUF-specific configuration."""

    wordlist: str = "/usr/share/seclists/Discovery/Web-Content/common.txt"
    threads: int = 40
    timeout: int = 10
    rate: int = 0  # Requests per second, 0 = unlimited
    recursion: bool = False
    recursion_depth: int = 1
    follow_redirects: bool = False
    auto_calibrate: bool = True
    filter_status: str = ""  # Filter by status codes
    filter_size: str = ""  # Filter by response size
    match_status: str = "200,204,301,302,307,401,403,405"


class FfufTool(BaseToolWrapper):
    """FFUF web fuzzer wrapper."""

    TOOL_BINARY: ClassVar[str] = "ffuf"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="ffuf",
        version="1.0.0",
        description="Fast web fuzzer written in Go",
        author="VOIDWAVE",
        plugin_type=PluginType.SCANNER,
        capabilities=[
            Capability.WEB_FUZZ,
            Capability.DIR_ENUM,
            Capability.WEB_SCAN,
        ],
        requires_root=False,
        external_tools=["ffuf"],
        config_schema=FfufConfig,
    )

    def __init__(self, ffuf_config: FfufConfig | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self.ffuf_config = ffuf_config or FfufConfig()

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build ffuf command."""
        cmd = []

        # URL with FUZZ keyword
        url = target if "FUZZ" in target else f"{target.rstrip('/')}/FUZZ"
        cmd.extend(["-u", url])

        # Wordlist
        wordlist = options.get("wordlist", self.ffuf_config.wordlist)
        cmd.extend(["-w", wordlist])

        # Output format (JSON for parsing)
        cmd.extend(["-of", "json"])
        cmd.extend(["-o", "-"])  # Output to stdout

        # Threads
        threads = options.get("threads", self.ffuf_config.threads)
        cmd.extend(["-t", str(threads)])

        # Timeout
        timeout = options.get("timeout", self.ffuf_config.timeout)
        cmd.extend(["-timeout", str(timeout)])

        # Rate limiting
        rate = options.get("rate", self.ffuf_config.rate)
        if rate > 0:
            cmd.extend(["-rate", str(rate)])

        # Recursion
        if options.get("recursion", self.ffuf_config.recursion):
            cmd.append("-recursion")
            depth = options.get("recursion_depth", self.ffuf_config.recursion_depth)
            cmd.extend(["-recursion-depth", str(depth)])

        # Follow redirects
        if options.get("follow_redirects", self.ffuf_config.follow_redirects):
            cmd.append("-r")

        # Auto calibration
        if options.get("auto_calibrate", self.ffuf_config.auto_calibrate):
            cmd.append("-ac")

        # Match status codes
        match_status = options.get("match_status", self.ffuf_config.match_status)
        if match_status:
            cmd.extend(["-mc", match_status])

        # Filter status codes
        filter_status = options.get("filter_status", self.ffuf_config.filter_status)
        if filter_status:
            cmd.extend(["-fc", filter_status])

        # Filter by size
        filter_size = options.get("filter_size", self.ffuf_config.filter_size)
        if filter_size:
            cmd.extend(["-fs", filter_size])

        # Filter by words
        filter_words = options.get("filter_words")
        if filter_words:
            cmd.extend(["-fw", filter_words])

        # Filter by lines
        filter_lines = options.get("filter_lines")
        if filter_lines:
            cmd.extend(["-fl", filter_lines])

        # Filter by regex
        filter_regex = options.get("filter_regex")
        if filter_regex:
            cmd.extend(["-fr", filter_regex])

        # Extensions
        extensions = options.get("extensions")
        if extensions:
            cmd.extend(["-e", extensions])

        # HTTP method
        method = options.get("method", "GET")
        cmd.extend(["-X", method])

        # POST data
        data = options.get("data")
        if data:
            cmd.extend(["-d", data])

        # Headers
        headers = options.get("headers")
        if headers:
            for header in headers:
                cmd.extend(["-H", header])

        # Cookies
        cookies = options.get("cookies")
        if cookies:
            cmd.extend(["-b", cookies])

        # Proxy
        proxy = options.get("proxy")
        if proxy:
            cmd.extend(["-x", proxy])

        # Silent mode
        cmd.append("-s")

        # No colors
        cmd.append("-c")

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse ffuf JSON output."""
        results = {
            "results": [],
            "directories": [],
            "files": [],
            "by_status": {},
        }

        # Try to find and parse JSON output
        json_start = output.find("{")
        if json_start != -1:
            try:
                # FFUF outputs complete JSON object
                json_data = json.loads(output[json_start:])

                # Extract results
                for result in json_data.get("results", []):
                    entry = {
                        "url": result.get("url", ""),
                        "input": result.get("input", {}).get("FUZZ", ""),
                        "status": result.get("status", 0),
                        "length": result.get("length", 0),
                        "words": result.get("words", 0),
                        "lines": result.get("lines", 0),
                        "content_type": result.get("content-type", ""),
                        "redirect_location": result.get("redirectlocation", ""),
                    }
                    results["results"].append(entry)

                    # Classify as file or directory
                    fuzz_input = entry["input"]
                    if "." in fuzz_input:
                        results["files"].append(entry)
                    else:
                        results["directories"].append(entry)

                    # Group by status
                    status = str(entry["status"])
                    if status not in results["by_status"]:
                        results["by_status"][status] = []
                    results["by_status"][status].append(entry)

            except json.JSONDecodeError:
                pass

        # Fallback to text parsing if no JSON
        if not results["results"]:
            results = self._parse_text_output(output)

        # Summary
        results["summary"] = {
            "total_results": len(results["results"]),
            "directories": len(results["directories"]),
            "files": len(results["files"]),
            "status_200": len(results["by_status"].get("200", [])),
            "status_301": len(results["by_status"].get("301", [])),
            "status_403": len(results["by_status"].get("403", [])),
        }

        return results

    def _parse_text_output(self, output: str) -> dict[str, Any]:
        """Fallback text output parsing."""
        results = {
            "results": [],
            "directories": [],
            "files": [],
            "by_status": {},
        }

        # Text format: path [Status: 200, Size: 1234, Words: 56, Lines: 7]
        pattern = re.compile(
            r"(\S+)\s+\[Status:\s*(\d+),\s*Size:\s*(\d+)"
            r"(?:,\s*Words:\s*(\d+))?(?:,\s*Lines:\s*(\d+))?\]"
        )

        for line in output.splitlines():
            match = pattern.search(line)
            if match:
                entry = {
                    "input": match.group(1),
                    "status": int(match.group(2)),
                    "length": int(match.group(3)),
                    "words": int(match.group(4)) if match.group(4) else 0,
                    "lines": int(match.group(5)) if match.group(5) else 0,
                }
                results["results"].append(entry)

                if "." in entry["input"]:
                    results["files"].append(entry)
                else:
                    results["directories"].append(entry)

        return results

    async def dir_fuzz(
        self,
        target: str,
        wordlist: str | None = None,
    ) -> dict[str, Any]:
        """Fuzz for directories."""
        options = {}
        if wordlist:
            options["wordlist"] = wordlist
        result = await self.execute(target, options)
        return result.data

    async def param_fuzz(
        self,
        target: str,
        wordlist: str | None = None,
    ) -> dict[str, Any]:
        """Fuzz for parameters (URL must contain FUZZ keyword)."""
        options = {"auto_calibrate": True}
        if wordlist:
            options["wordlist"] = wordlist
        result = await self.execute(target, options)
        return result.data

    async def extension_fuzz(
        self,
        target: str,
        extensions: str = "php,asp,aspx,jsp,html,js",
    ) -> dict[str, Any]:
        """Fuzz for files with specific extensions."""
        result = await self.execute(target, {"extensions": extensions})
        return result.data
