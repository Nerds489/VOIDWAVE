"""Automation framework for VOIDWAVE.

Provides preflight checking, auto-fix handlers, and subflow management.
"""

from voidwave.automation.engine import (
    RequirementType,
    RequirementStatus,
    Requirement,
    PreflightResult,
)
from voidwave.automation.preflight import PreflightChecker
from voidwave.automation.labels import AutoLabelRegistry, AUTO_REGISTRY
from voidwave.automation.requirements import ATTACK_REQUIREMENTS
from voidwave.automation.subflows import SubflowType, SubflowContext, SubflowManager
from voidwave.automation.fallbacks import FallbackManager, FALLBACK_CHAINS

__all__ = [
    "RequirementType",
    "RequirementStatus",
    "Requirement",
    "PreflightResult",
    "PreflightChecker",
    "AutoLabelRegistry",
    "AUTO_REGISTRY",
    "ATTACK_REQUIREMENTS",
    "SubflowType",
    "SubflowContext",
    "SubflowManager",
    "FallbackManager",
    "FALLBACK_CHAINS",
]
