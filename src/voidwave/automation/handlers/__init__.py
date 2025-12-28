"""AUTO-* handlers for the automation framework."""

from voidwave.automation.handlers.install import AutoInstallHandler
from voidwave.automation.handlers.privilege import AutoPrivHandler
from voidwave.automation.handlers.monitor import AutoMonHandler
from voidwave.automation.handlers.iface import AutoIfaceHandler
from voidwave.automation.handlers.acquire import AutoAcquireHandler
from voidwave.automation.handlers.data import AutoDataHandler
from voidwave.automation.handlers.keys import AutoKeysHandler
from voidwave.automation.handlers.setup import AutoSetupHandler
from voidwave.automation.handlers.fallback import AutoFallbackHandler
from voidwave.automation.handlers.guide import AutoGuideHandler
from voidwave.automation.handlers.cleanup import AutoCleanupHandler
from voidwave.automation.handlers.validate import AutoValidateHandler
from voidwave.automation.handlers.update import AutoUpdateHandler

__all__ = [
    "AutoInstallHandler",
    "AutoPrivHandler",
    "AutoMonHandler",
    "AutoIfaceHandler",
    "AutoAcquireHandler",
    "AutoDataHandler",
    "AutoKeysHandler",
    "AutoSetupHandler",
    "AutoFallbackHandler",
    "AutoGuideHandler",
    "AutoCleanupHandler",
    "AutoValidateHandler",
    "AutoUpdateHandler",
]
