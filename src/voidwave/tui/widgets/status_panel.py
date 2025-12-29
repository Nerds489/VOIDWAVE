"""System status display panel."""
from typing import ClassVar

from rich.table import Table
from textual.widgets import Static


class StatusPanel(Static):
    """Panel showing system and tool status."""

    DEFAULT_CSS: ClassVar[str] = """
    StatusPanel {
        height: 100%;
        border: solid #3a3a5e;
        background: $surface;
        padding: 1;
    }
    """

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        self._update_timer = None

    async def on_mount(self) -> None:
        """Start periodic status updates."""
        self._update_status()
        self._update_timer = self.set_interval(5.0, self._update_status)

    def _update_status(self) -> None:
        """Update the status display."""
        table = Table(show_header=True, header_style="bold magenta")
        table.add_column("Component", style="cyan")
        table.add_column("Status", justify="right")

        # System status
        table.add_row("System", "[green]Online[/]")
        table.add_row("Database", "[green]Connected[/]")
        table.add_row("Event Bus", "[green]Active[/]")

        # Tool availability (will be dynamic later)
        table.add_section()
        table.add_row("[bold]Core Tools[/]", "")
        table.add_row("  nmap", "[dim]Checking...[/]")
        table.add_row("  aircrack-ng", "[dim]Checking...[/]")
        table.add_row("  hashcat", "[dim]Checking...[/]")
        table.add_row("  metasploit", "[dim]Checking...[/]")

        # Active sessions
        table.add_section()
        table.add_row("[bold]Active Sessions[/]", "")
        table.add_row("  Running Tools", "0")
        table.add_row("  Background Tasks", "0")

        self.update(table)
