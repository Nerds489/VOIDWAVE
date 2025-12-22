"""System status screen."""
from textual.app import ComposeResult
from textual.containers import Container
from textual.screen import Screen
from textual.widgets import Static


class StatusScreen(Screen):
    """System status and tool availability."""

    BINDINGS = [
        ("escape", "app.pop_screen", "Back"),
    ]

    def compose(self) -> ComposeResult:
        """Compose the status screen layout."""
        with Container():
            yield Static(
                "[bold magenta]📈 System Status[/]\n\n"
                "[cyan]System information:[/]\n"
                "• Tool availability check\n"
                "• System resources\n"
                "• Active sessions\n"
                "• Running processes\n"
                "• Database status\n"
                "• Event bus monitoring\n\n"
                "[dim]Implementation coming soon...[/]"
            )
