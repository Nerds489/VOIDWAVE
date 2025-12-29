"""Real-time tool output widget with streaming support."""
from datetime import datetime
from typing import ClassVar

from textual.message import Message
from textual.widgets import RichLog


class ToolOutput(RichLog):
    """Widget for streaming security tool output."""

    DEFAULT_CSS: ClassVar[str] = """
    ToolOutput {
        height: 100%;
        border: solid #3a3a5e;
        background: #1a1a2e;
    }
    """

    class OutputLine(Message):
        """Message for new output line."""

        def __init__(self, tool: str, line: str, level: str = "info") -> None:
            super().__init__()
            self.tool = tool
            self.line = line
            self.level = level

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, highlight=True, markup=True, **kwargs)
        self._current_tool: str | None = None

    async def on_mount(self) -> None:
        """Subscribe to tool output events."""
        # Event bus subscription will be added when orchestration is ready
        # event_bus.on(Events.TOOL_OUTPUT, self._on_tool_output)
        # event_bus.on(Events.TOOL_STARTED, self._on_tool_started)
        # event_bus.on(Events.TOOL_COMPLETED, self._on_tool_completed)

        # Welcome message
        self.write_header("VOIDWAVE Output Console")
        self.write("[dim]Ready for operations...[/]")

    def write_header(self, text: str) -> None:
        """Write a header line."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.write(f"[dim]{timestamp}[/] [bold magenta]═══ {text} ═══[/]")

    def write_info(self, text: str, tool: str | None = None) -> None:
        """Write info-level output."""
        self._write_line(text, "cyan", tool)

    def write_success(self, text: str, tool: str | None = None) -> None:
        """Write success-level output."""
        self._write_line(text, "#00FF41", tool)

    def write_warning(self, text: str, tool: str | None = None) -> None:
        """Write warning-level output."""
        self._write_line(text, "#FF9A00", tool)

    def write_error(self, text: str, tool: str | None = None) -> None:
        """Write error-level output."""
        self._write_line(text, "#FF0040", tool)

    def _write_line(self, text: str, color: str, tool: str | None = None) -> None:
        """Write a colored line with optional tool prefix."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        tool_prefix = f"[bold]{tool}[/] " if tool else ""
        self.write(f"[dim]{timestamp}[/] {tool_prefix}[{color}]{text}[/]")

    async def _on_tool_output(self, data: dict) -> None:
        """Handle tool output event."""
        tool = data.get("tool", "unknown")
        line = data.get("line", "")
        level = data.get("level", "info")

        if level == "error":
            self.write_error(line, tool)
        elif level == "warning":
            self.write_warning(line, tool)
        elif level == "success":
            self.write_success(line, tool)
        else:
            self.write_info(line, tool)

    async def _on_tool_started(self, data: dict) -> None:
        """Handle tool started event."""
        tool = data.get("tool", "unknown")
        target = data.get("target", "")
        self._current_tool = tool
        self.write_header(f"{tool} Started")
        if target:
            self.write(f"[dim]Target: {target}[/]")

    async def _on_tool_completed(self, data: dict) -> None:
        """Handle tool completed event."""
        tool = data.get("tool", "unknown")
        exit_code = data.get("exit_code", 0)
        duration = data.get("duration", 0)

        if exit_code == 0:
            self.write_success(f"Completed in {duration:.1f}s", tool)
        else:
            self.write_error(f"Failed with exit code {exit_code}", tool)

        self._current_tool = None
