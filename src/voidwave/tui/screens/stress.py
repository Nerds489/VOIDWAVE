"""Stress testing screen for load and performance testing."""

import asyncio
import shutil
from textual.app import ComposeResult
from textual.containers import Container, Vertical, Horizontal, ScrollableContainer
from textual.screen import Screen
from textual.widgets import Static, Button, Input, DataTable, ListView, ListItem, Label, Select
from textual.binding import Binding

from voidwave.tui.widgets.tool_output import ToolOutput
from voidwave.tui.helpers.preflight_runner import PreflightRunner


class StressScreen(Screen):
    """Load testing and stress simulation (authorized testing only)."""

    CSS = """
    StressScreen {
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

    .warning-text {
        color: $error;
        text-style: bold;
    }

    #stop-btn {
        margin-top: 1;
    }
    """

    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back"),
        Binding("s", "stop_test", "Stop"),
        Binding("r", "refresh", "Refresh"),
    ]

    MENU_ITEMS = [
        ("http-flood", "HTTP Flood", "http_flood"),
        ("syn-flood", "SYN Flood", "syn_flood"),
        ("udp-flood", "UDP Flood", "udp_flood"),
        ("icmp-flood", "ICMP Flood", "icmp_flood"),
        ("slowloris", "Slowloris", "slowloris"),
        ("bandwidth", "Bandwidth Test", "bandwidth_test"),
        ("latency", "Latency Test", "latency_test"),
        ("conn-test", "Connection Test", "connection_test"),
        ("tc-delay", "Add Delay (tc)", "tc_delay"),
        ("tc-loss", "Add Loss (tc)", "tc_loss"),
        ("tc-clear", "Clear TC", "tc_clear"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self.stress_process: asyncio.subprocess.Process | None = None
        self._preflight: PreflightRunner | None = None

    def compose(self) -> ComposeResult:
        """Compose the stress screen layout."""
        with Vertical(id="menu-panel"):
            yield Static("[bold magenta]STRESS TESTING[/]", classes="panel-title")
            yield Static("[red]AUTHORIZED USE ONLY![/]", classes="warning-text")
            yield Static("─" * 20)
            yield Static("Target:", classes="label")
            yield Input(placeholder="IP or URL", id="target-input")
            yield Static("Port:", classes="label")
            yield Input(placeholder="80", id="port-input", value="80")
            yield Static("Duration (sec):", classes="label")
            yield Input(placeholder="10", id="duration-input", value="10")
            yield Static("─" * 20)
            yield Static("Actions:", classes="panel-title")
            with ListView(id="action-list"):
                for item_id, label, _ in self.MENU_ITEMS:
                    yield ListItem(Label(label), id=item_id, classes="action-item")
            yield Button("STOP TEST", id="stop-btn", variant="error")

        with ScrollableContainer(id="content-panel"):
            yield Static("[bold cyan]Statistics[/]", classes="panel-title")
            yield DataTable(id="stats-table", classes="result-table")

        with Vertical(id="output-panel"):
            yield Static("[bold yellow]Output[/]", classes="panel-title")
            yield ToolOutput(id="tool-output")

    def on_mount(self) -> None:
        """Initialize the stats table."""
        self._preflight = PreflightRunner(self.app)
        table = self.query_one("#stats-table", DataTable)
        table.add_columns("Metric", "Value", "Status")

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        """Handle menu selection."""
        item_id = event.item.id
        for menu_id, _, action_name in self.MENU_ITEMS:
            if menu_id == item_id:
                action_method = getattr(self, f"action_{action_name}", None)
                if action_method:
                    self.run_worker(action_method(), exclusive=True)
                break

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        if event.button.id == "stop-btn":
            self.run_worker(self.action_stop_test())

    def _get_target(self) -> str:
        """Get the target."""
        return self.query_one("#target-input", Input).value.strip()

    def _get_port(self) -> int:
        """Get the port."""
        try:
            return int(self.query_one("#port-input", Input).value.strip())
        except ValueError:
            return 80

    def _get_duration(self) -> int:
        """Get the duration."""
        try:
            return int(self.query_one("#duration-input", Input).value.strip())
        except ValueError:
            return 10

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

    def _add_stat(self, metric: str, value: str, status: str = "") -> None:
        """Add a statistic to the table."""
        table = self.query_one("#stats-table", DataTable)
        table.add_row(metric, value, status)

    async def _run_tool(self, tool: str, need_root: bool = True) -> str | None:
        """Run preflight checks for a tool and return target."""
        if not self._preflight:
            return None
        if need_root and not await self._preflight.ensure_root():
            return None
        ctx = await self._preflight.prepare_tool(tool)
        if not ctx.ready:
            self._write_output(ctx.error or f"{tool} not available", "error")
            return None
        if ctx.used_fallback and ctx.fallback_tool:
            self._write_output(f"Using {ctx.fallback_tool} instead of {tool}", "warning")
        target = self._get_target()
        if not target:
            target = await self._preflight.ensure_target("ip")
        return target

    async def action_stop_test(self) -> None:
        """Stop any running stress test."""
        if self.stress_process:
            self.stress_process.terminate()
            await self.stress_process.wait()
            self.stress_process = None
            self._write_output("Test stopped", "warning")
        else:
            self.notify("No test running", severity="warning")

    async def action_http_flood(self) -> None:
        """HTTP flood test using curl or hping3."""
        target = await self._run_tool("hping3")
        if not target:
            return

        port = self._get_port()
        duration = self._get_duration()

        self._write_output(f"Starting HTTP flood to {target}:{port} for {duration}s...", "warning")
        self._write_output("AUTHORIZED TESTING ONLY!", "error")

        if shutil.which("hping3"):
            self.stress_process = await asyncio.create_subprocess_exec(
                "hping3", "-S", "--flood", "-V", "-p", str(port), target,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )

            # Stop after duration
            await asyncio.sleep(duration)
            await self.action_stop_test()
        else:
            # Use curl loop
            self._write_output("hping3 not found, using curl...", "warning")
            count = 0
            start = asyncio.get_event_loop().time()

            while asyncio.get_event_loop().time() - start < duration:
                proc = await asyncio.create_subprocess_exec(
                    "curl", "-s", "-o", "/dev/null", f"http://{target}:{port}/",
                    stdout=asyncio.subprocess.DEVNULL,
                    stderr=asyncio.subprocess.DEVNULL,
                )
                await proc.wait()
                count += 1

            self._add_stat("Requests", str(count), "complete")
            self._write_output(f"Sent {count} requests in {duration}s", "success")

    async def action_syn_flood(self) -> None:
        """SYN flood test using hping3."""
        target = await self._run_tool("hping3")
        if not target:
            return

        port = self._get_port()
        duration = self._get_duration()

        self._write_output(f"Starting SYN flood to {target}:{port}...", "warning")
        self._write_output("AUTHORIZED TESTING ONLY - Root required!", "error")

        self.stress_process = await asyncio.create_subprocess_exec(
            "hping3", "-S", "--flood", "-p", str(port), target,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        await asyncio.sleep(duration)
        await self.action_stop_test()
        self._add_stat("SYN Flood", f"{duration}s", "complete")

    async def action_udp_flood(self) -> None:
        """UDP flood test using hping3."""
        target = await self._run_tool("hping3")
        if not target:
            return

        port = self._get_port()
        duration = self._get_duration()

        self._write_output(f"Starting UDP flood to {target}:{port}...", "warning")

        self.stress_process = await asyncio.create_subprocess_exec(
            "hping3", "--udp", "--flood", "-p", str(port), target,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        await asyncio.sleep(duration)
        await self.action_stop_test()
        self._add_stat("UDP Flood", f"{duration}s", "complete")

    async def action_icmp_flood(self) -> None:
        """ICMP flood test using hping3 or ping."""
        target = await self._run_tool("hping3")
        if not target:
            return

        duration = self._get_duration()

        self._write_output(f"Starting ICMP flood to {target}...", "warning")

        if shutil.which("hping3"):
            self.stress_process = await asyncio.create_subprocess_exec(
                "hping3", "--icmp", "--flood", target,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            await asyncio.sleep(duration)
            await self.action_stop_test()
        else:
            # Use ping
            self.stress_process = await asyncio.create_subprocess_exec(
                "ping", "-f", "-c", str(duration * 100), target,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, _ = await self.stress_process.communicate()
            self._write_output(stdout.decode())

        self._add_stat("ICMP Flood", f"{duration}s", "complete")

    async def action_slowloris(self) -> None:
        """Slowloris attack simulation."""
        target = self._get_target()
        if not target:
            if self._preflight:
                target = await self._preflight.ensure_target("ip")
            if not target:
                return

        port = self._get_port()

        self._write_output(f"Slowloris requires dedicated tool...", "warning")
        self._write_output("Install: pip install slowloris", "info")
        self._write_output(f"Usage: slowloris {target} -p {port} -s 500", "info")

        if shutil.which("slowloris"):
            self._write_output("Starting Slowloris...", "warning")
            self.stress_process = await asyncio.create_subprocess_exec(
                "slowloris", target, "-p", str(port), "-s", "100",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )

    async def action_bandwidth_test(self) -> None:
        """Bandwidth test using iperf3."""
        target = await self._run_tool("iperf3", need_root=False)
        if not target:
            return

        duration = self._get_duration()

        self._write_output(f"Testing bandwidth to {target}...")

        proc = await asyncio.create_subprocess_exec(
            "iperf3", "-c", target, "-t", str(duration),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()

        for line in stdout.decode().split("\n"):
            line = line.strip()
            if "Mbits" in line or "Gbits" in line:
                self._add_stat("Bandwidth", line, "measured")
                self._write_output(line, "success")

        self._write_output("Bandwidth test complete", "success")

    async def action_latency_test(self) -> None:
        """Latency test using ping."""
        target = await self._run_tool("ping", need_root=False)
        if not target:
            return

        count = min(self._get_duration(), 20)  # Max 20 pings

        self._write_output(f"Testing latency to {target}...")

        proc = await asyncio.create_subprocess_exec(
            "ping", "-c", str(count), target,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()

        for line in stdout.decode().split("\n"):
            line = line.strip()
            if "time=" in line:
                self._write_output(line)
            elif "min/avg/max" in line:
                self._add_stat("Latency", line, "measured")
                self._write_output(line, "success")

        self._write_output("Latency test complete", "success")

    async def action_connection_test(self) -> None:
        """Test maximum connections."""
        target = self._get_target()
        if not target:
            if self._preflight:
                target = await self._preflight.ensure_target("ip")
            if not target:
                return

        port = self._get_port()

        self._write_output(f"Testing connections to {target}:{port}...")

        import socket
        connections = 0
        sockets = []

        try:
            for i in range(100):  # Try 100 connections
                s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                s.settimeout(2)
                try:
                    s.connect((target, port))
                    sockets.append(s)
                    connections += 1
                except Exception:
                    break
        finally:
            for s in sockets:
                try:
                    s.close()
                except Exception:
                    pass

        self._add_stat("Connections", str(connections), "established")
        self._write_output(f"Established {connections} connections", "success")

    async def action_tc_delay(self) -> None:
        """Add network delay using tc."""
        self._write_output("Adding 100ms delay with tc...", "warning")
        self._write_output("Requires root!", "error")

        proc = await asyncio.create_subprocess_shell(
            "tc qdisc add dev eth0 root netem delay 100ms",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        _, stderr = await proc.communicate()

        if proc.returncode == 0:
            self._add_stat("TC Delay", "100ms", "active")
            self._write_output("Delay added to eth0", "success")
        else:
            self._write_output(f"Error: {stderr.decode()}", "error")

    async def action_tc_loss(self) -> None:
        """Add packet loss using tc."""
        self._write_output("Adding 10% packet loss with tc...", "warning")
        self._write_output("Requires root!", "error")

        proc = await asyncio.create_subprocess_shell(
            "tc qdisc add dev eth0 root netem loss 10%",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        _, stderr = await proc.communicate()

        if proc.returncode == 0:
            self._add_stat("TC Loss", "10%", "active")
            self._write_output("Packet loss added to eth0", "success")
        else:
            self._write_output(f"Error: {stderr.decode()}", "error")

    async def action_tc_clear(self) -> None:
        """Clear tc rules."""
        self._write_output("Clearing tc rules...", "warning")

        proc = await asyncio.create_subprocess_shell(
            "tc qdisc del dev eth0 root 2>/dev/null; true",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        await proc.communicate()

        self._write_output("TC rules cleared", "success")

    def action_refresh(self) -> None:
        """Clear results and refresh."""
        table = self.query_one("#stats-table", DataTable)
        table.clear()
        output = self.query_one("#tool-output", ToolOutput)
        output.clear()
        self.notify("Results cleared")
