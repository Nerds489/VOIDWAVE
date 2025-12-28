"""Event bus integration with TUI widgets."""
from __future__ import annotations

from typing import TYPE_CHECKING

from voidwave.core.logging import get_logger
from voidwave.orchestration.events import Events, VoidwaveEventBus

if TYPE_CHECKING:
    from textual.app import App

logger = get_logger(__name__)


class TUIEventBridge:
    """Bridges async event bus to TUI widgets via thread-safe message passing.

    This class subscribes to events from the event bus and routes them
    to the appropriate TUI widgets using Textual's thread-safe mechanisms.
    """

    def __init__(self, app: App, event_bus: VoidwaveEventBus) -> None:
        """Initialize the bridge.

        Args:
            app: The Textual application instance
            event_bus: The VOIDWAVE event bus
        """
        self.app = app
        self.bus = event_bus
        self._registered = False

    def connect(self) -> None:
        """Register all event handlers."""
        if self._registered:
            return

        # Tool lifecycle events
        self.bus.on(Events.TOOL_STARTED, self._on_tool_started)
        self.bus.on(Events.TOOL_OUTPUT, self._on_tool_output)
        self.bus.on(Events.TOOL_PROGRESS, self._on_tool_progress)
        self.bus.on(Events.TOOL_COMPLETED, self._on_tool_completed)
        self.bus.on(Events.TOOL_FAILED, self._on_tool_failed)

        # Task events
        self.bus.on(Events.TASK_STARTED, self._on_task_started)
        self.bus.on(Events.TASK_PROGRESS, self._on_task_progress)
        self.bus.on(Events.TASK_COMPLETED, self._on_task_completed)

        # Discovery events
        self.bus.on(Events.HOST_DISCOVERED, self._on_host_discovered)
        self.bus.on(Events.SERVICE_DISCOVERED, self._on_service_discovered)
        self.bus.on(Events.VULNERABILITY_FOUND, self._on_vulnerability_found)

        # Wireless events
        self.bus.on(Events.NETWORK_FOUND, self._on_network_found)
        self.bus.on(Events.HANDSHAKE_CAPTURED, self._on_handshake_captured)
        self.bus.on(Events.CREDENTIAL_CRACKED, self._on_credential_cracked)

        # UI events
        self.bus.on(Events.STATUS_UPDATE, self._on_status_update)
        self.bus.on(Events.NOTIFICATION, self._on_notification)

        self._registered = True
        logger.info("TUI event bridge connected")

    def disconnect(self) -> None:
        """Unregister all event handlers."""
        if not self._registered:
            return

        # Remove all handlers
        self.bus.off(Events.TOOL_STARTED, self._on_tool_started)
        self.bus.off(Events.TOOL_OUTPUT, self._on_tool_output)
        self.bus.off(Events.TOOL_PROGRESS, self._on_tool_progress)
        self.bus.off(Events.TOOL_COMPLETED, self._on_tool_completed)
        self.bus.off(Events.TOOL_FAILED, self._on_tool_failed)

        self.bus.off(Events.TASK_STARTED, self._on_task_started)
        self.bus.off(Events.TASK_PROGRESS, self._on_task_progress)
        self.bus.off(Events.TASK_COMPLETED, self._on_task_completed)

        self.bus.off(Events.HOST_DISCOVERED, self._on_host_discovered)
        self.bus.off(Events.SERVICE_DISCOVERED, self._on_service_discovered)
        self.bus.off(Events.VULNERABILITY_FOUND, self._on_vulnerability_found)

        self.bus.off(Events.NETWORK_FOUND, self._on_network_found)
        self.bus.off(Events.HANDSHAKE_CAPTURED, self._on_handshake_captured)
        self.bus.off(Events.CREDENTIAL_CRACKED, self._on_credential_cracked)

        self.bus.off(Events.STATUS_UPDATE, self._on_status_update)
        self.bus.off(Events.NOTIFICATION, self._on_notification)

        self._registered = False
        logger.info("TUI event bridge disconnected")

    # --------------------------------------------------------------------------
    # Tool Lifecycle Handlers
    # --------------------------------------------------------------------------

    async def _on_tool_started(self, data: dict) -> None:
        """Handle tool started event."""
        self.app.call_from_thread(self._update_tool_output, "started", data)

    async def _on_tool_output(self, data: dict) -> None:
        """Handle tool output event."""
        self.app.call_from_thread(self._update_tool_output, "output", data)

    async def _on_tool_progress(self, data: dict) -> None:
        """Handle tool progress event."""
        self.app.call_from_thread(self._update_progress_panel, data)

    async def _on_tool_completed(self, data: dict) -> None:
        """Handle tool completed event."""
        self.app.call_from_thread(self._update_tool_output, "completed", data)
        self.app.call_from_thread(self._update_status_panel, "tool_completed", data)

    async def _on_tool_failed(self, data: dict) -> None:
        """Handle tool failed event."""
        self.app.call_from_thread(self._update_tool_output, "failed", data)
        self.app.call_from_thread(self._update_status_panel, "tool_failed", data)

    # --------------------------------------------------------------------------
    # Task Handlers
    # --------------------------------------------------------------------------

    async def _on_task_started(self, data: dict) -> None:
        """Handle task started event."""
        self.app.call_from_thread(self._update_progress_panel, data)

    async def _on_task_progress(self, data: dict) -> None:
        """Handle task progress event."""
        self.app.call_from_thread(self._update_progress_panel, data)

    async def _on_task_completed(self, data: dict) -> None:
        """Handle task completed event."""
        self.app.call_from_thread(self._update_progress_panel, data)

    # --------------------------------------------------------------------------
    # Discovery Handlers
    # --------------------------------------------------------------------------

    async def _on_host_discovered(self, data: dict) -> None:
        """Handle host discovered event."""
        self.app.call_from_thread(self._update_target_tree, "host", data)
        self.app.call_from_thread(self._update_tool_output, "discovery", data)

    async def _on_service_discovered(self, data: dict) -> None:
        """Handle service discovered event."""
        self.app.call_from_thread(self._update_target_tree, "service", data)

    async def _on_vulnerability_found(self, data: dict) -> None:
        """Handle vulnerability found event."""
        self.app.call_from_thread(self._update_tool_output, "vulnerability", data)
        self.app.call_from_thread(self._show_notification, "vulnerability", data)

    # --------------------------------------------------------------------------
    # Wireless Handlers
    # --------------------------------------------------------------------------

    async def _on_network_found(self, data: dict) -> None:
        """Handle network found event."""
        self.app.call_from_thread(self._update_wireless_table, "network", data)

    async def _on_handshake_captured(self, data: dict) -> None:
        """Handle handshake captured event."""
        self.app.call_from_thread(self._update_tool_output, "handshake", data)
        self.app.call_from_thread(self._show_notification, "handshake", data)

    async def _on_credential_cracked(self, data: dict) -> None:
        """Handle credential cracked event."""
        self.app.call_from_thread(self._update_tool_output, "cracked", data)
        self.app.call_from_thread(self._show_notification, "cracked", data)

    # --------------------------------------------------------------------------
    # UI Handlers
    # --------------------------------------------------------------------------

    async def _on_status_update(self, data: dict) -> None:
        """Handle status update event."""
        self.app.call_from_thread(self._update_status_panel, "status", data)

    async def _on_notification(self, data: dict) -> None:
        """Handle notification event."""
        self.app.call_from_thread(self._show_notification, "notification", data)

    # --------------------------------------------------------------------------
    # Widget Update Methods (called from main thread)
    # --------------------------------------------------------------------------

    def _update_tool_output(self, event_type: str, data: dict) -> None:
        """Update the ToolOutput widget."""
        try:
            from voidwave.tui.widgets.tool_output import ToolOutput

            output = self.app.query_one("#tool-output", ToolOutput)

            if event_type == "started":
                tool = data.get("tool", "unknown")
                target = data.get("target", "")
                output.write_header(f"{tool} Started")
                if target:
                    output.write(f"[dim]Target: {target}[/]")
            elif event_type == "output":
                tool = data.get("tool", "unknown")
                line = data.get("line", "")
                level = data.get("level", "info")
                if level == "error":
                    output.write_error(line, tool)
                elif level == "warning":
                    output.write_warning(line, tool)
                elif level == "success":
                    output.write_success(line, tool)
                else:
                    output.write_info(line, tool)
            elif event_type == "completed":
                tool = data.get("tool", "unknown")
                exit_code = data.get("exit_code", 0)
                duration = data.get("duration", 0)
                if exit_code == 0:
                    output.write_success(f"Completed in {duration:.1f}s", tool)
                else:
                    output.write_error(f"Failed with exit code {exit_code}", tool)
            elif event_type == "failed":
                tool = data.get("tool", "unknown")
                error = data.get("error", "Unknown error")
                output.write_error(f"Failed: {error}", tool)
            elif event_type == "discovery":
                host = data.get("ip") or data.get("host", "unknown")
                output.write_success(f"Host discovered: {host}")
            elif event_type == "vulnerability":
                vuln = data.get("name", "Unknown vulnerability")
                severity = data.get("severity", "unknown")
                output.write_warning(f"Vulnerability found: {vuln} ({severity})")
            elif event_type == "handshake":
                bssid = data.get("bssid", "unknown")
                output.write_success(f"Handshake captured for {bssid}")
            elif event_type == "cracked":
                password = data.get("password", "***")
                output.write_success(f"Password cracked: {password}")
        except Exception as e:
            logger.warning(f"Failed to update tool output: {e}")

    def _update_progress_panel(self, data: dict) -> None:
        """Update the ProgressPanel widget."""
        try:
            from voidwave.tui.widgets.progress_panel import ProgressPanel

            panel = self.app.query_one("#progress-panel", ProgressPanel)
            panel.update_task(data)
        except Exception:
            # Progress panel may not exist in current screen
            logger.debug("Progress panel not available in current screen")

    def _update_status_panel(self, event_type: str, data: dict) -> None:
        """Update the StatusPanel widget."""
        try:
            from voidwave.tui.widgets.status_panel import StatusPanel

            panel = self.app.query_one("#status-panel", StatusPanel)
            panel._update_status()
        except Exception:
            # Status panel may not exist in current screen
            logger.debug("Status panel not available in current screen")

    def _update_target_tree(self, node_type: str, data: dict) -> None:
        """Update the TargetTree widget."""
        try:
            from voidwave.tui.widgets.target_tree import TargetTree

            tree = self.app.query_one("#target-tree", TargetTree)
            tree.add_node(node_type, data)
        except Exception:
            # Target tree may not exist in current screen
            logger.debug("Target tree not available in current screen")

    def _update_wireless_table(self, item_type: str, data: dict) -> None:
        """Update wireless network/client tables."""
        # This will be implemented when WirelessScreen is completed
        pass

    def _show_notification(self, notification_type: str, data: dict) -> None:
        """Show a notification to the user."""
        try:
            message = data.get("message") or data.get("name", "")
            severity = data.get("severity", "information")

            if notification_type == "vulnerability":
                message = f"Vulnerability: {data.get('name', 'Unknown')}"
                severity = "warning"
            elif notification_type == "handshake":
                message = f"Handshake captured: {data.get('bssid', 'Unknown')}"
                severity = "information"
            elif notification_type == "cracked":
                message = "Password cracked!"
                severity = "information"

            self.app.notify(message, severity=severity)
        except Exception as e:
            logger.warning(f"Failed to show notification: {e}")
