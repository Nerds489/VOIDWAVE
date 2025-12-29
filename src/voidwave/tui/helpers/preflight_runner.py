"""Preflight runner helper for TUI screens."""

from dataclasses import dataclass, field
from typing import Any, Callable, Coroutine, TYPE_CHECKING

from voidwave.automation.preflight import PreflightChecker
from voidwave.automation.engine import PreflightResult
from voidwave.automation.tool_requirements import get_tool_requirements, get_fallback_tool
from voidwave.core.logging import get_logger

if TYPE_CHECKING:
    from textual.app import App

logger = get_logger(__name__)


@dataclass
class ToolContext:
    """Context with all resolved values needed to run a tool."""

    tool: str
    ready: bool = False

    # Resolved values
    interface: str | None = None
    target: str | None = None
    wordlist: str | None = None
    api_key: str | None = None
    capture_file: str | None = None

    # What was resolved
    used_fallback: bool = False
    fallback_tool: str | None = None

    # Error info
    error: str | None = None


class PreflightRunner:
    """Helper class for running preflight checks with TUI integration."""

    def __init__(self, app: "App", session: Any = None) -> None:
        self.app = app
        self.session = session
        self.checker = PreflightChecker(session)

    async def run_with_preflight(
        self,
        action: str,
        callback: Callable[[], Coroutine[Any, Any, Any]],
        auto_fix: bool = True,
    ) -> bool:
        """Run preflight checks and execute callback if passed.

        Args:
            action: The action name to check requirements for
            callback: Async function to call if preflight passes
            auto_fix: Whether to automatically try fixing issues

        Returns:
            True if action was executed, False if cancelled or failed
        """
        # Run preflight check
        result = await self.checker.check(action)

        if result.all_met:
            # All good, run the action
            await callback()
            return True

        # Show preflight modal
        from voidwave.tui.modals.preflight_modal import PreflightModal

        proceed = await self.app.push_screen_wait(
            PreflightModal(result, self.session)
        )

        if proceed:
            # Re-check after fixes
            result = await self.checker.check(action)
            if result.all_met or result.can_proceed:
                await callback()
                return True

        return False

    async def ensure_interface(self, interface_type: str = "wireless") -> str | None:
        """Ensure an interface is selected, prompting if needed.

        Args:
            interface_type: Type of interface needed (wireless, monitor, all)

        Returns:
            Selected interface name or None if cancelled
        """
        from voidwave.automation.handlers.iface import AutoIfaceHandler
        from voidwave.tui.modals.preflight_modal import InterfaceSelectModal

        handler = AutoIfaceHandler(required_type=interface_type)
        interfaces = await handler.get_interfaces(interface_type)

        if not interfaces:
            self.app.notify(
                f"No {interface_type} interfaces found. Please connect an adapter.",
                severity="error"
            )
            return None

        if len(interfaces) == 1:
            # Auto-select single interface
            return interfaces[0].name

        # Multiple interfaces - prompt user
        interface_data = [
            {
                "name": iface.name,
                "type": iface.type,
                "mac": iface.mac,
                "driver": iface.driver,
            }
            for iface in interfaces
        ]

        selected = await self.app.push_screen_wait(
            InterfaceSelectModal(
                interface_data,
                title=f"Select {interface_type.title()} Interface"
            )
        )

        return selected

    async def ensure_monitor_mode(self, interface: str | None = None) -> str | None:
        """Ensure monitor mode is enabled on an interface.

        Args:
            interface: Specific interface to use, or None to auto-detect

        Returns:
            Monitor interface name or None if failed
        """
        from voidwave.automation.handlers.monitor import AutoMonHandler
        from voidwave.tui.modals.preflight_modal import ConfirmModal

        # Get interface if not specified
        if not interface:
            interface = await self.ensure_interface("wireless")
            if not interface:
                return None

        # Check if already in monitor mode
        handler = AutoMonHandler(interface)
        if await handler._is_monitor_mode(interface):
            return interface

        # Ask user to confirm
        confirm = await self.app.push_screen_wait(
            ConfirmModal(
                "Enable Monitor Mode",
                f"Enable monitor mode on {interface}?\n\n"
                "This will disconnect from WiFi networks."
            )
        )

        if not confirm:
            return None

        # Enable monitor mode
        self.app.notify(f"Enabling monitor mode on {interface}...", severity="information")

        success = await handler.fix()
        if success:
            self.app.notify(
                f"Monitor mode enabled: {handler.monitor_interface}",
                severity="information"
            )
            return handler.monitor_interface
        else:
            self.app.notify("Failed to enable monitor mode", severity="error")
            return None

    async def ensure_root(self) -> bool:
        """Ensure running as root, showing message if not.

        Returns:
            True if running as root
        """
        import os

        if os.geteuid() == 0:
            return True

        from voidwave.automation.handlers.privilege import AutoPrivHandler
        from voidwave.tui.modals.preflight_modal import ConfirmModal

        handler = AutoPrivHandler()
        relaunch_cmd = handler.get_relaunch_command()

        await self.app.push_screen_wait(
            ConfirmModal(
                "Root Required",
                f"This action requires root privileges.\n\n"
                f"Please restart with:\n{relaunch_cmd}"
            )
        )

        return False

    async def ensure_target(self, target_type: str = "ip") -> str | None:
        """Ensure a target is specified, prompting if needed.

        Args:
            target_type: Type of target (ip, host, url, bssid)

        Returns:
            Target value or None if cancelled
        """
        from voidwave.tui.modals.preflight_modal import InputModal
        from voidwave.automation.handlers.validate import AutoValidateHandler

        placeholders = {
            "ip": "192.168.1.1",
            "host": "example.com",
            "url": "https://example.com",
            "bssid": "AA:BB:CC:DD:EE:FF",
            "cidr": "192.168.1.0/24",
        }

        target = await self.app.push_screen_wait(
            InputModal(
                f"Enter Target ({target_type.upper()})",
                placeholder=placeholders.get(target_type, "")
            )
        )

        if not target:
            return None

        # Validate
        is_valid, error = AutoValidateHandler.validate_input(target_type, target)
        if not is_valid:
            self.app.notify(f"Invalid {target_type}: {error}", severity="error")
            return None

        return target

    async def ensure_tool(self, tool_name: str) -> bool:
        """Ensure a tool is installed, offering to install if missing.

        Args:
            tool_name: Name of the tool binary

        Returns:
            True if tool is available
        """
        import shutil

        if shutil.which(tool_name):
            return True

        from voidwave.automation.handlers.install import AutoInstallHandler
        from voidwave.tui.modals.preflight_modal import ConfirmModal

        handler = AutoInstallHandler(tool_name)

        if not await handler.can_fix():
            self.app.notify(
                f"Cannot install {tool_name}: no package manager found",
                severity="error"
            )
            return False

        confirm = await self.app.push_screen_wait(
            ConfirmModal(
                "Install Tool",
                await handler.get_ui_prompt()
            )
        )

        if not confirm:
            return False

        self.app.notify(f"Installing {tool_name}...", severity="information")
        success = await handler.fix()

        if success:
            self.app.notify(f"{tool_name} installed successfully", severity="information")
        else:
            self.app.notify(f"Failed to install {tool_name}", severity="error")

        return success

    async def ensure_api_key(self, service: str) -> str | None:
        """Ensure an API key is configured, prompting if needed.

        Args:
            service: Service name (shodan, censys, etc.)

        Returns:
            API key or None if not configured
        """
        from voidwave.automation.handlers.keys import AutoKeysHandler
        from voidwave.tui.modals.preflight_modal import InputModal

        handler = AutoKeysHandler(service)

        # Check if already configured
        existing = handler.get_key()
        if existing:
            return existing

        # Prompt for key
        url = handler.get_registration_url()
        title = f"Enter {service.title()} API Key"
        if url:
            title += f"\n(Get one at: {url})"

        key = await self.app.push_screen_wait(
            InputModal(title, placeholder="API Key", password=True)
        )

        if key:
            handler.save_key(key)
            self.app.notify(f"{service.title()} API key saved", severity="information")
            return key

        return None

    async def ensure_wordlist(self) -> str | None:
        """Ensure a wordlist is available, downloading if needed.

        Returns:
            Path to wordlist or None
        """
        from pathlib import Path
        from voidwave.automation.handlers.data import AutoDataHandler
        from voidwave.tui.modals.preflight_modal import ConfirmModal

        # Check standard locations
        standard_paths = [
            Path("/usr/share/wordlists/rockyou.txt"),
            Path("/usr/share/seclists/Passwords/rockyou.txt"),
            Path.home() / ".voidwave/wordlists/rockyou.txt",
        ]

        for path in standard_paths:
            if path.exists():
                return str(path)

        # Offer to download
        handler = AutoDataHandler("rockyou")

        if not await handler.can_fix():
            self.app.notify("Cannot download wordlist: curl/wget not found", severity="error")
            return None

        confirm = await self.app.push_screen_wait(
            ConfirmModal(
                "Download Wordlist",
                "No wordlist found. Download rockyou.txt (14MB)?"
            )
        )

        if not confirm:
            return None

        self.app.notify("Downloading rockyou.txt...", severity="information")
        success = await handler.fix()

        if success and handler.dest_path:
            self.app.notify("Wordlist downloaded", severity="information")
            return str(handler.dest_path)

        self.app.notify("Failed to download wordlist", severity="error")
        return None

    async def prepare_tool(
        self,
        tool_name: str,
        target: str | None = None,
        interface: str | None = None,
    ) -> ToolContext:
        """Prepare all requirements for a tool, prompting as needed.

        This is the main entry point for tool preparation. It:
        1. Checks if tool exists (offers to install or use fallback)
        2. Checks root requirement
        3. Gets/prompts for target if needed
        4. Gets/prompts for interface if needed
        5. Gets/prompts for wordlist if needed
        6. Gets/prompts for API key if needed

        Args:
            tool_name: Name of the tool to prepare
            target: Pre-provided target (optional)
            interface: Pre-provided interface (optional)

        Returns:
            ToolContext with all resolved values and ready=True if all requirements met
        """
        import shutil
        from voidwave.tui.modals.preflight_modal import ConfirmModal

        ctx = ToolContext(tool=tool_name)
        req = get_tool_requirements(tool_name)

        if not req:
            # Unknown tool - just check if it exists
            if not shutil.which(tool_name):
                if not await self.ensure_tool(tool_name):
                    ctx.error = f"Tool {tool_name} not found and could not be installed"
                    return ctx
            ctx.ready = True
            return ctx

        # Step 1: Check tool availability
        actual_tool = tool_name
        if not shutil.which(tool_name):
            # Try fallback first
            fallback = get_fallback_tool(tool_name)
            if fallback:
                confirm = await self.app.push_screen_wait(
                    ConfirmModal(
                        "Tool Not Found",
                        f"'{tool_name}' not found.\n\n"
                        f"Use '{fallback}' instead?"
                    )
                )
                if confirm:
                    actual_tool = fallback
                    ctx.used_fallback = True
                    ctx.fallback_tool = fallback
                else:
                    # Try to install original
                    if not await self.ensure_tool(tool_name):
                        ctx.error = f"Tool {tool_name} not available"
                        return ctx
            else:
                # No fallback, try to install
                if not await self.ensure_tool(tool_name):
                    ctx.error = f"Tool {tool_name} not available"
                    return ctx

        ctx.tool = actual_tool

        # Step 2: Check root requirement
        if req.needs_root:
            if not await self.ensure_root():
                ctx.error = "Root privileges required"
                return ctx

        # Step 3: Check target requirement
        if req.needs_target:
            if target:
                ctx.target = target
            else:
                resolved_target = await self.ensure_target(req.target_type)
                if not resolved_target:
                    ctx.error = f"Target ({req.target_type}) required"
                    return ctx
                ctx.target = resolved_target

        # Step 4: Check interface requirement
        if req.needs_interface:
            if interface:
                ctx.interface = interface
            elif req.interface_type == "monitor":
                resolved_iface = await self.ensure_monitor_mode()
                if not resolved_iface:
                    ctx.error = "Monitor mode interface required"
                    return ctx
                ctx.interface = resolved_iface
            else:
                resolved_iface = await self.ensure_interface(req.interface_type or "all")
                if not resolved_iface:
                    ctx.error = f"Interface ({req.interface_type}) required"
                    return ctx
                ctx.interface = resolved_iface

        # Step 5: Check wordlist requirement
        if req.needs_wordlist:
            wordlist = await self.ensure_wordlist()
            if not wordlist:
                ctx.error = "Wordlist required"
                return ctx
            ctx.wordlist = wordlist

        # Step 6: Check API key requirement
        if req.needs_api_key:
            api_key = await self.ensure_api_key(req.needs_api_key)
            if not api_key:
                ctx.error = f"API key for {req.needs_api_key} required"
                return ctx
            ctx.api_key = api_key

        # Step 7: Check GPU requirement (just warn)
        if req.needs_gpu:
            # Check for CUDA/OpenCL
            import subprocess
            try:
                result = subprocess.run(
                    [actual_tool, "-I"],
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                if "No devices found" in result.stdout or result.returncode != 0:
                    self.app.notify(
                        "No GPU found - performance may be slower",
                        severity="warning"
                    )
            except Exception:
                pass

        ctx.ready = True
        return ctx

    async def quick_check(self, tool_name: str) -> bool:
        """Quick check if a tool is available (install if not).

        Simpler than prepare_tool - just checks the tool exists.

        Args:
            tool_name: Name of the tool

        Returns:
            True if tool is available
        """
        import shutil

        if shutil.which(tool_name):
            return True

        # Check for fallback
        fallback = get_fallback_tool(tool_name)
        if fallback and shutil.which(fallback):
            self.app.notify(
                f"Using {fallback} instead of {tool_name}",
                severity="information"
            )
            return True

        # Try to install
        return await self.ensure_tool(tool_name)
