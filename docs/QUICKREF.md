# VOIDWAVE Quick Reference Card

## Common Commands

| Command | Description |
|---------|-------------|
| `voidwave` | Launch interactive menu |
| `voidwave scan <target>` | Quick scan a target |
| `voidwave scan <target> --full` | Full port scan |
| `voidwave wizard scan` | Guided scan wizard |
| `voidwave wifi` | WiFi attack menu |
| `voidwave status` | Show tool status |
| `voidwave install` | Launch installer |
| `voidwave config edit` | Edit configuration |
| `voidwave help` | Show all commands |

## Scan Flags

| Flag | Description |
|------|-------------|
| `--quick` | Top 100 ports (fastest) |
| `--standard` | Top 1000 ports |
| `--full` | All 65535 ports |
| `--stealth` | Slow, evades IDS |
| `--vuln` | Vulnerability scan |
| `-v, --verbose` | Verbose output |
| `-o, --output` | Save to file |

## Global Options

| Option | Description |
|--------|-------------|
| `-v, --verbose` | Enable verbose output |
| `-q, --quiet` | Suppress non-error output |
| `--no-color` | Disable colored output |
| `--debug` | Enable debug mode |

## File Locations

| Path | Description |
|------|-------------|
| `~/.voidwave/config` | Configuration file |
| `~/.voidwave/logs/` | Operation logs |
| `~/.voidwave/output/` | Scan results |
| `~/.voidwave/sessions/` | Saved sessions |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `VOIDWAVE_LOG_LEVEL` | DEBUG/INFO/WARN/ERROR |
| `VOIDWAVE_VERBOSE` | Enable verbose (true/false) |
| `VOIDWAVE_NO_COLOR` | Disable colors (true/false) |
| `VW_NON_INTERACTIVE` | Set to `1` (or rely on no TTY) to skip the wizard/legal prompts |

---
© 2025 Nerds489
