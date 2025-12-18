# VOIDWAVE Environment Variables

Complete reference for all environment variables used by VOIDWAVE.

## Core Settings

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `VOIDWAVE_HOME` | Path | `~/.voidwave` | Base directory for all data |
| `VOIDWAVE_CONFIG_DIR` | Path | `~/.voidwave/config` | Configuration file location |
| `VOIDWAVE_LOG_DIR` | Path | `~/.voidwave/logs` | Log file location |
| `VOIDWAVE_DATA_DIR` | Path | `~/.voidwave/data` | Data storage location |
| `VOIDWAVE_LOOT_DIR` | Path | `~/.voidwave/loot` | Captured credentials/handshakes |
| `VOIDWAVE_SESSION_DIR` | Path | `~/.voidwave/sessions` | Session files location |

## Runtime Behavior

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `VW_NON_INTERACTIVE` | 0/1 | `0` | Skip all interactive prompts |
| `VW_SUPPRESS_OUTPUT` | 0/1 | `0` | Silent mode - suppress non-essential output |
| `VW_DRY_RUN` | 0/1 | `0` | Preview mode - show commands without executing |
| `VW_UNSAFE_MODE` | 0/1 | `0` | Bypass safety checks (DANGEROUS) |
| `DEBUG` | 0/1 | `0` | Enable debug output |
| `NO_COLOR` | 0/1 | `0` | Disable colored output |

## Logging

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `VOIDWAVE_LOG_LEVEL` | 0-5 | `1` | Minimum log level (0=DEBUG, 5=FATAL) |
| `VOIDWAVE_FILE_LOGGING` | 0/1 | `1` | Enable logging to files |
| `VOIDWAVE_LOG_FORMAT` | text/json | `text` | Log output format |

**Log Levels:**
- 0 = DEBUG (verbose debugging info)
- 1 = INFO (general information)
- 2 = SUCCESS (successful operations)
- 3 = WARNING (non-critical issues)
- 4 = ERROR (errors that don't stop execution)
- 5 = FATAL (critical errors)

## API Keys

| Variable | Description |
|----------|-------------|
| `SHODAN_API_KEY` | Shodan.io API key for OSINT reconnaissance |
| `VT_API_KEY` | VirusTotal API key for file/URL analysis |
| `CENSYS_API_KEY` | Censys.io API key for internet-wide scanning |
| `HUNTER_API_KEY` | Hunter.io API key for email discovery |

## Wireless Settings

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `WIRELESS_INTERFACE` | String | auto | Default wireless interface |
| `MONITOR_INTERFACE` | String | - | Currently active monitor interface |
| `CHANNEL` | Integer | - | Wireless channel to use |

## Cracking Settings

| Variable | Type | Description |
|----------|------|-------------|
| `CRACK_USE_GPU` | 0/1 | Enable GPU acceleration for hashcat |
| `HASHCAT_OPTS` | String | Additional hashcat options |
| `JOHN_OPTS` | String | Additional John the Ripper options |

## Examples

### Run in non-interactive CI mode
```bash
VW_NON_INTERACTIVE=1 VW_SUPPRESS_OUTPUT=1 voidwave config show
```

### Dry-run to preview commands
```bash
VW_DRY_RUN=1 voidwave wifi scan
```

### Verbose debug logging
```bash
VOIDWAVE_LOG_LEVEL=0 DEBUG=1 voidwave status
```

### JSON logging for parsing
```bash
VOIDWAVE_LOG_FORMAT=json voidwave status 2>&1 | jq .
```

### Use with OSINT features
```bash
export SHODAN_API_KEY="your-api-key"
voidwave osint shodan target.com
```

### Disable colors for piping
```bash
NO_COLOR=1 voidwave status | grep -i interface
```

### Run headless scan
```bash
VW_NON_INTERACTIVE=1 \
WIRELESS_INTERFACE=wlan0 \
voidwave wifi scan --duration 60
```

## Configuration File

Most settings can also be set in the configuration file:

```bash
# View config file path
voidwave config path

# Show current configuration
voidwave config show

# Set a value
voidwave config set log_level DEBUG

# Validate configuration
voidwave config validate
```

Environment variables take precedence over configuration file settings.

## See Also

- [QUICKREF.md](QUICKREF.md) - Quick reference guide
- [HOWTO.md](HOWTO.md) - Common tasks and procedures
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Problem solving guide
