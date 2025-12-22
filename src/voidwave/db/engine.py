"""Async SQLite database engine."""
import asyncio
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any, AsyncIterator

import aiosqlite

from voidwave.core.constants import DB_PATH
from voidwave.core.logging import get_logger

logger = get_logger(__name__)


class DatabaseEngine:
    """Async SQLite database engine with connection pooling."""

    def __init__(self, db_path: Path = DB_PATH):
        self.db_path = db_path
        self._connection: aiosqlite.Connection | None = None
        self._lock = asyncio.Lock()

    async def initialize(self) -> None:
        """Initialize database and run migrations."""
        self.db_path.parent.mkdir(parents=True, exist_ok=True)

        async with self.connection() as db:
            # Enable WAL mode
            await db.execute("PRAGMA journal_mode=WAL")
            await db.execute("PRAGMA synchronous=NORMAL")
            await db.execute("PRAGMA foreign_keys=ON")

            # Create schema
            schema_path = Path(__file__).parent / "schema.sql"
            if schema_path.exists():
                schema_sql = schema_path.read_text()
                await db.executescript(schema_sql)

            await db.commit()
            logger.info(f"Database initialized at {self.db_path}")

    @asynccontextmanager
    async def connection(self) -> AsyncIterator[aiosqlite.Connection]:
        """Get database connection."""
        async with self._lock:
            if self._connection is None:
                self._connection = await aiosqlite.connect(
                    self.db_path,
                    timeout=30.0,
                )
                self._connection.row_factory = aiosqlite.Row

            yield self._connection

    async def execute(
        self, query: str, params: tuple[Any, ...] | dict[str, Any] = ()
    ) -> aiosqlite.Cursor:
        """Execute a query."""
        async with self.connection() as db:
            cursor = await db.execute(query, params)
            await db.commit()
            return cursor

    async def fetch_one(
        self, query: str, params: tuple[Any, ...] | dict[str, Any] = ()
    ) -> dict[str, Any] | None:
        """Fetch single row as dict."""
        async with self.connection() as db:
            cursor = await db.execute(query, params)
            row = await cursor.fetchone()
            return dict(row) if row else None

    async def fetch_all(
        self, query: str, params: tuple[Any, ...] | dict[str, Any] = ()
    ) -> list[dict[str, Any]]:
        """Fetch all rows as list of dicts."""
        async with self.connection() as db:
            cursor = await db.execute(query, params)
            rows = await cursor.fetchall()
            return [dict(row) for row in rows]

    async def close(self) -> None:
        """Close database connection."""
        if self._connection:
            await self._connection.close()
            self._connection = None


# Singleton instance
_db_engine: DatabaseEngine | None = None


async def get_db() -> DatabaseEngine:
    """Get database engine instance."""
    global _db_engine
    if _db_engine is None:
        _db_engine = DatabaseEngine()
        await _db_engine.initialize()
    return _db_engine
