"""OSINT gathering screen."""

import asyncio
import os
import shutil
from textual.app import ComposeResult
from textual.containers import Container, Vertical, Horizontal, ScrollableContainer
from textual.screen import Screen
from textual.widgets import Static, Button, Input, DataTable, ListView, ListItem, Label
from textual.binding import Binding

from voidwave.tui.widgets.output import ToolOutput


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
        border: solid green;
        padding: 1;
    }

    #content-panel {
        border: solid cyan;
        padding: 1;
    }

    #output-panel {
        border: solid yellow;
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
        background: $accent;
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

    async def action_theharvester(self) -> None:
        """Run theHarvester for email and subdomain enumeration."""
        target = self._get_target()
        if not target:
            self.notify("Enter a target domain", severity="error")
            return

        harvester = shutil.which("theHarvester") or shutil.which("theharvester")
        if not harvester:
            self.notify("theHarvester not installed", severity="error")
            return

        self._write_output(f"Running theHarvester on {target}...")

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
        target = self._get_target()
        if not target:
            self.notify("Enter a target domain", severity="error")
            return

        if not shutil.which("subfinder"):
            self.notify("subfinder not installed", severity="error")
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
        target = self._get_target()
        if not target:
            self.notify("Enter a target domain", severity="error")
            return

        if not shutil.which("amass"):
            self.notify("amass not installed", severity="error")
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
        target = self._get_target()
        if not target:
            self.notify("Enter a target domain or IP", severity="error")
            return

        if not shutil.which("whois"):
            self.notify("whois not installed", severity="error")
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
        target = self._get_target()
        if not target:
            self.notify("Enter a target domain", severity="error")
            return

        dig = shutil.which("dig")
        if not dig:
            self.notify("dig not installed", severity="error")
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
            self.notify("Enter a target IP or domain", severity="error")
            return

        api_key = os.environ.get("SHODAN_API_KEY")
        if not api_key:
            # Try to load from stored keys
            key_path = os.path.expanduser("~/.voidwave/keys/shodan.key")
            if os.path.exists(key_path):
                with open(key_path) as f:
                    api_key = f.read().strip()

        if not api_key:
            self.notify("Shodan API key required. Configure in Settings.", severity="error")
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
            self.notify("Enter a target IP", severity="error")
            return

        api_id = os.environ.get("CENSYS_API_ID")
        api_secret = os.environ.get("CENSYS_API_SECRET")

        if not api_id or not api_secret:
            self.notify("Censys API credentials required. Configure in Settings.", severity="error")
            return

        self._write_output(f"Searching Censys for {target}...")
        self._write_output("Censys search requires additional integration", "warning")

    async def action_google_dorks(self) -> None:
        """Generate Google dorks for the target."""
        target = self._get_target()
        if not target:
            self.notify("Enter a target domain", severity="error")
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
        target = self._get_target()
        if not target:
            self.notify("Enter a username to search", severity="error")
            return

        if not shutil.which("sherlock"):
            self.notify("sherlock not installed", severity="error")
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
