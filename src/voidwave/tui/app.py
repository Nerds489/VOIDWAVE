"""VOIDWAVE Textual Application."""
from pathlib import Path

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.widgets import Footer, Header

from voidwave.core.logging import get_logger

logger = get_logger(__name__)


class VoidwaveApp(App):
    """VOIDWAVE Security Framework TUI Application."""

    TITLE = "VOIDWAVE"
    SUB_TITLE = "Offensive Security Framework"
    CSS_PATH = Path(__file__).parent / "cyberpunk.tcss"

    BINDINGS = [
        Binding("ctrl+q", "quit", "Quit", show=True, priority=True),
        Binding("ctrl+p", "command_palette", "Commands", show=True),
        Binding("?", "show_help", "Help", show=True),
        Binding("ctrl+s", "new_scan", "New Scan"),
        Binding("ctrl+w", "wireless_menu", "Wireless"),
        Binding("ctrl+t", "toggle_theme", "Theme"),
        Binding("escape", "back", "Back"),

        # Vim-style navigation (global)
        Binding("j", "focus_next", "Down", show=False),
        Binding("k", "focus_previous", "Up", show=False),
        Binding("g g", "scroll_home", "Top", show=False),
        Binding("G", "scroll_end", "Bottom", show=False),
        Binding("ctrl+d", "page_down", "Page Down", show=False),
        Binding("ctrl+u", "page_up", "Page Up", show=False),
    ]

    def __init__(self) -> None:
        super().__init__()
        self._dark_mode = True

    def compose(self) -> ComposeResult:
        """Compose the application layout."""
        yield Header()
        # Import here to avoid circular imports
        from voidwave.tui.screens.main import MainScreen
        yield MainScreen()
        yield Footer()

    async def on_mount(self) -> None:
        """Handle application mount."""
        logger.info("VOIDWAVE TUI started")

        # Show first-run wizard if needed (check if we have database initialized)
        try:
            from pathlib import Path
            home = Path.home()
            voidwave_dir = home / ".voidwave"
            initialized = voidwave_dir / "initialized"

            if not initialized.exists():
                await self._show_first_run_wizard()
        except Exception as e:
            logger.warning(f"Could not check initialization status: {e}")

    async def _show_first_run_wizard(self) -> None:
        """Show first-run setup wizard."""
        try:
            from voidwave.tui.wizards.first_run import FirstRunWizard
            await self.push_screen(FirstRunWizard())
        except ImportError:
            logger.warning("First-run wizard not available")

    # Action handlers
    def action_quit(self) -> None:
        """Quit the application."""
        self.exit()

    def action_show_help(self) -> None:
        """Show help screen."""
        try:
            from voidwave.tui.screens.help import HelpScreen
            self.push_screen(HelpScreen())
        except ImportError:
            logger.warning("Help screen not available")

    def action_new_scan(self) -> None:
        """Start new scan workflow."""
        try:
            from voidwave.tui.screens.scan import ScanScreen
            self.push_screen(ScanScreen())
        except ImportError:
            logger.warning("Scan screen not available")

    def action_wireless_menu(self) -> None:
        """Open wireless menu."""
        try:
            from voidwave.tui.screens.wireless import WirelessScreen
            self.push_screen(WirelessScreen())
        except ImportError:
            logger.warning("Wireless screen not available")

    def action_toggle_theme(self) -> None:
        """Toggle dark/light theme."""
        self._dark_mode = not self._dark_mode
        self.dark = self._dark_mode

    def action_back(self) -> None:
        """Go back to previous screen."""
        if len(self.screen_stack) > 1:
            self.pop_screen()


def run_app() -> None:
    """Run the VOIDWAVE TUI application."""
    app = VoidwaveApp()
    app.run()


if __name__ == "__main__":
    run_app()
