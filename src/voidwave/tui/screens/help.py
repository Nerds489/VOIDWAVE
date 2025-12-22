"""Help and documentation screen."""
from textual.app import ComposeResult
from textual.containers import Container, VerticalScroll
from textual.screen import Screen
from textual.widgets import Markdown


HELP_CONTENT = """
# VOIDWAVE Help

## Overview

VOIDWAVE is a comprehensive offensive security framework with a modern TUI interface.

## Navigation

### Keyboard Shortcuts

- **Ctrl+Q**: Quit the application
- **Ctrl+P**: Open command palette
- **?**: Show this help screen
- **Ctrl+S**: Start new scan
- **Ctrl+W**: Open wireless menu
- **Ctrl+T**: Toggle theme
- **Escape**: Go back / Cancel

### Vim-style Navigation

- **j**: Move down
- **k**: Move up
- **gg**: Jump to top
- **G**: Jump to bottom
- **Ctrl+D**: Page down
- **Ctrl+U**: Page up

### Menu Navigation

- **1-9, 0**: Quick access to menu items

## Modules

### 📡 Wireless
WiFi attacks, monitor mode management, handshake capture, PMKID attacks

### 🔍 Scanning
Port scanning, service enumeration, OS detection, vulnerability scanning

### 🔑 Credentials
Password cracking, hash attacks, dictionary attacks, brute force

### 🌐 OSINT
Open source intelligence, domain recon, email harvesting, subdomain discovery

### 🎯 Recon
Network mapping, host discovery, service fingerprinting, banner grabbing

### 📊 Traffic
Packet capture, traffic analysis, MITM attacks, protocol analysis

### 💥 Exploit
Metasploit integration, exploit database, payload generation

### ⚡ Stress
Load testing, DoS simulation, bandwidth testing (authorized testing only)

### 📈 Status
System status, tool availability, active sessions, resource monitoring

### ⚙️ Settings
Configuration management, tool preferences, plugin settings

## Safety

VOIDWAVE includes built-in safety features:

- **Target validation**: Prevents attacks on unauthorized targets
- **Audit logging**: All actions are logged for accountability
- **Root checks**: Warns when running with elevated privileges
- **Scope enforcement**: Respects defined engagement boundaries

## Getting Started

1. Configure your engagement scope in Settings
2. Verify tool availability in Status screen
3. Start with reconnaissance (OSINT/Recon)
4. Progress to active scanning when authorized
5. Review findings in the Output tab

## Legal Notice

⚠️ **Use only on networks and systems you own or have explicit written authorization to test.**

Unauthorized access to computer systems is illegal. Always:
- Obtain written permission before testing
- Define clear scope boundaries
- Document all activities
- Follow responsible disclosure practices

## Support

For issues, documentation, or contributions:
- GitHub: https://github.com/voidwave/voidwave
- Documentation: https://docs.voidwave.io

---

Press **Escape** to close this help screen.
"""


class HelpScreen(Screen):
    """Help and documentation screen."""

    BINDINGS = [
        ("escape", "app.pop_screen", "Back"),
    ]

    def compose(self) -> ComposeResult:
        """Compose the help screen layout."""
        with VerticalScroll():
            yield Markdown(HELP_CONTENT)
