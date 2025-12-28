"""Export manager for session data and reports."""

from datetime import datetime
from pathlib import Path
from dataclasses import dataclass

from voidwave.core.constants import (
    VOIDWAVE_EXPORTS_DIR,
    VOIDWAVE_LOOT_DIR,
    VOIDWAVE_REPORTS_DIR,
    VOIDWAVE_SCANS_DIR,
    VOIDWAVE_WIFI_CAPTURES_DIR,
)
from voidwave.core.logging import get_logger

from .exporters import (
    ExportResult,
    JsonExporter,
    CsvExporter,
    HtmlExporter,
    PdfExporter,
    MarkdownExporter,
)

logger = get_logger(__name__)


@dataclass
class FileNamer:
    """Consistent file naming across the application."""

    @classmethod
    def capture(cls, session_id: int, bssid: str, capture_type: str) -> Path:
        """Generate capture file path."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        safe_bssid = bssid.replace(":", "")
        return VOIDWAVE_WIFI_CAPTURES_DIR / f"{timestamp}_{safe_bssid}.{capture_type}"

    @classmethod
    def scan(cls, session_id: int, tool: str, target: str) -> Path:
        """Generate scan output path."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        safe_target = target.replace("/", "_").replace(":", "_")
        return VOIDWAVE_SCANS_DIR / tool / f"{timestamp}_{safe_target}"

    @classmethod
    def report(cls, session_id: int, format_type: str) -> Path:
        """Generate report path."""
        return VOIDWAVE_REPORTS_DIR / f"session_{session_id:03d}" / f"report.{format_type}"

    @classmethod
    def loot_export(cls, session_id: int) -> Path:
        """Generate loot export path."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        return VOIDWAVE_LOOT_DIR / "exports" / f"export_{session_id}_{timestamp}.json"


class ExportManager:
    """Manages all export operations."""

    EXPORTERS = {
        "json": JsonExporter,
        "csv": CsvExporter,
        "html": HtmlExporter,
        "pdf": PdfExporter,
        "md": MarkdownExporter,
        "markdown": MarkdownExporter,
    }

    def __init__(self, db=None, loot=None):
        """Initialize export manager.

        Args:
            db: Database engine instance (optional)
            loot: Loot storage instance (optional)
        """
        self.db = db
        self.loot = loot

    async def export_session(
        self,
        session_id: int,
        formats: list[str],
        data: dict | None = None
    ) -> list[ExportResult]:
        """Export session in multiple formats.

        Args:
            session_id: The session ID to export
            formats: List of format names (json, csv, html, pdf, md)
            data: Optional pre-gathered data, if not provided will gather from DB

        Returns:
            List of ExportResult objects
        """
        # Gather session data if not provided
        if data is None:
            data = await self._gather_session_data(session_id)

        results = []
        for fmt in formats:
            exporter_class = self.EXPORTERS.get(fmt.lower())
            if exporter_class:
                exporter = exporter_class()
                path = FileNamer.report(session_id, exporter.format_name)

                # CSV needs list format
                if fmt.lower() == "csv":
                    # Flatten for CSV
                    csv_data = self._flatten_for_csv(data)
                    result = await exporter.export(csv_data, path)
                else:
                    result = await exporter.export(data, path)

                results.append(result)

        return results

    async def export_loot(self, session_id: int) -> ExportResult:
        """Export loot items to JSON.

        Args:
            session_id: The session ID

        Returns:
            ExportResult object
        """
        if self.loot:
            loot_items = await self.loot.list_by_session(session_id)
            decrypted = []
            for item in loot_items:
                try:
                    data = await self.loot.retrieve(item["id"])
                    decrypted.append(data)
                except Exception as e:
                    logger.debug(f"Failed to decrypt loot item {item.get('id')}: {e}")
                    decrypted.append(item)
        else:
            decrypted = []

        path = FileNamer.loot_export(session_id)
        exporter = JsonExporter()
        return await exporter.export(decrypted, path)

    async def export_targets(
        self,
        session_id: int,
        format_type: str = "json"
    ) -> ExportResult:
        """Export targets list.

        Args:
            session_id: The session ID
            format_type: Export format

        Returns:
            ExportResult object
        """
        if self.db:
            targets = await self.db.fetch_all(
                "SELECT * FROM targets WHERE session_id = ?", (session_id,)
            )
        else:
            targets = []

        path = VOIDWAVE_EXPORTS_DIR / f"targets_{session_id}.{format_type}"
        exporter_class = self.EXPORTERS.get(format_type, JsonExporter)
        exporter = exporter_class()

        return await exporter.export(targets, path)

    async def export_custom(
        self,
        data: dict | list,
        filename: str,
        format_type: str = "json"
    ) -> ExportResult:
        """Export custom data.

        Args:
            data: Data to export
            filename: Output filename (without extension)
            format_type: Export format

        Returns:
            ExportResult object
        """
        exporter_class = self.EXPORTERS.get(format_type, JsonExporter)
        exporter = exporter_class()
        path = VOIDWAVE_EXPORTS_DIR / f"{filename}.{exporter.format_name}"

        return await exporter.export(data, path)

    async def _gather_session_data(self, session_id: int) -> dict:
        """Gather all session data for reporting.

        Args:
            session_id: The session ID

        Returns:
            Dict containing all session data
        """
        session = {}
        targets = []
        loot = []
        tool_runs = []
        audit = []

        if self.db:
            try:
                session = await self.db.fetch_one(
                    "SELECT * FROM sessions WHERE id = ?", (session_id,)
                ) or {}
            except Exception as e:
                logger.debug(f"Failed to fetch session {session_id}: {e}")
                session = {"id": session_id, "name": f"Session {session_id}"}

            try:
                targets = await self.db.fetch_all(
                    "SELECT * FROM targets WHERE session_id = ?", (session_id,)
                ) or []
            except Exception as e:
                logger.debug(f"Failed to fetch targets for session {session_id}: {e}")

            try:
                tool_runs = await self.db.fetch_all(
                    "SELECT * FROM tool_executions WHERE session_id = ?", (session_id,)
                ) or []
            except Exception as e:
                logger.debug(f"Failed to fetch tool executions for session {session_id}: {e}")

            try:
                audit = await self.db.fetch_all(
                    "SELECT * FROM audit_log WHERE session_id = ? ORDER BY timestamp",
                    (session_id,)
                ) or []
            except Exception as e:
                logger.debug(f"Failed to fetch audit log for session {session_id}: {e}")

        if self.loot:
            try:
                loot = await self.loot.list_by_session(session_id) or []
            except Exception as e:
                logger.debug(f"Failed to fetch loot for session {session_id}: {e}")

        return {
            "session": session,
            "targets": targets,
            "loot": loot,
            "tool_executions": tool_runs,
            "audit_log": audit,
            "generated_at": datetime.now().isoformat(),
        }

    def _flatten_for_csv(self, data: dict) -> list[dict]:
        """Flatten hierarchical data for CSV export.

        Args:
            data: Hierarchical session data

        Returns:
            List of flat dicts suitable for CSV
        """
        rows = []

        # Flatten targets
        for target in data.get("targets", []):
            row = {
                "record_type": "target",
                "session_id": data.get("session", {}).get("id", ""),
            }
            row.update(target if isinstance(target, dict) else {"value": target})
            rows.append(row)

        # Flatten findings
        for item in data.get("loot", []):
            row = {
                "record_type": "finding",
                "session_id": data.get("session", {}).get("id", ""),
            }
            row.update(item if isinstance(item, dict) else {"value": item})
            rows.append(row)

        # Flatten tool runs
        for run in data.get("tool_executions", []):
            row = {
                "record_type": "tool_execution",
                "session_id": data.get("session", {}).get("id", ""),
            }
            row.update(run if isinstance(run, dict) else {"value": run})
            rows.append(row)

        return rows

    @staticmethod
    def get_supported_formats() -> list[str]:
        """Get list of supported export formats."""
        return list(ExportManager.EXPORTERS.keys())
