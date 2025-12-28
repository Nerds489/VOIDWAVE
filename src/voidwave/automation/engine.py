"""Core automation engine types and dataclasses."""

from dataclasses import dataclass, field
from enum import Enum
from typing import Callable, Any


class RequirementType(Enum):
    """Types of requirements for actions."""

    TOOL = "tool"  # Binary must exist
    PRIVILEGE = "privilege"  # Root, caps, group
    INTERFACE = "interface"  # Network interface
    DATA = "data"  # Wordlist, template, etc.
    INPUT = "input"  # Target, client, capture
    API_KEY = "api_key"  # External service key
    HARDWARE = "hardware"  # GPU, wireless adapter


class RequirementStatus(Enum):
    """Status of a requirement check."""

    MET = "met"  # Requirement satisfied
    MISSING = "missing"  # Not satisfied, no fix available
    FIXABLE = "fixable"  # Can be auto-fixed
    MANUAL = "manual"  # Requires manual action


@dataclass
class Requirement:
    """A single requirement for an action."""

    type: RequirementType
    name: str
    description: str
    check: Callable[[], bool]
    fix: Callable[[], bool] | None = None
    alternatives: list[str] = field(default_factory=list)
    auto_label: str = ""

    def check_status(self) -> RequirementStatus:
        """Check the status of this requirement."""
        try:
            if self.check():
                return RequirementStatus.MET
        except Exception:
            pass

        if self.fix:
            return RequirementStatus.FIXABLE
        return RequirementStatus.MANUAL


@dataclass
class PreflightResult:
    """Result of a preflight check."""

    action: str
    requirements: list[Requirement]
    all_met: bool
    missing: list[Requirement] = field(default_factory=list)
    fixable: list[Requirement] = field(default_factory=list)
    manual: list[Requirement] = field(default_factory=list)

    @property
    def can_proceed(self) -> bool:
        """Check if we can proceed with the action."""
        return self.all_met or (len(self.missing) == 0 and len(self.manual) == 0)

    @property
    def needs_user_action(self) -> bool:
        """Check if user action is required."""
        return len(self.manual) > 0

    @property
    def can_auto_fix(self) -> bool:
        """Check if all issues can be auto-fixed."""
        return len(self.fixable) > 0 and len(self.manual) == 0

    def summary(self) -> str:
        """Get a human-readable summary."""
        if self.all_met:
            return f"All requirements met for {self.action}"

        parts = []
        if self.fixable:
            parts.append(f"{len(self.fixable)} fixable")
        if self.manual:
            parts.append(f"{len(self.manual)} manual")
        if self.missing:
            parts.append(f"{len(self.missing)} missing")

        return f"{self.action}: {', '.join(parts)}"
