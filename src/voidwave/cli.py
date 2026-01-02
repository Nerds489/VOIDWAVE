"""VOIDWAVE CLI interface using Typer."""
import asyncio
from pathlib import Path
from typing import Optional

import typer
from rich.console import Console
from rich.table import Table

from voidwave import __version__
from voidwave.core.logging import get_logger

app = typer.Typer(
    name="voidwave",
    help="VOIDWAVE - Offensive Security Framework",
    add_completion=True,
    invoke_without_command=True,  # Allow running without subcommand
)

console = Console()
logger = get_logger(__name__)


# Version callback
def version_callback(value: bool):
    """Show version information."""
    if value:
        console.print(f"VOIDWAVE v{__version__}", style="bold cyan")
        raise typer.Exit()


@app.callback(invoke_without_command=True)
def main(
    ctx: typer.Context,
    version: bool = typer.Option(
        None, "--version", "-v", callback=version_callback, is_eager=True
    ),
):
    """VOIDWAVE - Offensive Security Framework."""
    # If no subcommand given, launch TUI by default
    if ctx.invoked_subcommand is None:
        _launch_tui()


def _launch_tui():
    """Launch the interactive TUI."""
    try:
        from voidwave.tui.app import run_app

        run_app()
    except ImportError as e:
        console.print(
            f"[red]Error: TUI dependencies not available: {e}[/red]", style="bold"
        )
        console.print(
            "[yellow]Install with: pipx install 'voidwave[tui]'[/yellow]"
        )
        raise typer.Exit(1)


@app.command()
def tui():
    """Launch the interactive TUI."""
    _launch_tui()


@app.command()
def scan(
    target: str = typer.Argument(..., help="Target IP, CIDR, or hostname"),
    scan_type: str = typer.Option(
        "standard", "--type", "-t", help="Scan type (quick/standard/full)"
    ),
    ports: Optional[str] = typer.Option(None, "--ports", "-p", help="Port specification"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output file"),
):
    """Run a network scan."""

    async def run_scan():
        from voidwave.tools.nmap import NmapTool

        console.print(f"[cyan]Scanning {target}...[/cyan]")

        nmap = NmapTool()
        await nmap.initialize()

        options = {"scan_type": scan_type}
        if ports:
            options["ports"] = ports

        result = await nmap.execute(target, options)

        if result.success:
            console.print("[green]Scan completed![/green]")
            summary = result.data.get("summary", {})
            console.print(f"Total hosts: {summary.get('total_hosts', 0)}")
            console.print(f"Up hosts: {summary.get('up_hosts', 0)}")
            console.print(f"Open ports: {summary.get('open_ports', 0)}")

            if output:
                import json

                output.write_text(json.dumps(result.data, indent=2))
                console.print(f"[green]Results saved to {output}[/green]")
        else:
            console.print(f"[red]Scan failed: {result.errors}[/red]")

    asyncio.run(run_scan())


@app.command()
def status():
    """Show system status and tool availability."""

    async def show_status():
        from voidwave.detection.tools import tool_registry

        await tool_registry.detect_all()

        # Create table
        table = Table(title="VOIDWAVE System Status")
        table.add_column("Tool", style="cyan")
        table.add_column("Status", style="green")
        table.add_column("Version", style="yellow")
        table.add_column("Path", style="dim")

        for tool_name, tool_info in tool_registry.tools.items():
            status = "✓ Available" if tool_info.available else "✗ Missing"
            status_style = "green" if tool_info.available else "red"
            table.add_row(
                tool_name,
                f"[{status_style}]{status}[/{status_style}]",
                tool_info.version or "N/A",
                str(tool_info.path) if tool_info.path else "N/A",
            )

        console.print(table)

    asyncio.run(show_status())


@app.command()
def config(
    action: str = typer.Argument(..., help="Action: get, set, list"),
    key: Optional[str] = typer.Argument(None, help="Configuration key"),
    value: Optional[str] = typer.Argument(None, help="Configuration value"),
):
    """Manage configuration."""
    from voidwave.config.settings import get_settings

    settings = get_settings()

    if action == "list":
        console.print("[cyan]Current Configuration:[/cyan]")
        console.print(settings.model_dump_json(indent=2))
    elif action == "get" and key:
        # Get nested key
        parts = key.split(".")
        val = settings
        for part in parts:
            val = getattr(val, part)
        console.print(f"{key} = {val}")
    elif action == "set" and key and value:
        console.print(f"[yellow]Setting {key} = {value}[/yellow]")
        console.print("[dim]Configuration changes require restart[/dim]")
    else:
        console.print("[red]Invalid config command[/red]")
        raise typer.Exit(1)


# WiFi commands
wifi_app = typer.Typer(help="Wireless operations")
app.add_typer(wifi_app, name="wifi")


@wifi_app.command("scan")
def wifi_scan(
    interface: str = typer.Argument(..., help="Wireless interface"),
    timeout: int = typer.Option(30, "--timeout", "-t", help="Scan timeout in seconds"),
):
    """Scan for wireless networks."""

    async def run_wifi_scan():
        console.print(f"[cyan]Scanning wireless networks on {interface}...[/cyan]")
        console.print(
            "[yellow]This feature requires full wireless module implementation[/yellow]"
        )

    asyncio.run(run_wifi_scan())


@wifi_app.command("monitor")
def wifi_monitor(
    action: str = typer.Argument(..., help="Action: enable, disable, status"),
    interface: str = typer.Argument(..., help="Wireless interface"),
):
    """Manage monitor mode."""

    async def manage_monitor():
        from voidwave.wireless.monitor import (
            disable_monitor_mode,
            enable_monitor_mode,
            get_monitor_status,
        )

        if action == "enable":
            console.print(f"[cyan]Enabling monitor mode on {interface}...[/cyan]")
            monitor_iface = await enable_monitor_mode(interface)
            console.print(f"[green]Monitor mode enabled: {monitor_iface}[/green]")
        elif action == "disable":
            console.print(f"[cyan]Disabling monitor mode on {interface}...[/cyan]")
            managed = await disable_monitor_mode(interface)
            console.print(f"[green]Monitor mode disabled: {managed}[/green]")
        elif action == "status":
            status = await get_monitor_status(interface)
            console.print(f"Interface: {interface}")
            console.print(f"Exists: {status.get('exists')}")
            console.print(f"Is wireless: {status.get('is_wireless')}")
            console.print(f"Current mode: {status.get('current_mode')}")
            console.print(f"Supports monitor: {status.get('supports_monitor')}")
        else:
            console.print("[red]Invalid action. Use: enable, disable, or status[/red]")
            raise typer.Exit(1)

    asyncio.run(manage_monitor())


# Plugin commands
plugin_app = typer.Typer(help="Plugin management")
app.add_typer(plugin_app, name="plugin")


@plugin_app.command("list")
def plugin_list():
    """List all available plugins."""

    async def list_plugins():
        from voidwave.plugins.registry import plugin_registry

        await plugin_registry.initialize()

        table = Table(title="Available Plugins")
        table.add_column("Name", style="cyan")
        table.add_column("Type", style="yellow")
        table.add_column("Version", style="green")
        table.add_column("Description", style="dim")

        for plugin in plugin_registry.list_all():
            table.add_row(
                plugin.name,
                plugin.metadata.plugin_type.value,
                plugin.metadata.version,
                plugin.metadata.description,
            )

        console.print(table)

    asyncio.run(list_plugins())


if __name__ == "__main__":
    app()
