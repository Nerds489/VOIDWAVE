"""Tests for core constants module."""

from pathlib import Path

import pytest


class TestPaths:
    """Test path constants."""

    def test_voidwave_home_is_in_user_home(self):
        """VOIDWAVE_HOME should be in user's home directory."""
        from voidwave.core.constants import VOIDWAVE_HOME

        assert VOIDWAVE_HOME.parts[-1] == ".voidwave"
        assert Path.home() in VOIDWAVE_HOME.parents or VOIDWAVE_HOME.parent == Path.home()

    def test_all_paths_are_under_home(self):
        """All paths should be under VOIDWAVE_HOME."""
        from voidwave.core.constants import (
            VOIDWAVE_HOME,
            VOIDWAVE_CONFIG_DIR,
            VOIDWAVE_DATA_DIR,
            VOIDWAVE_LOG_DIR,
            VOIDWAVE_OUTPUT_DIR,
            VOIDWAVE_CACHE_DIR,
        )

        for path in [
            VOIDWAVE_CONFIG_DIR,
            VOIDWAVE_DATA_DIR,
            VOIDWAVE_LOG_DIR,
            VOIDWAVE_OUTPUT_DIR,
            VOIDWAVE_CACHE_DIR,
        ]:
            assert VOIDWAVE_HOME in path.parents or path.parent == VOIDWAVE_HOME

    def test_export_paths_are_under_output(self):
        """Export paths should be under output directory."""
        from voidwave.core.constants import (
            VOIDWAVE_OUTPUT_DIR,
            VOIDWAVE_CAPTURES_DIR,
            VOIDWAVE_SCANS_DIR,
            VOIDWAVE_REPORTS_DIR,
            VOIDWAVE_LOOT_DIR,
            VOIDWAVE_EXPORTS_DIR,
        )

        for path in [
            VOIDWAVE_CAPTURES_DIR,
            VOIDWAVE_SCANS_DIR,
            VOIDWAVE_REPORTS_DIR,
            VOIDWAVE_LOOT_DIR,
            VOIDWAVE_EXPORTS_DIR,
        ]:
            assert VOIDWAVE_OUTPUT_DIR in path.parents or path.parent == VOIDWAVE_OUTPUT_DIR


class TestExitCodes:
    """Test exit code constants."""

    def test_success_is_zero(self):
        """SUCCESS exit code should be 0."""
        from voidwave.core.constants import ExitCode

        assert ExitCode.SUCCESS == 0

    def test_failure_is_nonzero(self):
        """FAILURE exit code should be non-zero."""
        from voidwave.core.constants import ExitCode

        assert ExitCode.FAILURE != 0
        assert ExitCode.FAILURE > 0


class TestLogLevels:
    """Test log level constants."""

    def test_log_levels_are_ordered(self):
        """Log levels should be in ascending order of severity."""
        from voidwave.core.constants import LogLevel

        assert LogLevel.DEBUG < LogLevel.INFO
        assert LogLevel.INFO < LogLevel.SUCCESS
        assert LogLevel.SUCCESS < LogLevel.WARNING
        assert LogLevel.WARNING < LogLevel.ERROR
        assert LogLevel.ERROR < LogLevel.FATAL


class TestConcurrencyLimits:
    """Test concurrency limit constants."""

    def test_password_cracker_is_single(self):
        """Password cracker should have limit of 1 (GPU exclusivity)."""
        from voidwave.core.constants import CONCURRENCY_LIMITS

        assert CONCURRENCY_LIMITS["password_cracker"] == 1

    def test_default_limit_exists(self):
        """Default concurrency limit should exist."""
        from voidwave.core.constants import CONCURRENCY_LIMITS

        assert "default" in CONCURRENCY_LIMITS
        assert CONCURRENCY_LIMITS["default"] > 0
