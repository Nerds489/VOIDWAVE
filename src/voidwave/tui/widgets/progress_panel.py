"""Multi-task progress tracking panel."""
from dataclasses import dataclass
from typing import ClassVar

from textual.widgets import Static


@dataclass
class TaskProgress:
    """Progress tracking for a single task."""

    task_id: str
    name: str
    total: int = 100
    completed: int = 0
    status: str = "running"
    description: str = ""


class ProgressPanel(Static):
    """Panel showing progress of multiple concurrent tasks."""

    DEFAULT_CSS: ClassVar[str] = """
    ProgressPanel {
        height: auto;
        min-height: 5;
        border: solid $border-dim;
        background: $surface;
        padding: 1;
    }
    """

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        self._tasks: dict[str, TaskProgress] = {}

    async def on_mount(self) -> None:
        """Subscribe to progress events."""
        # Event bus subscription will be added when orchestration is ready
        # event_bus.on(Events.TASK_STARTED, self._on_task_started)
        # event_bus.on(Events.TASK_PROGRESS, self._on_task_progress)
        # event_bus.on(Events.TASK_COMPLETED, self._on_task_completed)
        self._refresh_display()

    async def _on_task_started(self, data: dict) -> None:
        """Handle task start."""
        task_id = data.get("task_id", "")
        name = data.get("name", "Unknown")
        total = data.get("total", 100)

        self._tasks[task_id] = TaskProgress(
            task_id=task_id,
            name=name,
            total=total,
        )
        self._refresh_display()

    async def _on_task_progress(self, data: dict) -> None:
        """Handle progress update."""
        task_id = data.get("task_id", "")
        if task_id in self._tasks:
            self._tasks[task_id].completed = data.get("completed", 0)
            self._tasks[task_id].description = data.get("description", "")
            self._refresh_display()

    async def _on_task_completed(self, data: dict) -> None:
        """Handle task completion."""
        task_id = data.get("task_id", "")
        if task_id in self._tasks:
            self._tasks[task_id].status = "completed"
            self._tasks[task_id].completed = self._tasks[task_id].total
            self._refresh_display()

            # Remove after delay
            self.set_timer(5.0, lambda: self._remove_task(task_id))

    def _remove_task(self, task_id: str) -> None:
        """Remove completed task from display."""
        if task_id in self._tasks:
            del self._tasks[task_id]
            self._refresh_display()

    def _refresh_display(self) -> None:
        """Refresh the progress display."""
        if not self._tasks:
            self.update("[dim]No active tasks[/]")
            return

        lines = []
        for task in self._tasks.values():
            percent = (task.completed / task.total * 100) if task.total > 0 else 0
            bar_width = 20
            filled = int(bar_width * percent / 100)
            bar = "█" * filled + "░" * (bar_width - filled)

            status_color = "cyan" if task.status == "running" else "#00FF41"
            line = f"[bold]{task.name}[/] [{status_color}]{bar}[/] {percent:.0f}%"
            if task.description:
                line += f" [dim]{task.description}[/]"
            lines.append(line)

        self.update("\n".join(lines))

    def add_task(self, task_id: str, name: str, total: int = 100) -> None:
        """Manually add a task."""
        self._tasks[task_id] = TaskProgress(
            task_id=task_id,
            name=name,
            total=total,
        )
        self._refresh_display()

    def update_task(self, task_id: str, completed: int, description: str = "") -> None:
        """Manually update task progress."""
        if task_id in self._tasks:
            self._tasks[task_id].completed = completed
            self._tasks[task_id].description = description
            self._refresh_display()

    def complete_task(self, task_id: str) -> None:
        """Mark a task as completed."""
        if task_id in self._tasks:
            self._tasks[task_id].status = "completed"
            self._tasks[task_id].completed = self._tasks[task_id].total
            self._refresh_display()
            self.set_timer(5.0, lambda: self._remove_task(task_id))
