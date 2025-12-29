"""Base class for external tool wrappers."""
import asyncio
import os
import signal
import shutil
import time
from abc import abstractmethod
from dataclasses import dataclass
from pathlib import Path
from typing import Any, AsyncIterator, ClassVar

from voidwave.core.exceptions import SubprocessError, ToolNotFoundError
from voidwave.core.logging import get_logger
from voidwave.orchestration.events import Events, event_bus
from voidwave.plugins.base import PluginMetadata, PluginResult, ToolPlugin

logger = get_logger(__name__)


@dataclass
class ToolExecution:
    """Represents a tool execution context."""

    tool_name: str
    command: list[str]
    target: str
    output_file: Path | None = None
    started_at: float | None = None
    ended_at: float | None = None
    exit_code: int | None = None
    cancelled: bool = False


class BaseToolWrapper(ToolPlugin):
    """Base wrapper for external security tools."""

    # Subclasses must define
    TOOL_BINARY: ClassVar[str]  # e.g., "nmap"
    METADATA: ClassVar[PluginMetadata]

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        self._tool_path: Path | None = None
        self._current_process: asyncio.subprocess.Process | None = None
        self._execution: ToolExecution | None = None

    @property
    def tool_name(self) -> str:
        return self.TOOL_BINARY

    async def initialize(self) -> None:
        """Verify tool is available."""
        self._tool_path = shutil.which(self.TOOL_BINARY)
        if self._tool_path is None:
            raise ToolNotFoundError(
                f"Tool not found: {self.TOOL_BINARY}",
                details={"tool": self.TOOL_BINARY},
            )
        self._tool_path = Path(self._tool_path)
        self._initialized = True
        logger.debug(f"Tool initialized: {self.TOOL_BINARY} at {self._tool_path}")

    @abstractmethod
    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build command line arguments for the tool."""
        ...

    @abstractmethod
    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse tool output into structured data."""
        ...

    async def execute(self, target: str, options: dict[str, Any]) -> PluginResult:
        """Execute the tool and return results."""
        if not self._initialized:
            await self.initialize()

        command = self.build_command(target, options)
        full_command = [str(self._tool_path)] + command

        self._execution = ToolExecution(
            tool_name=self.TOOL_BINARY,
            command=full_command,
            target=target,
        )

        # Emit start event
        event_bus.emit(
            Events.TOOL_STARTED,
            {
                "tool": self.TOOL_BINARY,
                "target": target,
                "command": " ".join(full_command),
            },
        )

        self._execution.started_at = time.time()

        try:
            output = await self._run_subprocess(full_command, options)
            self._execution.ended_at = time.time()

            # Parse output
            parsed = self.parse_output(output)

            # Emit completion event
            event_bus.emit(
                Events.TOOL_COMPLETED,
                {
                    "tool": self.TOOL_BINARY,
                    "target": target,
                    "exit_code": self._execution.exit_code,
                    "duration": self._execution.ended_at - self._execution.started_at,
                },
            )

            return PluginResult(
                success=self._execution.exit_code == 0,
                data=parsed,
            )

        except asyncio.CancelledError:
            self._execution.cancelled = True
            await self.cancel()
            return PluginResult(
                success=False,
                data={},
                errors=["Execution cancelled"],
            )
        except Exception as e:
            logger.error(f"Tool execution failed: {e}")
            return PluginResult(
                success=False,
                data={},
                errors=[str(e)],
            )

    async def _run_subprocess(
        self, command: list[str], options: dict[str, Any]
    ) -> str:
        """Run the tool as a subprocess with output streaming."""
        timeout = options.get("timeout", self.config.timeout)

        self._current_process = await asyncio.create_subprocess_exec(
            *command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            start_new_session=True,  # Enable process group termination
        )

        output_lines = []

        try:
            async for line in self._stream_output():
                output_lines.append(line)

                # Emit output event for TUI
                event_bus.emit(
                    Events.TOOL_OUTPUT,
                    {
                        "tool": self.TOOL_BINARY,
                        "line": line,
                        "level": self._classify_line(line),
                    },
                )

            # Wait for process completion
            await asyncio.wait_for(
                self._current_process.wait(),
                timeout=timeout,
            )

            self._execution.exit_code = self._current_process.returncode

        except asyncio.TimeoutError:
            await self.cancel()
            raise SubprocessError(
                f"Tool timed out after {timeout}s",
                returncode=-1,
            )

        return "\n".join(output_lines)

    async def _stream_output(self) -> AsyncIterator[str]:
        """Stream output lines from subprocess."""
        if self._current_process is None or self._current_process.stdout is None:
            return

        while True:
            line = await self._current_process.stdout.readline()
            if not line:
                break
            yield line.decode().rstrip()

    def _classify_line(self, line: str) -> str:
        """Classify output line for display styling."""
        line_lower = line.lower()

        if any(w in line_lower for w in ["error", "fail", "critical"]):
            return "error"
        if any(w in line_lower for w in ["warn", "caution"]):
            return "warning"
        if any(w in line_lower for w in ["success", "found", "open", "vuln"]):
            return "success"
        return "info"

    async def cancel(self) -> None:
        """Cancel the running tool."""
        if self._current_process is not None:
            try:
                # Kill process group
                pgid = os.getpgid(self._current_process.pid)
                os.killpg(pgid, signal.SIGTERM)

                # Give it time to terminate gracefully
                await asyncio.sleep(2)

                # Force kill if still running
                if self._current_process.returncode is None:
                    os.killpg(pgid, signal.SIGKILL)

            except (ProcessLookupError, PermissionError):
                pass

            self._current_process = None

    async def cleanup(self) -> None:
        """Clean up resources."""
        await self.cancel()
