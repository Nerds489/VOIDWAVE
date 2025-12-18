# VOIDWAVE Troubleshooting

Use this decision tree to get back to hacking quickly.

## Start Here
1. Check version and config paths:
   - `voidwave --version`
   - `voidwave status` (tool availability)
   - Logs live in `~/.voidwave/logs/`; sessions in `~/.voidwave/sessions/`.
2. Verify install paths:
   - `command -v voidwave` and `command -v voidwave-install` should return `/usr/local/bin/voidwave` (or your chosen prefix). Repo clones also ship wrappers (`./voidwave`, `./voidwave-install`) that forward to the same executables under `bin/`.
3. Re-run status after updates: `sudo voidwave-install status` to confirm required tools are present.
4. Automation/CI: export `VW_NON_INTERACTIVE=1` (or run without a TTY) to skip the wizard/legal prompts and avoid blocked pipelines.

## Permission or Sudo Problems
- Menu actions that touch raw sockets, monitor mode, or packet injection need sudo. Re-run the command with `sudo` or start VOIDWAVE as root when testing locally.
- If sudo prompts do not appear, ensure your user is in sudoers (`sudo -l`).
- SELinux/AppArmor: temporarily set to permissive for troubleshooting (`setenforce 0`) if policies block network captures.

## Missing Tools / Not Installed
- Run `sudo voidwave-install essentials` or `sudo voidwave-install all` to install dependencies.
- For a specific set: `sudo voidwave-install recon`, `wireless`, `exploit`, or `creds`.
- If a tool shows as missing in status, install its package manually (`sudo apt install <tool>`) then rerun `voidwave status`.

## Wireless Interface Issues
- No interface found: `ip link` to confirm adapter; plug in USB adapters for VMs; install correct drivers/firmware.
- Soft-blocked: `rfkill list` -> `rfkill unblock wifi`.
- Monitor mode fails: stop conflicting services (`sudo systemctl stop NetworkManager wpa_supplicant`), then retry menu Wireless -> Capture/Deauth.
- Channel problems: set regulatory domain (`sudo iw reg set <CC>`), then re-attempt capture.

## Capture/Crack Problems
- Handshake not captured: ensure target traffic exists; try a brief deauth (Wireless -> Deauth) and keep capture running longer.
- Hashcat errors: install GPU drivers + OpenCL/CUDA; fall back to `john` if GPU unavailable.
- Wordlist issues: verify path (`/usr/share/wordlists/rockyou.txt`) and permissions.

## Recon/Exploit Hiccups
- Nmap permission errors: run scans with sudo for SYN/UDP modes.
- Slow scans: lower timing or switch to `rustscan`/`masscan` for discovery then hand off to nmap.
- Web scans failing over HTTPS: verify cert trust or add `--insecure` flags where supported (e.g., nikto/wpscan/sqlmap options in menus).

## Stress/Netem Issues
- `tc` not found: install `iproute2` (`sudo apt install iproute2`).
- Clearing impairment: `sudo tc qdisc del dev <iface> root` (menu prompts do this automatically).
- Iperf3 connection refused: confirm server is running (`iperf3 -s`) on the target; adjust firewall.

## Sessions, Loot, and Exports
- Session not saving: ensure `~/.voidwave/` is writable and not full; check `~/.voidwave/logs/` for errors.
- Loot not found: look in `~/.voidwave/loot/` and `~/.voidwave/output/` for captured creds/pcaps.
- Export failures: confirm tar/zip utilities are installed; re-run `voidwave session export` with a different destination.

## Updating VOIDWAVE
- Check for updates: `voidwave --version` (banner shows current).
- Re-run installer after updates if new dependencies are added: `sudo voidwave-install all`.

## Still Stuck?
- Re-run the action to reproduce and immediately inspect the latest log in `~/.voidwave/logs/` for the exact command/arguments used.
- If an external tool itself fails, run it directly with the logged arguments to isolate environment issues.
- When asking for help, include the session name, the failing menu path, and the relevant log snippet.
