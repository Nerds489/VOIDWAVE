"""Main dashboard screen."""
from textual.app import ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.screen import Screen
from textual.widgets import (
    Button,
    Label,
    ListItem,
    ListView,
    Static,
    TabbedContent,
    TabPane,
)

from voidwave.tui.widgets.tool_output import ToolOutput
from voidwave.tui.widgets.status_panel import StatusPanel
from voidwave.tui.widgets.sessions_panel import SessionsPanel

VOIDWAVE_BANNER = """
[cyan]██╗   ██╗ ██████╗ ██╗██████╗ ██╗    ██╗ █████╗ ██╗   ██╗███████╗[/]
[cyan]██║   ██║██╔═══██╗██║██╔══██╗██║    ██║██╔══██╗██║   ██║██╔════╝[/]
[magenta]██║   ██║██║   ██║██║██║  ██║██║ █╗ ██║███████║██║   ██║█████╗  [/]
[magenta]╚██╗ ██╔╝██║   ██║██║██║  ██║██║███╗██║██╔══██║╚██╗ ██╔╝██╔══╝  [/]
[cyan] ╚████╔╝ ╚██████╔╝██║██████╔╝╚███╔███╔╝██║  ██║ ╚████╔╝ ███████╗[/]
[cyan]  ╚═══╝   ╚═════╝ ╚═╝╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═╝  ╚═══╝  ╚══════╝[/]
[dim]            Offensive Security Framework v2.0[/]
"""


class MenuCategory:
    """Menu category definition."""

    def __init__(self, name: str, icon: str, screen: str, description: str):
        self.name = name
        self.icon = icon
        self.screen = screen
        self.description = description


MENU_CATEGORIES = [
    MenuCategory("Wireless", "📡", "wireless", "WiFi attacks, monitor mode, handshake capture"),
    MenuCategory("Scanning", "🔍", "scan", "Port scanning, service enumeration"),
    MenuCategory("Chains", "🔗", "chains", "Multi-step attack workflows"),
    MenuCategory("Credentials", "🔑", "credentials", "Password cracking, hash attacks"),
    MenuCategory("OSINT", "🌐", "osint", "Open source intelligence gathering"),
    MenuCategory("Recon", "🎯", "recon", "Network discovery, host enumeration"),
    MenuCategory("Traffic", "📊", "traffic", "Packet capture, MITM attacks"),
    MenuCategory("Exploit", "💥", "exploit", "Vulnerability exploitation"),
    MenuCategory("Stress", "⚡", "stress", "Load testing, DoS simulation"),
    MenuCategory("Status", "📈", "status", "System status, tool availability"),
    MenuCategory("Settings", "⚙️", "settings", "Configuration management"),
]


class MainScreen(Screen):
    """Main dashboard screen with menu navigation."""

    BINDINGS = [
        ("1", "menu_1", "Wireless"),
        ("2", "menu_2", "Scanning"),
        ("3", "menu_3", "Chains"),
        ("4", "menu_4", "Credentials"),
        ("5", "menu_5", "OSINT"),
        ("6", "menu_6", "Recon"),
        ("7", "menu_7", "Traffic"),
        ("8", "menu_8", "Exploit"),
        ("9", "menu_9", "Stress"),
        ("0", "menu_10", "Status"),
        ("-", "menu_11", "Settings"),
    ]

    def compose(self) -> ComposeResult:
        """Compose the main screen layout."""
        with Container(classes="main-container"):
            # Sidebar with menu
            with Vertical(classes="sidebar"):
                yield Static(VOIDWAVE_BANNER, classes="banner")
                yield Label("─" * 28, classes="separator")

                with ListView(id="main-menu"):
                    for i, cat in enumerate(MENU_CATEGORIES):
                        yield ListItem(
                            Static(f" {cat.icon}  {cat.name}"),
                            id=f"menu-{cat.screen}",
                            name=cat.screen,
                        )

            # Main content area
            with Vertical(classes="content"):
                with TabbedContent(initial="output"):
                    with TabPane("Output", id="output"):
                        yield ToolOutput(id="tool-output")

                    with TabPane("Status", id="status"):
                        yield StatusPanel(id="status-panel")

                    with TabPane("Sessions", id="sessions"):
                        yield SessionsPanel(id="sessions-panel")

                # Quick action buttons
                with Horizontal(classes="quick-actions"):
                    yield Button("Quick Scan", id="btn-quick-scan", classes="-primary")
                    yield Button("WiFi Scan", id="btn-wifi-scan")
                    yield Button("Stop All", id="btn-stop-all", classes="-error")

    async def on_list_view_selected(self, event: ListView.Selected) -> None:
        """Handle menu item selection."""
        screen_name = event.item.name
        await self._navigate_to_screen(screen_name)

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        button_id = event.button.id

        if button_id == "btn-quick-scan":
            await self._start_quick_scan()
        elif button_id == "btn-wifi-scan":
            await self._navigate_to_screen("wireless")
        elif button_id == "btn-stop-all":
            await self._stop_all_tools()

    async def _navigate_to_screen(self, screen_name: str) -> None:
        """Navigate to a specific screen."""
        screen_map = {
            "wireless": "voidwave.tui.screens.wireless:WirelessScreen",
            "scan": "voidwave.tui.screens.scan:ScanScreen",
            "chains": "voidwave.tui.screens.chains:ChainsScreen",
            "credentials": "voidwave.tui.screens.credentials:CredentialsScreen",
            "osint": "voidwave.tui.screens.osint:OsintScreen",
            "recon": "voidwave.tui.screens.recon:ReconScreen",
            "traffic": "voidwave.tui.screens.traffic:TrafficScreen",
            "exploit": "voidwave.tui.screens.exploit:ExploitScreen",
            "stress": "voidwave.tui.screens.stress:StressScreen",
            "status": "voidwave.tui.screens.status:StatusScreen",
            "settings": "voidwave.tui.screens.settings:SettingsScreen",
        }

        if screen_name in screen_map:
            try:
                module_path, class_name = screen_map[screen_name].rsplit(":", 1)
                module = __import__(module_path, fromlist=[class_name])
                screen_class = getattr(module, class_name)
                await self.app.push_screen(screen_class())
            except ImportError as e:
                # Screen not implemented yet
                output = self.query_one("#tool-output", ToolOutput)
                output.write_warning(f"Screen '{screen_name}' not yet implemented")

    async def _start_quick_scan(self) -> None:
        """Start a quick network scan."""
        try:
            from voidwave.tui.wizards.scan_wizard import ScanWizard
            await self.app.push_screen(ScanWizard())
        except ImportError:
            output = self.query_one("#tool-output", ToolOutput)
            output.write_warning("Scan wizard not yet implemented")

    async def _stop_all_tools(self) -> None:
        """Stop all running tools."""
        output = self.query_one("#tool-output", ToolOutput)
        output.write_info("Stopping all running tools...")

        # Use the execution controller to stop all tools
        results = await self.app.execution_controller.stop_all()

        cancelled = results.get("cancelled", 0)
        failed = results.get("failed", 0)

        if cancelled > 0:
            output.write_success(f"Stopped {cancelled} tool(s)")
        if failed > 0:
            output.write_warning(f"Failed to stop {failed} tool(s)")
        if cancelled == 0 and failed == 0:
            output.write_info("No tools were running")

    # Menu shortcut actions
    def action_menu_1(self) -> None:
        self.run_worker(self._navigate_to_screen("wireless"))

    def action_menu_2(self) -> None:
        self.run_worker(self._navigate_to_screen("scan"))

    def action_menu_3(self) -> None:
        self.run_worker(self._navigate_to_screen("chains"))

    def action_menu_4(self) -> None:
        self.run_worker(self._navigate_to_screen("credentials"))

    def action_menu_5(self) -> None:
        self.run_worker(self._navigate_to_screen("osint"))

    def action_menu_6(self) -> None:
        self.run_worker(self._navigate_to_screen("recon"))

    def action_menu_7(self) -> None:
        self.run_worker(self._navigate_to_screen("traffic"))

    def action_menu_8(self) -> None:
        self.run_worker(self._navigate_to_screen("exploit"))

    def action_menu_9(self) -> None:
        self.run_worker(self._navigate_to_screen("stress"))

    def action_menu_10(self) -> None:
        self.run_worker(self._navigate_to_screen("status"))

    def action_menu_11(self) -> None:
        self.run_worker(self._navigate_to_screen("settings"))
