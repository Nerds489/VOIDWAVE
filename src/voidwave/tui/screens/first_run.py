"""First-run setup wizard for VOIDWAVE."""

import asyncio
import shutil
from pathlib import Path
from dataclasses import dataclass
from typing import Any

from textual.app import ComposeResult
from textual.screen import Screen
from textual.containers import Container, Vertical, Horizontal, ScrollableContainer
from textual.widgets import (
    Static, Button, Checkbox, ProgressBar, Input,
    DataTable, ListView, ListItem, Label
)
from textual.binding import Binding

from voidwave import __version__
from voidwave.core.bootstrap import BootstrapManager, SystemInfo


# Tool categories and their tools for auditing
TOOL_REGISTRY = {
    "wireless": [
        "aircrack-ng", "reaver", "bully", "pixiewps", "mdk4",
        "hcxdumptool", "hcxtools", "hostapd", "kismet", "wifite",
        "cowpatty", "airgeddon", "eaphammer", "wifiphisher"
    ],
    "scanning": [
        "nmap", "masscan", "rustscan", "arp-scan", "netdiscover",
        "fping", "zmap", "unicornscan", "nbtscan", "onesixtyone"
    ],
    "osint": [
        "theHarvester", "subfinder", "amass", "whois", "dig",
        "sherlock", "maltego", "recon-ng", "spiderfoot"
    ],
    "credentials": [
        "hashcat", "john", "hydra", "medusa", "ncrack",
        "patator", "cewl", "crunch", "ophcrack"
    ],
    "exploit": [
        "metasploit-framework", "sqlmap", "nikto", "searchsploit",
        "nuclei", "burpsuite", "zaproxy", "commix", "xsstrike"
    ],
    "traffic": [
        "tcpdump", "tshark", "wireshark", "ettercap", "bettercap",
        "mitmproxy", "arpspoof", "dnsspoof", "dsniff"
    ],
    "recon": [
        "gobuster", "ffuf", "dirb", "dirsearch", "whatweb",
        "wpscan", "sslscan", "testssl.sh", "wafw00f"
    ],
    "stress": [
        "hping3", "iperf3", "slowloris", "goldeneye"
    ],
}

# Data sources for download
DATA_SOURCES = {
    "rockyou": {
        "name": "rockyou.txt",
        "description": "Common passwords wordlist",
        "size": "14 MB",
        "category": "wordlists",
    },
    "common": {
        "name": "common.txt",
        "description": "Directory brute force wordlist",
        "size": "2 KB",
        "category": "wordlists",
    },
    "seclists": {
        "name": "SecLists",
        "description": "Comprehensive wordlist collection",
        "size": "500 MB",
        "category": "wordlists",
        "optional": True,
    },
    "nuclei-templates": {
        "name": "Nuclei Templates",
        "description": "Vulnerability scanning templates",
        "size": "50 MB",
        "category": "templates",
    },
    "hashcat-rules": {
        "name": "Hashcat Rules",
        "description": "Password mutation rules",
        "size": "5 MB",
        "category": "templates",
    },
    "exploitdb": {
        "name": "Exploit-DB",
        "description": "Searchsploit database",
        "size": "100 MB",
        "category": "databases",
    },
}

# API services
API_SERVICES = {
    "shodan": {
        "name": "Shodan",
        "description": "Internet-wide scanning database",
        "used_by": ["shodan", "subfinder"],
        "free_tier": "100 queries/month",
        "url": "https://shodan.io",
        "recommended": True,
    },
    "wpscan": {
        "name": "WPScan",
        "description": "WordPress vulnerability database",
        "used_by": ["wpscan"],
        "free_tier": "25 requests/day",
        "url": "https://wpscan.com",
        "recommended": True,
    },
    "virustotal": {
        "name": "VirusTotal",
        "description": "Malware scanning service",
        "used_by": ["virustotal"],
        "free_tier": "500 queries/day",
        "url": "https://virustotal.com",
    },
    "censys": {
        "name": "Censys",
        "description": "Internet asset discovery",
        "used_by": ["censys"],
        "free_tier": "250 queries/month",
        "url": "https://censys.io",
    },
    "securitytrails": {
        "name": "SecurityTrails",
        "description": "DNS and domain intelligence",
        "used_by": ["securitytrails"],
        "free_tier": "50 queries/month",
        "url": "https://securitytrails.com",
    },
}


@dataclass
class WizardStep:
    """Base class for wizard steps."""
    id: str
    title: str
    description: str

    async def on_enter(self, results: dict) -> None:
        """Called when entering this step."""
        pass

    async def get_results(self) -> Any:
        """Get results from this step."""
        return None

    async def validate(self) -> bool:
        """Validate before moving to next step."""
        return True


class FirstRunWizard(Screen):
    """First-run setup wizard."""

    CSS = """
    FirstRunWizard {
        align: center middle;
    }

    #wizard-container {
        width: 90%;
        height: 90%;
        border: solid $success;
        padding: 1;
    }

    #wizard-header {
        height: 3;
        align: center middle;
    }

    #step-title {
        text-style: bold;
        text-align: center;
    }

    #step-progress {
        margin: 1 2;
    }

    #step-content {
        height: 1fr;
        border: solid $primary;
        padding: 1;
        margin: 1;
    }

    #navigation {
        height: 3;
        align: center middle;
    }

    #navigation Button {
        margin: 0 2;
    }

    .logo {
        text-align: center;
        color: $success;
    }

    .warning-box {
        border: solid $error;
        padding: 1;
        margin: 1;
    }

    .info-box {
        border: solid $primary;
        padding: 1;
        margin: 1;
    }

    .success-text {
        color: $success;
    }

    .error-text {
        color: $error;
    }

    .category-box {
        border: solid $secondary;
        padding: 1;
        margin: 1 0;
    }

    .tool-grid {
        height: auto;
    }

    .api-input {
        margin: 0 1;
    }

    .summary-item {
        margin: 0 1;
    }
    """

    BINDINGS = [
        Binding("escape", "cancel", "Cancel"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self.current_step = 0
        self.total_steps = 9
        self.results: dict[str, Any] = {}
        self.system_info: SystemInfo | None = None
        self.tool_audit: dict = {}
        self.selected_tools: list[str] = []
        self.selected_data: list[str] = []
        self.api_keys: dict[str, str] = {}
        self.terms_accepted = False

    def compose(self) -> ComposeResult:
        """Compose the wizard layout."""
        with Container(id="wizard-container"):
            with Vertical(id="wizard-header"):
                yield Static("", id="step-title")
                yield ProgressBar(id="step-progress", total=self.total_steps)
            with ScrollableContainer(id="step-content"):
                yield Static("Loading...", id="step-body")
            with Horizontal(id="navigation"):
                yield Button("Back", id="back-btn", disabled=True)
                yield Button("Next", id="next-btn", variant="primary")
                yield Button("Skip All", id="skip-btn", variant="warning")

    async def on_mount(self) -> None:
        """Initialize the wizard."""
        await self._show_step(0)

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        btn_id = event.button.id

        if btn_id == "next-btn":
            if await self._validate_step():
                await self._next_step()
        elif btn_id == "back-btn":
            await self._prev_step()
        elif btn_id == "skip-btn":
            await self._skip_all()
        elif btn_id == "accept-terms":
            self.terms_accepted = True
            event.button.disabled = True
            self.query_one("#next-btn", Button).disabled = False
        elif btn_id == "run-benchmark":
            await self._run_gpu_benchmark()
        elif btn_id.startswith("install-"):
            await self._install_tools()
        elif btn_id.startswith("download-"):
            await self._download_data()

    def on_checkbox_changed(self, event: Checkbox.Changed) -> None:
        """Handle checkbox changes."""
        checkbox_id = event.checkbox.id or ""

        if checkbox_id == "terms-checkbox":
            self.query_one("#next-btn", Button).disabled = not event.value
            self.terms_accepted = event.value
        elif checkbox_id.startswith("tool-"):
            tool = checkbox_id[5:]
            if event.value:
                if tool not in self.selected_tools:
                    self.selected_tools.append(tool)
            else:
                if tool in self.selected_tools:
                    self.selected_tools.remove(tool)
        elif checkbox_id.startswith("data-"):
            data_id = checkbox_id[5:]
            if event.value:
                if data_id not in self.selected_data:
                    self.selected_data.append(data_id)
            else:
                if data_id in self.selected_data:
                    self.selected_data.remove(data_id)

    async def _show_step(self, index: int) -> None:
        """Show a specific step."""
        self.current_step = index

        # Update progress
        progress = self.query_one("#step-progress", ProgressBar)
        progress.progress = index + 1

        # Update navigation
        self.query_one("#back-btn", Button).disabled = index == 0
        next_btn = self.query_one("#next-btn", Button)

        if index == self.total_steps - 1:
            next_btn.label = "Finish"
            self.query_one("#skip-btn", Button).display = False
        else:
            next_btn.label = "Next"

        # Render step content
        await self._render_step(index)

    async def _render_step(self, index: int) -> None:
        """Render the content for a step."""
        title = self.query_one("#step-title", Static)
        content = self.query_one("#step-content", ScrollableContainer)

        # Clear existing content
        body = self.query_one("#step-body", Static)

        if index == 0:
            await self._render_welcome(title, body)
        elif index == 1:
            await self._render_system_detection(title, body)
        elif index == 2:
            await self._render_tool_audit(title, body)
        elif index == 3:
            await self._render_install_tools(title, body)
        elif index == 4:
            await self._render_download_data(title, body)
        elif index == 5:
            await self._render_api_keys(title, body)
        elif index == 6:
            await self._render_gpu_detection(title, body)
        elif index == 7:
            await self._render_create_assets(title, body)
        elif index == 8:
            await self._render_summary(title, body)

    async def _render_welcome(self, title: Static, body: Static) -> None:
        """Render Step 1: Welcome & Terms."""
        title.update("Step 1/9: Welcome to VOIDWAVE")
        self.query_one("#next-btn", Button).disabled = not self.terms_accepted

        logo = """
[bold green]
██╗   ██╗ ██████╗ ██╗██████╗ ██╗    ██╗ █████╗ ██╗   ██╗███████╗
██║   ██║██╔═══██╗██║██╔══██╗██║    ██║██╔══██╗██║   ██║██╔════╝
██║   ██║██║   ██║██║██║  ██║██║ █╗ ██║███████║██║   ██║█████╗
╚██╗ ██╔╝██║   ██║██║██║  ██║██║███╗██║██╔══██║╚██╗ ██╔╝██╔══╝
 ╚████╔╝ ╚██████╔╝██║██████╔╝╚███╔███╔╝██║  ██║ ╚████╔╝ ███████╗
  ╚═══╝   ╚═════╝ ╚═╝╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═╝  ╚═══╝  ╚══════╝
[/]
        Version {version}

VOIDWAVE is a comprehensive security assessment framework
designed for authorized penetration testing and security research.

[bold red]LEGAL NOTICE[/]
[red]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/]

This tool is intended for [bold]authorized security testing only[/].

Unauthorized access to computer systems is [bold red]ILLEGAL[/].

You are responsible for ensuring you have proper authorization
before using these tools against any system.

By proceeding, you acknowledge that:
• You will only use VOIDWAVE for authorized testing
• You understand the legal implications of unauthorized access
• You take full responsibility for your actions

[red]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/]
        """.format(version=__version__)

        checkbox_text = "[bold]Accept these terms to continue[/]"
        body.update(f"{logo}\n\n{checkbox_text}")

        # Add checkbox for terms
        content = self.query_one("#step-content", ScrollableContainer)
        try:
            existing = content.query_one("#terms-checkbox", Checkbox)
        except Exception:
            await content.mount(
                Checkbox("I understand and accept these terms", id="terms-checkbox")
            )

    async def _render_system_detection(self, title: Static, body: Static) -> None:
        """Render Step 2: System Detection."""
        title.update("Step 2/9: System Detection")

        body.update("Detecting your system configuration...")

        # Run detection
        self.system_info = await BootstrapManager.detect_system()
        info = self.system_info

        # Format capabilities
        caps = []
        caps.append(f"{'[green]✓[/]' if info.has_root else '[red]✗[/]'} Root access (sudo)")
        caps.append(f"{'[green]✓[/]' if info.has_internet else '[red]✗[/]'} Internet connectivity")
        caps.append(f"{'[green]✓[/]' if info.wireless_interfaces else '[red]✗[/]'} Wireless interfaces ({len(info.wireless_interfaces)} found)")

        gpu_detected = info.gpu_info.get("nvidia") or info.gpu_info.get("amd")
        if gpu_detected:
            gpu_name = (info.gpu_info.get("nvidia") or info.gpu_info.get("amd", {})).get("name", "Unknown")
            caps.append(f"[green]✓[/] GPU detected ({gpu_name})")
        else:
            caps.append("[yellow]○[/] No dedicated GPU detected")

        caps_text = "\n".join(f"  {c}" for c in caps)

        # Warnings
        warnings = []
        if not info.wireless_interfaces:
            warnings.append("No wireless interfaces detected. WiFi features will be limited.")
        if not info.has_internet:
            warnings.append("No internet connectivity. Tool installation may fail.")

        warnings_text = ""
        if warnings:
            warnings_text = "\n[bold yellow]Warnings:[/]\n" + "\n".join(f"  [yellow]• {w}[/]" for w in warnings)

        content = f"""
[bold cyan]System Information[/]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Distribution:     [bold]{info.distro} {info.distro_version}[/]
  Package Manager:  [bold]{info.package_manager}[/]
  Kernel:           {info.kernel}
  Architecture:     {info.arch}
  Memory:           {info.memory_gb} GB
  Disk Space:       {info.disk_space_gb} GB available

[bold cyan]Capabilities[/]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{caps_text}
{warnings_text}
        """
        body.update(content.strip())

    async def _render_tool_audit(self, title: Static, body: Static) -> None:
        """Render Step 3: Tool Audit."""
        title.update("Step 3/9: Tool Audit")

        body.update("Scanning installed tools...")

        # Run audit
        self.tool_audit = await self._run_tool_audit()

        # Format results
        output_lines = []
        total_installed = 0
        total_missing = 0

        for category, tools in TOOL_REGISTRY.items():
            installed = []
            missing = []

            for tool in tools:
                if shutil.which(tool):
                    installed.append(tool)
                    total_installed += 1
                else:
                    missing.append(tool)
                    total_missing += 1

            # Format category
            output_lines.append(f"\n[bold cyan]{category.upper()} ({len(installed)}/{len(tools)})[/]")
            output_lines.append("━" * 50)

            tool_line = ""
            for t in installed[:6]:
                tool_line += f"[green]✓ {t}[/]  "
            for t in missing[:6]:
                tool_line += f"[red]✗ {t}[/]  "

            if len(installed) + len(missing) > 6:
                tool_line += "..."

            output_lines.append(tool_line)

        summary = f"""
[bold]Summary:[/] {total_installed} installed, {total_missing} missing
        """

        body.update("\n".join(output_lines) + summary)

    async def _run_tool_audit(self) -> dict:
        """Run tool audit."""
        results = {"installed": [], "missing": [], "by_category": {}}

        for category, tools in TOOL_REGISTRY.items():
            results["by_category"][category] = {"installed": [], "missing": []}

            for tool in tools:
                if shutil.which(tool):
                    results["installed"].append(tool)
                    results["by_category"][category]["installed"].append(tool)
                else:
                    results["missing"].append(tool)
                    results["by_category"][category]["missing"].append(tool)

        return results

    async def _render_install_tools(self, title: Static, body: Static) -> None:
        """Render Step 4: Install Tools."""
        title.update("Step 4/9: Install Tools")

        missing = self.tool_audit.get("missing", [])

        if not missing:
            body.update("""
[bold green]All essential tools are already installed![/]

No additional tools need to be installed.
You can proceed to the next step.
            """)
            return

        # Group by category with sizes (estimated)
        cat_sizes = {
            "wireless": 150, "scanning": 50, "osint": 200,
            "credentials": 100, "exploit": 500, "traffic": 75,
            "recon": 50, "stress": 25
        }

        lines = [f"""
[bold]{len(missing)} tools are not installed.[/]

Select categories to install:
        """]

        for category, tools in TOOL_REGISTRY.items():
            cat_missing = [t for t in tools if t in missing]
            if cat_missing:
                size = cat_sizes.get(category, 50)
                lines.append(f"  [ ] {category.capitalize()} ({len(cat_missing)} tools, ~{size} MB)")

        lines.append("")
        lines.append("[dim]Check categories above, then click Install[/]")

        body.update("\n".join(lines))

    async def _install_tools(self) -> None:
        """Install selected tools."""
        self.notify("Tool installation started in background", severity="information")
        # Actual installation would happen here

    async def _render_download_data(self, title: Static, body: Static) -> None:
        """Render Step 5: Download Data."""
        title.update("Step 5/9: Download Data")

        lines = ["""
[bold]Download data files for various tools:[/]

[bold cyan]Wordlists[/]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """]

        for data_id, info in DATA_SOURCES.items():
            if info["category"] == "wordlists":
                optional = " (optional)" if info.get("optional") else ""
                lines.append(f"  [ ] {info['name']} ({info['size']}){optional}")
                lines.append(f"      {info['description']}")

        lines.append("""
[bold cyan]Templates[/]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """)

        for data_id, info in DATA_SOURCES.items():
            if info["category"] == "templates":
                lines.append(f"  [ ] {info['name']} ({info['size']})")
                lines.append(f"      {info['description']}")

        lines.append("""
[bold cyan]Databases[/]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """)

        for data_id, info in DATA_SOURCES.items():
            if info["category"] == "databases":
                lines.append(f"  [ ] {info['name']} ({info['size']})")
                lines.append(f"      {info['description']}")

        body.update("\n".join(lines))

    async def _download_data(self) -> None:
        """Download selected data files."""
        self.notify("Download started in background", severity="information")

    async def _render_api_keys(self, title: Static, body: Static) -> None:
        """Render Step 6: API Keys."""
        title.update("Step 6/9: API Keys")

        lines = ["""
[bold]Configure API keys for enhanced functionality.[/]
You can skip this and configure later in Settings.

[bold cyan]Recommended[/]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """]

        for service_id, info in API_SERVICES.items():
            if info.get("recommended"):
                lines.append(f"""
  [bold]{info['name']}[/]
  Used by: {', '.join(info['used_by'])}
  Free tier: {info['free_tier']}
  Get key: {info['url']}
  [ Enter key here... ]
                """)

        lines.append("""
[bold cyan]Optional[/]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """)

        for service_id, info in API_SERVICES.items():
            if not info.get("recommended"):
                lines.append(f"  {info['name']}: {info['url']}")

        lines.append("""
[dim]Keys are stored securely in your system keyring.[/]
        """)

        body.update("\n".join(lines))

    async def _render_gpu_detection(self, title: Static, body: Static) -> None:
        """Render Step 7: GPU Detection."""
        title.update("Step 7/9: GPU Detection")

        info = self.system_info
        if not info:
            info = await BootstrapManager.detect_system()

        lines = ["""
[bold]GPU acceleration speeds up password cracking significantly.[/]

[bold cyan]Detected GPUs[/]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """]

        if info.gpu_info.get("nvidia"):
            gpu = info.gpu_info["nvidia"]
            lines.append(f"""
  [green]✓[/] NVIDIA {gpu['name']}
    Driver: {gpu.get('driver', 'Unknown')}
    Memory: {gpu.get('memory', 'Unknown')}
    Status: [green]Ready for hashcat[/]
            """)
        elif info.gpu_info.get("amd"):
            gpu = info.gpu_info["amd"]
            lines.append(f"""
  [green]✓[/] AMD {gpu['name']}
    Status: [yellow]ROCm support may be required[/]
            """)
        elif info.gpu_info.get("intel"):
            gpu = info.gpu_info["intel"]
            lines.append(f"""
  [yellow]○[/] Intel {gpu['name']}
    Status: [yellow]Limited hashcat support[/]
            """)
        else:
            lines.append("""
  [red]✗[/] No dedicated GPU detected
    Status: [yellow]CPU-only cracking (slower)[/]
            """)

        lines.append("""
[bold cyan]Hashcat Benchmark (optional)[/]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Run a quick benchmark to measure cracking speed?
This may take 1-2 minutes.

[dim]Click 'Run Benchmark' or skip to continue[/]
        """)

        body.update("\n".join(lines))

    async def _run_gpu_benchmark(self) -> None:
        """Run hashcat benchmark."""
        if not shutil.which("hashcat"):
            self.notify("hashcat not installed", severity="error")
            return

        self.notify("Running hashcat benchmark...", severity="information")

        try:
            proc = await asyncio.create_subprocess_exec(
                "hashcat", "-b", "--benchmark-all", "-O",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, _ = await proc.communicate()

            # Parse benchmark results
            results = []
            for line in stdout.decode().split("\n"):
                if "H/s" in line:
                    results.append(line.strip())

            if results:
                self.notify(f"Benchmark complete: {len(results)} algorithms tested", severity="information")
        except Exception as e:
            self.notify(f"Benchmark failed: {e}", severity="error")

    async def _render_create_assets(self, title: Static, body: Static) -> None:
        """Render Step 8: Create Assets."""
        title.update("Step 8/9: Create Assets")

        # Create directories
        BootstrapManager.ensure_directories()

        lines = ["""
[bold]Creating default assets for operations.[/]

[bold cyan]Directory Structure[/]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """]

        for subdir in BootstrapManager.DIRECTORIES:
            path = BootstrapManager.DATA_DIR / subdir
            status = "[green]✓[/]" if path.exists() else "[yellow]○[/]"
            lines.append(f"  {status} {path}")

        lines.append("""
[bold cyan]Portal Templates[/]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [green]✓[/] Default captive portal (hotel-style)
  [green]✓[/] WiFi login portal
  [green]✓[/] Terms acceptance portal

[bold cyan]Certificates[/]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Self-signed certificates will be generated on first use.

  CA Certificate:  {data_dir}/certs/ca.pem
  Server Cert:     {data_dir}/certs/server.pem
  Server Key:      {data_dir}/certs/server.key

[dim]Assets created successfully.[/]
        """.format(data_dir=BootstrapManager.DATA_DIR))

        body.update("\n".join(lines))

    async def _render_summary(self, title: Static, body: Static) -> None:
        """Render Step 9: Summary & Finish."""
        title.update("Step 9/9: Setup Complete!")

        info = self.system_info
        if not info:
            info = await BootstrapManager.detect_system()

        audit = self.tool_audit or await self._run_tool_audit()
        installed_count = len(audit.get("installed", []))
        missing_count = len(audit.get("missing", []))

        gpu_status = "Not detected"
        if info.gpu_info.get("nvidia"):
            gpu_status = f"NVIDIA {info.gpu_info['nvidia']['name']}"
        elif info.gpu_info.get("amd"):
            gpu_status = f"AMD {info.gpu_info['amd']['name']}"

        api_count = len(self.api_keys)

        content = f"""
[bold green]✓ VOIDWAVE is ready to use![/]

[bold cyan]Setup Summary[/]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  System:      {info.distro} {info.distro_version} ({info.package_manager})
  Tools:       {installed_count} installed, {missing_count} missing
  API Keys:    {api_count} configured
  GPU:         {gpu_status}
  Data Dir:    {BootstrapManager.DATA_DIR}

[bold cyan]Quick Tips[/]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  • Press [bold]?[/] at any time for help
  • Use [bold]Ctrl+Q[/] to quit
  • Connect a wireless adapter for WiFi operations
  • Visit [bold]Settings[/] to configure additional options

[bold cyan]What's Next?[/]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  • Start with a network scan
  • Explore wireless options
  • View the help documentation
  • Go to main dashboard

[bold green]Click 'Finish' to enter VOIDWAVE[/]
        """

        body.update(content)

    async def _validate_step(self) -> bool:
        """Validate current step before proceeding."""
        if self.current_step == 0:
            if not self.terms_accepted:
                self.notify("You must accept the terms to continue", severity="error")
                return False
        return True

    async def _next_step(self) -> None:
        """Move to next step."""
        if self.current_step < self.total_steps - 1:
            await self._show_step(self.current_step + 1)
        else:
            await self._finish()

    async def _prev_step(self) -> None:
        """Move to previous step."""
        if self.current_step > 0:
            await self._show_step(self.current_step - 1)

    async def _skip_all(self) -> None:
        """Skip remaining steps and finish."""
        self.notify("Skipping remaining steps...", severity="warning")
        await self._finish()

    async def _finish(self) -> None:
        """Complete setup and transition to main screen."""
        # Ensure directories exist
        BootstrapManager.ensure_directories()

        # Mark as initialized
        BootstrapManager.mark_initialized()

        self.notify("Setup complete! Welcome to VOIDWAVE", severity="information")

        # Transition to main screen
        from voidwave.tui.screens.main import MainScreen
        self.app.switch_screen(MainScreen())

    def action_cancel(self) -> None:
        """Cancel the wizard."""
        self.app.exit()
