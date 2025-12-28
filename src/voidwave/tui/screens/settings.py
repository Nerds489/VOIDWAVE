"""Settings screen with configuration management."""
from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

from textual.app import ComposeResult
from textual.containers import Horizontal, ScrollableContainer, Vertical
from textual.screen import Screen
from textual.widgets import (
    Button,
    Checkbox,
    Input,
    Label,
    ListItem,
    ListView,
    Select,
    Static,
    Switch,
)

from voidwave.config.keys import API_SERVICES, APIService, api_key_manager
from voidwave.config.settings import get_settings, reload_settings
from voidwave.core.constants import LogLevel
from voidwave.core.logging import get_logger

if TYPE_CHECKING:
    pass

logger = get_logger(__name__)


class SettingsCategory:
    """Settings category definition."""

    def __init__(self, name: str, icon: str, description: str):
        self.name = name
        self.icon = icon
        self.description = description


SETTINGS_CATEGORIES = [
    SettingsCategory("General", "🔧", "General application settings"),
    SettingsCategory("Logging", "📝", "Logging and debug options"),
    SettingsCategory("Wireless", "📡", "Wireless attack settings"),
    SettingsCategory("Scanning", "🔍", "Network scanning options"),
    SettingsCategory("Credentials", "🔑", "Password cracking settings"),
    SettingsCategory("Safety", "🛡️", "Safety and authorization"),
    SettingsCategory("API Keys", "🔐", "External service API keys"),
    SettingsCategory("Paths", "📁", "Output and file paths"),
    SettingsCategory("Actions", "⚡", "Import, export, and reset"),
]


class SettingsScreen(Screen):
    """Configuration and settings management screen."""

    CSS = """
    SettingsScreen {
        layout: grid;
        grid-size: 2 2;
        grid-columns: 1fr 3fr;
        grid-rows: 1fr auto;
    }

    #category-menu {
        height: 100%;
        border: solid $primary;
        padding: 1;
    }

    #category-menu Label {
        padding: 0 1;
        margin-bottom: 1;
    }

    #settings-panel {
        height: 100%;
        border: solid $secondary;
        padding: 1 2;
    }

    #output-panel {
        column-span: 2;
        height: 6;
        border: solid $surface;
        padding: 1;
    }

    .settings-group {
        margin-bottom: 2;
    }

    .settings-label {
        margin-bottom: 0;
    }

    .settings-description {
        color: $text-muted;
        margin-bottom: 1;
    }

    .settings-input {
        margin-bottom: 1;
    }

    .settings-row {
        height: auto;
        margin-bottom: 1;
    }

    .api-key-row {
        height: 3;
        margin-bottom: 1;
    }

    .api-key-status {
        margin-left: 1;
    }

    #save-button {
        margin-top: 2;
    }
    """

    BINDINGS = [
        ("escape", "app.pop_screen", "Back"),
        ("ctrl+s", "save_settings", "Save"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self._current_category = "General"
        self._modified = False

    def compose(self) -> ComposeResult:
        # Left: Category menu
        with Vertical(id="category-menu"):
            yield Label("[bold magenta]Settings Categories[/]")
            with ListView(id="settings-menu"):
                for cat in SETTINGS_CATEGORIES:
                    yield ListItem(
                        Static(f"{cat.icon} {cat.name}"),
                        id=f"cat-{cat.name.lower().replace(' ', '-')}",
                        name=cat.name,
                    )

        # Right: Settings panel
        with ScrollableContainer(id="settings-panel"):
            yield Label("[bold cyan]General Settings[/]", id="panel-title")
            yield Static("[dim]Select a category from the left menu[/]", id="panel-content")

        # Bottom: Output
        with Vertical(id="output-panel"):
            yield Label("[bold]Status[/]")
            yield Static("Settings loaded", id="settings-output")

    async def on_mount(self) -> None:
        """Initialize screen."""
        self._show_category("General")

    async def on_list_view_selected(self, event: ListView.Selected) -> None:
        """Handle category selection."""
        if event.item.name:
            self._show_category(event.item.name)

    def _show_category(self, category: str) -> None:
        """Display settings for a category."""
        self._current_category = category

        title = self.query_one("#panel-title", Label)
        content = self.query_one("#panel-content", Static)
        panel = self.query_one("#settings-panel", ScrollableContainer)

        # Find category info
        cat_info = next((c for c in SETTINGS_CATEGORIES if c.name == category), None)
        if cat_info:
            title.update(f"[bold cyan]{cat_info.icon} {cat_info.name}[/]")

        # Remove old content (except title)
        for widget in panel.query("*"):
            if widget.id not in ("panel-title",):
                widget.remove()

        # Add new content based on category
        if category == "General":
            self._compose_general_settings(panel)
        elif category == "Logging":
            self._compose_logging_settings(panel)
        elif category == "Wireless":
            self._compose_wireless_settings(panel)
        elif category == "Scanning":
            self._compose_scanning_settings(panel)
        elif category == "Credentials":
            self._compose_credentials_settings(panel)
        elif category == "Safety":
            self._compose_safety_settings(panel)
        elif category == "API Keys":
            self._compose_api_key_settings(panel)
        elif category == "Paths":
            self._compose_path_settings(panel)
        elif category == "Actions":
            self._compose_actions(panel)

    def _compose_general_settings(self, panel: ScrollableContainer) -> None:
        """Compose general settings form."""
        settings = get_settings()

        panel.mount(Label("[dim]General application settings[/]", classes="settings-description"))

        # Theme
        panel.mount(Label("Theme", classes="settings-label"))
        panel.mount(
            Select(
                [(theme, theme) for theme in ["cyberpunk", "dark", "light", "hacker"]],
                value=settings.ui.theme,
                id="setting-theme",
                classes="settings-input",
            )
        )

        # Show banner
        panel.mount(
            Horizontal(
                Switch(value=settings.ui.show_banner, id="setting-show-banner"),
                Label(" Show startup banner"),
                classes="settings-row",
            )
        )

        # Vim bindings
        panel.mount(
            Horizontal(
                Switch(value=settings.ui.vim_bindings, id="setting-vim-bindings"),
                Label(" Enable Vim-style key bindings"),
                classes="settings-row",
            )
        )

        # Non-interactive mode
        panel.mount(
            Horizontal(
                Switch(value=settings.non_interactive, id="setting-non-interactive"),
                Label(" Non-interactive mode (no prompts)"),
                classes="settings-row",
            )
        )

        # Debug mode
        panel.mount(
            Horizontal(
                Switch(value=settings.debug, id="setting-debug"),
                Label(" Debug mode"),
                classes="settings-row",
            )
        )

        panel.mount(Button("Save Settings", id="save-button", variant="primary"))

    def _compose_logging_settings(self, panel: ScrollableContainer) -> None:
        """Compose logging settings form."""
        settings = get_settings()

        panel.mount(Label("[dim]Logging and debug configuration[/]", classes="settings-description"))

        # Log level
        panel.mount(Label("Log Level", classes="settings-label"))
        panel.mount(
            Select(
                [(level.value, level.value) for level in LogLevel],
                value=settings.logging.level.value,
                id="setting-log-level",
                classes="settings-input",
            )
        )

        # File logging
        panel.mount(
            Horizontal(
                Switch(value=settings.logging.file_logging, id="setting-file-logging"),
                Label(" Enable file logging"),
                classes="settings-row",
            )
        )

        # Log directory
        panel.mount(Label("Log Directory", classes="settings-label"))
        panel.mount(
            Input(
                value=str(settings.logging.log_dir),
                id="setting-log-dir",
                classes="settings-input",
            )
        )

        # Max file size
        panel.mount(Label("Max Log File Size (bytes)", classes="settings-label"))
        panel.mount(
            Input(
                value=str(settings.logging.max_file_size),
                id="setting-max-file-size",
                type="integer",
                classes="settings-input",
            )
        )

        # Backup count
        panel.mount(Label("Log Backup Count", classes="settings-label"))
        panel.mount(
            Input(
                value=str(settings.logging.backup_count),
                id="setting-backup-count",
                type="integer",
                classes="settings-input",
            )
        )

        panel.mount(Button("Save Settings", id="save-button", variant="primary"))

    def _compose_wireless_settings(self, panel: ScrollableContainer) -> None:
        """Compose wireless settings form."""
        settings = get_settings()

        panel.mount(Label("[dim]Wireless attack configuration[/]", classes="settings-description"))

        # Default interface
        panel.mount(Label("Default Interface", classes="settings-label"))
        panel.mount(
            Input(
                value=settings.wireless.default_interface or "",
                placeholder="e.g., wlan0",
                id="setting-wireless-interface",
                classes="settings-input",
            )
        )

        # Monitor interface prefix
        panel.mount(Label("Monitor Interface Prefix", classes="settings-label"))
        panel.mount(
            Input(
                value=settings.wireless.monitor_interface_prefix,
                id="setting-monitor-prefix",
                classes="settings-input",
            )
        )

        # Deauth count
        panel.mount(Label("Deauth Packet Count", classes="settings-label"))
        panel.mount(
            Input(
                value=str(settings.wireless.deauth_count),
                id="setting-deauth-count",
                type="integer",
                classes="settings-input",
            )
        )

        # Channel hop interval
        panel.mount(Label("Channel Hop Interval (seconds)", classes="settings-label"))
        panel.mount(
            Input(
                value=str(settings.wireless.channel_hop_interval),
                id="setting-channel-hop",
                type="number",
                classes="settings-input",
            )
        )

        # Handshake timeout
        panel.mount(Label("Handshake Capture Timeout (seconds)", classes="settings-label"))
        panel.mount(
            Input(
                value=str(settings.wireless.handshake_timeout),
                id="setting-handshake-timeout",
                type="integer",
                classes="settings-input",
            )
        )

        panel.mount(Button("Save Settings", id="save-button", variant="primary"))

    def _compose_scanning_settings(self, panel: ScrollableContainer) -> None:
        """Compose scanning settings form."""
        settings = get_settings()

        panel.mount(Label("[dim]Network scanning configuration[/]", classes="settings-description"))

        # Default scan type
        panel.mount(Label("Default Scan Type", classes="settings-label"))
        panel.mount(
            Select(
                [("quick", "quick"), ("standard", "standard"), ("full", "full"), ("stealth", "stealth")],
                value=settings.scanning.default_scan_type,
                id="setting-scan-type",
                classes="settings-input",
            )
        )

        # Default ports
        panel.mount(Label("Default Port Range", classes="settings-label"))
        panel.mount(
            Input(
                value=settings.scanning.default_ports,
                placeholder="e.g., 1-1000, 22,80,443",
                id="setting-default-ports",
                classes="settings-input",
            )
        )

        # Timing template
        panel.mount(Label("Nmap Timing Template (T0-T5)", classes="settings-label"))
        panel.mount(
            Select(
                [(f"T{i}", str(i)) for i in range(6)],
                value=str(settings.scanning.timing_template),
                id="setting-timing",
                classes="settings-input",
            )
        )

        # Max concurrent hosts
        panel.mount(Label("Max Concurrent Hosts", classes="settings-label"))
        panel.mount(
            Input(
                value=str(settings.scanning.max_concurrent_hosts),
                id="setting-max-hosts",
                type="integer",
                classes="settings-input",
            )
        )

        panel.mount(Button("Save Settings", id="save-button", variant="primary"))

    def _compose_credentials_settings(self, panel: ScrollableContainer) -> None:
        """Compose credentials settings form."""
        settings = get_settings()

        panel.mount(Label("[dim]Password cracking configuration[/]", classes="settings-description"))

        # Default wordlist
        panel.mount(Label("Default Wordlist Path", classes="settings-label"))
        panel.mount(
            Input(
                value=str(settings.credentials.default_wordlist),
                id="setting-wordlist",
                classes="settings-input",
            )
        )

        # Hashcat workload
        panel.mount(Label("Hashcat Workload Profile (1-4)", classes="settings-label"))
        panel.mount(
            Select(
                [("Low (1)", "1"), ("Default (2)", "2"), ("High (3)", "3"), ("Insane (4)", "4")],
                value=str(settings.credentials.hashcat_workload),
                id="setting-hashcat-workload",
                classes="settings-input",
            )
        )

        # John format
        panel.mount(Label("John the Ripper Format Override", classes="settings-label"))
        panel.mount(
            Input(
                value=settings.credentials.john_format or "",
                placeholder="Leave empty for auto-detect",
                id="setting-john-format",
                classes="settings-input",
            )
        )

        panel.mount(Button("Save Settings", id="save-button", variant="primary"))

    def _compose_safety_settings(self, panel: ScrollableContainer) -> None:
        """Compose safety settings form."""
        settings = get_settings()

        panel.mount(Label("[dim]Safety and authorization controls[/]", classes="settings-description"))

        # Confirm dangerous
        panel.mount(
            Horizontal(
                Switch(value=settings.safety.confirm_dangerous, id="setting-confirm-dangerous"),
                Label(" Confirm dangerous operations"),
                classes="settings-row",
            )
        )

        # Warn public IP
        panel.mount(
            Horizontal(
                Switch(value=settings.safety.warn_public_ip, id="setting-warn-public"),
                Label(" Warn when targeting public IPs"),
                classes="settings-row",
            )
        )

        # Require authorization
        panel.mount(
            Horizontal(
                Switch(value=settings.safety.require_authorization, id="setting-require-auth"),
                Label(" Require authorization confirmation"),
                classes="settings-row",
            )
        )

        # Dry run
        panel.mount(
            Horizontal(
                Switch(value=settings.safety.dry_run, id="setting-dry-run"),
                Label(" Dry run mode (no actual attacks)"),
                classes="settings-row",
            )
        )

        # Unsafe mode (dangerous!)
        panel.mount(Static(""))
        panel.mount(Label("[bold red]Danger Zone[/]"))
        panel.mount(
            Horizontal(
                Switch(value=settings.safety.unsafe_mode, id="setting-unsafe-mode"),
                Label(" [red]Unsafe mode (disable all safety checks)[/]"),
                classes="settings-row",
            )
        )

        panel.mount(Button("Save Settings", id="save-button", variant="primary"))

    def _compose_api_key_settings(self, panel: ScrollableContainer) -> None:
        """Compose API key settings form."""
        panel.mount(Label("[dim]Configure API keys for external services[/]", classes="settings-description"))

        # Keyring status
        status = api_key_manager.get_status()
        if status["keyring_available"]:
            panel.mount(Static("[green]Secure keyring storage available[/]"))
        else:
            panel.mount(Static("[yellow]Keyring not available - keys stored in memory only[/]"))

        panel.mount(Static(""))

        # API key entries
        for service in APIService:
            info = API_SERVICES.get(service)
            if info is None:
                continue  # Skip services without metadata

            has_key = api_key_manager.has_key(service)

            status_text = "[green]Configured[/]" if has_key else "[dim]Not set[/]"

            panel.mount(Label(f"[bold]{info.display_name}[/] - {info.description}", classes="settings-label"))

            # Create row container with children properly
            row = Horizontal(
                Input(
                    value="••••••••" if has_key else "",
                    placeholder="Enter API key",
                    password=True,
                    id=f"api-key-{service.value}",
                ),
                Button("Set", id=f"api-set-{service.value}"),
                Button("Clear", id=f"api-clear-{service.value}", variant="warning"),
                Static(status_text, classes="api-key-status"),
                classes="api-key-row",
            )
            panel.mount(row)

    def _compose_path_settings(self, panel: ScrollableContainer) -> None:
        """Compose path settings form."""
        settings = get_settings()

        panel.mount(Label("[dim]Output and storage paths[/]", classes="settings-description"))

        # Output directory
        panel.mount(Label("Output Directory", classes="settings-label"))
        panel.mount(
            Input(
                value=str(settings.output_dir),
                id="setting-output-dir",
                classes="settings-input",
            )
        )

        # Database path
        panel.mount(Label("Database Path", classes="settings-label"))
        panel.mount(
            Input(
                value=str(settings.database.path),
                id="setting-db-path",
                classes="settings-input",
            )
        )

        panel.mount(Button("Save Settings", id="save-button", variant="primary"))

    def _compose_actions(self, panel: ScrollableContainer) -> None:
        """Compose actions panel."""
        panel.mount(Label("[dim]Import, export, and reset actions[/]", classes="settings-description"))

        # Export
        panel.mount(Label("[bold]Export Configuration[/]"))
        panel.mount(Static("Export current settings to a TOML file"))
        panel.mount(Button("Export Settings", id="action-export", variant="primary"))

        panel.mount(Static(""))

        # Import
        panel.mount(Label("[bold]Import Configuration[/]"))
        panel.mount(Static("Import settings from a TOML file"))
        panel.mount(
            Input(
                placeholder="Path to config file",
                id="import-path",
                classes="settings-input",
            )
        )
        panel.mount(Button("Import Settings", id="action-import", variant="primary"))

        panel.mount(Static(""))

        # Reset
        panel.mount(Label("[bold red]Reset to Defaults[/]"))
        panel.mount(Static("[dim]This will reset all settings to their default values[/]"))
        panel.mount(Button("Reset All Settings", id="action-reset", variant="error"))

        # Reload
        panel.mount(Static(""))
        panel.mount(Label("[bold]Reload from File[/]"))
        panel.mount(Static("[dim]Reload settings from the config file[/]"))
        panel.mount(Button("Reload Settings", id="action-reload"))

    def _write_output(self, message: str) -> None:
        """Write message to output panel."""
        output = self.query_one("#settings-output", Static)
        output.update(message)

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        button_id = event.button.id

        if button_id == "save-button":
            self._save_current_category()
        elif button_id == "action-export":
            self._export_settings()
        elif button_id == "action-import":
            self._import_settings()
        elif button_id == "action-reset":
            self._reset_settings()
        elif button_id == "action-reload":
            self._reload_settings()
        elif button_id and button_id.startswith("api-set-"):
            service_name = button_id.replace("api-set-", "")
            self._set_api_key(service_name)
        elif button_id and button_id.startswith("api-clear-"):
            service_name = button_id.replace("api-clear-", "")
            self._clear_api_key(service_name)

    def _save_current_category(self) -> None:
        """Save settings for the current category."""
        try:
            settings = get_settings()
            category = self._current_category

            if category == "General":
                # Get values from UI
                theme_select = self.query_one("#setting-theme", Select)
                if theme_select.value:
                    settings.ui.theme = str(theme_select.value)

                settings.ui.show_banner = self.query_one("#setting-show-banner", Switch).value
                settings.ui.vim_bindings = self.query_one("#setting-vim-bindings", Switch).value
                settings.non_interactive = self.query_one("#setting-non-interactive", Switch).value
                settings.debug = self.query_one("#setting-debug", Switch).value

            elif category == "Logging":
                level_select = self.query_one("#setting-log-level", Select)
                if level_select.value:
                    settings.logging.level = LogLevel(level_select.value)

                settings.logging.file_logging = self.query_one("#setting-file-logging", Switch).value
                settings.logging.log_dir = Path(self.query_one("#setting-log-dir", Input).value)

                max_size = self.query_one("#setting-max-file-size", Input).value
                if max_size.isdigit():
                    settings.logging.max_file_size = int(max_size)

                backup = self.query_one("#setting-backup-count", Input).value
                if backup.isdigit():
                    settings.logging.backup_count = int(backup)

            elif category == "Wireless":
                iface = self.query_one("#setting-wireless-interface", Input).value
                settings.wireless.default_interface = iface if iface else None
                settings.wireless.monitor_interface_prefix = self.query_one("#setting-monitor-prefix", Input).value

                deauth = self.query_one("#setting-deauth-count", Input).value
                if deauth.isdigit():
                    settings.wireless.deauth_count = int(deauth)

                hop = self.query_one("#setting-channel-hop", Input).value
                try:
                    settings.wireless.channel_hop_interval = float(hop)
                except ValueError:
                    pass

                timeout = self.query_one("#setting-handshake-timeout", Input).value
                if timeout.isdigit():
                    settings.wireless.handshake_timeout = int(timeout)

            elif category == "Scanning":
                scan_type = self.query_one("#setting-scan-type", Select)
                if scan_type.value:
                    settings.scanning.default_scan_type = str(scan_type.value)

                settings.scanning.default_ports = self.query_one("#setting-default-ports", Input).value

                timing = self.query_one("#setting-timing", Select)
                if timing.value:
                    settings.scanning.timing_template = int(timing.value)

                max_hosts = self.query_one("#setting-max-hosts", Input).value
                if max_hosts.isdigit():
                    settings.scanning.max_concurrent_hosts = int(max_hosts)

            elif category == "Credentials":
                settings.credentials.default_wordlist = Path(self.query_one("#setting-wordlist", Input).value)

                workload = self.query_one("#setting-hashcat-workload", Select)
                if workload.value:
                    settings.credentials.hashcat_workload = int(workload.value)

                john_fmt = self.query_one("#setting-john-format", Input).value
                settings.credentials.john_format = john_fmt if john_fmt else None

            elif category == "Safety":
                settings.safety.confirm_dangerous = self.query_one("#setting-confirm-dangerous", Switch).value
                settings.safety.warn_public_ip = self.query_one("#setting-warn-public", Switch).value
                settings.safety.require_authorization = self.query_one("#setting-require-auth", Switch).value
                settings.safety.dry_run = self.query_one("#setting-dry-run", Switch).value
                settings.safety.unsafe_mode = self.query_one("#setting-unsafe-mode", Switch).value

            elif category == "Paths":
                settings.output_dir = Path(self.query_one("#setting-output-dir", Input).value)
                settings.database.path = Path(self.query_one("#setting-db-path", Input).value)

            # Save to file
            settings.save()
            self._write_output(f"[green]Settings saved for {category}[/]")

        except Exception as e:
            self._write_output(f"[red]Failed to save settings: {e}[/]")

    def _set_api_key(self, service_name: str) -> None:
        """Set an API key."""
        try:
            service = APIService(service_name)
            input_widget = self.query_one(f"#api-key-{service_name}", Input)
            key = input_widget.value

            if key and key != "••••••••":
                if api_key_manager.set_key(service, key):
                    self._write_output(f"[green]API key set for {service_name}[/]")
                    # Refresh the panel
                    self._show_category("API Keys")
                else:
                    self._write_output(f"[red]Failed to set API key for {service_name}[/]")
            else:
                self._write_output(f"[yellow]Please enter a valid API key[/]")

        except Exception as e:
            self._write_output(f"[red]Error setting API key: {e}[/]")

    def _clear_api_key(self, service_name: str) -> None:
        """Clear an API key."""
        try:
            service = APIService(service_name)
            api_key_manager.delete_key(service)
            self._write_output(f"[green]API key cleared for {service_name}[/]")
            # Refresh the panel
            self._show_category("API Keys")

        except Exception as e:
            self._write_output(f"[red]Error clearing API key: {e}[/]")

    def _export_settings(self) -> None:
        """Export settings to file."""
        try:
            settings = get_settings()
            export_path = Path.home() / "voidwave_settings_export.toml"
            settings.save(export_path)
            self._write_output(f"[green]Settings exported to {export_path}[/]")
        except Exception as e:
            self._write_output(f"[red]Export failed: {e}[/]")

    def _import_settings(self) -> None:
        """Import settings from file."""
        try:
            import_path = self.query_one("#import-path", Input).value
            if not import_path:
                self._write_output("[yellow]Please enter a path to import from[/]")
                return

            path = Path(import_path).expanduser()
            if not path.exists():
                self._write_output(f"[red]File not found: {path}[/]")
                return

            # Load and save the imported settings
            from voidwave.config.settings import Settings

            imported = Settings.load(path)
            imported.save()  # Save to default location

            # Reload
            reload_settings()
            self._show_category(self._current_category)
            self._write_output(f"[green]Settings imported from {path}[/]")

        except Exception as e:
            self._write_output(f"[red]Import failed: {e}[/]")

    def _reset_settings(self) -> None:
        """Reset settings to defaults."""
        try:
            from voidwave.config.settings import Settings

            default_settings = Settings()
            default_settings.save()
            reload_settings()
            self._show_category(self._current_category)
            self._write_output("[green]Settings reset to defaults[/]")
        except Exception as e:
            self._write_output(f"[red]Reset failed: {e}[/]")

    def _reload_settings(self) -> None:
        """Reload settings from file."""
        try:
            reload_settings()
            self._show_category(self._current_category)
            self._write_output("[green]Settings reloaded from file[/]")
        except Exception as e:
            self._write_output(f"[red]Reload failed: {e}[/]")

    def action_save_settings(self) -> None:
        """Save settings action."""
        self._save_current_category()
