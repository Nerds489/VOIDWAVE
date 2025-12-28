"""AUTO-FALLBACK handler for switching to alternate tools."""

import shutil

from voidwave.automation.labels import AUTO_REGISTRY
from voidwave.automation.fallbacks import FALLBACK_CHAINS


class AutoFallbackHandler:
    """Handles AUTO-FALLBACK for switching to alternate tools."""

    def __init__(self, primary: str = "", fallback: str = "") -> None:
        self.primary = primary
        self.fallback = fallback
        self.selected_tool: str | None = None

    async def can_fix(self) -> bool:
        """Check if a fallback is available."""
        if not self.primary:
            return False

        chain = FALLBACK_CHAINS.get(self.primary, [])
        for tool in chain:
            if shutil.which(tool):
                self.fallback = tool
                return True

        return False

    async def fix(self) -> bool:
        """Switch to the fallback tool."""
        if self.fallback and shutil.which(self.fallback):
            self.selected_tool = self.fallback
            return True
        return False

    async def get_ui_prompt(self) -> str:
        """Get the UI prompt for this fix."""
        if self.fallback:
            return f"'{self.primary}' not found. Use '{self.fallback}' instead?"
        return f"'{self.primary}' not found. Check for alternatives?"

    def get_available_alternatives(self) -> list[str]:
        """Get list of available alternative tools."""
        if not self.primary:
            return []

        chain = FALLBACK_CHAINS.get(self.primary, [])
        return [tool for tool in chain if shutil.which(tool)]

    def get_fallback_chain(self) -> list[str]:
        """Get the full fallback chain for the primary tool."""
        return FALLBACK_CHAINS.get(self.primary, [])


# Register the handler
AUTO_REGISTRY.register("AUTO-FALLBACK", AutoFallbackHandler)
