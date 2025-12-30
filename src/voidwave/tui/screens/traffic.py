"""Network traffic analysis screen."""

import asyncio
import shutil
import tempfile
from pathlib import Path
from textual.app import ComposeResult
from textual.containers import Container, Vertical, Horizontal, ScrollableContainer
from textual.screen import Screen
from textual.widgets import Static, Button, Input, DataTable, ListView, ListItem, Label, Select
from textual.binding import Binding

from voidwave.tui.widgets.tool_output import ToolOutput
from voidwave.tui.helpers.preflight_runner import PreflightRunner


class TrafficScreen(Screen):
    """Packet capture and network traffic analysis."""

    CSS = """
    TrafficScreen {
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

    .result-table {
        height: 100%;
    }

    #stop-btn {
        margin-top: 1;
    }
    """

    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back"),
        Binding("s", "stop_capture", "Stop"),
        Binding("r", "refresh", "Refresh"),
    ]

    MENU_ITEMS = [
        ("tcpdump", "Packet Capture", "tcpdump_capture"),
        ("tshark", "TShark Capture", "tshark_capture"),
        ("wireshark", "Open Wireshark", "wireshark"),
        ("arp-spoof", "ARP Spoofing", "arp_spoof"),
        ("dns-spoof", "DNS Spoofing", "dns_spoof"),
        ("http-sniff", "HTTP Sniffing", "http_sniff"),
        ("dns-sniff", "DNS Sniffing", "dns_sniff"),
        ("creds", "Credential Sniffing", "creds_sniff"),
        ("analyze", "Analyze PCAP", "analyze_pcap"),
        ("stats", "Interface Stats", "interface_stats"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self.capture_process: asyncio.subprocess.Process | None = None
        self.capture_file: str = ""
        self._preflight: PreflightRunner | None = None

    def compose(self) -> ComposeResult:
        """Compose the traffic screen layout."""
        with Vertical(id="menu-panel"):
            yield Static("[bold magenta]TRAFFIC[/]", classes="panel-title")
            yield Static("Interface:", classes="label")
            yield Select(
                [("eth0", "eth0"), ("wlan0", "wlan0"), ("any", "any")],
                id="iface-select",
                value="any",
            )
            yield Static("Filter:", classes="label")
            yield Input(placeholder="tcp port 80", id="filter-input")
            yield Static("─" * 20)
            yield Static("Actions:", classes="panel-title")
            with ListView(id="action-list"):
                for item_id, label, _ in self.MENU_ITEMS:
                    yield ListItem(Label(label), id=item_id, classes="action-item")
            yield Button("Stop Capture", id="stop-btn", variant="error")

        with ScrollableContainer(id="content-panel"):
            yield Static("[bold cyan]Packets[/]", classes="panel-title")
            yield DataTable(id="packets-table", classes="result-table")

        with Vertical(id="output-panel"):
            yield Static("[bold yellow]Output[/]", classes="panel-title")
            yield ToolOutput(id="tool-output")

    def on_mount(self) -> None:
        """Initialize the packets table."""
        self._preflight = PreflightRunner(self.app)
        table = self.query_one("#packets-table", DataTable)
        table.add_columns("Time", "Source", "Dest", "Protocol", "Info")

    async def on_list_view_selected(self, event: ListView.Selected) -> None:
        """Handle menu selection."""
        item_id = event.item.id
        for menu_id, _, action_name in self.MENU_ITEMS:
            if menu_id == item_id:
                action_method = getattr(self, f"action_{action_name}", None)
                if action_method:
                    await action_method()
                break

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        if event.button.id == "stop-btn":
            await self.action_stop_capture()

    def _get_interface(self) -> str:
        """Get the selected interface."""
        select = self.query_one("#iface-select", Select)
        return str(select.value)

    def _get_filter(self) -> str:
        """Get the capture filter."""
        input_widget = self.query_one("#filter-input", Input)
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

    def _add_packet(self, time: str, src: str, dst: str, proto: str, info: str) -> None:
        """Add a packet to the table."""
        table = self.query_one("#packets-table", DataTable)
        table.add_row(time, src, dst, proto, info[:50])

    async def _run_tool(self, tool: str, need_root: bool = True) -> bool:
        """Run preflight checks for a tool."""
        if not self._preflight:
            return False
        if need_root and not await self._preflight.ensure_root():
            return False
        ctx = await self._preflight.prepare_tool(tool)
        if not ctx.ready:
            self._write_output(ctx.error or f"{tool} not available", "error")
            return False
        if ctx.used_fallback and ctx.fallback_tool:
            self._write_output(f"Using {ctx.fallback_tool} instead of {tool}", "warning")
        return True

    async def action_tcpdump_capture(self) -> None:
        """Start tcpdump capture."""
        if not await self._run_tool("tcpdump"):
            return

        interface = self._get_interface()
        filter_expr = self._get_filter()

        self.capture_file = tempfile.mktemp(suffix=".pcap")
        self._write_output(f"Starting capture on {interface}...")

        cmd = ["tcpdump", "-i", interface, "-l", "-nn"]
        if filter_expr:
            cmd.extend(filter_expr.split())
        cmd.extend(["-w", self.capture_file])

        self.capture_process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        self._write_output(f"Capturing to {self.capture_file}", "success")
        self._write_output("Press 'Stop Capture' to end", "warning")

        # Read output in background
        asyncio.create_task(self._read_capture_output())

    async def action_tshark_capture(self) -> None:
        """Start tshark capture."""
        if not await self._run_tool("tshark"):
            return

        interface = self._get_interface()
        filter_expr = self._get_filter()

        self._write_output(f"Starting tshark on {interface}...")

        cmd = ["tshark", "-i", interface, "-l"]
        if filter_expr:
            cmd.extend(["-f", filter_expr])

        self.capture_process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        # Read and display output
        asyncio.create_task(self._read_tshark_output())

    async def _read_capture_output(self) -> None:
        """Read capture output in background."""
        if not self.capture_process:
            return

        while True:
            if self.capture_process.returncode is not None:
                break
            await asyncio.sleep(1)

    async def _read_tshark_output(self) -> None:
        """Read tshark output and display packets."""
        if not self.capture_process or not self.capture_process.stdout:
            return

        while True:
            line = await self.capture_process.stdout.readline()
            if not line:
                break

            line = line.decode().strip()
            if line:
                # Parse tshark output
                parts = line.split()
                if len(parts) >= 5:
                    time = parts[0] if parts[0] else "?"
                    src = parts[2] if len(parts) > 2 else "?"
                    dst = parts[4] if len(parts) > 4 else "?"
                    proto = parts[5] if len(parts) > 5 else "?"
                    info = " ".join(parts[6:]) if len(parts) > 6 else ""
                    self._add_packet(time, src, dst, proto, info)

    async def action_stop_capture(self) -> None:
        """Stop any running capture."""
        if self.capture_process:
            self.capture_process.terminate()
            await self.capture_process.wait()
            self.capture_process = None
            self._write_output("Capture stopped", "success")
            if self.capture_file:
                self._write_output(f"Saved to: {self.capture_file}")
        else:
            self.notify("No capture running", severity="warning")

    async def action_wireshark(self) -> None:
        """Open Wireshark."""
        if not await self._run_tool("wireshark", need_root=False):
            return

        interface = self._get_interface()
        self._write_output("Opening Wireshark...")

        await asyncio.create_subprocess_exec(
            "wireshark", "-i", interface, "-k",
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
        )

    async def action_arp_spoof(self) -> None:
        """Start ARP spoofing (requires target configuration)."""
        if not await self._run_tool("arpspoof"):
            return

        self._write_output("ARP spoofing requires target and gateway configuration", "warning")
        self._write_output("Usage: arpspoof -i interface -t target gateway")

    async def action_dns_spoof(self) -> None:
        """Start DNS spoofing."""
        if not await self._run_tool("dnsspoof"):
            return

        self._write_output("DNS spoofing requires hosts file configuration", "warning")
        self._write_output("Usage: dnsspoof -i interface -f hosts.txt")

    async def action_http_sniff(self) -> None:
        """Sniff HTTP traffic."""
        if not await self._run_tool("tcpdump"):
            return

        interface = self._get_interface()
        self._write_output(f"Sniffing HTTP on {interface}...")

        self.capture_process = await asyncio.create_subprocess_exec(
            "tcpdump", "-i", interface, "-A", "-s0",
            "tcp", "port", "80", "or", "port", "8080",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        asyncio.create_task(self._read_http_output())

    async def _read_http_output(self) -> None:
        """Read and parse HTTP traffic."""
        if not self.capture_process or not self.capture_process.stdout:
            return

        while True:
            line = await self.capture_process.stdout.readline()
            if not line:
                break

            line = line.decode(errors="ignore").strip()
            if any(x in line for x in ["GET ", "POST ", "HTTP/", "Host:", "Cookie:"]):
                self._write_output(line, "success")
                if "Cookie:" in line or "Authorization:" in line:
                    self._add_packet("", "", "", "HTTP", line)

    async def action_dns_sniff(self) -> None:
        """Sniff DNS queries."""
        if not await self._run_tool("tcpdump"):
            return

        interface = self._get_interface()
        self._write_output(f"Sniffing DNS on {interface}...")

        self.capture_process = await asyncio.create_subprocess_exec(
            "tcpdump", "-i", interface, "-l", "-nn",
            "udp", "port", "53",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        asyncio.create_task(self._read_dns_output())

    async def _read_dns_output(self) -> None:
        """Read and parse DNS queries."""
        if not self.capture_process or not self.capture_process.stdout:
            return

        while True:
            line = await self.capture_process.stdout.readline()
            if not line:
                break

            line = line.decode().strip()
            if line:
                parts = line.split()
                if len(parts) >= 3:
                    time = parts[0]
                    # Try to extract domain
                    domain = "unknown"
                    for p in parts:
                        if "." in p and not p.replace(".", "").isdigit():
                            domain = p
                            break
                    self._add_packet(time, parts[2] if len(parts) > 2 else "", "", "DNS", domain)
                    self._write_output(line)

    async def action_creds_sniff(self) -> None:
        """Sniff for credentials."""
        if not await self._run_tool("tcpdump"):
            return

        self._write_output("Sniffing for credentials (FTP, HTTP, SMTP)...", "warning")
        interface = self._get_interface()

        # Capture on common credential ports
        self.capture_process = await asyncio.create_subprocess_exec(
            "tcpdump", "-i", interface, "-A", "-s0",
            "tcp", "port", "21", "or", "port", "23", "or",
            "port", "25", "or", "port", "110", "or", "port", "143",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        asyncio.create_task(self._read_creds_output())

    async def _read_creds_output(self) -> None:
        """Read and look for credentials."""
        if not self.capture_process or not self.capture_process.stdout:
            return

        keywords = ["user", "pass", "login", "auth", "USER", "PASS"]

        while True:
            line = await self.capture_process.stdout.readline()
            if not line:
                break

            line = line.decode(errors="ignore").strip()
            for kw in keywords:
                if kw.lower() in line.lower():
                    self._write_output(f"[CRED] {line}", "warning")
                    self._add_packet("", "", "", "CRED", line[:50])
                    break

    async def action_analyze_pcap(self) -> None:
        """Analyze a PCAP file."""
        if not self.capture_file:
            self.notify("No capture file available", severity="error")
            return

        if not await self._run_tool("tshark", need_root=False):
            return

        self._write_output(f"Analyzing {self.capture_file}...")

        # Get protocol statistics
        proc = await asyncio.create_subprocess_exec(
            "tshark", "-r", self.capture_file, "-q", "-z", "io,phs",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()

        for line in stdout.decode().split("\n"):
            if line.strip():
                self._write_output(line)

        self._write_output("Analysis complete", "success")

    async def action_interface_stats(self) -> None:
        """Show interface statistics."""
        interface = self._get_interface()
        self._write_output(f"Interface statistics for {interface}...")

        # Read from /sys/class/net
        stats_path = Path(f"/sys/class/net/{interface}/statistics")
        if stats_path.exists():
            for stat_file in stats_path.iterdir():
                try:
                    value = stat_file.read_text().strip()
                    self._write_output(f"{stat_file.name}: {value}")
                except Exception:
                    pass
        else:
            self._write_output(f"Stats not available for {interface}", "warning")

    def action_refresh(self) -> None:
        """Clear results and refresh."""
        table = self.query_one("#packets-table", DataTable)
        table.clear()
        output = self.query_one("#tool-output", ToolOutput)
        output.clear()
        self.notify("Results cleared")
