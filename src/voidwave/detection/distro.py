"""Linux distribution detection and package manager mapping."""
import platform
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Self


class DistroFamily(Enum):
    """Linux distribution families."""

    DEBIAN = "debian"
    REDHAT = "redhat"
    ARCH = "arch"
    SUSE = "suse"
    ALPINE = "alpine"
    VOID = "void"
    GENTOO = "gentoo"
    NIXOS = "nixos"
    UNKNOWN = "unknown"


class PackageManager(Enum):
    """Package manager identifiers."""

    APT = "apt"
    DNF = "dnf"
    YUM = "yum"
    PACMAN = "pacman"
    ZYPPER = "zypper"
    APK = "apk"
    XBPS = "xbps"
    EMERGE = "emerge"
    NIX = "nix"
    UNKNOWN = "unknown"


@dataclass
class SystemInfo:
    """Detected system information."""

    distro_id: str
    distro_name: str
    distro_version: str
    distro_family: DistroFamily
    package_manager: PackageManager
    is_immutable: bool
    immutable_type: str | None
    is_wsl: bool
    is_container: bool
    is_steamdeck: bool
    architecture: str
    kernel_version: str

    @classmethod
    def detect(cls) -> Self:
        """Detect current system information."""
        # Read os-release
        os_release = cls._read_os_release()

        distro_id = os_release.get("ID", "unknown").lower()
        distro_name = os_release.get("NAME", "Unknown")
        distro_version = os_release.get("VERSION_ID", "")

        # Determine family
        id_like = os_release.get("ID_LIKE", "").lower().split()
        distro_family = cls._determine_family(distro_id, id_like)

        # Determine package manager
        package_manager = cls._determine_package_manager(distro_id, distro_family)

        # Check special system types
        is_immutable, immutable_type = cls._check_immutable()
        is_wsl = cls._check_wsl()
        is_container = cls._check_container()
        is_steamdeck = cls._check_steamdeck()

        return cls(
            distro_id=distro_id,
            distro_name=distro_name,
            distro_version=distro_version,
            distro_family=distro_family,
            package_manager=package_manager,
            is_immutable=is_immutable,
            immutable_type=immutable_type,
            is_wsl=is_wsl,
            is_container=is_container,
            is_steamdeck=is_steamdeck,
            architecture=platform.machine(),
            kernel_version=platform.release(),
        )

    @staticmethod
    def _read_os_release() -> dict[str, str]:
        """Read /etc/os-release file."""
        os_release = {}
        for path in [Path("/etc/os-release"), Path("/usr/lib/os-release")]:
            if path.exists():
                content = path.read_text()
                for line in content.splitlines():
                    if "=" in line:
                        key, _, value = line.partition("=")
                        os_release[key] = value.strip('"\'')
                break
        return os_release

    @staticmethod
    def _determine_family(distro_id: str, id_like: list[str]) -> DistroFamily:
        """Determine distribution family."""
        debian_ids = {
            "debian",
            "ubuntu",
            "kali",
            "parrot",
            "mint",
            "pop",
            "elementary",
        }
        redhat_ids = {"fedora", "rhel", "centos", "rocky", "alma", "oracle"}
        arch_ids = {"arch", "manjaro", "endeavouros", "garuda", "blackarch"}
        suse_ids = {"opensuse", "suse", "opensuse-leap", "opensuse-tumbleweed"}

        if distro_id in debian_ids or "debian" in id_like or "ubuntu" in id_like:
            return DistroFamily.DEBIAN
        if distro_id in redhat_ids or "fedora" in id_like or "rhel" in id_like:
            return DistroFamily.REDHAT
        if distro_id in arch_ids or "arch" in id_like:
            return DistroFamily.ARCH
        if distro_id in suse_ids or "suse" in id_like:
            return DistroFamily.SUSE
        if distro_id == "alpine":
            return DistroFamily.ALPINE
        if distro_id == "void":
            return DistroFamily.VOID
        if distro_id == "gentoo":
            return DistroFamily.GENTOO
        if distro_id == "nixos":
            return DistroFamily.NIXOS
        return DistroFamily.UNKNOWN

    @staticmethod
    def _determine_package_manager(
        distro_id: str, family: DistroFamily
    ) -> PackageManager:
        """Determine package manager for distribution."""
        manager_map = {
            DistroFamily.DEBIAN: PackageManager.APT,
            DistroFamily.REDHAT: PackageManager.DNF,
            DistroFamily.ARCH: PackageManager.PACMAN,
            DistroFamily.SUSE: PackageManager.ZYPPER,
            DistroFamily.ALPINE: PackageManager.APK,
            DistroFamily.VOID: PackageManager.XBPS,
            DistroFamily.GENTOO: PackageManager.EMERGE,
            DistroFamily.NIXOS: PackageManager.NIX,
        }
        return manager_map.get(family, PackageManager.UNKNOWN)

    @staticmethod
    def _check_immutable() -> tuple[bool, str | None]:
        """Check if system is immutable."""
        # rpm-ostree (Fedora Silverblue, Kinoite)
        if Path("/run/ostree-booted").exists():
            return True, "ostree"
        # Check for read-only /usr
        if Path("/usr").stat().st_mode & 0o222 == 0:
            return True, "readonly-usr"
        return False, None

    @staticmethod
    def _check_wsl() -> bool:
        """Check if running in WSL."""
        return "microsoft" in platform.release().lower()

    @staticmethod
    def _check_container() -> bool:
        """Check if running in container."""
        return Path("/.dockerenv").exists() or Path("/run/.containerenv").exists()

    @staticmethod
    def _check_steamdeck() -> bool:
        """Check if running on Steam Deck."""
        os_release = SystemInfo._read_os_release()
        return os_release.get("ID") == "steamos"


# Singleton for cached system info
_system_info: SystemInfo | None = None


def get_system_info() -> SystemInfo:
    """Get cached system information."""
    global _system_info
    if _system_info is None:
        _system_info = SystemInfo.detect()
    return _system_info
