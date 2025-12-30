"""OSINT gathering screen."""

import asyncio
import os
import shutil
from textual.app import ComposeResult
from textual.containers import Container, Vertical, Horizontal, ScrollableContainer
from textual.screen import Screen
from textual.widgets import Static, Button, Input, DataTable, ListView, ListItem, Label
from textual.binding import Binding

from voidwave.tui.widgets.tool_output import ToolOutput
from voidwave.tui.helpers.preflight_runner import PreflightRunner


class OsintScreen(Screen):
    """Open Source Intelligence gathering."""

    CSS = """
    OsintScreen {
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
        ("harvester", "theHarvester", "theharvester"),
        ("subfinder", "Subfinder", "subfinder"),
        ("amass", "Amass", "amass"),
        ("whois", "WHOIS Lookup", "whois_lookup"),
        ("dns", "DNS Lookup", "dns_lookup"),
        ("shodan", "Shodan Search", "shodan_search"),
        ("censys", "Censys Search", "censys_search"),
        ("dorks", "Google Dorks", "google_dorks"),
        ("sherlock", "Sherlock", "sherlock"),
        ("full", "Full Investigation", "full_investigation"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self.current_target: str = ""
        self._preflight: PreflightRunner | None = None

    def compose(self) -> ComposeResult:
        """Compose the OSINT screen layout."""
        with Vertical(id="menu-panel"):
            yield Static("[bold magenta]OSINT[/]", classes="panel-title")
            yield Static("Target:", classes="label")
            yield Input(placeholder="domain.com or IP", id="target-input")
            yield Static("─" * 20)
            yield Static("Actions:", classes="panel-title")
            with ListView(id="action-list"):
                for item_id, label, _ in self.MENU_ITEMS:
                    yield ListItem(Label(label), id=item_id, classes="action-item")

        with ScrollableContainer(id="content-panel"):
            yield Static("[bold cyan]Results[/]", classes="panel-title")
            yield DataTable(id="results-table", classes="result-table")

        with Vertical(id="output-panel"):
            yield Static("[bold yellow]Output[/]", classes="panel-title")
            yield ToolOutput(id="tool-output")

    def on_mount(self) -> None:
        """Initialize the results table."""
        self._preflight = PreflightRunner(self.app)
        table = self.query_one("#results-table", DataTable)
        table.add_columns("Type", "Data", "Source")

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
        """Get the current target from input."""
        input_widget = self.query_one("#target-input", Input)
        return input_widget.value.strip()

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

    def _add_result(self, result_type: str, data: str, source: str) -> None:
        """Add a result to the table."""
        table = self.query_one("#results-table", DataTable)
        table.add_row(result_type, data, source)

    async def _run_tool(self, tool: str) -> str | None:
        """Run preflight checks for a tool and return target."""
        if not self._preflight:
            return None
        ctx = await self._preflight.prepare_tool(tool)
        if not ctx.ready:
            self._write_output(ctx.error or f"{tool} not available", "error")
            return None
        if ctx.used_fallback and ctx.fallback_tool:
            self._write_output(f"Using {ctx.fallback_tool} instead of {tool}", "warning")
        target = self._get_target()
        if not target:
            target = await self._preflight.ensure_target("domain")
        return target

    async def action_theharvester(self) -> None:
        """Run theHarvester for email and subdomain enumeration."""
        target = await self._run_tool("theharvester")
        if not target:
            return

        self._write_output(f"Running theHarvester on {target}...")
        harvester = shutil.which("theHarvester") or shutil.which("theharvester")

        proc = await asyncio.create_subprocess_exec(
            harvester, "-d", target, "-b", "all",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await proc.communicate()

        output = stdout.decode()
        # Parse emails and subdomains
        for line in output.split("\n"):
            line = line.strip()
            if "@" in line and "." in line:
                self._add_result("Email", line, "theHarvester")
                self._write_output(f"Email: {line}", "success")
            elif target in line and not line.startswith("["):
                self._add_result("Subdomain", line, "theHarvester")
                self._write_output(f"Subdomain: {line}", "success")

        self._write_output("theHarvester complete", "success")

    async def action_subfinder(self) -> None:
        """Run subfinder for subdomain enumeration."""
        target = await self._run_tool("subfinder")
        if not target:
            return

        self._write_output(f"Running subfinder on {target}...")

        proc = await asyncio.create_subprocess_exec(
            "subfinder", "-d", target, "-silent",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()

        for line in stdout.decode().split("\n"):
            subdomain = line.strip()
            if subdomain:
                self._add_result("Subdomain", subdomain, "subfinder")
                self._write_output(f"Found: {subdomain}", "success")

        self._write_output("subfinder complete", "success")

    async def action_amass(self) -> None:
        """Run amass for subdomain enumeration."""
        target = await self._run_tool("amass")
        if not target:
            return

        self._write_output(f"Running amass on {target} (this may take a while)...")

        proc = await asyncio.create_subprocess_exec(
            "amass", "enum", "-passive", "-d", target,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()

        for line in stdout.decode().split("\n"):
            subdomain = line.strip()
            if subdomain:
                self._add_result("Subdomain", subdomain, "amass")
                self._write_output(f"Found: {subdomain}", "success")

        self._write_output("amass complete", "success")

    async def action_whois_lookup(self) -> None:
        """Run WHOIS lookup."""
        target = await self._run_tool("whois")
        if not target:
            return

        self._write_output(f"Running WHOIS on {target}...")

        proc = await asyncio.create_subprocess_exec(
            "whois", target,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()

        output = stdout.decode()
        # Parse key fields
        fields = ["Registrant", "Admin", "Tech", "Name Server", "Creation Date", "Expiry"]
        for line in output.split("\n"):
            for field in fields:
                if field.lower() in line.lower():
                    self._add_result("WHOIS", line.strip(), "whois")
                    self._write_output(line.strip())
                    break

        self._write_output("WHOIS complete", "success")

    async def action_dns_lookup(self) -> None:
        """Run DNS lookups."""
        target = await self._run_tool("dig")
        if not target:
            return

        self._write_output(f"Running DNS lookups on {target}...")

        record_types = ["A", "AAAA", "MX", "NS", "TXT", "CNAME", "SOA"]

        for rtype in record_types:
            proc = await asyncio.create_subprocess_exec(
                "dig", "+short", target, rtype,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, _ = await proc.communicate()

            for line in stdout.decode().split("\n"):
                record = line.strip()
                if record:
                    self._add_result(f"DNS-{rtype}", record, "dig")
                    self._write_output(f"{rtype}: {record}", "success")

        self._write_output("DNS lookup complete", "success")

    async def action_shodan_search(self) -> None:
        """Search Shodan for the target."""
        target = self._get_target()
        if not target:
            if self._preflight:
                target = await self._preflight.ensure_target("ip")
            if not target:
                return

        api_key = os.environ.get("SHODAN_API_KEY")
        if not api_key:
            # Try to load from stored keys
            key_path = os.path.expanduser("~/.voidwave/keys/shodan.key")
            if os.path.exists(key_path):
                with open(key_path) as f:
                    api_key = f.read().strip()

        if not api_key and self._preflight:
            api_key = await self._preflight.ensure_api_key("SHODAN_API_KEY")

        if not api_key:
            self._write_output("Shodan API key required. Configure in Settings.", "error")
            return

        if not shutil.which("curl"):
            self.notify("curl not installed", severity="error")
            return

        self._write_output(f"Searching Shodan for {target}...")

        # Use Shodan API directly
        proc = await asyncio.create_subprocess_shell(
            f'curl -s "https://api.shodan.io/shodan/host/{target}?key={api_key}"',
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()

        import json
        try:
            data = json.loads(stdout.decode())
            if "error" in data:
                self._write_output(f"Shodan error: {data['error']}", "error")
            else:
                # Parse results
                if "ports" in data:
                    self._add_result("Ports", ", ".join(map(str, data["ports"])), "shodan")
                if "os" in data:
                    self._add_result("OS", data["os"], "shodan")
                if "org" in data:
                    self._add_result("Organization", data["org"], "shodan")
                if "isp" in data:
                    self._add_result("ISP", data["isp"], "shodan")
                for item in data.get("data", [])[:10]:
                    port = item.get("port", "?")
                    product = item.get("product", "unknown")
                    self._add_result(f"Service:{port}", product, "shodan")
                    self._write_output(f"Port {port}: {product}", "success")
        except json.JSONDecodeError:
            self._write_output("Failed to parse Shodan response", "error")

        self._write_output("Shodan search complete", "success")

    async def action_censys_search(self) -> None:
        """Search Censys for the target."""
        target = self._get_target()
        if not target:
            if self._preflight:
                target = await self._preflight.ensure_target("ip")
            if not target:
                return

        api_id = os.environ.get("CENSYS_API_ID")
        api_secret = os.environ.get("CENSYS_API_SECRET")

        if not api_id and self._preflight:
            api_id = await self._preflight.ensure_api_key("CENSYS_API_ID")
        if not api_secret and self._preflight:
            api_secret = await self._preflight.ensure_api_key("CENSYS_API_SECRET")

        if not api_id or not api_secret:
            self._write_output("Censys API credentials required. Configure in Settings.", "error")
            return

        self._write_output(f"Searching Censys for {target}...")
        self._write_output("Censys search requires additional integration", "warning")

    async def action_google_dorks(self) -> None:
        """Generate Google dorks for the target."""
        target = self._get_target()
        if not target:
            if self._preflight:
                target = await self._preflight.ensure_target("domain")
            if not target:
                return

        self._write_output(f"Generating Google dorks for {target}...")

        dorks = [
            f'site:{target} filetype:pdf',
            f'site:{target} filetype:doc OR filetype:docx',
            f'site:{target} filetype:xls OR filetype:xlsx',
            f'site:{target} inurl:admin',
            f'site:{target} inurl:login',
            f'site:{target} inurl:config',
            f'site:{target} "index of"',
            f'site:{target} intitle:"Index of"',
            f'site:{target} ext:sql OR ext:db',
            f'site:{target} "password" OR "passwd"',
            f'site:{target} inurl:wp-content',
            f'site:{target} inurl:backup',
        ]

        for dork in dorks:
            self._add_result("Dork", dork, "manual")
            self._write_output(dork)

        self._write_output("Google dorks generated - copy to browser", "success")

    async def action_sherlock(self) -> None:
        """Run Sherlock for username enumeration."""
        target = await self._run_tool("sherlock")
        if not target:
            return

        self._write_output(f"Running Sherlock for username: {target}...")

        proc = await asyncio.create_subprocess_exec(
            "sherlock", target, "--print-found",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()

        for line in stdout.decode().split("\n"):
            line = line.strip()
            if "http" in line:
                self._add_result("Social", line, "sherlock")
                self._write_output(f"Found: {line}", "success")

        self._write_output("Sherlock complete", "success")

    async def action_full_investigation(self) -> None:
        """Run full OSINT investigation."""
        target = self._get_target()
        if not target:
            self.notify("Enter a target domain", severity="error")
            return

        self._write_output(f"Starting full investigation on {target}...")

        # Run multiple tools
        await self.action_whois_lookup()
        await self.action_dns_lookup()
        await self.action_subfinder()
        await self.action_google_dorks()

        self._write_output("Full investigation complete", "success")

    def action_refresh(self) -> None:
        """Clear results and refresh."""
        table = self.query_one("#results-table", DataTable)
        table.clear()
        output = self.query_one("#tool-output", ToolOutput)
        output.clear()
        self.notify("Results cleared")
