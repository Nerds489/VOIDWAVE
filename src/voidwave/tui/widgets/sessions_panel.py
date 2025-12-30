"""Sessions panel widget for the main screen."""

import asyncio
from textual.app import ComposeResult
from textual.containers import Vertical, Horizontal, ScrollableContainer
from textual.widgets import Static, Button, DataTable, Input, Label
from textual.widget import Widget

from voidwave.sessions import get_session_manager, Session, SessionStatus


class SessionsPanel(Widget):
    """Panel showing session management in the main screen."""

    CSS = """
    SessionsPanel {
        height: 100%;
        padding: 1;
    }

    #current-session-box {
        height: auto;
        border: solid $primary;
        padding: 1;
        margin-bottom: 1;
    }

    #sessions-table-container {
        height: 1fr;
        border: solid $surface;
        padding: 1;
    }

    #sessions-table {
        height: 100%;
    }

    #session-actions {
        height: 3;
        margin-top: 1;
    }

    #session-actions Button {
        margin-right: 1;
    }

    .session-label {
        color: $text-muted;
    }

    .session-value {
        color: $primary;
        text-style: bold;
    }

    .session-active {
        color: $success;
    }

    .session-paused {
        color: $warning;
    }

    .session-completed {
        color: $text-muted;
    }
    """

    def __init__(self, **kwargs) -> None:
        super().__init__(**kwargs)
        self._manager = get_session_manager()

    def compose(self) -> ComposeResult:
        with Vertical():
            # Current session info
            with Vertical(id="current-session-box"):
                yield Static("[bold]Current Session[/]")
                yield Static("[dim]No active session[/]", id="current-session-info")

            # Sessions list
            with Vertical(id="sessions-table-container"):
                yield Static("[bold]Recent Sessions[/]")
                yield DataTable(id="sessions-table")

            # Actions
            with Horizontal(id="session-actions"):
                yield Button("New Session", id="btn-new-session", variant="success")
                yield Button("Resume", id="btn-resume-session")
                yield Button("End Session", id="btn-end-session", variant="warning")
                yield Button("Delete", id="btn-delete-session", variant="error")

    async def on_mount(self) -> None:
        """Initialize the panel."""
        table = self.query_one("#sessions-table", DataTable)
        table.add_columns("Name", "Status", "Duration", "Targets", "Tools")
        table.cursor_type = "row"

        await self._refresh_sessions()

    async def _refresh_sessions(self) -> None:
        """Refresh the sessions display."""
        # Update current session
        current = self._manager.current
        info_widget = self.query_one("#current-session-info", Static)

        if current:
            status_class = f"session-{current.status.value}" if isinstance(current.status, SessionStatus) else "session-active"
            info_widget.update(
                f"[{status_class}]{current.name}[/] | "
                f"Status: [{status_class}]{current.status.value if isinstance(current.status, SessionStatus) else current.status}[/] | "
                f"Duration: {current.duration} | "
                f"Targets: {current.summary.target_count}"
            )
        else:
            info_widget.update("[dim]No active session - Create one to track your work[/]")

        # Update sessions table
        table = self.query_one("#sessions-table", DataTable)
        table.clear()

        try:
            sessions = await self._manager.get_recent(limit=10)

            for session in sessions:
                status = session.status.value if isinstance(session.status, SessionStatus) else session.status
                status_display = {
                    "active": "[green]● Active[/]",
                    "paused": "[yellow]◐ Paused[/]",
                    "completed": "[dim]✓ Done[/]",
                    "failed": "[red]✗ Failed[/]",
                }.get(status, status)

                table.add_row(
                    session.name,
                    status_display,
                    session.duration,
                    str(session.summary.target_count),
                    str(session.summary.tool_executions),
                    key=session.id,
                )
        except Exception as e:
            self.notify(f"Failed to load sessions: {e}", severity="error")

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        button_id = event.button.id

        if button_id == "btn-new-session":
            await self._create_new_session()
        elif button_id == "btn-resume-session":
            await self._resume_selected_session()
        elif button_id == "btn-end-session":
            await self._end_current_session()
        elif button_id == "btn-delete-session":
            await self._delete_selected_session()

    async def _create_new_session(self) -> None:
        """Create a new session."""
        from datetime import datetime

        # Generate a default name
        name = f"Session {datetime.now().strftime('%Y-%m-%d %H:%M')}"

        try:
            session = await self._manager.create(name=name)
            self.notify(f"Created session: {session.name}", severity="information")
            await self._refresh_sessions()
        except Exception as e:
            self.notify(f"Failed to create session: {e}", severity="error")

    async def _resume_selected_session(self) -> None:
        """Resume the selected session."""
        table = self.query_one("#sessions-table", DataTable)

        if table.cursor_row is None:
            self.notify("Select a session to resume", severity="warning")
            return

        try:
            row_key = table.get_row_at(table.cursor_row)
            session_id = table.get_row_key(row_key)

            if session_id:
                session = await self._manager.resume(str(session_id))
                if session:
                    self.notify(f"Resumed: {session.name}", severity="information")
                    await self._refresh_sessions()
        except Exception as e:
            self.notify(f"Failed to resume session: {e}", severity="error")

    async def _end_current_session(self) -> None:
        """End the current session."""
        current = self._manager.current

        if not current:
            self.notify("No active session to end", severity="warning")
            return

        try:
            await self._manager.complete(current.id)
            self.notify(f"Session completed: {current.name}", severity="information")
            await self._refresh_sessions()
        except Exception as e:
            self.notify(f"Failed to end session: {e}", severity="error")

    async def _delete_selected_session(self) -> None:
        """Delete the selected session."""
        table = self.query_one("#sessions-table", DataTable)

        if table.cursor_row is None:
            self.notify("Select a session to delete", severity="warning")
            return

        try:
            row_key = table.get_row_at(table.cursor_row)
            session_id = table.get_row_key(row_key)

            if session_id:
                deleted = await self._manager.delete(str(session_id))
                if deleted:
                    self.notify("Session deleted", severity="information")
                    await self._refresh_sessions()
        except Exception as e:
            self.notify(f"Failed to delete session: {e}", severity="error")

    async def on_data_table_row_selected(self, event: DataTable.RowSelected) -> None:
        """Handle row selection for potential resume."""
        pass  # Could show details in a panel
