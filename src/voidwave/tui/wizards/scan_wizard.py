"""Network scan wizard."""
from textual.app import ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.screen import ModalScreen
from textual.widgets import Button, Input, Label, Select, Static


class ScanWizard(ModalScreen):
    """Wizard for configuring and starting network scans."""

    BINDINGS = [
        ("escape", "dismiss", "Cancel"),
    ]

    def compose(self) -> ComposeResult:
        """Compose the wizard layout."""
        with Container(classes="modal-container"):
            yield Static(
                "[bold magenta]🔍 Network Scan Wizard[/]",
                classes="modal-title"
            )

            with Vertical():
                yield Label("Configure your network scan parameters.")
                yield Label("")

                # Target
                yield Label("[bold]Target[/]")
                yield Input(
                    placeholder="192.168.1.0/24 or example.com",
                    id="scan-target"
                )
                yield Label("[dim]IP address, CIDR range, or hostname[/]")
                yield Label("")

                # Scan type
                yield Label("[bold]Scan Type[/]")
                yield Select(
                    [
                        ("Quick Scan", "quick"),
                        ("Standard Scan", "standard"),
                        ("Full Scan", "full"),
                        ("Stealth Scan", "stealth"),
                        ("UDP Scan", "udp"),
                        ("Vulnerability Scan", "vuln"),
                    ],
                    value="standard",
                    id="scan-type"
                )
                yield Label("")

                # Port range
                yield Label("[bold]Port Range (Optional)[/]")
                yield Input(
                    placeholder="1-1000 or 80,443,8080",
                    id="port-range"
                )
                yield Label("[dim]Leave empty for default ports[/]")
                yield Label("")

                # Options
                yield Label("[bold]Options[/]")
                with Vertical():
                    yield Static("[ ] Service detection", id="opt-service")
                    yield Static("[ ] OS detection (requires root)", id="opt-os")
                    yield Static("[ ] Script scanning", id="opt-scripts")
                yield Label("")

                yield Static(
                    "[yellow]⚠️ Warning:[/] Ensure you have authorization to scan the target.\n"
                    "[dim]Unauthorized scanning may be illegal.[/]"
                )
                yield Label("")

                # Action buttons
                with Horizontal():
                    yield Button("Start Scan", id="btn-start", variant="primary")
                    yield Button("Cancel", id="btn-cancel", variant="default")

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        if event.button.id == "btn-start":
            await self._start_scan()
        elif event.button.id == "btn-cancel":
            self.dismiss(None)

    async def _start_scan(self) -> None:
        """Start the configured scan."""
        # Get input values
        target_input = self.query_one("#scan-target", Input)
        scan_type_select = self.query_one("#scan-type", Select)
        port_range_input = self.query_one("#port-range", Input)

        target = target_input.value
        if not target:
            self.app.bell()
            self.notify("Please specify a target", severity="error")
            return

        scan_config = {
            "target": target,
            "scan_type": scan_type_select.value,
            "ports": port_range_input.value or None,
            "service_detection": True,  # Would check checkbox state
            "os_detection": False,
            "script_scan": False,
        }

        # Dismiss with configuration
        self.dismiss(scan_config)

    def action_dismiss(self) -> None:
        """Dismiss the wizard."""
        self.dismiss(None)
