"""OSINT gathering screen."""
from textual.app import ComposeResult
from textual.containers import Container
from textual.screen import Screen
from textual.widgets import Static


class OsintScreen(Screen):
    """Open Source Intelligence gathering."""

    BINDINGS = [
        ("escape", "app.pop_screen", "Back"),
    ]

    def compose(self) -> ComposeResult:
        """Compose the OSINT screen layout."""
        with Container():
            yield Static(
                "[bold magenta]🌐 OSINT Module[/]\n\n"
                "[cyan]Available operations:[/]\n"
                "• Domain reconnaissance\n"
                "• Email harvesting\n"
                "• Social media enumeration\n"
                "• Subdomain discovery\n"
                "• DNS intelligence\n"
                "• WHOIS lookups\n\n"
                "[dim]Implementation coming soon...[/]"
            )
