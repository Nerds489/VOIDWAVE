"""Concurrency control with category-based limits."""
import asyncio
from collections import defaultdict
from typing import Any

from voidwave.core.constants import CONCURRENCY_LIMITS
from voidwave.core.logging import get_logger

logger = get_logger(__name__)


class CategorySemaphore:
    """Semaphore with per-category limits."""

    def __init__(self) -> None:
        self._semaphores: dict[str, asyncio.Semaphore] = {}
        self._active: dict[str, int] = defaultdict(int)

    def _get_semaphore(self, category: str) -> asyncio.Semaphore:
        """Get or create semaphore for category."""
        if category not in self._semaphores:
            limit = CONCURRENCY_LIMITS.get(category, CONCURRENCY_LIMITS["default"])
            self._semaphores[category] = asyncio.Semaphore(limit)
        return self._semaphores[category]

    async def acquire(self, category: str) -> None:
        """Acquire semaphore for category."""
        sem = self._get_semaphore(category)
        await sem.acquire()
        self._active[category] += 1
        logger.debug(f"Acquired {category} semaphore ({self._active[category]} active)")

    def release(self, category: str) -> None:
        """Release semaphore for category."""
        if category in self._semaphores:
            self._semaphores[category].release()
            self._active[category] -= 1
            logger.debug(
                f"Released {category} semaphore ({self._active[category]} active)"
            )

    def get_active_count(self, category: str) -> int:
        """Get number of active tasks in category."""
        return self._active.get(category, 0)

    def get_all_active(self) -> dict[str, int]:
        """Get all active counts."""
        return dict(self._active)


class ToolOrchestrator:
    """Orchestrates tool execution with concurrency control."""

    def __init__(self) -> None:
        self._semaphores = CategorySemaphore()
        self._running_tasks: dict[str, asyncio.Task] = {}

    async def execute(
        self,
        tool_name: str,
        category: str,
        coro: Any,
    ) -> Any:
        """Execute a tool with concurrency control."""
        task_id = f"{tool_name}_{id(coro)}"

        await self._semaphores.acquire(category)
        try:
            task = asyncio.create_task(coro)
            self._running_tasks[task_id] = task
            return await task
        finally:
            self._semaphores.release(category)
            if task_id in self._running_tasks:
                del self._running_tasks[task_id]

    async def execute_batch(
        self,
        tasks: list[tuple[str, str, Any]],  # (tool_name, category, coro)
    ) -> list[Any]:
        """Execute multiple tools concurrently."""
        async with asyncio.TaskGroup() as tg:
            futures = [
                tg.create_task(self.execute(name, cat, coro))
                for name, cat, coro in tasks
            ]
        return [f.result() for f in futures]

    async def cancel_all(self) -> None:
        """Cancel all running tasks."""
        for task in self._running_tasks.values():
            task.cancel()

        if self._running_tasks:
            await asyncio.gather(*self._running_tasks.values(), return_exceptions=True)

        self._running_tasks.clear()


# Singleton orchestrator
tool_orchestrator = ToolOrchestrator()
