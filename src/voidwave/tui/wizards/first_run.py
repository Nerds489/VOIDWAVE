"""First-run setup wizard."""
from pathlib import Path

from textual.app import ComposeResult
from textual.containers import Container, Vertical
from textual.screen import ModalScreen
from textual.widgets import Button, Input, Label, Static


class FirstRunWizard(ModalScreen):
    """First-run setup wizard for VOIDWAVE."""

    BINDINGS = [
        ("escape", "dismiss", "Cancel"),
    ]

    def compose(self) -> ComposeResult:
        """Compose the wizard layout."""
        with Container(classes="modal-container"):
            yield Static(
                "[bold magenta]🌟 Welcome to VOIDWAVE[/]\n\n"
                "[cyan]First-Time Setup[/]",
                classes="modal-title"
            )

            with Vertical():
                yield Label("This wizard will help you configure VOIDWAVE for first use.")
                yield Label("")

                # Database location
                yield Label("[bold]Database Location[/]")
                yield Input(
                    value=str(Path.home() / ".voidwave" / "voidwave.db"),
                    placeholder="Database file path",
                    id="db-path"
                )
                yield Label("")

                # Output directory
                yield Label("[bold]Output Directory[/]")
                yield Input(
                    value=str(Path.home() / ".voidwave" / "output"),
                    placeholder="Output directory for results",
                    id="output-dir"
                )
                yield Label("")

                # Wordlist directory
                yield Label("[bold]Wordlist Directory (Optional)[/]")
                yield Input(
                    placeholder="/usr/share/wordlists",
                    id="wordlist-dir"
                )
                yield Label("")

                yield Static(
                    "[dim]Note: VOIDWAVE will create necessary directories and\n"
                    "initialize the database with default settings.[/]"
                )
                yield Label("")

                # Action buttons
                with Container():
                    yield Button("Complete Setup", id="btn-complete", variant="primary")
                    yield Button("Skip for Now", id="btn-skip", variant="default")

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        if event.button.id == "btn-complete":
            await self._complete_setup()
        elif event.button.id == "btn-skip":
            self.dismiss(False)

    async def _complete_setup(self) -> None:
        """Complete the first-run setup."""
        # Get input values
        db_path_input = self.query_one("#db-path", Input)
        output_dir_input = self.query_one("#output-dir", Input)
        wordlist_dir_input = self.query_one("#wordlist-dir", Input)

        db_path = Path(db_path_input.value)
        output_dir = Path(output_dir_input.value)
        wordlist_dir = Path(wordlist_dir_input.value) if wordlist_dir_input.value else None

        # Create directories
        try:
            db_path.parent.mkdir(parents=True, exist_ok=True)
            output_dir.mkdir(parents=True, exist_ok=True)

            # Create initialization marker
            init_file = db_path.parent / "initialized"
            init_file.touch()

            # Store configuration
            config_file = db_path.parent / "config.ini"
            with open(config_file, "w") as f:
                f.write("[paths]\n")
                f.write(f"database = {db_path}\n")
                f.write(f"output = {output_dir}\n")
                if wordlist_dir:
                    f.write(f"wordlists = {wordlist_dir}\n")

            self.dismiss(True)

        except Exception as e:
            # Show error (in full implementation, use a proper error dialog)
            self.app.bell()
            self.notify(f"Setup failed: {e}", severity="error")

    def action_dismiss(self) -> None:
        """Dismiss the wizard."""
        self.dismiss(False)
