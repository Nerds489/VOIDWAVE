"""Tests for export functionality."""

import json
from pathlib import Path

import pytest


class TestFileNamer:
    """Test FileNamer path generation."""

    def test_capture_path_format(self):
        """Capture paths should have correct format."""
        from voidwave.export.manager import FileNamer

        path = FileNamer.capture(1, "AA:BB:CC:DD:EE:FF", "cap")

        assert path.suffix == ".cap"
        assert "AABBCCDDEEFF" in path.name
        assert "wifi" in str(path) or "captures" in str(path)

    def test_capture_sanitizes_bssid(self):
        """BSSID colons should be removed from filename."""
        from voidwave.export.manager import FileNamer

        path = FileNamer.capture(1, "AA:BB:CC:DD:EE:FF", "pcap")

        assert ":" not in path.name

    def test_scan_path_format(self):
        """Scan paths should include tool name."""
        from voidwave.export.manager import FileNamer

        path = FileNamer.scan(1, "nmap", "192.168.1.1")

        assert "nmap" in str(path)
        assert "192.168.1.1" in path.name

    def test_report_path_format(self):
        """Report paths should have session and format."""
        from voidwave.export.manager import FileNamer

        path = FileNamer.report(1, "html")

        assert path.suffix == ".html"
        assert "session_001" in str(path)


class TestJsonExporter:
    """Test JSON exporter."""

    @pytest.mark.asyncio
    async def test_export_creates_file(self, temp_dir):
        """JSON export should create file."""
        from voidwave.export.exporters import JsonExporter

        exporter = JsonExporter()
        data = {"test": "data", "number": 42}
        path = temp_dir / "test.json"

        result = await exporter.export(data, path)

        assert result.success
        assert path.exists()
        assert result.size > 0

    @pytest.mark.asyncio
    async def test_export_valid_json(self, temp_dir):
        """Exported JSON should be valid."""
        from voidwave.export.exporters import JsonExporter

        exporter = JsonExporter()
        data = {"key": "value", "nested": {"a": 1}}
        path = temp_dir / "test.json"

        await exporter.export(data, path)

        loaded = json.loads(path.read_text())
        assert loaded == data

    @pytest.mark.asyncio
    async def test_export_creates_parent_dirs(self, temp_dir):
        """Export should create parent directories."""
        from voidwave.export.exporters import JsonExporter

        exporter = JsonExporter()
        path = temp_dir / "a" / "b" / "c" / "test.json"

        result = await exporter.export({"test": True}, path)

        assert result.success
        assert path.parent.exists()


class TestCsvExporter:
    """Test CSV exporter."""

    @pytest.mark.asyncio
    async def test_export_list_of_dicts(self, temp_dir):
        """CSV export should handle list of dicts."""
        from voidwave.export.exporters import CsvExporter

        exporter = CsvExporter()
        data = [
            {"name": "Alice", "age": 30},
            {"name": "Bob", "age": 25},
        ]
        path = temp_dir / "test.csv"

        result = await exporter.export(data, path)

        assert result.success
        content = path.read_text()
        assert "name" in content
        assert "Alice" in content

    @pytest.mark.asyncio
    async def test_empty_list_creates_file(self, temp_dir):
        """Empty list should still create file."""
        from voidwave.export.exporters import CsvExporter

        exporter = CsvExporter()
        path = temp_dir / "empty.csv"

        result = await exporter.export([], path)

        assert result.success
        assert path.exists()


class TestHtmlExporter:
    """Test HTML exporter."""

    @pytest.mark.asyncio
    async def test_export_session_data(self, temp_dir, sample_session_data):
        """HTML export should work with session data."""
        from voidwave.export.exporters import HtmlExporter

        exporter = HtmlExporter()
        path = temp_dir / "report.html"

        result = await exporter.export(sample_session_data, path)

        assert result.success
        content = path.read_text()
        assert "VOIDWAVE" in content
        assert "192.168.1.1" in content

    @pytest.mark.asyncio
    async def test_calculate_duration(self, sample_session_data):
        """Duration calculation should work."""
        from voidwave.export.exporters import HtmlExporter

        exporter = HtmlExporter()
        session = sample_session_data["session"]

        duration = exporter._calculate_duration(session)

        assert duration != "N/A"
        assert "h" in duration or "m" in duration or "s" in duration


class TestMarkdownExporter:
    """Test Markdown exporter."""

    @pytest.mark.asyncio
    async def test_export_session_data(self, temp_dir, sample_session_data):
        """Markdown export should work with session data."""
        from voidwave.export.exporters import MarkdownExporter

        exporter = MarkdownExporter()
        path = temp_dir / "report.md"

        result = await exporter.export(sample_session_data, path)

        assert result.success
        content = path.read_text()
        assert "# VOIDWAVE" in content
        assert "## Targets" in content


class TestExportManager:
    """Test ExportManager orchestration."""

    @pytest.mark.asyncio
    async def test_export_session_multiple_formats(self, temp_dir, sample_session_data, monkeypatch):
        """Export manager should handle multiple formats."""
        from voidwave.export.manager import ExportManager
        from voidwave.core import constants

        # Mock the report path
        monkeypatch.setattr(constants, "VOIDWAVE_REPORTS_DIR", temp_dir)

        manager = ExportManager()

        results = await manager.export_session(
            session_id=1,
            formats=["json", "md"],
            data=sample_session_data,
        )

        assert len(results) == 2
        assert all(r.success for r in results)

    def test_get_supported_formats(self):
        """Should return list of supported formats."""
        from voidwave.export.manager import ExportManager

        formats = ExportManager.get_supported_formats()

        assert "json" in formats
        assert "csv" in formats
        assert "html" in formats
        assert "md" in formats
