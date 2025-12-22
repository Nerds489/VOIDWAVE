"""State machine-based attack workflows."""
import asyncio
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any, Callable

from transitions.extensions.asyncio import AsyncMachine

from voidwave.core.logging import get_logger
from voidwave.orchestration.events import Events, event_bus

logger = get_logger(__name__)


class WorkflowState(str, Enum):
    """Standard workflow states."""

    IDLE = "idle"
    INITIALIZING = "initializing"
    RECONNAISSANCE = "reconnaissance"
    SCANNING = "scanning"
    EXPLOITATION = "exploitation"
    POST_EXPLOITATION = "post_exploitation"
    REPORTING = "reporting"
    COMPLETED = "completed"
    FAILED = "failed"
    PAUSED = "paused"


@dataclass
class WorkflowContext:
    """Context shared across workflow phases."""

    target: str
    options: dict[str, Any] = field(default_factory=dict)
    results: dict[str, Any] = field(default_factory=dict)
    artifacts: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
    started_at: datetime | None = None
    ended_at: datetime | None = None
    current_phase: str = "idle"
    metadata: dict[str, Any] = field(default_factory=dict)


class BaseWorkflow:
    """Base class for attack workflows with state machine."""

    # Subclasses define their states and transitions
    STATES: list[str] = [s.value for s in WorkflowState]
    INITIAL_STATE: str = WorkflowState.IDLE.value

    def __init__(self, target: str, options: dict[str, Any] | None = None) -> None:
        self.context = WorkflowContext(target=target, options=options or {})
        self._setup_machine()

    def _setup_machine(self) -> None:
        """Initialize the state machine."""
        self.machine = AsyncMachine(
            model=self,
            states=self.STATES,
            initial=self.INITIAL_STATE,
            auto_transitions=False,
            send_event=True,
        )

        # Standard transitions
        self.machine.add_transition(
            "start", WorkflowState.IDLE, WorkflowState.INITIALIZING
        )
        self.machine.add_transition(
            "initialize_complete",
            WorkflowState.INITIALIZING,
            WorkflowState.RECONNAISSANCE,
        )
        self.machine.add_transition(
            "recon_complete", WorkflowState.RECONNAISSANCE, WorkflowState.SCANNING
        )
        self.machine.add_transition(
            "scan_complete",
            WorkflowState.SCANNING,
            WorkflowState.EXPLOITATION,
            conditions=["has_targets"],
        )
        self.machine.add_transition(
            "exploit_complete",
            WorkflowState.EXPLOITATION,
            WorkflowState.POST_EXPLOITATION,
        )
        self.machine.add_transition(
            "post_complete", WorkflowState.POST_EXPLOITATION, WorkflowState.REPORTING
        )
        self.machine.add_transition(
            "report_complete", WorkflowState.REPORTING, WorkflowState.COMPLETED
        )

        # Failure and pause transitions from any state
        self.machine.add_transition("fail", "*", WorkflowState.FAILED)
        self.machine.add_transition("pause", "*", WorkflowState.PAUSED)
        self.machine.add_transition("resume", WorkflowState.PAUSED, WorkflowState.IDLE)

    # Conditions
    def has_targets(self, event_data: Any = None) -> bool:
        """Check if we have targets to exploit."""
        return len(self.context.results.get("targets", [])) > 0

    # State entry callbacks (to be overridden)
    async def on_enter_initializing(self, event_data: Any = None) -> None:
        """Initialize workflow."""
        self.context.started_at = datetime.now()
        self.context.current_phase = "initializing"
        await event_bus.emit(
            Events.TASK_STARTED,
            {
                "task_id": id(self),
                "name": f"{self.__class__.__name__}",
                "target": self.context.target,
            },
        )

    async def on_enter_completed(self, event_data: Any = None) -> None:
        """Workflow completed."""
        self.context.ended_at = datetime.now()
        self.context.current_phase = "completed"
        await event_bus.emit(
            Events.TASK_COMPLETED,
            {
                "task_id": id(self),
                "results": self.context.results,
            },
        )

    async def on_enter_failed(self, event_data: Any = None) -> None:
        """Workflow failed."""
        self.context.ended_at = datetime.now()
        self.context.current_phase = "failed"
        logger.error(f"Workflow failed: {self.context.errors}")

    async def run(self) -> WorkflowContext:
        """Execute the workflow."""
        try:
            await self.start()
            await self._run_phases()
        except Exception as e:
            self.context.errors.append(str(e))
            await self.fail()

        return self.context

    async def _run_phases(self) -> None:
        """Run through workflow phases. Override in subclasses."""
        raise NotImplementedError
