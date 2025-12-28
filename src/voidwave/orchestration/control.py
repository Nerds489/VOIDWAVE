"""Execution controller for managing running tools and tasks."""
from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
from datetime import datetime
from typing import TYPE_CHECKING

from voidwave.core.logging import get_logger
from voidwave.orchestration.events import Events, VoidwaveEventBus

if TYPE_CHECKING:
    from asyncio.subprocess import Process

logger = get_logger(__name__)


@dataclass
class RunningProcess:
    """Information about a running subprocess."""

    process_id: str
    tool_name: str
    process: Process
    started_at: datetime = field(default_factory=datetime.now)
    target: str | None = None


class ExecutionController:
    """Centralized control for all running operations.

    Manages running subprocesses, provides cancel functionality,
    and implements the "Stop All" operation.
    """

    def __init__(self, event_bus: VoidwaveEventBus) -> None:
        """Initialize the controller.

        Args:
            event_bus: The VOIDWAVE event bus for emitting events
        """
        self.bus = event_bus
        self._processes: dict[str, RunningProcess] = {}
        self._lock = asyncio.Lock()
        self._stop_all_in_progress = False

        # Subscribe to stop all event
        self.bus.on(Events.STOP_ALL_TOOLS, self._on_stop_all)

    async def register(
        self,
        process_id: str,
        tool_name: str,
        process: Process,
        target: str | None = None,
    ) -> None:
        """Register a running subprocess.

        Args:
            process_id: Unique identifier for this process
            tool_name: Name of the tool being run
            process: The asyncio subprocess
            target: Optional target being operated on
        """
        async with self._lock:
            self._processes[process_id] = RunningProcess(
                process_id=process_id,
                tool_name=tool_name,
                process=process,
                target=target,
            )
            logger.debug(f"Registered process: {process_id} ({tool_name})")

    async def unregister(self, process_id: str) -> None:
        """Unregister a subprocess (typically when it completes).

        Args:
            process_id: The process ID to unregister
        """
        async with self._lock:
            if process_id in self._processes:
                del self._processes[process_id]
                logger.debug(f"Unregistered process: {process_id}")

    async def cancel(self, process_id: str, timeout: float = 5.0) -> bool:
        """Cancel a specific running process.

        Args:
            process_id: The process ID to cancel
            timeout: Seconds to wait for graceful termination

        Returns:
            True if process was cancelled, False if not found
        """
        async with self._lock:
            if process_id not in self._processes:
                return False

            running = self._processes[process_id]

        return await self._terminate_process(running, timeout)

    async def stop_all(self, timeout: float = 5.0) -> dict:
        """Stop all running processes.

        Args:
            timeout: Seconds to wait for graceful termination per process

        Returns:
            Dict with counts of cancelled, failed, and errors
        """
        if self._stop_all_in_progress:
            logger.warning("Stop all already in progress")
            return {"cancelled": 0, "failed": 0, "errors": []}

        self._stop_all_in_progress = True

        results = {
            "cancelled": 0,
            "failed": 0,
            "errors": [],
        }

        try:
            async with self._lock:
                processes_to_stop = list(self._processes.values())

            logger.info(f"Stopping {len(processes_to_stop)} processes")

            for running in processes_to_stop:
                try:
                    success = await self._terminate_process(running, timeout)
                    if success:
                        results["cancelled"] += 1
                    else:
                        results["failed"] += 1
                except Exception as e:
                    results["errors"].append(f"{running.tool_name}: {e}")
                    results["failed"] += 1

            # Emit completion event
            await self.bus.emit(
                Events.STATUS_UPDATE,
                {
                    "action": "stop_all_completed",
                    "results": results,
                },
            )

            logger.info(
                f"Stop all completed: {results['cancelled']} cancelled, "
                f"{results['failed']} failed"
            )

        finally:
            self._stop_all_in_progress = False

        return results

    async def _terminate_process(
        self, running: RunningProcess, timeout: float
    ) -> bool:
        """Terminate a single process gracefully.

        Args:
            running: The running process info
            timeout: Seconds to wait for graceful termination

        Returns:
            True if terminated successfully
        """
        process = running.process

        if process.returncode is not None:
            # Already terminated
            await self.unregister(running.process_id)
            return True

        try:
            # First try graceful termination
            process.terminate()

            try:
                await asyncio.wait_for(process.wait(), timeout=timeout)
                logger.debug(f"Process {running.process_id} terminated gracefully")
            except asyncio.TimeoutError:
                # Force kill if timeout
                logger.warning(
                    f"Process {running.process_id} did not terminate, killing"
                )
                process.kill()
                await process.wait()

            # Emit event
            await self.bus.emit(
                Events.TOOL_FAILED,
                {
                    "tool": running.tool_name,
                    "process_id": running.process_id,
                    "error": "Cancelled by user",
                    "target": running.target,
                },
            )

            await self.unregister(running.process_id)
            return True

        except Exception as e:
            logger.error(f"Failed to terminate process {running.process_id}: {e}")
            return False

    async def _on_stop_all(self, data: dict) -> None:
        """Handle stop all event from event bus."""
        await self.stop_all()

    def get_running_count(self) -> int:
        """Get the count of running processes."""
        return len(self._processes)

    def get_running_tools(self) -> list[dict]:
        """Get info about all running tools.

        Returns:
            List of dicts with tool info
        """
        return [
            {
                "process_id": p.process_id,
                "tool_name": p.tool_name,
                "target": p.target,
                "started_at": p.started_at.isoformat(),
                "duration": (datetime.now() - p.started_at).total_seconds(),
            }
            for p in self._processes.values()
        ]

    def is_tool_running(self, tool_name: str) -> bool:
        """Check if a specific tool is running.

        Args:
            tool_name: Name of the tool to check

        Returns:
            True if the tool is running
        """
        return any(p.tool_name == tool_name for p in self._processes.values())
