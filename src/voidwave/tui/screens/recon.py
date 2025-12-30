"""Reconnaissance screen for web application scanning."""

import asyncio
import shutil
from textual.app import ComposeResult
from textual.containers import Container, Vertical, Horizontal, ScrollableContainer
from textual.screen import Screen
from textual.widgets import Static, Button, Input, DataTable, ListView, ListItem, Label, Select
from textual.binding import Binding

from voidwave.tui.widgets.tool_output import ToolOutput
from voidwave.tui.helpers.preflight_runner import PreflightRunner


class ReconScreen(Screen):
    """Network reconnaissance and web enumeration."""

    CSS = """
    ReconScreen {
        layout: grid;
        grid-size: 2 2;
        grid-rows: 1fr 1fr;
        grid-columns: 1fr 2fr;
    }

    #menu-panel {
        row-span: 2;
        border: solid $success;
        padding: 1;
    }

    #content-panel {
        border: solid $primary;
        padding: 1;
    }

    #output-panel {
        border: solid $warning;
        padding: 1;
    }

    .panel-title {
        text-style: bold;
        margin-bottom: 1;
    }

    .action-item {
        padding: 0 1;
    }

    .action-item:hover {
        background: $secondary;
    }

    #target-input {
        margin: 1 0;
    }

    .result-table {
        height: 100%;
    }
    """

    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back"),
        Binding("r", "refresh", "Refresh"),
    ]

    MENU_ITEMS = [
        ("nikto", "Nikto Web Scan", "nikto_scan"),
        ("gobuster", "Gobuster Dir", "gobuster_scan"),
        ("ffuf", "FFUF Fuzz", "ffuf_scan"),
        ("dirb", "Dirb", "dirb_scan"),
        ("nuclei", "Nuclei Vuln", "nuclei_scan"),
        ("whatweb", "WhatWeb", "whatweb_scan"),
        ("wpscan", "WPScan", "wpscan_scan"),
        ("sslscan", "SSL Scan", "ssl_scan"),
        ("headers", "Security Headers", "headers_check"),
        ("robots", "Robots/Sitemap", "robots_check"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self.current_target: str = ""
        self._preflight: PreflightRunner | None = None

    def compose(self) -> ComposeResult:
        """Compose the recon screen layout."""
        with Vertical(id="menu-panel"):
            yield Static("[bold magenta]RECON[/]", classes="panel-title")
            yield Static("Target URL:", classes="label")
            yield Input(placeholder="https://example.com", id="target-input")
            yield Static("─" * 20)
            yield Static("Wordlist:", classes="label")
            yield Select(
                [
                    ("common.txt", "common"),
                    ("directory-list-2.3-medium.txt", "medium"),
                    ("big.txt", "big"),
                    ("raft-medium-words.txt", "raft"),
                ],
                id="wordlist-select",
                value="common",
            )
            yield Static("─" * 20)
            yield Static("Actions:", classes="panel-title")
            with ListView(id="action-list"):
                for item_id, label, _ in self.MENU_ITEMS:
                    yield ListItem(Label(label), id=item_id, classes="action-item")

        with ScrollableContainer(id="content-panel"):
            yield Static("[bold cyan]Findings[/]", classes="panel-title")
            yield DataTable(id="results-table", classes="result-table")

        with Vertical(id="output-panel"):
            yield Static("[bold yellow]Output[/]", classes="panel-title")
            yield ToolOutput(id="tool-output")

    def on_mount(self) -> None:
        """Initialize the results table."""
        self._preflight = PreflightRunner(self.app)
        table = self.query_one("#results-table", DataTable)
        table.add_columns("Type", "Finding", "Details")

    async def _run_tool(self, tool_name: str, needs_target: bool = True) -> str | None:
        """Prepare and validate tool, return target if ready.

        Args:
            tool_name: Name of the tool to run
            needs_target: Whether a target URL is required

        Returns:
            Target URL if ready, None if cancelled
        """
        target = self._get_target() if needs_target else None

        # Prepare tool with preflight
        ctx = await self._preflight.prepare_tool(tool_name, target=target)

        if not ctx.ready:
            self.notify(ctx.error or f"Cannot run {tool_name}", severity="error")
            return None

        # If we needed a target and got one from preflight, use it
        if needs_target and ctx.target:
            target = ctx.target
            self.query_one("#target-input", Input).value = target

        # Notify if using fallback
        if ctx.used_fallback:
            self._write_output(f"Using {ctx.fallback_tool} instead of {tool_name}", "warning")

        return target

    async def on_list_view_selected(self, event: ListView.Selected) -> None:
        """Handle menu selection."""
        item_id = event.item.id
        for menu_id, _, action_name in self.MENU_ITEMS:
            if menu_id == item_id:
                action_method = getattr(self, f"action_{action_name}", None)
                if action_method:
                    await action_method()
                break

    def _get_target(self) -> str:
        """Get the current target URL."""
        input_widget = self.query_one("#target-input", Input)
        return input_widget.value.strip()

    def _get_wordlist(self) -> str:
        """Get the selected wordlist path."""
        select = self.query_one("#wordlist-select", Select)
        wordlists = {
            "common": "/usr/share/wordlists/dirb/common.txt",
            "medium": "/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt",
            "big": "/usr/share/wordlists/dirb/big.txt",
            "raft": "/usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt",
        }
        return wordlists.get(str(select.value), wordlists["common"])

    def _write_output(self, message: str, level: str = "info") -> None:
        """Write to output panel."""
        output = self.query_one("#tool-output", ToolOutput)
        if level == "success":
            output.write_line(f"[green]{message}[/]")
        elif level == "error":
            output.write_line(f"[red]{message}[/]")
        elif level == "warning":
            output.write_line(f"[yellow]{message}[/]")
        else:
            output.write_line(message)

    def _add_result(self, finding_type: str, finding: str, details: str = "") -> None:
        """Add a finding to the table."""
        table = self.query_one("#results-table", DataTable)
        table.add_row(finding_type, finding, details)

    async def action_nikto_scan(self) -> None:
        """Run Nikto web server scanner."""
        target = await self._run_tool("nikto")
        if not target:
            return

        self._write_output(f"Running Nikto on {target}...")

        proc = await asyncio.create_subprocess_exec(
            "nikto", "-h", target, "-nointeractive",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()

        for line in stdout.decode().split("\n"):
            line = line.strip()
            if line.startswith("+"):
                if "OSVDB" in line or "vulnerability" in line.lower():
                    self._add_result("Vuln", line[2:], "nikto")
                    self._write_output(line, "warning")
                elif "Server:" in line:
                    self._add_result("Server", line[2:], "nikto")
                    self._write_output(line)

        self._write_output("Nikto scan complete", "success")

    async def action_gobuster_scan(self) -> None:
        """Run Gobuster directory brute force."""
        target = await self._run_tool("gobuster")
        if not target:
            return

        wordlist = self._get_wordlist()
        self._write_output(f"Running Gobuster on {target}...")

        proc = await asyncio.create_subprocess_exec(
            "gobuster", "dir", "-u", target, "-w", wordlist, "-q",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()

        for line in stdout.decode().split("\n"):
            line = line.strip()
            if line and "(Status:" in line:
                parts = line.split()
                if parts:
                    path = parts[0]
                    status = line.split("(Status:")[1].split(")")[0] if "(Status:" in line else ""
                    self._add_result("Directory", path, f"Status: {status}")
                    self._write_output(f"Found: {path} [{status}]", "success")

        self._write_output("Gobuster complete", "success")

    async def action_ffuf_scan(self) -> None:
        """Run FFUF fuzzing."""
        target = await self._run_tool("ffuf")
        if not target:
            return

        # Ensure target has FUZZ keyword
        if "FUZZ" not in target:
            target = target.rstrip("/") + "/FUZZ"

        wordlist = self._get_wordlist()
        self._write_output(f"Running FFUF on {target}...")

        proc = await asyncio.create_subprocess_exec(
            "ffuf", "-u", target, "-w", wordlist, "-mc", "200,301,302,403",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()

        for line in stdout.decode().split("\n"):
            if "[Status:" in line:
                self._add_result("Fuzz", line.strip(), "ffuf")
                self._write_output(line.strip(), "success")

        self._write_output("FFUF complete", "success")

    async def action_dirb_scan(self) -> None:
        """Run Dirb directory scanner."""
        target = await self._run_tool("dirb")
        if not target:
            return

        wordlist = self._get_wordlist()
        self._write_output(f"Running Dirb on {target}...")

        proc = await asyncio.create_subprocess_exec(
            "dirb", target, wordlist, "-S",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()

        for line in stdout.decode().split("\n"):
            if "==>" in line or "DIRECTORY:" in line:
                self._add_result("Directory", line.strip(), "dirb")
                self._write_output(line.strip(), "success")

        self._write_output("Dirb complete", "success")

    async def action_nuclei_scan(self) -> None:
        """Run Nuclei vulnerability scanner."""
        target = await self._run_tool("nuclei")
        if not target:
            return

        self._write_output(f"Running Nuclei on {target}...")

        proc = await asyncio.create_subprocess_exec(
            "nuclei", "-u", target, "-severity", "low,medium,high,critical",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()

        for line in stdout.decode().split("\n"):
            line = line.strip()
            if line and "[" in line:
                severity = "info"
                if "[critical]" in line.lower():
                    severity = "error"
                elif "[high]" in line.lower():
                    severity = "error"
                elif "[medium]" in line.lower():
                    severity = "warning"
                self._add_result("Vuln", line, "nuclei")
                self._write_output(line, severity)

        self._write_output("Nuclei scan complete", "success")

    async def action_whatweb_scan(self) -> None:
        """Run WhatWeb fingerprinting."""
        target = await self._run_tool("whatweb")
        if not target:
            return

        self._write_output(f"Running WhatWeb on {target}...")

        proc = await asyncio.create_subprocess_exec(
            "whatweb", "-a", "3", target,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()

        output = stdout.decode()
        # Parse technologies
        techs = output.replace("\n", " ").split(",")
        for tech in techs:
            tech = tech.strip()
            if tech and "[" in tech:
                self._add_result("Tech", tech, "whatweb")
                self._write_output(f"Detected: {tech}", "success")

        self._write_output("WhatWeb complete", "success")

    async def action_wpscan_scan(self) -> None:
        """Run WPScan for WordPress sites."""
        target = await self._run_tool("wpscan")
        if not target:
            return

        self._write_output(f"Running WPScan on {target}...")

        proc = await asyncio.create_subprocess_exec(
            "wpscan", "--url", target, "--enumerate", "vp,vt,u",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()

        for line in stdout.decode().split("\n"):
            line = line.strip()
            if "[!]" in line:
                self._add_result("Warning", line, "wpscan")
                self._write_output(line, "warning")
            elif "[+]" in line:
                self._add_result("Info", line, "wpscan")
                self._write_output(line, "success")

        self._write_output("WPScan complete", "success")

    async def action_ssl_scan(self) -> None:
        """Run SSL/TLS scan."""
        target = self._get_target()
        if not target:
            self.notify("Enter a target URL or host", severity="error")
            return

        # Extract hostname
        from urllib.parse import urlparse
        parsed = urlparse(target)
        host = parsed.netloc or target

        sslscan = shutil.which("sslscan") or shutil.which("sslyze")
        if not sslscan:
            self.notify("sslscan or sslyze not installed", severity="error")
            return

        self._write_output(f"Running SSL scan on {host}...")

        if "sslscan" in sslscan:
            proc = await asyncio.create_subprocess_exec(
                "sslscan", host,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
        else:
            proc = await asyncio.create_subprocess_exec(
                "sslyze", host,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )

        stdout, _ = await proc.communicate()

        for line in stdout.decode().split("\n"):
            line = line.strip()
            if "SSL" in line or "TLS" in line or "cipher" in line.lower():
                level = "warning" if "weak" in line.lower() or "vulnerable" in line.lower() else "info"
                self._add_result("SSL", line, "sslscan")
                self._write_output(line, level)

        self._write_output("SSL scan complete", "success")

    async def action_headers_check(self) -> None:
        """Check security headers."""
        target = self._get_target()
        if not target:
            self.notify("Enter a target URL", severity="error")
            return

        if not shutil.which("curl"):
            self.notify("curl not installed", severity="error")
            return

        self._write_output(f"Checking security headers on {target}...")

        proc = await asyncio.create_subprocess_exec(
            "curl", "-I", "-s", target,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()

        security_headers = [
            "Content-Security-Policy",
            "X-Frame-Options",
            "X-Content-Type-Options",
            "Strict-Transport-Security",
            "X-XSS-Protection",
            "Referrer-Policy",
            "Permissions-Policy",
        ]

        found_headers = []
        for line in stdout.decode().split("\n"):
            for header in security_headers:
                if header.lower() in line.lower():
                    found_headers.append(header)
                    self._add_result("Header", line.strip(), "Present")
                    self._write_output(f"Found: {line.strip()}", "success")

        # Report missing headers
        for header in security_headers:
            if header not in found_headers:
                self._add_result("Header", header, "MISSING")
                self._write_output(f"Missing: {header}", "warning")

        self._write_output("Headers check complete", "success")

    async def action_robots_check(self) -> None:
        """Check robots.txt and sitemap."""
        target = self._get_target()
        if not target:
            self.notify("Enter a target URL", severity="error")
            return

        if not shutil.which("curl"):
            self.notify("curl not installed", severity="error")
            return

        base_url = target.rstrip("/")
        self._write_output(f"Checking robots.txt and sitemap...")

        # Check robots.txt
        proc = await asyncio.create_subprocess_exec(
            "curl", "-s", f"{base_url}/robots.txt",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()

        robots = stdout.decode()
        if "User-agent" in robots or "Disallow" in robots:
            for line in robots.split("\n"):
                line = line.strip()
                if line and not line.startswith("#"):
                    self._add_result("Robots", line, "robots.txt")
                    if "Disallow" in line:
                        self._write_output(line, "warning")
                    else:
                        self._write_output(line)

        # Check sitemap.xml
        proc = await asyncio.create_subprocess_exec(
            "curl", "-s", "-I", f"{base_url}/sitemap.xml",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()

        if "200" in stdout.decode():
            self._add_result("Sitemap", "sitemap.xml exists", base_url)
            self._write_output("Sitemap found at /sitemap.xml", "success")

        self._write_output("Robots/sitemap check complete", "success")

    def action_refresh(self) -> None:
        """Clear results and refresh."""
        table = self.query_one("#results-table", DataTable)
        table.clear()
        output = self.query_one("#tool-output", ToolOutput)
        output.clear()
        self.notify("Results cleared")
