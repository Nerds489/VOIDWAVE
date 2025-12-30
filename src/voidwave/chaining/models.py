"""Tool chaining data models."""

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any, Callable


class OnErrorBehavior(str, Enum):
    """Behavior when a step fails."""

    STOP = "stop"
    SKIP = "skip"
    RETRY = "retry"
    FALLBACK = "fallback"


class StepStatus(str, Enum):
    """Status of a chain step."""

    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    SKIPPED = "skipped"
    FAILED = "failed"


@dataclass
class DataBinding:
    """Maps output from one step to input of another.

    Example:
        DataBinding(
            source_step="fast_scan",
            source_path="hosts[*].ip",
            target_option="target",
            transform=lambda ips: ",".join(ips),
        )
    """

    source_step: str
    source_path: str
    target_option: str
    transform: Callable[[Any], Any] | None = None
    required: bool = True
    default: Any = None


@dataclass
class Condition:
    """Conditional execution of a step.

    Checks:
        - exists: value is not None
        - count_gt: len(value) > comparison_value
        - count_lt: len(value) < comparison_value
        - value_eq: value == comparison_value
        - value_ne: value != comparison_value
        - has_key: comparison_value in value (dict)
        - contains: comparison_value in value (list/str)
    """

    source_step: str
    check: str
    path: str
    value: Any = None
    negate: bool = False


@dataclass
class ChainStep:
    """A single step in a tool chain."""

    id: str
    tool: str
    description: str = ""

    # Target configuration
    target_binding: DataBinding | None = None
    target_static: str | None = None

    # Options
    options: dict[str, Any] = field(default_factory=dict)
    option_bindings: list[DataBinding] = field(default_factory=list)

    # Execution control
    condition: Condition | None = None
    on_error: OnErrorBehavior = OnErrorBehavior.STOP
    retry_count: int = 3
    retry_delay: float = 1.0
    timeout: int | None = None
    fallback_tool: str | None = None

    # Dependencies and parallelization
    depends_on: list[str] = field(default_factory=list)
    parallel_with: list[str] = field(default_factory=list)

    # Output processing
    output_key: str | None = None  # Key to store output under (defaults to step id)


@dataclass
class ChainDefinition:
    """Complete chain definition."""

    id: str
    name: str
    description: str
    steps: list[ChainStep]

    # Chain-level config
    target_type: str = "ip"
    preflight_action: str | None = None

    # Metadata
    tags: list[str] = field(default_factory=list)
    version: str = "1.0"


@dataclass
class StepResult:
    """Result of executing a single step."""

    step_id: str
    tool: str
    status: StepStatus
    data: dict[str, Any] = field(default_factory=dict)
    errors: list[str] = field(default_factory=list)
    duration: float = 0.0
    retries: int = 0
    started_at: datetime | None = None
    ended_at: datetime | None = None


@dataclass
class ChainResult:
    """Result of executing an entire chain."""

    chain_id: str
    success: bool
    steps: dict[str, StepResult] = field(default_factory=dict)
    final_output: dict[str, Any] = field(default_factory=dict)
    total_duration: float = 0.0
    errors: list[str] = field(default_factory=list)
    started_at: datetime | None = None
    ended_at: datetime | None = None
