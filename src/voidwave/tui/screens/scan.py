"""Network scanning screen with port scanning and service enumeration."""
from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
from datetime import datetime
from typing import TYPE_CHECKING

from textual.app import ComposeResult
from textual.containers import Horizontal, ScrollableContainer, Vertical
from textual.screen import Screen
from textual.widgets import (
    Button,
    Checkbox,
    DataTable,
    Input,
    Label,
    OptionList,
    Select,
    Static,
    TabbedContent,
    TabPane,
)
from textual.widgets.option_list import Option

from voidwave.config.settings import get_settings
from voidwave.core.logging import get_logger
from voidwave.orchestration.events import Events

if TYPE_CHECKING:
    pass

logger = get_logger(__name__)


@dataclass
class HostResult:
    """Represents a discovered host."""

    ip: str
    hostname: str = ""
    state: str = "up"
    os: str = ""
    ports: list = field(default_factory=list)
    last_scan: datetime = field(default_factory=datetime.now)


@dataclass
class PortResult:
    """Represents a discovered port."""

    port: int
    protocol: str
    state: str
    service: str = ""
    version: str = ""
    scripts: list = field(default_factory=list)


SCAN_TYPES = [
    ("Quick Scan", "quick", "-T4 -F"),
    ("Standard Scan", "standard", "-T3 -sV"),
    ("Full Scan", "full", "-T4 -A -p-"),
    ("Stealth Scan", "stealth", "-sS -T2"),
    ("UDP Scan", "udp", "-sU --top-ports 100"),
    ("Service Version", "version", "-sV --version-intensity 5"),
    ("OS Detection", "os", "-O --osscan-guess"),
    ("Vuln Scan", "vuln", "-sV --script=vuln"),
    ("Custom", "custom", ""),
]


class ScanScreen(Screen):
    """Network and port scanning operations screen."""

    CSS = """
    ScanScreen {
        layout: grid;
        grid-size: 3 2;
        grid-columns: 1fr 2fr 2fr;
        grid-rows: 1fr auto;
    }

    #config-panel {
        height: 100%;
        border: solid $primary;
        padding: 1;
    }

    #config-panel Label {
        margin-bottom: 0;
    }

    #results-panel {
        column-span: 2;
        height: 100%;
        border: solid $secondary;
        padding: 1;
    }

    #output-panel {
        column-span: 3;
        height: 12;
        border: solid $surface;
        padding: 1;
    }

    .config-input {
        margin-bottom: 1;
    }

    .action-button {
        width: 100%;
        margin: 0 0 1 0;
    }

    .host-details {
        padding: 1;
    }
    """

    BINDINGS = [
        ("escape", "app.pop_screen", "Back"),
        ("s", "start_scan", "Start Scan"),
        ("x", "stop_scan", "Stop Scan"),
        ("c", "clear_results", "Clear"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self._scanning = False
        self._scan_task: asyncio.Task | None = None
        self._hosts: dict[str, HostResult] = {}
        self._selected_host: HostResult | None = None

    def compose(self) -> ComposeResult:
        settings = get_settings()

        # Left: Configuration panel
        with Vertical(id="config-panel"):
            yield Label("[bold magenta]Scan Configuration[/]")

            yield Label("Target(s):")
            yield Input(
                placeholder="IP, range, or CIDR (e.g., 192.168.1.0/24)",
                id="input-target",
                classes="config-input",
            )

            yield Label("Scan Type:")
            yield Select(
                [(name, scan_id) for name, scan_id, _ in SCAN_TYPES],
                value="standard",
                id="select-scan-type",
                classes="config-input",
            )

            yield Label("Port Range:")
            yield Input(
                value=settings.scanning.default_ports,
                placeholder="1-1000 or 22,80,443",
                id="input-ports",
                classes="config-input",
            )

            yield Label("Timing Template (T0-T5):")
            yield Select(
                [(f"T{i} - {'Paranoid Slow Normal Aggressive Insane'.split()[i]}", str(i)) for i in range(6)],
                value=str(settings.scanning.timing_template),
                id="select-timing",
                classes="config-input",
            )

            yield Label("Custom Arguments:")
            yield Input(
                placeholder="Additional nmap flags",
                id="input-custom-args",
                classes="config-input",
            )

            yield Static("")
            yield Label("[bold]Options[/]")
            yield Checkbox("Service Version Detection (-sV)", True, id="check-version")
            yield Checkbox("OS Detection (-O)", False, id="check-os")
            yield Checkbox("Script Scan (-sC)", False, id="check-scripts")
            yield Checkbox("Skip Host Discovery (-Pn)", False, id="check-skip-discovery")
            yield Checkbox("Save Results", True, id="check-save")

            yield Static("")
            yield Button("Start Scan", id="btn-start-scan", variant="success", classes="action-button")
            yield Button("Stop Scan", id="btn-stop-scan", variant="error", classes="action-button")

        # Center/Right: Results panel with tabs
        with Vertical(id="results-panel"):
            yield Label("[bold cyan]Scan Results[/]")
            with TabbedContent(initial="hosts"):
                with TabPane("Hosts", id="hosts"):
                    yield DataTable(id="hosts-table")

                with TabPane("Ports", id="ports"):
                    yield DataTable(id="ports-table")

                with TabPane("Services", id="services"):
                    yield DataTable(id="services-table")

                with TabPane("Details", id="details"):
                    yield Static("Select a host to view details", id="host-details", classes="host-details")

        # Bottom: Output
        with Vertical(id="output-panel"):
            yield Label("[bold]Scan Output[/]")
            yield Static("Ready to scan. Enter a target and click Start Scan.", id="scan-output")

    async def on_mount(self) -> None:
        """Initialize screen."""
        self._setup_tables()
        self._subscribe_events()

    def _setup_tables(self) -> None:
        """Set up data tables."""
        # Hosts table
        hosts_table = self.query_one("#hosts-table", DataTable)
        hosts_table.add_columns("IP", "Hostname", "State", "OS", "Open Ports")
        hosts_table.cursor_type = "row"

        # Ports table
        ports_table = self.query_one("#ports-table", DataTable)
        ports_table.add_columns("Port", "Protocol", "State", "Service", "Version")
        ports_table.cursor_type = "row"

        # Services table
        services_table = self.query_one("#services-table", DataTable)
        services_table.add_columns("Service", "Port", "Host", "Version", "Info")
        services_table.cursor_type = "row"

    def _subscribe_events(self) -> None:
        """Subscribe to scan-related events."""
        from voidwave.orchestration.events import event_bus

        event_bus.on(Events.HOST_DISCOVERED, self._on_host_discovered)
        event_bus.on(Events.SERVICE_DISCOVERED, self._on_service_discovered)

    async def _on_host_discovered(self, data: dict) -> None:
        """Handle host discovered event."""
        try:
            host = HostResult(
                ip=data.get("ip", ""),
                hostname=data.get("hostname", ""),
                state=data.get("state", "up"),
                os=data.get("os", ""),
            )

            self._hosts[host.ip] = host
            self.app.call_from_thread(self._refresh_hosts_table)

        except Exception as e:
            logger.warning(f"Failed to process host: {e}")

    async def _on_service_discovered(self, data: dict) -> None:
        """Handle service discovered event."""
        try:
            host_ip = data.get("host", "")
            port = PortResult(
                port=int(data.get("port", 0)),
                protocol=data.get("protocol", "tcp"),
                state=data.get("state", "open"),
                service=data.get("service", ""),
                version=data.get("version", ""),
            )

            if host_ip in self._hosts:
                self._hosts[host_ip].ports.append(port)
                self.app.call_from_thread(self._refresh_hosts_table)
                self.app.call_from_thread(self._refresh_services_table)

        except Exception as e:
            logger.warning(f"Failed to process service: {e}")

    def _refresh_hosts_table(self) -> None:
        """Refresh the hosts table."""
        table = self.query_one("#hosts-table", DataTable)
        table.clear()

        for host in sorted(self._hosts.values(), key=lambda x: x.ip):
            open_ports = sum(1 for p in host.ports if p.state == "open")
            table.add_row(
                host.ip,
                host.hostname or "-",
                host.state,
                host.os[:20] if host.os else "-",
                str(open_ports),
                key=host.ip,
            )

    def _refresh_ports_table(self, host: HostResult | None = None) -> None:
        """Refresh the ports table."""
        table = self.query_one("#ports-table", DataTable)
        table.clear()

        if host:
            for port in sorted(host.ports, key=lambda x: x.port):
                table.add_row(
                    str(port.port),
                    port.protocol,
                    port.state,
                    port.service or "-",
                    port.version[:30] if port.version else "-",
                )

    def _refresh_services_table(self) -> None:
        """Refresh the services table."""
        table = self.query_one("#services-table", DataTable)
        table.clear()

        services = []
        for host in self._hosts.values():
            for port in host.ports:
                if port.service:
                    services.append((port.service, port.port, host.ip, port.version))

        for service, port, host_ip, version in sorted(services, key=lambda x: x[0]):
            table.add_row(
                service,
                str(port),
                host_ip,
                version[:30] if version else "-",
                "",
            )

    def _write_output(self, message: str) -> None:
        """Write message to output panel."""
        output = self.query_one("#scan-output", Static)
        output.update(message)

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        button_id = event.button.id

        if button_id == "btn-start-scan":
            await self._start_scan()
        elif button_id == "btn-stop-scan":
            await self._stop_scan()

    async def on_data_table_row_selected(self, event: DataTable.RowSelected) -> None:
        """Handle row selection."""
        if event.data_table.id == "hosts-table":
            # Get selected host
            row_key = event.row_key
            if row_key and row_key.value in self._hosts:
                host = self._hosts[row_key.value]
                self._selected_host = host
                self._refresh_ports_table(host)
                self._show_host_details(host)

    def _show_host_details(self, host: HostResult) -> None:
        """Show details for selected host."""
        details = self.query_one("#host-details", Static)

        lines = [
            f"[bold cyan]Host: {host.ip}[/]",
            f"[dim]Hostname:[/] {host.hostname or 'N/A'}",
            f"[dim]State:[/] {host.state}",
            f"[dim]OS:[/] {host.os or 'Unknown'}",
            "",
            f"[bold]Open Ports ({sum(1 for p in host.ports if p.state == 'open')}):[/]",
        ]

        for port in sorted(host.ports, key=lambda x: x.port):
            if port.state == "open":
                lines.append(
                    f"  [green]{port.port}/{port.protocol}[/] - "
                    f"{port.service or 'unknown'} {port.version or ''}"
                )

        details.update("\n".join(lines))

    async def _start_scan(self) -> None:
        """Start network scan."""
        if self._scanning:
            self._write_output("[yellow]Scan already running[/]")
            return

        target = self.query_one("#input-target", Input).value.strip()
        if not target:
            self._write_output("[red]Please enter a target[/]")
            return

        self._scanning = True
        self._write_output(f"[green]Starting scan of {target}...[/]")

        self._scan_task = asyncio.create_task(self._run_scan(target))

    async def _run_scan(self, target: str) -> None:
        """Run the network scan."""
        try:
            from voidwave.tools.nmap import NmapTool

            tool = NmapTool()
            await tool.initialize()

            # Build options from UI
            options = self._build_scan_options()
            options["target"] = target

            self._write_output(f"[cyan]Running nmap scan...[/]")

            result = await tool.execute(target, options)

            if result.success:
                # Parse nmap results
                data = result.data

                # Add hosts from result
                hosts = data.get("hosts", [])
                for host_data in hosts:
                    host = HostResult(
                        ip=host_data.get("ip", ""),
                        hostname=host_data.get("hostname", ""),
                        state=host_data.get("state", "up"),
                        os=host_data.get("os", ""),
                    )

                    # Add ports
                    for port_data in host_data.get("ports", []):
                        port = PortResult(
                            port=port_data.get("port", 0),
                            protocol=port_data.get("protocol", "tcp"),
                            state=port_data.get("state", ""),
                            service=port_data.get("service", ""),
                            version=port_data.get("version", ""),
                        )
                        host.ports.append(port)

                    self._hosts[host.ip] = host

                self._refresh_hosts_table()
                self._refresh_services_table()

                host_count = len(self._hosts)
                port_count = sum(len(h.ports) for h in self._hosts.values())
                self._write_output(
                    f"[green]Scan complete. Found {host_count} host(s) with {port_count} port(s)[/]"
                )

            else:
                self._write_output(f"[red]Scan failed: {result.errors}[/]")

        except asyncio.CancelledError:
            self._write_output("[yellow]Scan cancelled[/]")
        except Exception as e:
            self._write_output(f"[red]Scan error: {e}[/]")
        finally:
            self._scanning = False

    def _build_scan_options(self) -> dict:
        """Build scan options from UI."""
        options = {}

        # Scan type
        scan_type = self.query_one("#select-scan-type", Select).value
        for name, scan_id, args in SCAN_TYPES:
            if scan_id == scan_type:
                if args:
                    options["extra_args"] = args.split()
                break

        # Ports
        ports = self.query_one("#input-ports", Input).value.strip()
        if ports:
            options["ports"] = ports

        # Timing
        timing = self.query_one("#select-timing", Select).value
        if timing:
            options["timing"] = int(timing)

        # Custom args
        custom = self.query_one("#input-custom-args", Input).value.strip()
        if custom:
            extra = options.get("extra_args", [])
            extra.extend(custom.split())
            options["extra_args"] = extra

        # Options
        if self.query_one("#check-version", Checkbox).value:
            options["service_version"] = True
        if self.query_one("#check-os", Checkbox).value:
            options["os_detection"] = True
        if self.query_one("#check-scripts", Checkbox).value:
            options["script_scan"] = True
        if self.query_one("#check-skip-discovery", Checkbox).value:
            options["skip_discovery"] = True

        return options

    async def _stop_scan(self) -> None:
        """Stop the current scan."""
        if not self._scanning:
            self._write_output("[yellow]No scan running[/]")
            return

        if self._scan_task:
            self._scan_task.cancel()
            self._scan_task = None

        self._scanning = False
        self._write_output("[green]Scan stopped[/]")

    def action_start_scan(self) -> None:
        """Start scan action."""
        asyncio.create_task(self._start_scan())

    def action_stop_scan(self) -> None:
        """Stop scan action."""
        asyncio.create_task(self._stop_scan())

    def action_clear_results(self) -> None:
        """Clear results action."""
        self._hosts.clear()
        self._selected_host = None
        self._refresh_hosts_table()
        self._refresh_ports_table(None)
        self._refresh_services_table()
        self.query_one("#host-details", Static).update("Select a host to view details")
        self._write_output("[dim]Results cleared[/]")
