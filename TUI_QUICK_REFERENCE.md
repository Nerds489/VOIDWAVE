# VOIDWAVE TUI - Quick Reference Guide

## 📁 File Locations

```
/var/home/mintys/Desktop/VOIDWAVE/src/voidwave/tui/
```

## 🚀 Launch Commands

```bash
# Direct execution
python -m voidwave.tui.app

# From Python
from voidwave.tui import run_app
run_app()

# Test imports
python test_tui.py

# Validate structure
./validate_tui_structure.sh
```

## ⌨️ Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Ctrl+Q` | Quit application |
| `Ctrl+P` | Open command palette |
| `?` | Show help |
| `Ctrl+S` | New scan |
| `Ctrl+W` | Wireless menu |
| `Ctrl+T` | Toggle theme |
| `Escape` | Go back |
| `j` / `k` | Navigate down/up |
| `g g` | Jump to top |
| `G` | Jump to bottom |
| `Ctrl+D` | Page down |
| `Ctrl+U` | Page up |
| `1-9, 0` | Quick menu access |

## 🎨 Color Scheme

```python
NEON_CYAN = "#0ABDC6"     # Primary
HOT_MAGENTA = "#EA00D9"   # Secondary
DEEP_NAVY = "#091833"     # Background
MATRIX_GREEN = "#00FF41"  # Success
NEON_ORANGE = "#FF9A00"   # Warning
CORAL_RED = "#FF0040"     # Error
```

## 📺 Screen Map

| Number | Screen | Purpose |
|--------|--------|---------|
| 1 | Wireless | WiFi attacks, monitor mode |
| 2 | Scanning | Port scanning, enumeration |
| 3 | Credentials | Password cracking |
| 4 | OSINT | Intelligence gathering |
| 5 | Recon | Network discovery |
| 6 | Traffic | Packet capture, MITM |
| 7 | Exploit | Vulnerability exploitation |
| 8 | Stress | Load testing |
| 9 | Status | System monitoring |
| 0 | Settings | Configuration |

## 🧩 Widget Usage

### ToolOutput
```python
from voidwave.tui.widgets import ToolOutput

output = ToolOutput(id="tool-output")
output.write_info("Info message")
output.write_success("Success message")
output.write_warning("Warning message")
output.write_error("Error message")
output.write_header("Section Header")
```

### StatusPanel
```python
from voidwave.tui.widgets import StatusPanel

status = StatusPanel(id="status-panel")
# Auto-refreshes every 5 seconds
```

### TargetTree
```python
from voidwave.tui.widgets import TargetTree

tree = TargetTree()
tree.add_network("192.168.1.0/24")
tree.add_host("192.168.1.100", network="192.168.1.0/24", hostname="server.local")
tree.add_service("192.168.1.100", 80, "http", "Apache 2.4")
tree.add_vulnerability("192.168.1.100", "CVE-2023-1234", "high", "SQL Injection")
tree.update_status("host", "192.168.1.100", "completed")
```

### ProgressPanel
```python
from voidwave.tui.widgets import ProgressPanel

progress = ProgressPanel(id="progress-panel")
progress.add_task("scan1", "Network Scan", total=100)
progress.update_task("scan1", completed=50, description="Scanning ports...")
progress.complete_task("scan1")
```

## 🧙 Wizard Integration

### FirstRunWizard
```python
from voidwave.tui.wizards import FirstRunWizard

result = await self.app.push_screen(FirstRunWizard())
if result:
    print("Setup completed")
```

### ScanWizard
```python
from voidwave.tui.wizards import ScanWizard

config = await self.app.push_screen(ScanWizard())
if config:
    target = config["target"]
    scan_type = config["scan_type"]
    # Start scan with config
```

## 🎮 Command Palette

Access with `Ctrl+P`, then type:
- `scan` - Start scan
- `wireless` - Open wireless menu
- `help` - Show help
- `quick-scan` - Quick scan
- `stop-all` - Stop all tools

## 📦 Dependencies Check

```bash
pip install textual rich pydantic pydantic-settings aiosqlite pyee
```

## 🔧 Customization

### Add New Screen
1. Create `src/voidwave/tui/screens/myscreen.py`
2. Subclass `Screen`
3. Implement `compose()` method
4. Add to `screens/__init__.py`
5. Add to menu in `main.py`

### Add New Widget
1. Create `src/voidwave/tui/widgets/mywidget.py`
2. Subclass appropriate Textual widget
3. Add `DEFAULT_CSS` class variable
4. Add to `widgets/__init__.py`

### Customize Theme
Edit `src/voidwave/tui/cyberpunk.tcss` for colors and styles.

## 🐛 Troubleshooting

**Import errors:**
```bash
# Install dependencies
pip install -e .
```

**CSS not loading:**
Check that `cyberpunk.tcss` is in same directory as `app.py`

**Screen not found:**
Check import path in `main.py` screen_map

## 📚 Documentation

- Full summary: `TUI_IMPLEMENTATION_SUMMARY.md`
- Implementation plan: `VOIDWAVE-UPGRADE/IMPLEMENTATION-PLAN-PART2.md`
- Help screen: Press `?` in application
