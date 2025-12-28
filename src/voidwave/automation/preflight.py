"""Preflight checker for validating requirements before actions."""

import asyncio
import shutil
from typing import Any

from voidwave.core.logging import get_logger
from voidwave.automation.engine import (
    Requirement,
    RequirementStatus,
    PreflightResult,
)
from voidwave.automation.requirements import ATTACK_REQUIREMENTS
from voidwave.automation.labels import AUTO_REGISTRY

logger = get_logger(__name__)


class PreflightChecker:
    """Checks requirements before executing actions."""

    def __init__(self, session: Any = None) -> None:
        self.session = session
        self._update_session_checks()

    def _update_session_checks(self) -> None:
        """Update session-based checks from current session state."""
        from voidwave.automation.requirements import set_session_check

        if self.session is None:
            return

        # Update session checks based on session state
        set_session_check(
            "interface", getattr(self.session, "selected_interface", None) is not None
        )
        set_session_check(
            "monitor_mode", getattr(self.session, "monitor_interface", None) is not None
        )
        set_session_check(
            "target", getattr(self.session, "selected_target", None) is not None
        )
        set_session_check(
            "capture_file", getattr(self.session, "capture_file", None) is not None
        )
        set_session_check(
            "hash_file", getattr(self.session, "hash_file", None) is not None
        )
        set_session_check(
            "handshake", getattr(self.session, "handshake_file", None) is not None
        )

    async def check(self, action: str) -> PreflightResult:
        """Check all requirements for an action."""
        self._update_session_checks()

        requirements = ATTACK_REQUIREMENTS.get(action, [])
        result = PreflightResult(
            action=action,
            requirements=requirements,
            all_met=True,
            missing=[],
            fixable=[],
            manual=[],
        )

        for req in requirements:
            status = await self._check_requirement(req)

            if status == RequirementStatus.MET:
                continue
            elif status == RequirementStatus.FIXABLE:
                result.fixable.append(req)
                result.all_met = False
            elif status == RequirementStatus.MANUAL:
                result.manual.append(req)
                result.all_met = False
            else:
                result.missing.append(req)
                result.all_met = False

        return result

    async def _check_requirement(self, req: Requirement) -> RequirementStatus:
        """Check a single requirement, considering alternatives."""
        # Check primary requirement
        try:
            met = await asyncio.to_thread(req.check)
            if met:
                return RequirementStatus.MET
        except Exception as e:
            logger.debug(f"Requirement check failed for {req.name}: {e}")

        # Check alternatives (for tools)
        for alt_name in req.alternatives:
            if shutil.which(alt_name):
                return RequirementStatus.MET

        # Not met - can we fix it?
        if req.auto_label and AUTO_REGISTRY.get(req.auto_label):
            return RequirementStatus.FIXABLE
        elif req.fix:
            return RequirementStatus.FIXABLE

        return RequirementStatus.MANUAL

    async def fix_all(self, result: PreflightResult) -> PreflightResult:
        """Attempt to fix all fixable requirements."""
        for req in result.fixable[:]:  # Copy list to allow modification
            success = await self._try_fix(req)
            if success:
                result.fixable.remove(req)

        # Re-check to update all_met status
        result.all_met = (
            len(result.missing) == 0
            and len(result.fixable) == 0
            and len(result.manual) == 0
        )

        return result

    async def _try_fix(self, req: Requirement) -> bool:
        """Try to fix a single requirement."""
        # Try AUTO-* handler first
        if req.auto_label:
            handler_class = AUTO_REGISTRY.get(req.auto_label)
            if handler_class:
                try:
                    handler = handler_class()
                    if await handler.can_fix():
                        return await handler.fix()
                except Exception as e:
                    logger.debug(f"AUTO-* handler {req.auto_label} failed for {req.name}: {e}")

        # Try requirement's own fix method
        if req.fix:
            try:
                return await asyncio.to_thread(req.fix)
            except Exception as e:
                logger.debug(f"Fix method failed for {req.name}: {e}")

        return False

    def check_sync(self, action: str) -> PreflightResult:
        """Synchronous version of check for non-async contexts."""
        return asyncio.get_event_loop().run_until_complete(self.check(action))


def with_preflight(action_name: str):
    """Decorator to add preflight checks to actions.

    Usage:
        @with_preflight("pixie_dust")
        async def action_pixie_dust(self):
            # Action implementation
            pass
    """

    def decorator(func):
        async def wrapper(self, *args, **kwargs):
            # Get session from self if available
            session = getattr(self, "session", None)
            checker = PreflightChecker(session)
            result = await checker.check(action_name)

            if not result.all_met:
                # Emit event for TUI to show modal
                if hasattr(self, "app"):
                    self.app.post_message_no_wait(
                        PreflightRequired(result)  # Custom message type
                    )
                    return None

            return await func(self, *args, **kwargs)

        return wrapper

    return decorator


class PreflightRequired:
    """Message indicating preflight check failed and user action needed."""

    def __init__(self, result: PreflightResult) -> None:
        self.result = result
