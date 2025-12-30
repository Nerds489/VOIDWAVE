"""Session data models."""

from datetime import datetime
from enum import Enum
from typing import Any

from pydantic import BaseModel, Field


class SessionStatus(str, Enum):
    """Session status enumeration."""

    ACTIVE = "active"
    PAUSED = "paused"
    COMPLETED = "completed"
    FAILED = "failed"


class SessionConfig(BaseModel):
    """Session configuration stored as JSON."""

    target: str | None = None
    interface: str | None = None
    wordlist: str | None = None
    scan_type: str | None = None
    options: dict[str, Any] = Field(default_factory=dict)


class SessionMetadata(BaseModel):
    """Session metadata stored as JSON."""

    description: str = ""
    tags: list[str] = Field(default_factory=list)
    notes: str = ""


class SessionSummary(BaseModel):
    """Summary statistics for a session."""

    target_count: int = 0
    tool_executions: int = 0
    loot_count: int = 0
    hosts_discovered: int = 0
    services_discovered: int = 0
    credentials_found: int = 0


class Session(BaseModel):
    """Session model representing a security testing session."""

    id: str
    name: str
    status: SessionStatus = SessionStatus.ACTIVE
    workflow_state: str | None = None
    config: SessionConfig = Field(default_factory=SessionConfig)
    metadata: SessionMetadata = Field(default_factory=SessionMetadata)
    created_at: datetime = Field(default_factory=datetime.now)
    updated_at: datetime = Field(default_factory=datetime.now)
    ended_at: datetime | None = None
    summary: SessionSummary = Field(default_factory=SessionSummary)

    class Config:
        use_enum_values = True

    @classmethod
    def from_db_row(cls, row: dict[str, Any]) -> "Session":
        """Create Session from database row."""
        import json

        config_data = json.loads(row.get("config") or "{}")
        metadata_data = json.loads(row.get("metadata") or "{}")

        return cls(
            id=row["id"],
            name=row["name"],
            status=SessionStatus(row.get("status", "active")),
            workflow_state=row.get("workflow_state"),
            config=SessionConfig(**config_data),
            metadata=SessionMetadata(**metadata_data),
            created_at=datetime.fromisoformat(row["created_at"]) if row.get("created_at") else datetime.now(),
            updated_at=datetime.fromisoformat(row["updated_at"]) if row.get("updated_at") else datetime.now(),
            ended_at=datetime.fromisoformat(row["ended_at"]) if row.get("ended_at") else None,
        )

    def to_db_dict(self) -> dict[str, Any]:
        """Convert to dictionary for database storage."""
        import json

        return {
            "id": self.id,
            "name": self.name,
            "status": self.status.value if isinstance(self.status, SessionStatus) else self.status,
            "workflow_state": self.workflow_state,
            "config": json.dumps(self.config.model_dump()),
            "metadata": json.dumps(self.metadata.model_dump()),
            "updated_at": self.updated_at.isoformat(),
            "ended_at": self.ended_at.isoformat() if self.ended_at else None,
        }

    @property
    def duration(self) -> str:
        """Get human-readable session duration."""
        end = self.ended_at or datetime.now()
        delta = end - self.created_at

        hours, remainder = divmod(int(delta.total_seconds()), 3600)
        minutes, seconds = divmod(remainder, 60)

        if hours > 0:
            return f"{hours}h {minutes}m"
        elif minutes > 0:
            return f"{minutes}m {seconds}s"
        else:
            return f"{seconds}s"

    @property
    def is_active(self) -> bool:
        """Check if session is active."""
        return self.status == SessionStatus.ACTIVE
