"""Encrypted storage for captured credentials and sensitive data."""
import json
from datetime import datetime
from pathlib import Path
from typing import Any

from cryptography.fernet import Fernet

from voidwave.core.constants import VOIDWAVE_DATA_DIR
from voidwave.core.logging import get_logger
from voidwave.db.engine import get_db

logger = get_logger(__name__)


class LootStorage:
    """Encrypted storage for captured loot."""

    def __init__(self, key_path: Path | None = None) -> None:
        self.key_path = key_path or (VOIDWAVE_DATA_DIR / "loot.key")
        self._cipher: Fernet | None = None

    async def initialize(self) -> None:
        """Initialize encryption key."""
        self.key_path.parent.mkdir(parents=True, exist_ok=True)

        if self.key_path.exists():
            key = self.key_path.read_bytes()
        else:
            key = Fernet.generate_key()
            self.key_path.write_bytes(key)
            self.key_path.chmod(0o600)  # Owner read/write only
            logger.info("Generated new loot encryption key")

        self._cipher = Fernet(key)

    def encrypt(self, data: dict[str, Any]) -> str:
        """Encrypt data to string."""
        if self._cipher is None:
            raise RuntimeError("LootStorage not initialized")

        json_data = json.dumps(data)
        encrypted = self._cipher.encrypt(json_data.encode())
        return encrypted.decode()

    def decrypt(self, encrypted: str) -> dict[str, Any]:
        """Decrypt string to data."""
        if self._cipher is None:
            raise RuntimeError("LootStorage not initialized")

        decrypted = self._cipher.decrypt(encrypted.encode())
        return json.loads(decrypted.decode())

    async def store(
        self,
        loot_type: str,
        data: dict[str, Any],
        session_id: str | None = None,
        target_id: int | None = None,
        source_tool: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> int:
        """Store encrypted loot in database."""
        if self._cipher is None:
            await self.initialize()

        encrypted_data = self.encrypt(data)

        db = await get_db()
        cursor = await db.execute(
            """
            INSERT INTO loot (
                session_id, target_id, loot_type, encrypted_data,
                source_tool, metadata
            ) VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                session_id,
                target_id,
                loot_type,
                encrypted_data,
                source_tool,
                json.dumps(metadata) if metadata else None,
            ),
        )

        loot_id = cursor.lastrowid
        logger.info(f"Stored loot #{loot_id}: {loot_type}")
        return loot_id

    async def retrieve(self, loot_id: int) -> dict[str, Any] | None:
        """Retrieve and decrypt loot by ID."""
        if self._cipher is None:
            await self.initialize()

        db = await get_db()
        row = await db.fetch_one("SELECT * FROM loot WHERE id = ?", (loot_id,))

        if row is None:
            return None

        decrypted = self.decrypt(row["encrypted_data"])
        return {
            "id": row["id"],
            "loot_type": row["loot_type"],
            "data": decrypted,
            "discovered_at": row["discovered_at"],
            "source_tool": row["source_tool"],
            "metadata": json.loads(row["metadata"]) if row["metadata"] else None,
        }

    async def list_by_session(self, session_id: str) -> list[dict]:
        """List all loot for a session (without decrypting)."""
        db = await get_db()
        rows = await db.fetch_all(
            "SELECT id, loot_type, discovered_at, source_tool, metadata FROM loot WHERE session_id = ?",
            (session_id,),
        )

        return [
            {
                "id": row["id"],
                "loot_type": row["loot_type"],
                "discovered_at": row["discovered_at"],
                "source_tool": row["source_tool"],
                "metadata": json.loads(row["metadata"]) if row["metadata"] else None,
            }
            for row in rows
        ]

    async def list_by_type(self, loot_type: str) -> list[dict]:
        """List all loot of a specific type."""
        db = await get_db()
        rows = await db.fetch_all(
            "SELECT id, loot_type, discovered_at, source_tool, metadata FROM loot WHERE loot_type = ?",
            (loot_type,),
        )

        return [dict(row) for row in rows]

    async def export_decrypted(self, loot_ids: list[int]) -> list[dict]:
        """Export multiple loot items decrypted."""
        results = []
        for loot_id in loot_ids:
            item = await self.retrieve(loot_id)
            if item:
                results.append(item)
        return results

    async def delete(self, loot_id: int) -> bool:
        """Delete a loot entry."""
        db = await get_db()
        cursor = await db.execute("DELETE FROM loot WHERE id = ?", (loot_id,))
        return cursor.rowcount > 0


# Singleton instance
loot_storage = LootStorage()
