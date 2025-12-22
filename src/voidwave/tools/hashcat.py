"""Hashcat password cracker wrapper."""
import re
from pathlib import Path
from typing import Any, ClassVar

from pydantic import BaseModel

from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper


class HashcatConfig(BaseModel):
    """Hashcat-specific configuration."""

    workload: int = 3  # -w 1-4
    device_types: str = "1,2"  # CPU=1, GPU=2
    optimized_kernels: bool = True
    potfile_path: Path | None = None
    session_name: str = "voidwave"


class HashcatTool(BaseToolWrapper):
    """Hashcat password cracker wrapper."""

    TOOL_BINARY: ClassVar[str] = "hashcat"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="hashcat",
        version="1.0.0",
        description="Advanced GPU-accelerated password recovery",
        author="VOIDWAVE",
        plugin_type=PluginType.CRACKER,
        capabilities=[Capability.PASSWORD_CRACK],
        requires_root=False,
        external_tools=["hashcat"],
        config_schema=HashcatConfig,
    )

    # Common hash modes
    HASH_MODES = {
        "md5": 0,
        "sha1": 100,
        "sha256": 1400,
        "sha512": 1700,
        "ntlm": 1000,
        "netlmv2": 5600,
        "wpa": 22000,  # PMKID/EAPOL
        "wpa2": 22000,
        "bcrypt": 3200,
        "mysql": 300,
        "mssql": 1731,
    }

    # Attack modes
    ATTACK_MODES = {
        "dictionary": 0,
        "combinator": 1,
        "bruteforce": 3,
        "hybrid_dict_mask": 6,
        "hybrid_mask_dict": 7,
    }

    def __init__(self, hashcat_config: HashcatConfig | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self.hashcat_config = hashcat_config or HashcatConfig()

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build hashcat command."""
        cmd = []

        # Hash mode
        hash_type = options.get("hash_type", "md5")
        if hash_type in self.HASH_MODES:
            cmd.extend(["-m", str(self.HASH_MODES[hash_type])])
        elif hash_type.isdigit():
            cmd.extend(["-m", hash_type])

        # Attack mode
        attack_mode = options.get("attack_mode", "dictionary")
        if attack_mode in self.ATTACK_MODES:
            cmd.extend(["-a", str(self.ATTACK_MODES[attack_mode])])

        # Workload profile
        workload = options.get("workload", self.hashcat_config.workload)
        cmd.extend(["-w", str(workload)])

        # Device types
        cmd.extend(["-D", self.hashcat_config.device_types])

        # Optimized kernels
        if self.hashcat_config.optimized_kernels:
            cmd.append("-O")

        # Session name
        session = options.get("session", self.hashcat_config.session_name)
        cmd.extend(["--session", session])

        # Output file
        output_file = options.get("output_file")
        if output_file:
            cmd.extend(["-o", str(output_file)])

        # Status updates
        cmd.extend(["--status", "--status-timer", "10"])

        # Hash file/value
        cmd.append(target)

        # Wordlist or mask
        wordlist = options.get("wordlist")
        mask = options.get("mask")

        if attack_mode in ("dictionary", "combinator", "hybrid_dict_mask"):
            if wordlist:
                cmd.append(str(wordlist))
        if attack_mode in ("bruteforce", "hybrid_dict_mask", "hybrid_mask_dict"):
            if mask:
                cmd.append(mask)

        # Rules
        rules = options.get("rules", [])
        for rule in rules:
            cmd.extend(["-r", str(rule)])

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse hashcat output."""
        result = {
            "cracked": [],
            "status": "unknown",
            "progress": 0,
            "speed": None,
            "time_started": None,
            "time_estimated": None,
        }

        for line in output.splitlines():
            # Cracked password
            if ":" in line and not line.startswith("["):
                parts = line.strip().split(":")
                if len(parts) >= 2:
                    result["cracked"].append(
                        {
                            "hash": parts[0],
                            "password": ":".join(parts[1:]),
                        }
                    )

            # Status line
            status_match = re.search(r"Status\.+:\s*(\w+)", line)
            if status_match:
                result["status"] = status_match.group(1).lower()

            # Progress
            progress_match = re.search(
                r"Progress\.+:\s*\d+/\d+\s*\((\d+\.\d+)%\)", line
            )
            if progress_match:
                result["progress"] = float(progress_match.group(1))

            # Speed
            speed_match = re.search(r"Speed\.#\*\.+:\s*(.+)", line)
            if speed_match:
                result["speed"] = speed_match.group(1).strip()

            # Time estimated
            time_match = re.search(r"Time\.Estimated\.+:\s*(.+)", line)
            if time_match:
                result["time_estimated"] = time_match.group(1).strip()

        return result

    async def crack_wpa(
        self, capture_file: Path, wordlist: Path, **kwargs
    ) -> dict[str, Any]:
        """Crack WPA/WPA2 handshake or PMKID."""
        result = await self.execute(
            str(capture_file),
            {
                "hash_type": "wpa2",
                "attack_mode": "dictionary",
                "wordlist": wordlist,
                **kwargs,
            },
        )
        return result.data

    async def crack_hash(
        self,
        hash_value: str,
        hash_type: str,
        wordlist: Path | None = None,
        mask: str | None = None,
        **kwargs,
    ) -> dict[str, Any]:
        """Crack a single hash."""
        options = {"hash_type": hash_type, **kwargs}

        if wordlist:
            options["attack_mode"] = "dictionary"
            options["wordlist"] = wordlist
        elif mask:
            options["attack_mode"] = "bruteforce"
            options["mask"] = mask

        result = await self.execute(hash_value, options)
        return result.data
