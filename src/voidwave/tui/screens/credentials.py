"""Credential attacks screen with password cracking functionality."""
from __future__ import annotations

import asyncio
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
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
    ProgressBar,
    Select,
    Static,
    TabbedContent,
    TabPane,
    TextArea,
)

from voidwave.config.settings import get_settings
from voidwave.core.logging import get_logger
from voidwave.orchestration.events import Events
from voidwave.tui.helpers.preflight_runner import PreflightRunner

if TYPE_CHECKING:
    pass

logger = get_logger(__name__)


# Hashcat attack modes
ATTACK_MODES = [
    ("Dictionary Attack (0)", "0"),
    ("Combination Attack (1)", "1"),
    ("Brute Force (3)", "3"),
    ("Hybrid Wordlist + Mask (6)", "6"),
    ("Hybrid Mask + Wordlist (7)", "7"),
]

# Common hash types
HASH_TYPES = [
    ("WPA/WPA2 (2500)", "2500"),
    ("WPA-PBKDF2-PMKID+EAPOL (22000)", "22000"),
    ("MD5 (0)", "0"),
    ("SHA1 (100)", "100"),
    ("SHA256 (1400)", "1400"),
    ("SHA512 (1700)", "1700"),
    ("NTLM (1000)", "1000"),
    ("NetNTLMv2 (5600)", "5600"),
    ("bcrypt (3200)", "3200"),
    ("MySQL (300)", "300"),
    ("Custom", "custom"),
]

# Common wordlists
WORDLISTS = [
    ("rockyou.txt", "/usr/share/wordlists/rockyou.txt"),
    ("darkc0de.lst", "/usr/share/wordlists/darkc0de.lst"),
    ("fasttrack.txt", "/usr/share/wordlists/fasttrack.txt"),
    ("Custom", "custom"),
]


@dataclass
class CrackJob:
    """Represents a password cracking job."""

    job_id: str
    hash_type: str
    attack_mode: str
    target_file: str
    wordlist: str = ""
    mask: str = ""
    status: str = "pending"
    progress: float = 0.0
    speed: str = ""
    recovered: int = 0
    total: int = 0
    started_at: datetime | None = None
    cracked_passwords: list = None

    def __post_init__(self):
        if self.cracked_passwords is None:
            self.cracked_passwords = []


class CredentialsScreen(Screen):
    """Password cracking and credential attacks screen."""

    CSS = """
    CredentialsScreen {
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

    #hash-input {
        height: 8;
    }

    #progress-container {
        height: auto;
        padding: 1;
        border: solid $accent;
        margin-bottom: 1;
    }

    .cracked-item {
        color: $success;
    }
    """

    BINDINGS = [
        ("escape", "app.pop_screen", "Back"),
        ("s", "start_crack", "Start"),
        ("x", "stop_crack", "Stop"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self._cracking = False
        self._crack_task: asyncio.Task | None = None
        self._current_job: CrackJob | None = None
        self._cracked_passwords: list[tuple[str, str]] = []
        self._preflight: PreflightRunner | None = None

    def compose(self) -> ComposeResult:
        settings = get_settings()

        # Left: Configuration panel
        with Vertical(id="config-panel"):
            yield Label("[bold magenta]Crack Configuration[/]")

            yield Label("Hash Type:")
            yield Select(
                [(name, hash_id) for name, hash_id in HASH_TYPES],
                value="22000",
                id="select-hash-type",
                classes="config-input",
            )

            yield Label("Custom Hash Type (if Custom):")
            yield Input(
                placeholder="Enter hash mode number",
                id="input-custom-hash",
                classes="config-input",
            )

            yield Label("Attack Mode:")
            yield Select(
                ATTACK_MODES,
                value="0",
                id="select-attack-mode",
                classes="config-input",
            )

            yield Label("Wordlist:")
            yield Select(
                [(name, path) for name, path in WORDLISTS],
                value="/usr/share/wordlists/rockyou.txt",
                id="select-wordlist",
                classes="config-input",
            )

            yield Label("Custom Wordlist Path:")
            yield Input(
                value=str(settings.credentials.default_wordlist),
                id="input-wordlist",
                classes="config-input",
            )

            yield Label("Mask (for brute force):")
            yield Input(
                placeholder="e.g., ?a?a?a?a?a?a?a?a",
                id="input-mask",
                classes="config-input",
            )

            yield Label("Rules File (optional):")
            yield Input(
                placeholder="Path to rules file",
                id="input-rules",
                classes="config-input",
            )

            yield Label("Workload Profile (1-4):")
            yield Select(
                [("Low (1)", "1"), ("Default (2)", "2"), ("High (3)", "3"), ("Insane (4)", "4")],
                value=str(settings.credentials.hashcat_workload),
                id="select-workload",
                classes="config-input",
            )

            yield Static("")
            yield Button("Start Cracking", id="btn-start", variant="success", classes="action-button")
            yield Button("Stop", id="btn-stop", variant="error", classes="action-button")

        # Center/Right: Results panel with tabs
        with Vertical(id="results-panel"):
            with TabbedContent(initial="input"):
                with TabPane("Hash Input", id="input"):
                    yield Label("Enter hashes or path to hash file:")
                    yield TextArea(id="hash-input")
                    yield Label("Or select a file:")
                    yield Input(placeholder="Path to hash/capture file", id="input-hash-file")
                    yield Button("Load File", id="btn-load-file")

                with TabPane("Progress", id="progress"):
                    with Vertical(id="progress-container"):
                        yield Label("Status: [dim]Idle[/]", id="label-status")
                        yield ProgressBar(id="crack-progress", show_eta=True)
                        yield Label("Speed: [dim]--[/]", id="label-speed")
                        yield Label("Recovered: [dim]0/0[/]", id="label-recovered")

                with TabPane("Cracked", id="cracked"):
                    yield DataTable(id="cracked-table")

                with TabPane("Potfile", id="potfile"):
                    yield Static("Previously cracked passwords from potfile", id="potfile-content")

        # Bottom: Output
        with Vertical(id="output-panel"):
            yield Label("[bold]Output[/]")
            yield Static("Ready. Configure attack and click Start Cracking.", id="crack-output")

    async def on_mount(self) -> None:
        """Initialize screen."""
        self._preflight = PreflightRunner(self.app)
        self._setup_tables()
        self._subscribe_events()
        self._load_potfile()

    def _setup_tables(self) -> None:
        """Set up data tables."""
        table = self.query_one("#cracked-table", DataTable)
        table.add_columns("Hash", "Password", "Time")
        table.cursor_type = "row"

    def _subscribe_events(self) -> None:
        """Subscribe to credential-related events."""
        from voidwave.orchestration.events import event_bus

        event_bus.on(Events.CREDENTIAL_CRACKED, self._on_credential_cracked)

    async def _on_credential_cracked(self, data: dict) -> None:
        """Handle credential cracked event."""
        try:
            hash_val = data.get("hash", "")
            password = data.get("password", "")

            self._cracked_passwords.append((hash_val, password))
            self.app.call_from_thread(self._refresh_cracked_table)
            self.app.call_from_thread(
                self._write_output,
                f"[green]Cracked: {hash_val[:20]}... = {password}[/]"
            )

            # Show notification
            self.app.notify(f"Password cracked: {password}", severity="information")

        except Exception as e:
            logger.warning(f"Failed to process cracked credential: {e}")

    def _refresh_cracked_table(self) -> None:
        """Refresh the cracked passwords table."""
        table = self.query_one("#cracked-table", DataTable)
        table.clear()

        for hash_val, password in self._cracked_passwords:
            table.add_row(
                hash_val[:40] + "..." if len(hash_val) > 40 else hash_val,
                password,
                datetime.now().strftime("%H:%M:%S"),
            )

    def _load_potfile(self) -> None:
        """Load previously cracked passwords from hashcat potfile."""
        try:
            potfile = Path.home() / ".local" / "share" / "hashcat" / "hashcat.potfile"
            if not potfile.exists():
                potfile = Path.home() / ".hashcat" / "hashcat.potfile"

            if potfile.exists():
                content = potfile.read_text()
                lines = content.strip().split("\n")[-20:]  # Last 20 entries

                potfile_widget = self.query_one("#potfile-content", Static)
                if lines:
                    formatted = []
                    for line in lines:
                        if ":" in line:
                            hash_part, password = line.rsplit(":", 1)
                            formatted.append(f"[dim]{hash_part[:30]}...[/] = [green]{password}[/]")
                    potfile_widget.update("\n".join(formatted) if formatted else "[dim]No entries in potfile[/]")
                else:
                    potfile_widget.update("[dim]Potfile is empty[/]")
            else:
                potfile_widget = self.query_one("#potfile-content", Static)
                potfile_widget.update("[dim]Potfile not found[/]")

        except Exception as e:
            logger.warning(f"Failed to load potfile: {e}")

    def _write_output(self, message: str) -> None:
        """Write message to output panel."""
        output = self.query_one("#crack-output", Static)
        output.update(message)

    def _update_progress(self, status: str, progress: float, speed: str, recovered: int, total: int) -> None:
        """Update progress display."""
        status_label = self.query_one("#label-status", Label)
        progress_bar = self.query_one("#crack-progress", ProgressBar)
        speed_label = self.query_one("#label-speed", Label)
        recovered_label = self.query_one("#label-recovered", Label)

        status_label.update(f"Status: [cyan]{status}[/]")
        progress_bar.update(total=100, progress=progress)
        speed_label.update(f"Speed: [yellow]{speed}[/]")
        recovered_label.update(f"Recovered: [green]{recovered}[/]/{total}")

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        button_id = event.button.id

        if button_id == "btn-start":
            await self._start_cracking()
        elif button_id == "btn-stop":
            await self._stop_cracking()
        elif button_id == "btn-load-file":
            self._load_hash_file()

    def _load_hash_file(self) -> None:
        """Load hashes from file."""
        file_path = self.query_one("#input-hash-file", Input).value.strip()
        if not file_path:
            self._write_output("[red]Please enter a file path[/]")
            return

        path = Path(file_path).expanduser()
        if not path.exists():
            self._write_output(f"[red]File not found: {path}[/]")
            return

        try:
            content = path.read_text()
            hash_input = self.query_one("#hash-input", TextArea)
            hash_input.load_text(content)
            self._write_output(f"[green]Loaded {len(content.splitlines())} lines from {path}[/]")
        except Exception as e:
            self._write_output(f"[red]Failed to load file: {e}[/]")

    async def _start_cracking(self) -> None:
        """Start password cracking."""
        if self._cracking:
            self._write_output("[yellow]Cracking already in progress[/]")
            return

        # Prepare hashcat - this handles tool check, wordlist, etc.
        ctx = await self._preflight.prepare_tool("hashcat")

        if not ctx.ready:
            self._write_output(f"[red]{ctx.error}[/]")
            return

        # Use fallback tool name if needed
        tool_name = ctx.tool

        # Get hash input
        hash_input = self.query_one("#hash-input", TextArea).text.strip()
        hash_file = self.query_one("#input-hash-file", Input).value.strip()

        if not hash_input and not hash_file:
            self._write_output("[red]Please enter hashes or specify a hash file[/]")
            return

        # Use wordlist from preflight if available
        if ctx.wordlist:
            wordlist_input = self.query_one("#input-wordlist", Input)
            wordlist_input.value = ctx.wordlist

        self._cracking = True
        self._write_output(f"[green]Starting cracking session with {tool_name}...[/]")
        self._update_progress("Starting", 0, "--", 0, 0)

        self._crack_task = asyncio.create_task(self._run_crack(hash_input, hash_file, tool_name))

    async def _run_crack(self, hash_input: str, hash_file: str, tool_name: str = "hashcat") -> None:
        """Run the cracking process."""
        try:
            import tempfile

            # Use appropriate tool
            if tool_name == "john":
                from voidwave.tools.john import JohnTool
                tool = JohnTool()
            else:
                from voidwave.tools.hashcat import HashcatTool
                tool = HashcatTool()

            await tool.initialize()

            # Build options
            options = self._build_crack_options()

            # Determine target file
            if hash_file:
                target = hash_file
            else:
                # Write hashes to temp file
                with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
                    f.write(hash_input)
                    target = f.name

            options["hash_file"] = target

            self._write_output(f"[cyan]Running hashcat...[/]")
            self._update_progress("Running", 0, "--", 0, 0)

            result = await tool.execute(target, options)

            if result.success:
                data = result.data
                cracked = data.get("cracked", [])

                for entry in cracked:
                    self._cracked_passwords.append((entry.get("hash", ""), entry.get("password", "")))

                self._refresh_cracked_table()
                self._update_progress("Complete", 100, "--", len(cracked), data.get("total", 0))
                self._write_output(f"[green]Cracking complete. Recovered {len(cracked)} password(s)[/]")

            else:
                self._write_output(f"[red]Cracking failed: {result.errors}[/]")
                self._update_progress("Failed", 0, "--", 0, 0)

        except asyncio.CancelledError:
            self._write_output("[yellow]Cracking cancelled[/]")
            self._update_progress("Cancelled", 0, "--", 0, 0)
        except Exception as e:
            self._write_output(f"[red]Cracking error: {e}[/]")
            self._update_progress("Error", 0, "--", 0, 0)
        finally:
            self._cracking = False

    def _build_crack_options(self) -> dict:
        """Build cracking options from UI."""
        options = {}

        # Hash type
        hash_type = self.query_one("#select-hash-type", Select).value
        if hash_type == "custom":
            custom_hash = self.query_one("#input-custom-hash", Input).value.strip()
            if custom_hash.isdigit():
                options["hash_mode"] = int(custom_hash)
        else:
            options["hash_mode"] = int(hash_type)

        # Attack mode
        attack_mode = self.query_one("#select-attack-mode", Select).value
        options["attack_mode"] = int(attack_mode)

        # Wordlist
        wordlist_select = self.query_one("#select-wordlist", Select).value
        if wordlist_select == "custom":
            wordlist = self.query_one("#input-wordlist", Input).value.strip()
        else:
            wordlist = wordlist_select

        if wordlist:
            options["wordlist"] = wordlist

        # Mask
        mask = self.query_one("#input-mask", Input).value.strip()
        if mask:
            options["mask"] = mask

        # Rules - HashcatTool expects a list
        rules = self.query_one("#input-rules", Input).value.strip()
        if rules:
            options["rules"] = [rules]

        # Workload
        workload = self.query_one("#select-workload", Select).value
        if workload:
            options["workload"] = int(workload)

        return options

    async def _stop_cracking(self) -> None:
        """Stop the cracking process."""
        if not self._cracking:
            self._write_output("[yellow]No cracking in progress[/]")
            return

        if self._crack_task:
            self._crack_task.cancel()
            self._crack_task = None

        self._cracking = False
        self._write_output("[green]Cracking stopped[/]")

    def action_start_crack(self) -> None:
        """Start crack action."""
        asyncio.create_task(self._start_cracking())

    def action_stop_crack(self) -> None:
        """Stop crack action."""
        asyncio.create_task(self._stop_cracking())
