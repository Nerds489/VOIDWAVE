"""Reconnaissance screen."""
from textual.app import ComposeResult
from textual.containers import Container
from textual.screen import Screen
from textual.widgets import Static


class ReconScreen(Screen):
    """Network reconnaissance and host enumeration."""

    BINDINGS = [
        ("escape", "app.pop_screen", "Back"),
    ]

    def compose(self) -> ComposeResult:
        """Compose the recon screen layout."""
        with Container():
            yield Static(
                "[bold magenta]🎯 Reconnaissance Module[/]\n\n"
                "[cyan]Available operations:[/]\n"
                "• Network mapping\n"
                "• Host discovery\n"
                "• Service fingerprinting\n"
                "• Banner grabbing\n"
                "• Technology detection\n"
                "• Network topology\n\n"
                "[dim]Implementation coming soon...[/]"
            )
