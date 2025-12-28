"""Tests for automation framework."""

import pytest


class TestAutoCleanupHandler:
    """Test AUTO-CLEANUP handler."""

    def test_register_cleanup_action(self):
        """Should register cleanup actions."""
        from voidwave.automation.handlers.cleanup import AutoCleanupHandler

        # Clear any existing actions
        AutoCleanupHandler.clear_cleanup_stack()

        AutoCleanupHandler.register_cleanup(
            name="test_action",
            action=lambda: None,
            priority=10,
        )

        pending = AutoCleanupHandler.get_pending_actions()

        assert "test_action" in pending

    def test_clear_cleanup_stack(self):
        """Should clear all pending actions."""
        from voidwave.automation.handlers.cleanup import AutoCleanupHandler

        AutoCleanupHandler.register_cleanup("action1", lambda: None)
        AutoCleanupHandler.register_cleanup("action2", lambda: None)

        AutoCleanupHandler.clear_cleanup_stack()

        assert len(AutoCleanupHandler.get_pending_actions()) == 0

    @pytest.mark.asyncio
    async def test_cleanup_all_executes_actions(self):
        """cleanup_all should execute all registered actions."""
        from voidwave.automation.handlers.cleanup import AutoCleanupHandler

        AutoCleanupHandler.clear_cleanup_stack()

        executed = []
        AutoCleanupHandler.register_cleanup(
            "action1",
            lambda: executed.append("action1"),
        )
        AutoCleanupHandler.register_cleanup(
            "action2",
            lambda: executed.append("action2"),
        )

        await AutoCleanupHandler.cleanup_all()

        assert "action1" in executed
        assert "action2" in executed

    @pytest.mark.asyncio
    async def test_cleanup_priority_order(self):
        """Higher priority actions should execute first."""
        from voidwave.automation.handlers.cleanup import AutoCleanupHandler

        AutoCleanupHandler.clear_cleanup_stack()

        order = []
        AutoCleanupHandler.register_cleanup(
            "low",
            lambda: order.append("low"),
            priority=1,
        )
        AutoCleanupHandler.register_cleanup(
            "high",
            lambda: order.append("high"),
            priority=10,
        )
        AutoCleanupHandler.register_cleanup(
            "medium",
            lambda: order.append("medium"),
            priority=5,
        )

        await AutoCleanupHandler.cleanup_all()

        assert order == ["high", "medium", "low"]


class TestAutoSetupHandler:
    """Test AUTO-SETUP handler."""

    @pytest.mark.asyncio
    async def test_can_fix_known_types(self):
        """Should return True for known setup types."""
        from voidwave.automation.handlers.setup import AutoSetupHandler

        for setup_type in ["directories", "config", "certs", "portal", "hostapd", "dnsmasq"]:
            handler = AutoSetupHandler(setup_type=setup_type)
            assert await handler.can_fix()

    @pytest.mark.asyncio
    async def test_can_fix_unknown_type(self):
        """Should return False for unknown setup types."""
        from voidwave.automation.handlers.setup import AutoSetupHandler

        handler = AutoSetupHandler(setup_type="unknown_type")

        assert not await handler.can_fix()

    @pytest.mark.asyncio
    async def test_get_ui_prompt_returns_string(self):
        """Should return a prompt string."""
        from voidwave.automation.handlers.setup import AutoSetupHandler

        handler = AutoSetupHandler(setup_type="directories")
        prompt = await handler.get_ui_prompt()

        assert isinstance(prompt, str)
        assert len(prompt) > 0


class TestAutoDataHandler:
    """Test AUTO-DATA handler."""

    def test_list_available_data(self):
        """Should list available data sources."""
        from voidwave.automation.handlers.data import AutoDataHandler

        sources = AutoDataHandler.list_available_data()

        assert len(sources) > 0
        assert all("name" in s for s in sources)
        assert all("url" in s for s in sources)
        assert all("dest" in s for s in sources)

    @pytest.mark.asyncio
    async def test_can_fix_with_curl(self, mock_which):
        """Should return True if curl is available."""
        from voidwave.automation.handlers.data import AutoDataHandler

        handler = AutoDataHandler(data_type="rockyou")

        assert await handler.can_fix()

    @pytest.mark.asyncio
    async def test_get_ui_prompt_known_source(self):
        """Should return detailed prompt for known sources."""
        from voidwave.automation.handlers.data import AutoDataHandler

        handler = AutoDataHandler(data_type="rockyou")
        prompt = await handler.get_ui_prompt()

        assert "rockyou" in prompt
        assert "14M" in prompt


class TestPreflightChecker:
    """Test preflight requirement checking."""

    @pytest.mark.asyncio
    async def test_check_returns_result(self):
        """check() should return PreflightResult."""
        from voidwave.automation.preflight import PreflightChecker

        checker = PreflightChecker()
        result = await checker.check("unknown_action")

        assert hasattr(result, "action")
        assert hasattr(result, "all_met")
        assert hasattr(result, "missing")
        assert hasattr(result, "fixable")
