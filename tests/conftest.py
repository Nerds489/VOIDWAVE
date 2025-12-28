"""Pytest configuration and shared fixtures."""

import asyncio
import tempfile
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest


@pytest.fixture(scope="session")
def event_loop():
    """Create event loop for async tests."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
def temp_dir():
    """Provide a temporary directory for test files."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)


@pytest.fixture
def mock_voidwave_home(temp_dir, monkeypatch):
    """Mock VOIDWAVE_HOME to use temp directory."""
    # Patch the constants at import time
    monkeypatch.setattr(
        "voidwave.core.constants.VOIDWAVE_HOME",
        temp_dir,
    )
    monkeypatch.setattr(
        "voidwave.core.constants.VOIDWAVE_CONFIG_DIR",
        temp_dir / "config",
    )
    monkeypatch.setattr(
        "voidwave.core.constants.VOIDWAVE_DATA_DIR",
        temp_dir / "data",
    )
    monkeypatch.setattr(
        "voidwave.core.constants.VOIDWAVE_LOG_DIR",
        temp_dir / "logs",
    )
    monkeypatch.setattr(
        "voidwave.core.constants.VOIDWAVE_OUTPUT_DIR",
        temp_dir / "output",
    )
    return temp_dir


@pytest.fixture
def mock_db():
    """Mock database connection."""
    db = AsyncMock()
    db.fetch_one = AsyncMock(return_value={"id": 1, "name": "Test Session"})
    db.fetch_all = AsyncMock(return_value=[])
    db.execute = AsyncMock(return_value=None)
    return db


@pytest.fixture
def mock_loot():
    """Mock loot storage."""
    loot = AsyncMock()
    loot.list_by_session = AsyncMock(return_value=[])
    loot.retrieve = AsyncMock(return_value={})
    return loot


@pytest.fixture
def sample_session_data():
    """Provide sample session data for export tests."""
    return {
        "session": {
            "id": 1,
            "name": "Test Session",
            "created_at": "2024-01-01T10:00:00",
            "completed_at": "2024-01-01T12:30:00",
            "state": "completed",
        },
        "targets": [
            {"type": "ip", "value": "192.168.1.1", "status": "scanned"},
            {"type": "domain", "value": "example.com", "status": "pending"},
        ],
        "loot": [
            {"type": "credential", "target": "192.168.1.1", "severity": "high"},
        ],
        "tool_executions": [
            {"tool_name": "nmap", "exit_code": 0, "duration": 30},
            {"tool_name": "nikto", "exit_code": 0, "duration": 120},
        ],
        "audit_log": [
            {"timestamp": "2024-01-01T10:00:00", "action": "start", "details": "Session started"},
            {"timestamp": "2024-01-01T10:05:00", "action": "scan", "details": "Port scan initiated"},
        ],
    }


@pytest.fixture
def mock_subprocess():
    """Mock asyncio subprocess creation."""
    mock_proc = AsyncMock()
    mock_proc.returncode = 0
    mock_proc.communicate = AsyncMock(return_value=(b"output", b""))
    mock_proc.wait = AsyncMock(return_value=0)
    mock_proc.stdout = AsyncMock()
    mock_proc.stdout.readline = AsyncMock(side_effect=[b"line1\n", b"line2\n", b""])

    with patch("asyncio.create_subprocess_exec", return_value=mock_proc) as mock:
        yield mock, mock_proc


@pytest.fixture
def mock_which():
    """Mock shutil.which for tool detection."""
    def _which(cmd):
        available = {"nmap", "masscan", "hashcat", "aircrack-ng", "ip", "curl"}
        if cmd in available:
            return f"/usr/bin/{cmd}"
        return None

    with patch("shutil.which", side_effect=_which) as mock:
        yield mock
