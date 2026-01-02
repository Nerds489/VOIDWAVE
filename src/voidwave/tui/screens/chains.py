"""Tool chains screen for browsing, running, and monitoring attack chains."""
from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
from datetime import datetime
from typing import TYPE_CHECKING

from textual.app import ComposeResult
from textual.containers import Horizontal, ScrollableContainer, Vertical
from textual.screen import Screen
from textual.widgets import (
    Button,
    DataTable,
    Input,
    Label,
    OptionList,
    Static,
)
from textual.widgets.option_list import Option

from voidwave.core.logging import get_logger
from voidwave.orchestration.events import Events, event_bus
from voidwave.tui.helpers.preflight_runner import PreflightRunner

if TYPE_CHECKING:
    from voidwave.chaining import ChainDefinition, ChainResult

logger = get_logger(__name__)


@dataclass
class StepProgress:
    """Tracks progress of a chain step."""

    step_id: str
    tool: str
    status: str = "pending"  # pending, running, completed, failed, skipped
    started_at: datetime | None = None
    ended_at: datetime | None = None
    error: str = ""


@dataclass
class ChainProgress:
    """Tracks progress of a running chain."""

    chain_id: str
    chain_name: str
    status: str = "pending"  # pending, running, completed, failed, cancelled
    steps: dict[str, StepProgress] = field(default_factory=dict)
    started_at: datetime | None = None
    ended_at: datetime | None = None
    current_step: str = ""


class ChainsScreen(Screen):
    """Browse, configure, and run tool chains."""

    CSS = """
    ChainsScreen {
        layout: grid;
        grid-size: 3 2;
        grid-columns: 1fr 2fr 2fr;
        grid-rows: 1fr auto;
    }

    #chain-browser {
        height: 100%;
        border: solid $primary;
        padding: 1;
    }

    #chain-browser Label {
        margin-bottom: 1;
    }

    #chain-list {
        height: 1fr;
        margin-bottom: 1;
    }

    #chain-details {
        height: 100%;
        border: solid $secondary;
        padding: 1;
    }

    #step-monitor {
        height: 100%;
        border: solid $accent;
        padding: 1;
    }

    #output-panel {
        column-span: 3;
        height: 12;
        border: solid $surface;
        padding: 1;
    }

    #output-scroll {
        height: 100%;
    }

    .action-button {
        width: 100%;
        margin: 0 0 1 0;
    }

    .tag-label {
        color: $text-muted;
    }

    #steps-table {
        height: 1fr;
    }

    #step-details {
        height: auto;
        max-height: 10;
        padding: 1;
        border: solid $surface;
    }

    .status-pending { color: $text-muted; }
    .status-running { color: $warning; }
    .status-completed { color: $success; }
    .status-failed { color: $error; }
    .status-skipped { color: $text-muted; }
    """

    BINDINGS = [
        ("escape", "app.pop_screen", "Back"),
        ("r", "run_chain", "Run Chain"),
        ("x", "stop_chain", "Stop Chain"),
        ("f", "focus_search", "Search"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self._chains: dict[str, ChainDefinition] = {}
        self._selected_chain: ChainDefinition | None = None
        self._running_chain: ChainProgress | None = None
        self._chain_task: asyncio.Task | None = None
        self._preflight: PreflightRunner | None = None
        self._output_lines: list[str] = []

    def compose(self) -> ComposeResult:
        # Left: Chain browser
        with Vertical(id="chain-browser"):
            yield Label("[bold magenta]Chain Browser[/]")
            yield Input(placeholder="Search chains...", id="search-input")
            yield OptionList(id="chain-list")
            yield Static("", id="chain-tags", classes="tag-label")

        # Center: Chain details
        with Vertical(id="chain-details"):
            yield Label("[bold cyan]Chain Details[/]")
            yield Static("Select a chain to view details", id="chain-info")
            yield Label("")
            yield Label("[bold]Steps:[/]")
            yield DataTable(id="steps-table")
            yield Static("", id="step-details")

        # Right: Step monitor
        with Vertical(id="step-monitor"):
            yield Label("[bold green]Execution Monitor[/]")
            yield Static("[dim]No chain running[/]", id="execution-status")
            yield Label("")
            yield Label("[bold]Target:[/]")
            yield Input(placeholder="Target (IP, CIDR, interface...)", id="target-input")
            yield Label("")
            yield Button("Run Chain", id="btn-run", variant="success", classes="action-button")
            yield Button("Stop Chain", id="btn-stop", variant="error", classes="action-button")

        # Bottom: Output
        with Vertical(id="output-panel"):
            yield Label("[bold]Output[/]")
            with ScrollableContainer(id="output-scroll"):
                yield Static("Ready. Select a chain from the browser.", id="output-text")

    async def on_mount(self) -> None:
        """Initialize screen."""
        self._preflight = PreflightRunner(self.app)
        self._load_chains()
        self._setup_tables()
        self._subscribe_events()

    def _load_chains(self) -> None:
        """Load chains from registry."""
        try:
            from voidwave.chaining import chain_registry, initialize_chains

            # Initialize built-in chains if not already done
            initialize_chains()

            # Load all chains
            self._chains = {chain.id: chain for chain in chain_registry}

            # Populate the chain list
            chain_list = self.query_one("#chain-list", OptionList)
            chain_list.clear_options()

            for chain in sorted(self._chains.values(), key=lambda c: c.name):
                chain_list.add_option(Option(f"{chain.name}", id=chain.id))

            self._write_output(f"[green]Loaded {len(self._chains)} chains[/]")

        except Exception as e:
            logger.error(f"Failed to load chains: {e}")
            self._write_output(f"[red]Failed to load chains: {e}[/]")

    def _setup_tables(self) -> None:
        """Set up data tables."""
        steps_table = self.query_one("#steps-table", DataTable)
        steps_table.add_columns("Step", "Tool", "Status", "Duration")
        steps_table.cursor_type = "row"

    def _subscribe_events(self) -> None:
        """Subscribe to chain events."""
        event_bus.on(Events.CHAIN_STARTED, self._on_chain_started)
        event_bus.on(Events.CHAIN_STEP_STARTED, self._on_step_started)
        event_bus.on(Events.CHAIN_STEP_COMPLETED, self._on_step_completed)
        event_bus.on(Events.CHAIN_STEP_FAILED, self._on_step_failed)
        event_bus.on(Events.CHAIN_STEP_SKIPPED, self._on_step_skipped)
        event_bus.on(Events.CHAIN_COMPLETED, self._on_chain_completed)
        event_bus.on(Events.CHAIN_FAILED, self._on_chain_failed)
        event_bus.on(Events.CHAIN_CANCELLED, self._on_chain_cancelled)

    def _unsubscribe_events(self) -> None:
        """Unsubscribe from chain events."""
        event_bus.off(Events.CHAIN_STARTED, self._on_chain_started)
        event_bus.off(Events.CHAIN_STEP_STARTED, self._on_step_started)
        event_bus.off(Events.CHAIN_STEP_COMPLETED, self._on_step_completed)
        event_bus.off(Events.CHAIN_STEP_FAILED, self._on_step_failed)
        event_bus.off(Events.CHAIN_STEP_SKIPPED, self._on_step_skipped)
        event_bus.off(Events.CHAIN_COMPLETED, self._on_chain_completed)
        event_bus.off(Events.CHAIN_FAILED, self._on_chain_failed)
        event_bus.off(Events.CHAIN_CANCELLED, self._on_chain_cancelled)

    async def on_unmount(self) -> None:
        """Clean up when screen is unmounted."""
        self._unsubscribe_events()

    # --------------------------------------------------------------------------
    # Event Handlers
    # --------------------------------------------------------------------------

    async def _on_chain_started(self, data: dict) -> None:
        """Handle chain started event."""
        chain_id = data.get("chain_id", "")
        chain_name = data.get("chain_name", "")
        step_count = data.get("step_count", 0)

        self._running_chain = ChainProgress(
            chain_id=chain_id,
            chain_name=chain_name,
            status="running",
            started_at=datetime.now(),
        )

        self.app.call_from_thread(
            self._update_execution_status,
            f"[yellow]Running:[/] {chain_name} ({step_count} steps)",
        )
        self.app.call_from_thread(
            self._write_output,
            f"[cyan]Chain started:[/] {chain_name}",
        )

    async def _on_step_started(self, data: dict) -> None:
        """Handle step started event."""
        step_id = data.get("step_id", "")
        tool = data.get("tool", "")

        if self._running_chain:
            self._running_chain.current_step = step_id
            self._running_chain.steps[step_id] = StepProgress(
                step_id=step_id,
                tool=tool,
                status="running",
                started_at=datetime.now(),
            )

        self.app.call_from_thread(
            self._write_output,
            f"[yellow]Step started:[/] {step_id} ({tool})",
        )
        self.app.call_from_thread(self._refresh_steps_table)

    async def _on_step_completed(self, data: dict) -> None:
        """Handle step completed event."""
        step_id = data.get("step_id", "")
        duration = data.get("duration", 0)

        if self._running_chain and step_id in self._running_chain.steps:
            step = self._running_chain.steps[step_id]
            step.status = "completed"
            step.ended_at = datetime.now()

        self.app.call_from_thread(
            self._write_output,
            f"[green]Step completed:[/] {step_id} ({duration:.1f}s)",
        )
        self.app.call_from_thread(self._refresh_steps_table)

    async def _on_step_failed(self, data: dict) -> None:
        """Handle step failed event."""
        step_id = data.get("step_id", "")
        error = data.get("error", "Unknown error")

        if self._running_chain and step_id in self._running_chain.steps:
            step = self._running_chain.steps[step_id]
            step.status = "failed"
            step.ended_at = datetime.now()
            step.error = error

        self.app.call_from_thread(
            self._write_output,
            f"[red]Step failed:[/] {step_id} - {error}",
        )
        self.app.call_from_thread(self._refresh_steps_table)

    async def _on_step_skipped(self, data: dict) -> None:
        """Handle step skipped event."""
        step_id = data.get("step_id", "")
        reason = data.get("reason", "Condition not met")

        if self._running_chain and step_id in self._running_chain.steps:
            step = self._running_chain.steps[step_id]
            step.status = "skipped"
            step.ended_at = datetime.now()

        self.app.call_from_thread(
            self._write_output,
            f"[dim]Step skipped:[/] {step_id} - {reason}",
        )
        self.app.call_from_thread(self._refresh_steps_table)

    async def _on_chain_completed(self, data: dict) -> None:
        """Handle chain completed event."""
        chain_id = data.get("chain_id", "")
        duration = data.get("duration", 0)

        if self._running_chain:
            self._running_chain.status = "completed"
            self._running_chain.ended_at = datetime.now()

        self.app.call_from_thread(
            self._update_execution_status,
            f"[green]Completed:[/] {chain_id} ({duration:.1f}s)",
        )
        self.app.call_from_thread(
            self._write_output,
            f"[green]Chain completed:[/] {chain_id} in {duration:.1f}s",
        )

    async def _on_chain_failed(self, data: dict) -> None:
        """Handle chain failed event."""
        chain_id = data.get("chain_id", "")
        error = data.get("error", "Unknown error")

        if self._running_chain:
            self._running_chain.status = "failed"
            self._running_chain.ended_at = datetime.now()

        self.app.call_from_thread(
            self._update_execution_status,
            f"[red]Failed:[/] {chain_id}",
        )
        self.app.call_from_thread(
            self._write_output,
            f"[red]Chain failed:[/] {chain_id} - {error}",
        )

    async def _on_chain_cancelled(self, data: dict) -> None:
        """Handle chain cancelled event."""
        chain_id = data.get("chain_id", "")

        if self._running_chain:
            self._running_chain.status = "cancelled"
            self._running_chain.ended_at = datetime.now()

        self.app.call_from_thread(
            self._update_execution_status,
            f"[yellow]Cancelled:[/] {chain_id}",
        )
        self.app.call_from_thread(
            self._write_output,
            f"[yellow]Chain cancelled:[/] {chain_id}",
        )

    # --------------------------------------------------------------------------
    # UI Event Handlers
    # --------------------------------------------------------------------------

    async def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
        """Handle chain selection."""
        chain_id = event.option.id
        if chain_id and chain_id in self._chains:
            self._selected_chain = self._chains[chain_id]
            self._show_chain_details(self._selected_chain)

    async def on_input_changed(self, event: Input.Changed) -> None:
        """Handle search input."""
        if event.input.id == "search-input":
            self._filter_chains(event.value)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        if event.button.id == "btn-run":
            self.run_worker(self._run_chain(), exclusive=True)
        elif event.button.id == "btn-stop":
            self.run_worker(self._stop_chain())

    async def on_data_table_row_selected(self, event: DataTable.RowSelected) -> None:
        """Handle step selection in table."""
        if event.data_table.id == "steps-table" and self._selected_chain:
            row_key = event.row_key
            if row_key:
                step_id = row_key.value
                self._show_step_details(step_id)

    # --------------------------------------------------------------------------
    # UI Update Methods
    # --------------------------------------------------------------------------

    def _filter_chains(self, query: str) -> None:
        """Filter chain list by search query."""
        chain_list = self.query_one("#chain-list", OptionList)
        chain_list.clear_options()

        query = query.lower()
        for chain in sorted(self._chains.values(), key=lambda c: c.name):
            if (
                query in chain.name.lower()
                or query in chain.description.lower()
                or any(query in tag.lower() for tag in chain.tags)
            ):
                chain_list.add_option(Option(f"{chain.name}", id=chain.id))

    def _show_chain_details(self, chain: ChainDefinition) -> None:
        """Display chain details."""
        info = self.query_one("#chain-info", Static)

        lines = [
            f"[bold]{chain.name}[/]",
            f"[dim]ID:[/] {chain.id}",
            "",
            f"{chain.description}",
            "",
            f"[dim]Target Type:[/] {chain.target_type}",
            f"[dim]Steps:[/] {len(chain.steps)}",
        ]

        if chain.preflight_action:
            lines.append(f"[dim]Preflight:[/] {chain.preflight_action}")

        info.update("\n".join(lines))

        # Update tags
        tags = self.query_one("#chain-tags", Static)
        if chain.tags:
            tag_str = " ".join(f"[{tag}]" for tag in chain.tags)
            tags.update(f"Tags: {tag_str}")
        else:
            tags.update("")

        # Populate steps table
        self._populate_steps_table(chain)

    def _populate_steps_table(self, chain: ChainDefinition) -> None:
        """Populate the steps table for a chain."""
        table = self.query_one("#steps-table", DataTable)
        table.clear()

        for step in chain.steps:
            # Check if we have progress info for this step
            status = "pending"
            duration = "-"

            if self._running_chain and step.id in self._running_chain.steps:
                progress = self._running_chain.steps[step.id]
                status = progress.status
                if progress.started_at and progress.ended_at:
                    dur = (progress.ended_at - progress.started_at).total_seconds()
                    duration = f"{dur:.1f}s"
                elif progress.status == "running":
                    duration = "..."

            # Format status with color
            status_display = self._format_status(status)

            table.add_row(
                step.id,
                step.tool,
                status_display,
                duration,
                key=step.id,
            )

    def _refresh_steps_table(self) -> None:
        """Refresh steps table with current progress."""
        if self._selected_chain:
            self._populate_steps_table(self._selected_chain)

    def _format_status(self, status: str) -> str:
        """Format status with color."""
        colors = {
            "pending": "dim",
            "running": "yellow",
            "completed": "green",
            "failed": "red",
            "skipped": "dim",
        }
        color = colors.get(status, "white")
        return f"[{color}]{status}[/]"

    def _show_step_details(self, step_id: str) -> None:
        """Show details for a selected step."""
        if not self._selected_chain:
            return

        step = None
        for s in self._selected_chain.steps:
            if s.id == step_id:
                step = s
                break

        if not step:
            return

        details = self.query_one("#step-details", Static)

        lines = [
            f"[bold]{step.id}[/] - {step.tool}",
            f"[dim]{step.description}[/]" if step.description else "",
        ]

        if step.depends_on:
            lines.append(f"[dim]Depends on:[/] {', '.join(step.depends_on)}")

        if step.options:
            lines.append(f"[dim]Options:[/] {len(step.options)} configured")

        if step.condition:
            lines.append(f"[dim]Condition:[/] {step.condition.check} on {step.condition.path}")

        if step.on_error:
            lines.append(f"[dim]On Error:[/] {step.on_error.value}")

        if step.timeout:
            lines.append(f"[dim]Timeout:[/] {step.timeout}s")

        details.update("\n".join(filter(None, lines)))

    def _update_execution_status(self, message: str) -> None:
        """Update execution status display."""
        status = self.query_one("#execution-status", Static)
        status.update(message)

    def _write_output(self, message: str) -> None:
        """Write message to output panel."""
        self._output_lines.append(message)
        # Keep last 100 lines
        if len(self._output_lines) > 100:
            self._output_lines = self._output_lines[-100:]

        output = self.query_one("#output-text", Static)
        output.update("\n".join(self._output_lines))

        # Scroll to bottom
        scroll = self.query_one("#output-scroll", ScrollableContainer)
        scroll.scroll_end(animate=False)

    # --------------------------------------------------------------------------
    # Chain Execution
    # --------------------------------------------------------------------------

    async def _run_chain(self) -> None:
        """Run the selected chain."""
        if not self._selected_chain:
            self._write_output("[yellow]No chain selected[/]")
            return

        if self._chain_task and not self._chain_task.done():
            self._write_output("[yellow]A chain is already running[/]")
            return

        chain = self._selected_chain
        target = self.query_one("#target-input", Input).value.strip()

        # Check if target is required
        if not target:
            self._write_output(f"[yellow]Enter a target ({chain.target_type})[/]")
            self.query_one("#target-input", Input).focus()
            return

        # Run preflight if specified
        if chain.preflight_action:
            ctx = await self._preflight.run_with_preflight(
                chain.preflight_action,
                lambda: None,
            )
            if not ctx:
                self._write_output("[red]Preflight checks failed[/]")
                return

        # Reset progress tracking
        self._running_chain = None

        # Clear previous step progress
        self._refresh_steps_table()

        self._write_output(f"[cyan]Starting chain:[/] {chain.name}")
        self._write_output(f"[dim]Target:[/] {target}")

        # Execute chain
        self._chain_task = asyncio.create_task(self._execute_chain(chain, target))

    async def _execute_chain(self, chain: ChainDefinition, target: str) -> None:
        """Execute a chain."""
        try:
            from voidwave.chaining import ChainExecutor

            executor = ChainExecutor()
            result = await executor.execute(chain, target)

            if result.success:
                self._write_output(f"[green]Chain completed successfully[/]")

                # Show summary
                completed = sum(1 for s in result.steps.values() if s.status.value == "completed")
                failed = sum(1 for s in result.steps.values() if s.status.value == "failed")
                skipped = sum(1 for s in result.steps.values() if s.status.value == "skipped")

                self._write_output(
                    f"[dim]Summary: {completed} completed, {failed} failed, {skipped} skipped[/]"
                )
            else:
                self._write_output(f"[red]Chain failed[/]")
                for error in result.errors:
                    self._write_output(f"[red]  - {error}[/]")

        except asyncio.CancelledError:
            self._write_output("[yellow]Chain execution cancelled[/]")
        except Exception as e:
            logger.error(f"Chain execution error: {e}")
            self._write_output(f"[red]Error: {e}[/]")

    async def _stop_chain(self) -> None:
        """Stop the running chain."""
        if not self._chain_task or self._chain_task.done():
            self._write_output("[yellow]No chain running[/]")
            return

        self._chain_task.cancel()
        self._write_output("[yellow]Stopping chain...[/]")

    # --------------------------------------------------------------------------
    # Actions
    # --------------------------------------------------------------------------

    def action_run_chain(self) -> None:
        """Run chain action."""
        asyncio.create_task(self._run_chain())

    def action_stop_chain(self) -> None:
        """Stop chain action."""
        asyncio.create_task(self._stop_chain())

    def action_focus_search(self) -> None:
        """Focus search input."""
        self.query_one("#search-input", Input).focus()
