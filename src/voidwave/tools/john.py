"""John the Ripper password cracker wrapper with output parsing."""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any, ClassVar

from pydantic import BaseModel

from voidwave.core.logging import get_logger
from voidwave.orchestration.events import Events, event_bus
from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper

logger = get_logger(__name__)


class JohnConfig(BaseModel):
    """John-specific configuration."""

    session_name: str = "voidwave"
    pot_file: Path | None = None
    fork: int = 0  # Number of processes (0 = auto)


class JohnTool(BaseToolWrapper):
    """John the Ripper password cracker wrapper."""

    TOOL_BINARY: ClassVar[str] = "john"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="john",
        version="1.0.0",
        description="Password cracker",
        author="VOIDWAVE",
        plugin_type=PluginType.CRACKER,
        capabilities=[Capability.PASSWORD_CRACK],
        requires_root=False,
        external_tools=["john"],
        config_schema=JohnConfig,
    )

    # Common hash formats
    HASH_FORMATS = {
        "raw-md5": "Raw MD5",
        "raw-sha1": "Raw SHA1",
        "raw-sha256": "Raw SHA256",
        "raw-sha512": "Raw SHA512",
        "nt": "Windows NT (NTLM)",
        "lm": "Windows LM",
        "bcrypt": "bcrypt",
        "descrypt": "Traditional DES",
        "md5crypt": "MD5 crypt",
        "sha256crypt": "SHA256 crypt",
        "sha512crypt": "SHA512 crypt",
        "wpapsk": "WPA/WPA2 PSK",
        "mysql-sha1": "MySQL 4.1+",
        "mssql": "MS SQL",
        "oracle": "Oracle 10",
        "oracle11": "Oracle 11",
        "postgres": "PostgreSQL",
        "zip": "PKZIP",
        "rar": "RAR archive",
        "pdf": "PDF",
        "office": "MS Office",
        "ssh": "SSH private key",
        "keepass": "KeePass",
    }

    def __init__(self, john_config: JohnConfig | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self.john_config = john_config or JohnConfig()

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build john command.

        Args:
            target: Hash file to crack
            options: Command options including:
                - wordlist: Path to wordlist
                - format: Hash format
                - rules: Rule set to apply
                - incremental: Incremental mode charset
                - mask: Mask mode pattern
                - single: Single crack mode
                - show: Show cracked passwords
                - session: Session name
                - restore: Restore session
                - fork: Number of processes
        """
        cmd = []

        # Show mode (display cracked)
        if options.get("show"):
            cmd.append("--show")
            if options.get("format"):
                cmd.extend(["--format=" + options["format"]])
            cmd.append(target)
            return cmd

        # Restore session
        if options.get("restore"):
            session = options.get("session", self.john_config.session_name)
            cmd.extend(["--restore=" + session])
            return cmd

        # Wordlist mode
        wordlist = options.get("wordlist")
        if wordlist:
            cmd.append("--wordlist=" + str(wordlist))

        # Format
        format_type = options.get("format")
        if format_type:
            cmd.append("--format=" + format_type)

        # Rules
        rules = options.get("rules")
        if rules:
            if rules is True:
                cmd.append("--rules")
            else:
                cmd.append("--rules=" + rules)

        # Incremental mode
        incremental = options.get("incremental")
        if incremental:
            if incremental is True:
                cmd.append("--incremental")
            else:
                cmd.append("--incremental=" + incremental)

        # Mask mode
        mask = options.get("mask")
        if mask:
            cmd.append("--mask=" + mask)

        # Single crack mode
        if options.get("single"):
            cmd.append("--single")

        # Session name
        session = options.get("session", self.john_config.session_name)
        cmd.append("--session=" + session)

        # Fork (parallel processes)
        fork = options.get("fork", self.john_config.fork)
        if fork > 0:
            cmd.append("--fork=" + str(fork))

        # Pot file
        pot_file = options.get("pot_file", self.john_config.pot_file)
        if pot_file:
            cmd.append("--pot=" + str(pot_file))

        # Max run time
        max_time = options.get("max_time")
        if max_time:
            cmd.append("--max-run-time=" + str(max_time))

        # Target file
        cmd.append(target)

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse john output."""
        result = {
            "raw_output": output,
            "cracked": [],
            "status": "unknown",
            "session": None,
            "guesses": 0,
            "time": None,
            "errors": [],
        }

        lines = output.strip().split('\n')

        for line in lines:
            # Cracked password (from --show output)
            # username:password or hash:password
            if ":" in line and not line.startswith("("):
                parts = line.strip().split(":")
                if len(parts) >= 2:
                    # Check if it looks like a cracked result
                    # Avoid parsing status lines
                    if not any(skip in line.lower() for skip in ["loaded", "remaining", "node"]):
                        result["cracked"].append({
                            "hash_or_user": parts[0],
                            "password": ":".join(parts[1:]),
                        })
                        continue

            # Session status
            session_match = re.search(r'Session completed', line)
            if session_match:
                result["status"] = "completed"
                continue

            # Guesses count
            guess_match = re.search(r'(\d+)g\s+', line)
            if guess_match:
                result["guesses"] = int(guess_match.group(1))
                continue

            # Time elapsed
            time_match = re.search(r'(\d+:\d+:\d+:\d+)', line)
            if time_match:
                result["time"] = time_match.group(1)
                continue

            # Loaded hashes
            loaded_match = re.search(r'Loaded (\d+) password hash', line)
            if loaded_match:
                result["loaded_hashes"] = int(loaded_match.group(1))
                continue

            # Remaining hashes
            remaining_match = re.search(r'(\d+) password hashes? remaining', line)
            if remaining_match:
                result["remaining"] = int(remaining_match.group(1))
                continue

            # Cracked during run (real-time output)
            cracked_match = re.search(r'^(\S+)\s+\((\S+)\)$', line)
            if cracked_match:
                result["cracked"].append({
                    "password": cracked_match.group(1),
                    "hash_or_user": cracked_match.group(2),
                })
                continue

            # Errors
            if "error" in line.lower():
                result["errors"].append(line.strip())

        return result

    async def crack_hashes(
        self,
        hash_file: str,
        wordlist: str | None = None,
        format_type: str | None = None,
        rules: str | bool = False,
    ) -> dict[str, Any]:
        """Crack password hashes.

        Args:
            hash_file: Path to file containing hashes
            wordlist: Path to wordlist
            format_type: Hash format (auto-detected if not specified)
            rules: Rule set to apply (True for default, string for specific)

        Returns:
            Cracking results
        """
        options = {}

        if wordlist:
            options["wordlist"] = wordlist

        if format_type:
            options["format"] = format_type

        if rules:
            options["rules"] = rules

        result = await self.execute(hash_file, options)

        # Emit events for cracked passwords
        for crack in result.data.get("cracked", []):
            event_bus.emit(Events.CREDENTIAL_CRACKED, {
                "hash": crack.get("hash_or_user", ""),
                "password": crack.get("password", ""),
            })

        return result.data

    async def crack_incremental(
        self,
        hash_file: str,
        format_type: str | None = None,
        charset: str = "ASCII",
    ) -> dict[str, Any]:
        """Crack using incremental (brute force) mode.

        Args:
            hash_file: Path to file containing hashes
            format_type: Hash format
            charset: Character set (ASCII, Alpha, Digits, etc.)

        Returns:
            Cracking results
        """
        options = {
            "incremental": charset,
        }

        if format_type:
            options["format"] = format_type

        result = await self.execute(hash_file, options)
        return result.data

    async def crack_mask(
        self,
        hash_file: str,
        mask: str,
        format_type: str | None = None,
    ) -> dict[str, Any]:
        """Crack using mask mode.

        Args:
            hash_file: Path to file containing hashes
            mask: Mask pattern (e.g., ?l?l?l?l?d?d?d?d)
            format_type: Hash format

        Returns:
            Cracking results
        """
        options = {
            "mask": mask,
        }

        if format_type:
            options["format"] = format_type

        result = await self.execute(hash_file, options)
        return result.data

    async def show_cracked(
        self,
        hash_file: str,
        format_type: str | None = None,
    ) -> dict[str, Any]:
        """Show previously cracked passwords.

        Args:
            hash_file: Path to file containing hashes
            format_type: Hash format

        Returns:
            Cracked passwords from potfile
        """
        options = {
            "show": True,
        }

        if format_type:
            options["format"] = format_type

        result = await self.execute(hash_file, options)
        return result.data

    async def restore_session(
        self,
        session: str | None = None,
    ) -> dict[str, Any]:
        """Restore a previous cracking session.

        Args:
            session: Session name to restore

        Returns:
            Session results
        """
        options = {
            "restore": True,
        }

        if session:
            options["session"] = session

        # Target doesn't matter for restore
        result = await self.execute("", options)
        return result.data
