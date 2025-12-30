"""VOIDWAVE Textual Application."""
from pathlib import Path
from typing import TYPE_CHECKING

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.widgets import Footer, Header

from voidwave.core.logging import get_logger
from voidwave.orchestration.events import event_bus
from voidwave.orchestration.control import ExecutionController
from voidwave.tui.integration import TUIEventBridge
from voidwave.sessions import get_session_manager, Session, SessionManager

if TYPE_CHECKING:
    from voidwave.orchestration.events import VoidwaveEventBus

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

        # Initialize event bus integration
        self.event_bus: VoidwaveEventBus = event_bus
        self.execution_controller = ExecutionController(self.event_bus)
        self._event_bridge: TUIEventBridge | None = None

        # Session management
        self.session_manager: SessionManager = get_session_manager()

    @property
    def current_session(self) -> Session | None:
        """Get the current active session."""
        return self.session_manager.current

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

        # Initialize database
        try:
            from voidwave.db.engine import get_db
            await get_db()
            logger.info("Database initialized")
        except Exception as e:
            logger.error(f"Failed to initialize database: {e}")

        # Connect event bridge to wire events to widgets
        self._event_bridge = TUIEventBridge(self, self.event_bus)
        self._event_bridge.connect()
        logger.info("Event bridge connected")

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

    async def on_unmount(self) -> None:
        """Handle application unmount."""
        # Pause current session if active
        if self.current_session:
            try:
                await self.session_manager.pause(self.current_session.id)
                logger.info(f"Session paused: {self.current_session.name}")
            except Exception as e:
                logger.warning(f"Failed to pause session: {e}")

        # Disconnect event bridge
        if self._event_bridge:
            self._event_bridge.disconnect()
            logger.info("Event bridge disconnected")

        # Stop any running tools
        await self.execution_controller.stop_all(timeout=3.0)

        # Close database connection
        try:
            from voidwave.db.engine import _db_engine
            if _db_engine:
                await _db_engine.close()
        except Exception as e:
            logger.warning(f"Failed to close database: {e}")

        logger.info("VOIDWAVE TUI shutdown complete")

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
