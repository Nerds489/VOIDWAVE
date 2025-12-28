"""System status screen with tool detection and installation."""
from __future__ import annotations

import platform
import os
from typing import TYPE_CHECKING

from textual.app import ComposeResult
from textual.containers import Container, Horizontal, ScrollableContainer, Vertical
from textual.screen import Screen
from textual.widgets import (
    Button,
    Collapsible,
    Label,
    ListItem,
    ListView,
    ProgressBar,
    Static,
)
from textual.worker import Worker, get_current_worker

from voidwave.core.logging import get_logger
from voidwave.detection.tools import ToolCategory, tool_registry

if TYPE_CHECKING:
    from voidwave.detection.tools import ToolInfo

logger = get_logger(__name__)


CATEGORY_ICONS = {
    ToolCategory.WIRELESS: "📡",
    ToolCategory.SCANNING: "🔍",
    ToolCategory.CREDENTIALS: "🔑",
    ToolCategory.OSINT: "🌐",
    ToolCategory.RECON: "🎯",
    ToolCategory.TRAFFIC: "📊",
    ToolCategory.EXPLOIT: "💥",
    ToolCategory.STRESS: "⚡",
    ToolCategory.UTILITY: "🔧",
}


class ToolStatusItem(Static):
    """Widget displaying a single tool's status."""

    def __init__(self, name: str, info: ToolInfo) -> None:
        self.tool_name = name
        self.tool_info = info
        super().__init__()

    def compose(self) -> ComposeResult:
        if self.tool_info.available:
            status = "[green]✓[/]"
            version = f"[dim]{self.tool_info.version[:40]}[/]" if self.tool_info.version else ""
        else:
            status = "[red]✗[/]"
            version = "[dim]not installed[/]"

        desc = self.tool_info.description or ""
        if len(desc) > 30:
            desc = desc[:27] + "..."

        yield Static(f"{status} [bold]{self.tool_name}[/] {version}")


class CategoryPanel(Collapsible):
    """Collapsible panel for a tool category."""

    def __init__(self, category: ToolCategory) -> None:
        self.category = category
        icon = CATEGORY_ICONS.get(category, "📦")
        super().__init__(title=f"{icon} {category.value.title()}", collapsed=True)

    def update_tools(self, tools: dict[str, ToolInfo]) -> None:
        """Update the tool list."""
        container = self.query_one(Vertical)
        container.remove_children()

        # Sort: installed first, then alphabetically
        sorted_tools = sorted(
            tools.items(),
            key=lambda x: (not x[1].available, x[0].lower()),
        )

        for name, info in sorted_tools:
            container.mount(ToolStatusItem(name, info))

    def compose(self) -> ComposeResult:
        with Vertical():
            yield Static("[dim]Loading...[/]")


class StatusScreen(Screen):
    """System status and tool availability screen."""

    CSS = """
    StatusScreen {
        layout: grid;
        grid-size: 3 2;
        grid-columns: 1fr 2fr 2fr;
        grid-rows: 1fr auto;
    }

    #menu-panel {
        height: 100%;
        border: solid $primary;
        padding: 1;
    }

    #menu-panel Label {
        padding: 0 1;
        margin-bottom: 1;
    }

    #category-panel {
        height: 100%;
        border: solid $secondary;
        padding: 1;
    }

    #info-panel {
        height: 100%;
        border: solid $accent;
        padding: 1;
    }

    #output-panel {
        column-span: 3;
        height: 12;
        border: solid $surface;
        padding: 1;
    }

    .action-button {
        width: 100%;
        margin: 0 0 1 0;
    }

    CategoryPanel {
        margin-bottom: 1;
    }

    ToolStatusItem {
        padding: 0 1;
    }

    #system-info {
        height: auto;
    }

    #progress-container {
        height: 3;
        margin: 1 0;
    }

    #progress-label {
        text-align: center;
    }
    """

    BINDINGS = [
        ("escape", "app.pop_screen", "Back"),
        ("r", "refresh", "Refresh"),
        ("f", "full_check", "Full Check"),
        ("i", "install_missing", "Install Missing"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self._checking = False
        self._installing = False

    def compose(self) -> ComposeResult:
        # Left: Action menu
        with Vertical(id="menu-panel"):
            yield Label("[bold magenta]Actions[/]")
            yield Button("Full Check", id="btn-full-check", classes="action-button")
            yield Button("Quick Check", id="btn-quick-check", classes="action-button")
            yield Button("Refresh", id="btn-refresh", classes="action-button")
            yield Static("")
            yield Button("Install Missing", id="btn-install", variant="primary", classes="action-button")
            yield Static("")
            with Vertical(id="progress-container"):
                yield ProgressBar(id="check-progress", show_eta=False)
                yield Label("", id="progress-label")

        # Center: Category panels
        with ScrollableContainer(id="category-panel"):
            yield Label("[bold cyan]Tool Status by Category[/]")
            for category in ToolCategory:
                yield CategoryPanel(category)

        # Right: System info
        with Vertical(id="info-panel"):
            yield Label("[bold green]System Information[/]")
            yield Static(id="system-info")
            yield Static("")
            yield Label("[bold yellow]Summary[/]")
            yield Static(id="summary-info")

        # Bottom: Output
        with Vertical(id="output-panel"):
            yield Label("[bold]Output[/]")
            yield Static(id="status-output")

    async def on_mount(self) -> None:
        """Initialize screen."""
        self._update_system_info()
        # Start a quick check on mount
        self.run_worker(self._run_quick_check(), exclusive=True)

    def _update_system_info(self) -> None:
        """Update system information display."""
        info_widget = self.query_one("#system-info", Static)

        try:
            uname = platform.uname()
            distro = tool_registry.distro.value
            pkg_mgr = tool_registry.package_manager.value

            info_lines = [
                f"[cyan]OS:[/] {uname.system} {uname.release}",
                f"[cyan]Distro:[/] {distro}",
                f"[cyan]Package Manager:[/] {pkg_mgr}",
                f"[cyan]Architecture:[/] {uname.machine}",
                f"[cyan]Hostname:[/] {uname.node}",
                f"[cyan]Python:[/] {platform.python_version()}",
            ]

            # Check if running as root
            if os.geteuid() == 0:
                info_lines.append("[green]Running as root[/]")
            else:
                info_lines.append("[yellow]Not running as root[/]")

            info_widget.update("\n".join(info_lines))

        except Exception as e:
            info_widget.update(f"[red]Error getting system info: {e}[/]")

    def _update_summary(self, summary: dict) -> None:
        """Update summary display."""
        summary_widget = self.query_one("#summary-info", Static)

        installed = summary.get("installed", 0)
        missing = summary.get("missing", 0)
        total = summary.get("total", 0)

        percent = (installed / total * 100) if total > 0 else 0

        lines = [
            f"[green]Installed:[/] {installed}",
            f"[red]Missing:[/] {missing}",
            f"[cyan]Total:[/] {total}",
            f"[bold]Coverage:[/] {percent:.1f}%",
        ]

        summary_widget.update("\n".join(lines))

    def _write_output(self, message: str) -> None:
        """Write message to output panel."""
        output = self.query_one("#status-output", Static)
        output.update(message)

    def _update_progress(self, current: int, total: int, label: str = "") -> None:
        """Update progress bar."""
        progress = self.query_one("#check-progress", ProgressBar)
        progress_label = self.query_one("#progress-label", Label)

        if total > 0:
            progress.update(total=total, progress=current)
            progress_label.update(f"{label} ({current}/{total})")
        else:
            progress.update(total=100, progress=0)
            progress_label.update("")

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        button_id = event.button.id

        if button_id == "btn-full-check":
            await self._start_full_check()
        elif button_id == "btn-quick-check":
            self.run_worker(self._run_quick_check(), exclusive=True)
        elif button_id == "btn-refresh":
            tool_registry.clear_cache()
            self.run_worker(self._run_quick_check(), exclusive=True)
        elif button_id == "btn-install":
            await self._start_install_missing()

    async def _start_full_check(self) -> None:
        """Start full tool check."""
        if self._checking:
            self._write_output("[yellow]Check already in progress...[/]")
            return

        self._checking = True
        self.run_worker(self._run_full_check(), exclusive=True)

    async def _run_quick_check(self) -> None:
        """Run a quick check of all tools (uses cache)."""
        self._write_output("[cyan]Running quick check...[/]")

        try:
            summary = tool_registry.get_summary()
            self._update_summary(summary)

            # Update category panels
            for category in ToolCategory:
                tools = {}
                for name in tool_registry.get_tools_in_category(category):
                    tools[name] = tool_registry.check(name)

                try:
                    panel = self.query_one(f"CategoryPanel", CategoryPanel)
                    for p in self.query(CategoryPanel):
                        if p.category == category:
                            p.update_tools(tools)
                            break
                except Exception:
                    pass

            self._write_output(
                f"[green]Quick check complete.[/] "
                f"Installed: {summary['installed']}, Missing: {summary['missing']}"
            )

        except Exception as e:
            self._write_output(f"[red]Error during check: {e}[/]")

    async def _run_full_check(self) -> None:
        """Run a full check with progress updates."""
        self._write_output("[cyan]Running full check (clearing cache)...[/]")

        try:
            tool_registry.clear_cache()
            tools = list(tool_registry.TOOL_DEFINITIONS.keys())
            total = len(tools)

            for i, name in enumerate(tools):
                self._update_progress(i + 1, total, name)
                tool_registry.check(name)

                # Yield control periodically
                if i % 10 == 0:
                    await self.app.refresh()

            # Update displays
            summary = tool_registry.get_summary()
            self._update_summary(summary)

            # Update category panels
            for category in ToolCategory:
                tools_dict = {}
                for name in tool_registry.get_tools_in_category(category):
                    tools_dict[name] = tool_registry.check(name)

                for panel in self.query(CategoryPanel):
                    if panel.category == category:
                        panel.update_tools(tools_dict)
                        break

            self._update_progress(0, 0)
            self._write_output(
                f"[green]Full check complete.[/] "
                f"Installed: {summary['installed']}, Missing: {summary['missing']}"
            )

        except Exception as e:
            self._write_output(f"[red]Error during full check: {e}[/]")

        finally:
            self._checking = False

    async def _start_install_missing(self) -> None:
        """Start installing missing tools."""
        if self._installing:
            self._write_output("[yellow]Installation already in progress...[/]")
            return

        missing = tool_registry.get_missing_tools()
        if not missing:
            self._write_output("[green]All tools are already installed![/]")
            return

        # Filter to only tools with packages available
        installable = [
            name for name in missing
            if tool_registry.get_package_name(name) is not None
        ]

        if not installable:
            self._write_output(
                f"[yellow]Found {len(missing)} missing tools but none have "
                f"package manager support for {tool_registry.distro.value}[/]"
            )
            return

        self._installing = True
        self._write_output(
            f"[cyan]Installing {len(installable)} tools...[/]\n"
            f"[dim]This requires sudo privileges[/]"
        )

        self.run_worker(self._run_install(installable), exclusive=True)

    async def _run_install(self, tools: list[str]) -> None:
        """Run installation of tools."""
        try:
            total = len(tools)
            success_count = 0
            fail_count = 0

            for i, name in enumerate(tools):
                self._update_progress(i + 1, total, f"Installing {name}")
                self._write_output(f"[cyan]Installing {name}...[/]")

                success, msg = await tool_registry.install_tool(name)

                if success:
                    success_count += 1
                    self._write_output(f"[green]{msg}[/]")
                else:
                    fail_count += 1
                    self._write_output(f"[red]{msg}[/]")

            # Refresh displays
            self._update_progress(0, 0)
            await self._run_quick_check()

            self._write_output(
                f"[bold]Installation complete.[/] "
                f"[green]Success: {success_count}[/], [red]Failed: {fail_count}[/]"
            )

        except Exception as e:
            self._write_output(f"[red]Installation error: {e}[/]")

        finally:
            self._installing = False

    def action_refresh(self) -> None:
        """Refresh tool status."""
        tool_registry.clear_cache()
        self.run_worker(self._run_quick_check(), exclusive=True)

    def action_full_check(self) -> None:
        """Run full check."""
        self.run_worker(self._start_full_check())

    def action_install_missing(self) -> None:
        """Install missing tools."""
        self.run_worker(self._start_install_missing())
