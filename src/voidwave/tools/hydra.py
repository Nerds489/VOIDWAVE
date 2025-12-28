"""Hydra network authentication cracker wrapper with output parsing."""
from __future__ import annotations

import re
from typing import Any, ClassVar

from pydantic import BaseModel

from voidwave.core.logging import get_logger
from voidwave.orchestration.events import Events, event_bus
from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper

logger = get_logger(__name__)


class HydraConfig(BaseModel):
    """Hydra-specific configuration."""

    default_threads: int = 16
    timeout: int = 30
    exit_on_first: bool = True
    verbose: bool = False


class HydraTool(BaseToolWrapper):
    """Hydra network authentication cracker wrapper."""

    TOOL_BINARY: ClassVar[str] = "hydra"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="hydra",
        version="1.0.0",
        description="Network authentication cracker",
        author="VOIDWAVE",
        plugin_type=PluginType.CRACKER,
        capabilities=[Capability.PASSWORD_CRACK],
        requires_root=False,
        external_tools=["hydra"],
        config_schema=HydraConfig,
    )

    # Supported services
    SERVICES = [
        "ssh", "ftp", "telnet", "http-get", "http-post", "http-head",
        "https-get", "https-post", "http-proxy", "smb", "smbnt",
        "mysql", "mssql", "postgres", "oracle", "vnc", "rdp",
        "snmp", "ldap", "imap", "pop3", "smtp", "socks5",
        "rlogin", "rsh", "rexec", "cisco", "cisco-enable",
        "teamspeak", "svn", "firebird", "ncp", "afp",
    ]

    def __init__(self, hydra_config: HydraConfig | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self.hydra_config = hydra_config or HydraConfig()

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build hydra command.

        Args:
            target: Target host/IP
            options: Command options including:
                - service: Target service (ssh, ftp, etc.)
                - username: Single username (-l)
                - user_list: Username wordlist (-L)
                - password: Single password (-p)
                - pass_list: Password wordlist (-P)
                - colon_file: user:pass combo file (-C)
                - threads: Number of parallel tasks (-t)
                - port: Custom port (-s)
                - ssl: Use SSL (-S)
                - vhost: Virtual host for HTTP (-V)
                - exit_first: Stop after first found (-f)
                - loop_users: Loop around users (-u)
                - http_path: Path for HTTP attacks
                - http_form: Form parameters for http-post-form
        """
        cmd = []

        # Username options
        username = options.get("username")
        if username:
            cmd.extend(["-l", username])

        user_list = options.get("user_list")
        if user_list:
            cmd.extend(["-L", str(user_list)])

        # Password options
        password = options.get("password")
        if password:
            cmd.extend(["-p", password])

        pass_list = options.get("pass_list")
        if pass_list:
            cmd.extend(["-P", str(pass_list)])

        # Colon-separated file (user:pass)
        colon_file = options.get("colon_file")
        if colon_file:
            cmd.extend(["-C", str(colon_file)])

        # Threads
        threads = options.get("threads", self.hydra_config.default_threads)
        cmd.extend(["-t", str(threads)])

        # Port
        port = options.get("port")
        if port:
            cmd.extend(["-s", str(port)])

        # SSL
        if options.get("ssl"):
            cmd.append("-S")

        # Virtual host
        vhost = options.get("vhost")
        if vhost:
            cmd.extend(["-V", vhost])

        # Exit on first found
        if options.get("exit_first", self.hydra_config.exit_on_first):
            cmd.append("-f")

        # Loop around users
        if options.get("loop_users"):
            cmd.append("-u")

        # Verbose
        if options.get("verbose", self.hydra_config.verbose):
            cmd.append("-v")

        # Wait time
        wait = options.get("wait")
        if wait:
            cmd.extend(["-W", str(wait)])

        # Timeout
        timeout = options.get("timeout", self.hydra_config.timeout)
        cmd.extend(["-w", str(timeout)])

        # Output file
        output_file = options.get("output_file")
        if output_file:
            cmd.extend(["-o", str(output_file)])

        # Target
        cmd.append(target)

        # Service with optional parameters
        service = options.get("service", "ssh")
        http_path = options.get("http_path")
        http_form = options.get("http_form")

        if service.startswith("http") and http_form:
            # HTTP form attack: http-post-form "/path:user=^USER^&pass=^PASS^:F=error"
            cmd.append(f"{service}")
            cmd.append(http_form)
        elif service.startswith("http") and http_path:
            cmd.append(f"{service}")
            cmd.append(http_path)
        else:
            cmd.append(service)

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse hydra output."""
        result = {
            "raw_output": output,
            "credentials": [],
            "attempts": 0,
            "valid_passwords": 0,
            "hosts_done": 0,
            "errors": [],
        }

        lines = output.strip().split('\n')

        for line in lines:
            # Successful credential
            # [22][ssh] host: 192.168.1.1   login: admin   password: admin123
            cred_match = re.search(
                r'\[(\d+)\]\[(\w+)\]\s+host:\s*(\S+)\s+login:\s*(\S+)\s+password:\s*(.+)',
                line
            )
            if cred_match:
                credential = {
                    "port": int(cred_match.group(1)),
                    "service": cred_match.group(2),
                    "host": cred_match.group(3),
                    "username": cred_match.group(4),
                    "password": cred_match.group(5).strip(),
                }
                result["credentials"].append(credential)
                result["valid_passwords"] += 1
                continue

            # Alternative format: [ssh] 192.168.1.1:22 - login: admin - password: admin123
            alt_match = re.search(
                r'\[(\w+)\]\s+(\S+):(\d+).*login:\s*(\S+).*password:\s*(.+)',
                line
            )
            if alt_match:
                credential = {
                    "service": alt_match.group(1),
                    "host": alt_match.group(2),
                    "port": int(alt_match.group(3)),
                    "username": alt_match.group(4),
                    "password": alt_match.group(5).strip(),
                }
                result["credentials"].append(credential)
                result["valid_passwords"] += 1
                continue

            # Attempts statistics
            attempts_match = re.search(
                r'(\d+)\s+valid password[s]? found',
                line
            )
            if attempts_match:
                result["valid_passwords"] = int(attempts_match.group(1))
                continue

            # Total attempts
            total_match = re.search(
                r'(\d+)\s+of\s+(\d+)\s+target[s]?.*completed',
                line
            )
            if total_match:
                result["hosts_done"] = int(total_match.group(1))
                continue

            # Error messages
            if "error" in line.lower() or "failed" in line.lower():
                result["errors"].append(line.strip())

            # Connection refused
            if "Connection refused" in line:
                result["errors"].append(f"Connection refused: {line.strip()}")

        return result

    async def attack_ssh(
        self,
        target: str,
        user_list: str | None = None,
        pass_list: str | None = None,
        username: str | None = None,
        password: str | None = None,
        port: int = 22,
    ) -> dict[str, Any]:
        """Attack SSH service.

        Args:
            target: Target host
            user_list: Path to username wordlist
            pass_list: Path to password wordlist
            username: Single username to try
            password: Single password to try
            port: SSH port

        Returns:
            Attack results with found credentials
        """
        options = {
            "service": "ssh",
            "port": port,
        }

        if user_list:
            options["user_list"] = user_list
        elif username:
            options["username"] = username

        if pass_list:
            options["pass_list"] = pass_list
        elif password:
            options["password"] = password

        result = await self.execute(target, options)

        # Emit events for found credentials
        for cred in result.data.get("credentials", []):
            await event_bus.emit(Events.CREDENTIAL_CRACKED, {
                "service": "ssh",
                "host": target,
                "username": cred["username"],
                "password": cred["password"],
            })

        return result.data

    async def attack_http_form(
        self,
        target: str,
        form_path: str,
        form_data: str,
        failure_string: str,
        user_list: str | None = None,
        pass_list: str | None = None,
        username: str | None = None,
        ssl: bool = False,
    ) -> dict[str, Any]:
        """Attack HTTP form login.

        Args:
            target: Target host
            form_path: Path to login form (e.g., /login.php)
            form_data: Form data with ^USER^ and ^PASS^ placeholders
            failure_string: String that indicates login failure
            user_list: Path to username wordlist
            pass_list: Path to password wordlist
            username: Single username
            ssl: Use HTTPS

        Returns:
            Attack results with found credentials
        """
        service = "https-post-form" if ssl else "http-post-form"

        # Build form string: "/path:user=^USER^&pass=^PASS^:F=failure"
        http_form = f"{form_path}:{form_data}:F={failure_string}"

        options = {
            "service": service,
            "http_form": http_form,
            "ssl": ssl,
        }

        if user_list:
            options["user_list"] = user_list
        elif username:
            options["username"] = username

        if pass_list:
            options["pass_list"] = pass_list

        result = await self.execute(target, options)
        return result.data

    async def attack_ftp(
        self,
        target: str,
        user_list: str | None = None,
        pass_list: str | None = None,
        username: str | None = None,
        port: int = 21,
    ) -> dict[str, Any]:
        """Attack FTP service."""
        options = {
            "service": "ftp",
            "port": port,
        }

        if user_list:
            options["user_list"] = user_list
        elif username:
            options["username"] = username

        if pass_list:
            options["pass_list"] = pass_list

        result = await self.execute(target, options)
        return result.data

    async def attack_smb(
        self,
        target: str,
        user_list: str | None = None,
        pass_list: str | None = None,
        username: str | None = None,
        port: int = 445,
    ) -> dict[str, Any]:
        """Attack SMB/CIFS service."""
        options = {
            "service": "smb",
            "port": port,
        }

        if user_list:
            options["user_list"] = user_list
        elif username:
            options["username"] = username

        if pass_list:
            options["pass_list"] = pass_list

        result = await self.execute(target, options)
        return result.data

    async def attack_rdp(
        self,
        target: str,
        user_list: str | None = None,
        pass_list: str | None = None,
        username: str | None = None,
        port: int = 3389,
    ) -> dict[str, Any]:
        """Attack RDP service."""
        options = {
            "service": "rdp",
            "port": port,
        }

        if user_list:
            options["user_list"] = user_list
        elif username:
            options["username"] = username

        if pass_list:
            options["pass_list"] = pass_list

        result = await self.execute(target, options)
        return result.data

    async def attack_mysql(
        self,
        target: str,
        user_list: str | None = None,
        pass_list: str | None = None,
        username: str = "root",
        port: int = 3306,
    ) -> dict[str, Any]:
        """Attack MySQL service."""
        options = {
            "service": "mysql",
            "port": port,
            "username": username,
        }

        if user_list:
            options["user_list"] = user_list

        if pass_list:
            options["pass_list"] = pass_list

        result = await self.execute(target, options)
        return result.data
