"""Session manager for VOIDWAVE."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from voidwave.core.logging import get_logger
from voidwave.db.engine import get_db
from voidwave.orchestration.events import Events, event_bus
from voidwave.sessions.models import (
    Session,
    SessionConfig,
    SessionMetadata,
    SessionStatus,
    SessionSummary,
)

logger = get_logger(__name__)


class SessionManager:
    """Manages session lifecycle and persistence."""

    def __init__(self) -> None:
        self._current_session: Session | None = None

    @property
    def current(self) -> Session | None:
        """Get current active session."""
        return self._current_session

    async def create(
        self,
        name: str,
        config: SessionConfig | None = None,
        metadata: SessionMetadata | None = None,
    ) -> Session:
        """Create a new session."""
        session_id = f"sess_{uuid.uuid4().hex[:12]}"

        session = Session(
            id=session_id,
            name=name,
            status=SessionStatus.ACTIVE,
            config=config or SessionConfig(),
            metadata=metadata or SessionMetadata(),
        )

        db = await get_db()
        db_dict = session.to_db_dict()

        await db.execute(
            """
            INSERT INTO sessions (id, name, status, workflow_state, config, metadata)
            VALUES (:id, :name, :status, :workflow_state, :config, :metadata)
            """,
            db_dict,
        )

        self._current_session = session

        event_bus.emit(Events.SESSION_STARTED, {
            "session_id": session_id,
            "name": name,
        })

        logger.info(f"Created session: {name} ({session_id})")
        return session

    async def get(self, session_id: str) -> Session | None:
        """Get session by ID."""
        db = await get_db()
        row = await db.fetch_one(
            "SELECT * FROM sessions WHERE id = ?",
            (session_id,),
        )

        if not row:
            return None

        session = Session.from_db_row(row)
        session.summary = await self._get_summary(session_id)
        return session

    async def list(
        self,
        status: SessionStatus | None = None,
        limit: int = 20,
    ) -> list[Session]:
        """List sessions, optionally filtered by status."""
        db = await get_db()

        if status:
            rows = await db.fetch_all(
                """
                SELECT * FROM sessions
                WHERE status = ?
                ORDER BY updated_at DESC
                LIMIT ?
                """,
                (status.value, limit),
            )
        else:
            rows = await db.fetch_all(
                """
                SELECT * FROM sessions
                ORDER BY updated_at DESC
                LIMIT ?
                """,
                (limit,),
            )

        sessions = []
        for row in rows:
            session = Session.from_db_row(row)
            session.summary = await self._get_summary(session.id)
            sessions.append(session)

        return sessions

    async def update(
        self,
        session_id: str,
        name: str | None = None,
        status: SessionStatus | None = None,
        workflow_state: str | None = None,
        config: SessionConfig | None = None,
        metadata: SessionMetadata | None = None,
    ) -> Session | None:
        """Update session fields."""
        session = await self.get(session_id)
        if not session:
            return None

        if name is not None:
            session.name = name
        if status is not None:
            session.status = status
            if status in (SessionStatus.COMPLETED, SessionStatus.FAILED):
                session.ended_at = datetime.now()
        if workflow_state is not None:
            session.workflow_state = workflow_state
        if config is not None:
            session.config = config
        if metadata is not None:
            session.metadata = metadata

        session.updated_at = datetime.now()

        db = await get_db()
        db_dict = session.to_db_dict()

        await db.execute(
            """
            UPDATE sessions
            SET name = :name, status = :status, workflow_state = :workflow_state,
                config = :config, metadata = :metadata, updated_at = :updated_at,
                ended_at = :ended_at
            WHERE id = :id
            """,
            db_dict,
        )

        if self._current_session and self._current_session.id == session_id:
            self._current_session = session

        event_bus.emit(Events.SESSION_UPDATED, {
            "session_id": session_id,
            "status": session.status,
        })

        return session

    async def pause(self, session_id: str) -> Session | None:
        """Pause a session."""
        return await self.update(session_id, status=SessionStatus.PAUSED)

    async def resume(self, session_id: str) -> Session | None:
        """Resume a paused session."""
        session = await self.update(session_id, status=SessionStatus.ACTIVE)
        if session:
            self._current_session = session
        return session

    async def complete(self, session_id: str) -> Session | None:
        """Mark session as completed."""
        session = await self.update(session_id, status=SessionStatus.COMPLETED)
        if self._current_session and self._current_session.id == session_id:
            self._current_session = None
        return session

    async def fail(self, session_id: str) -> Session | None:
        """Mark session as failed."""
        session = await self.update(session_id, status=SessionStatus.FAILED)
        if self._current_session and self._current_session.id == session_id:
            self._current_session = None
        return session

    async def delete(self, session_id: str) -> bool:
        """Delete a session and all related data."""
        db = await get_db()

        # Cascade delete handled by foreign keys
        cursor = await db.execute(
            "DELETE FROM sessions WHERE id = ?",
            (session_id,),
        )

        if self._current_session and self._current_session.id == session_id:
            self._current_session = None

        deleted = cursor.rowcount > 0
        if deleted:
            logger.info(f"Deleted session: {session_id}")

        return deleted

    async def add_target(
        self,
        session_id: str,
        target_type: str,
        value: str,
        metadata: dict[str, Any] | None = None,
    ) -> int | None:
        """Add a target to a session."""
        import json

        db = await get_db()

        try:
            cursor = await db.execute(
                """
                INSERT INTO targets (session_id, target_type, value, metadata)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(session_id, target_type, value) DO UPDATE SET
                    last_scanned = CURRENT_TIMESTAMP
                """,
                (session_id, target_type, value, json.dumps(metadata or {})),
            )
            return cursor.lastrowid
        except Exception as e:
            logger.warning(f"Failed to add target: {e}")
            return None

    async def log_tool_execution(
        self,
        session_id: str,
        tool_name: str,
        command: str,
        status: str = "running",
        exit_code: int | None = None,
        summary: str | None = None,
        output_file: str | None = None,
    ) -> int | None:
        """Log a tool execution."""
        db = await get_db()

        try:
            cursor = await db.execute(
                """
                INSERT INTO tool_executions
                (session_id, tool_name, command, status, exit_code, summary, output_file)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (session_id, tool_name, command, status, exit_code, summary, output_file),
            )
            return cursor.lastrowid
        except Exception as e:
            logger.warning(f"Failed to log tool execution: {e}")
            return None

    async def update_tool_execution(
        self,
        execution_id: int,
        status: str,
        exit_code: int | None = None,
        summary: str | None = None,
    ) -> None:
        """Update a tool execution record."""
        db = await get_db()

        await db.execute(
            """
            UPDATE tool_executions
            SET status = ?, exit_code = ?, summary = ?, ended_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (status, exit_code, summary, execution_id),
        )

    async def _get_summary(self, session_id: str) -> SessionSummary:
        """Get summary statistics for a session."""
        db = await get_db()

        # Target count
        target_row = await db.fetch_one(
            "SELECT COUNT(*) as count FROM targets WHERE session_id = ?",
            (session_id,),
        )

        # Tool executions
        exec_row = await db.fetch_one(
            "SELECT COUNT(*) as count FROM tool_executions WHERE session_id = ?",
            (session_id,),
        )

        # Loot count
        loot_row = await db.fetch_one(
            "SELECT COUNT(*) as count FROM loot WHERE session_id = ?",
            (session_id,),
        )

        # Credentials specifically
        cred_row = await db.fetch_one(
            "SELECT COUNT(*) as count FROM loot WHERE session_id = ? AND loot_type = 'credential'",
            (session_id,),
        )

        return SessionSummary(
            target_count=target_row["count"] if target_row else 0,
            tool_executions=exec_row["count"] if exec_row else 0,
            loot_count=loot_row["count"] if loot_row else 0,
            credentials_found=cred_row["count"] if cred_row else 0,
        )

    async def get_recent(self, limit: int = 5) -> list[Session]:
        """Get most recent sessions."""
        return await self.list(limit=limit)

    async def get_active(self) -> list[Session]:
        """Get all active sessions."""
        return await self.list(status=SessionStatus.ACTIVE)

    def set_current(self, session: Session) -> None:
        """Set the current active session."""
        self._current_session = session

    def clear_current(self) -> None:
        """Clear the current session."""
        self._current_session = None


# Singleton instance
_session_manager: SessionManager | None = None


def get_session_manager() -> SessionManager:
    """Get session manager instance."""
    global _session_manager
    if _session_manager is None:
        _session_manager = SessionManager()
    return _session_manager
