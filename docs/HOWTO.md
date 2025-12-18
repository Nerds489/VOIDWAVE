# HOWTO: VOIDWAVE Field Guide

## Table of Contents
- [Overview](#overview)
- [Install & Prep](#install--prep)
- [First Run](#first-run)
- [Install the Arsenal](#install-the-arsenal)
- [Common Workflows](#common-workflows)
- [Sessions, Config, Logs](#sessions-config-logs)
- [Exporting Results](#exporting-results)
- [Safety Tips](#safety-tips)

## Overview
VOIDWAVE is a unified offensive toolkit with 70+ tools behind one interface. Use it to scan, attack, monitor, and report without juggling individual commands.

**What's new in v6.2.2 (Phantom Protocol):** executables now live in `bin/` with repo-level wrappers, the first-run wizard honors non-interactive mode, docs live entirely under `docs/`, and Apache 2.0 is the only license (no separate EULA).

## Logging & Verbosity
- Levels: DEBUG, INFO, WARN, ERROR, FATAL (set via `VOIDWAVE_LOG_LEVEL` or config).
- Audit trail: `~/.voidwave/logs/audit_*.log` records installs/runs.
- Verbose mode: `-v/--verbose` or config `VERBOSE=true`.

## Configuration
- File: `~/.voidwave/config` (auto-created on first run).
- Edit interactively: `voidwave config edit`.
- Show: `voidwave config show`; reset: `voidwave config reset`.

## Wizards
- First run wizard handles legal notice, verbose preference, and optional essentials install.
- Non-interactive/CI sessions (`VW_NON_INTERACTIVE=1` or no TTY) skip that wizard, auto-set `FIRST_RUN_COMPLETE`, and generate the legal acceptance file so pipelines never block.
- Scan wizard: `voidwave wizard scan` (target selection, scan type, timing, output).
- WiFi wizard: `voidwave wizard wifi` (interface selection, attack type, confirmation).

## Privilege Handling
- Many WiFi/packet actions need root. The tool prompts with sudo and checks capability.
- `require_root` prompts, `run_privileged` wraps commands with sudo when available.

## Updated Command Examples
- `voidwave scan 192.168.1.0/24 --full`
- `voidwave wizard scan`
- `voidwave wifi --monitor wlan0`
- `voidwave status --json`
- `voidwave config show`

## Install & Prep
1. Extract and navigate to VOIDWAVE directory: `cd VOIDWAVE`.
2. Install: `sudo ./install.sh` (calls `bin/voidwave-install` and drops `/usr/local/bin/voidwave*` wrappers; inside the repo keep using `./voidwave` and `./voidwave-install`).
3. Verify basics: `voidwave --version` and `voidwave status`.
4. Recommended packages (for full wireless/graphics support): `sudo apt install aircrack-ng wireshark hashcat hydra` if your distro does not provide them via the installer.

## First Run
```bash
voidwave
```
- Accept the legal disclaimer on first launch.
- Navigate the main menu: Recon, Wireless, Exploit, Stress, Tools, Intel, Credentials, Post-Exploit.
- Use arrow keys/number input; `q` or `Q` exits.

> Headless/CI usage: set `VW_NON_INTERACTIVE=1` (or let VOIDWAVE detect the missing TTY) to bypass the wizard and legal prompt automatically.

## Install the Arsenal
Choose what to install before heavier tasks (run `./voidwave-install` from the repo or `voidwave-install` after installing system-wide):
- Essentials (lean): `sudo voidwave-install essentials`
- Full arsenal: `sudo voidwave-install all`
- By category: `sudo voidwave-install recon`, `sudo voidwave-install wireless`, `sudo voidwave-install exploit`, `sudo voidwave-install creds`
- Check status anytime: `voidwave status` or `sudo voidwave-install status`

## Common Workflows
1) Quick Recon of a subnet
```
voidwave scan 192.168.1.0/24 --quick
```
- Uses nmap quick profile. Add `--vuln` for vuln scripts or run from menu [1] Recon.

2) Full Recon + Service/Vuln sweep
```
voidwave scan 10.0.0.5 --full --vuln
```
- Runs a comprehensive TCP scan with version detection and common NSE vulns.

3) Wireless handshake capture and crack
```
voidwave wifi --monitor wlan0
voidwave crack handshake.cap --hashcat
```
- Monitor mode is started/stopped automatically; outputs go to `~/.voidwave/output/`.

4) Credential brute force (SSH/HTTP)
- Menu: Credentials -> Hydra/Medusa. Supply target, service, user/wordlists; VOIDWAVE builds the command and logs output.

5) Stress/throughput test
- Menu: Stress -> iperf3 for bandwidth testing or HTTP Load for ab-based tests. Use the guided prompts for duration, streams, and concurrency.

6) Session management
```
voidwave session start
voidwave session resume <name>
voidwave session export
```
- Sessions keep targets, outputs, and state across runs.

## Sessions, Config, Logs
- Config: `~/.voidwave/config` (edit via `voidwave config edit`; view with `voidwave config show`).
- Sessions: `~/.voidwave/sessions/` with per-session metadata.
- Logs: `~/.voidwave/logs/` (timestamped). Review after each run to see exact commands executed.
- Loot/output: `~/.voidwave/loot/` and `~/.voidwave/output/` for captures, creds, reports.

## Exporting Results
- Use `voidwave session export` (or the menu export option) to bundle logs, outputs, and summaries.
- Many modules drop Markdown/CSV/JSON next to their raw outputs for reporting.

## Safety Tips
- Run invasive modules (wireless attacks, brute force, stress) only with written authorization.
- Review the command previews shown before execution and read the corresponding log entries when testing new options.
- Keep tool versions updated: `sudo voidwave-install all` to refresh.
- Always verify interfaces: `ip link`, `rfkill list` before enabling monitor mode.
