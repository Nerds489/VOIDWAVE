"""Bootstrap manager for first-run setup and version migrations."""

import os
import platform
import shutil
import asyncio
from pathlib import Path
from dataclasses import dataclass, field

from voidwave import __version__


@dataclass
class SystemInfo:
    """System information detected during bootstrap."""
    distro: str = ""
    distro_version: str = ""
    package_manager: str = ""
    kernel: str = ""
    arch: str = ""
    memory_gb: float = 0.0
    disk_space_gb: float = 0.0
    has_root: bool = False
    has_internet: bool = False
    wireless_interfaces: list[str] = field(default_factory=list)
    gpu_info: dict = field(default_factory=dict)


class BootstrapManager:
    """Manages first-run initialization and version upgrades."""

    # Use XDG-compliant paths
    CONFIG_DIR = Path(os.path.expanduser("~/.config/voidwave"))
    DATA_DIR = Path(os.path.expanduser("~/.local/share/voidwave"))
    INIT_FLAG = CONFIG_DIR / ".initialized"
    VERSION_FILE = CONFIG_DIR / ".version"

    # Directory structure
    DIRECTORIES = [
        "logs",
        "captures",
        "loot",
        "scans",
        "wordlists",
        "templates",
        "templates/nuclei",
        "templates/portals",
        "templates/rules",
        "certs",
        "keys",
        "reports",
    ]

    @classmethod
    def needs_bootstrap(cls) -> bool:
        """Check if first-run wizard should execute."""
        # Never initialized
        if not cls.INIT_FLAG.exists():
            return True

        # Version upgrade check
        if cls.VERSION_FILE.exists():
            installed_version = cls.VERSION_FILE.read_text().strip()
            if installed_version != __version__:
                return cls._needs_migration(installed_version)

        return False

    @classmethod
    def _needs_migration(cls, from_version: str) -> bool:
        """Check if migration is needed between versions."""
        # Parse versions for comparison
        try:
            from_parts = [int(x) for x in from_version.split(".")]
            to_parts = [int(x) for x in __version__.split(".")]

            # Major version change always needs migration
            if from_parts[0] != to_parts[0]:
                return True

            # Minor version upgrade may need migration
            if from_parts[1] < to_parts[1]:
                return True

        except (ValueError, IndexError):
            # Invalid version format, run migration to be safe
            return True

        return False

    @classmethod
    def mark_initialized(cls, version: str | None = None) -> None:
        """Mark first-run as complete."""
        version = version or __version__
        cls.CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        cls.INIT_FLAG.touch()
        cls.VERSION_FILE.write_text(version)

    @classmethod
    def get_installed_version(cls) -> str | None:
        """Get the currently installed version."""
        if cls.VERSION_FILE.exists():
            return cls.VERSION_FILE.read_text().strip()
        return None

    @classmethod
    def ensure_directories(cls) -> None:
        """Create all required directories."""
        cls.CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        cls.DATA_DIR.mkdir(parents=True, exist_ok=True)

        for subdir in cls.DIRECTORIES:
            (cls.DATA_DIR / subdir).mkdir(parents=True, exist_ok=True)

    @classmethod
    async def detect_system(cls) -> SystemInfo:
        """Detect system configuration."""
        info = SystemInfo()

        # Distribution detection
        info.distro, info.distro_version = cls._detect_distribution()
        info.package_manager = cls._detect_package_manager()
        info.kernel = platform.release()
        info.arch = platform.machine()

        # Memory
        info.memory_gb = cls._get_memory_gb()

        # Disk space
        info.disk_space_gb = cls._get_disk_space_gb()

        # Capabilities
        info.has_root = await cls._can_sudo()
        info.has_internet = await cls._check_internet()
        info.wireless_interfaces = cls._get_wireless_interfaces()
        info.gpu_info = await cls._detect_gpu()

        return info

    @classmethod
    def _detect_distribution(cls) -> tuple[str, str]:
        """Detect Linux distribution."""
        os_release = Path("/etc/os-release")
        if os_release.exists():
            content = os_release.read_text()
            name = ""
            version = ""
            for line in content.split("\n"):
                if line.startswith("NAME="):
                    name = line.split("=", 1)[1].strip('"')
                elif line.startswith("VERSION_ID="):
                    version = line.split("=", 1)[1].strip('"')
            return name, version

        # Fallback
        return platform.system(), platform.release()

    @classmethod
    def _detect_package_manager(cls) -> str:
        """Detect the system package manager."""
        managers = [
            ("apt", "apt-get"),
            ("dnf", "dnf"),
            ("yum", "yum"),
            ("pacman", "pacman"),
            ("zypper", "zypper"),
            ("emerge", "emerge"),
            ("apk", "apk"),
            ("brew", "brew"),
        ]

        for name, cmd in managers:
            if shutil.which(cmd):
                return name

        return "unknown"

    @classmethod
    def _get_memory_gb(cls) -> float:
        """Get total system memory in GB."""
        meminfo = Path("/proc/meminfo")
        if meminfo.exists():
            content = meminfo.read_text()
            for line in content.split("\n"):
                if line.startswith("MemTotal:"):
                    kb = int(line.split()[1])
                    return round(kb / 1024 / 1024, 1)
        return 0.0

    @classmethod
    def _get_disk_space_gb(cls) -> float:
        """Get available disk space in GB."""
        try:
            statvfs = os.statvfs(cls.DATA_DIR if cls.DATA_DIR.exists() else Path.home())
            available = statvfs.f_frsize * statvfs.f_bavail
            return round(available / 1024 / 1024 / 1024, 1)
        except OSError:
            return 0.0

    @classmethod
    async def _can_sudo(cls) -> bool:
        """Check if user can use sudo."""
        try:
            proc = await asyncio.create_subprocess_exec(
                "sudo", "-n", "true",
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL,
            )
            await proc.wait()
            return proc.returncode == 0
        except Exception:
            return False

    @classmethod
    async def _check_internet(cls) -> bool:
        """Check internet connectivity."""
        try:
            proc = await asyncio.create_subprocess_exec(
                "ping", "-c", "1", "-W", "2", "8.8.8.8",
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL,
            )
            await proc.wait()
            return proc.returncode == 0
        except Exception:
            return False

    @classmethod
    def _get_wireless_interfaces(cls) -> list[str]:
        """Get list of wireless interfaces."""
        interfaces = []
        wireless_path = Path("/sys/class/net")

        if wireless_path.exists():
            for iface in wireless_path.iterdir():
                wireless_dir = iface / "wireless"
                if wireless_dir.exists():
                    interfaces.append(iface.name)

        return interfaces

    @classmethod
    async def _detect_gpu(cls) -> dict:
        """Detect GPU for hashcat acceleration."""
        result = {"nvidia": None, "amd": None, "intel": None}

        # NVIDIA
        if shutil.which("nvidia-smi"):
            try:
                proc = await asyncio.create_subprocess_exec(
                    "nvidia-smi", "--query-gpu=name,memory.total,driver_version",
                    "--format=csv,noheader",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.DEVNULL,
                )
                stdout, _ = await proc.communicate()
                if proc.returncode == 0:
                    parts = stdout.decode().strip().split(", ")
                    if len(parts) >= 3:
                        result["nvidia"] = {
                            "name": parts[0],
                            "memory": parts[1],
                            "driver": parts[2],
                        }
            except Exception:
                pass

        # AMD ROCm
        if shutil.which("rocm-smi"):
            try:
                proc = await asyncio.create_subprocess_exec(
                    "rocm-smi", "--showproductname",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.DEVNULL,
                )
                stdout, _ = await proc.communicate()
                if proc.returncode == 0:
                    result["amd"] = {"name": stdout.decode().strip()}
            except Exception:
                pass

        # Intel (check for integrated)
        lspci = shutil.which("lspci")
        if lspci:
            try:
                proc = await asyncio.create_subprocess_exec(
                    lspci,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.DEVNULL,
                )
                stdout, _ = await proc.communicate()
                output = stdout.decode()
                for line in output.split("\n"):
                    if "VGA" in line and "Intel" in line:
                        result["intel"] = {"name": line.split(":")[-1].strip()}
                        break
            except Exception:
                pass

        return result
