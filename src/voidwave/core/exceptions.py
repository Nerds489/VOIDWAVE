"""Custom exception hierarchy for VOIDWAVE."""
from .constants import ExitCode


class VoidwaveError(Exception):
    """Base exception for all VOIDWAVE errors."""

    exit_code: ExitCode = ExitCode.FAILURE

    def __init__(self, message: str, details: dict | None = None):
        super().__init__(message)
        self.message = message
        self.details = details or {}


class ConfigurationError(VoidwaveError):
    """Configuration-related errors."""

    exit_code = ExitCode.CONFIG_ERROR


class ToolNotFoundError(VoidwaveError):
    """Required tool not installed."""

    exit_code = ExitCode.TOOL_MISSING


class PermissionError(VoidwaveError):
    """Insufficient permissions for operation."""

    exit_code = ExitCode.PERMISSION_DENIED


class TargetValidationError(VoidwaveError):
    """Invalid or protected target."""

    exit_code = ExitCode.TARGET_INVALID


class NetworkError(VoidwaveError):
    """Network operation failed."""

    exit_code = ExitCode.NETWORK_ERROR


class TimeoutError(VoidwaveError):
    """Operation timed out."""

    exit_code = ExitCode.TIMEOUT


class PluginError(VoidwaveError):
    """Plugin loading or execution error."""

    pass


class SubprocessError(VoidwaveError):
    """Subprocess execution failed."""

    def __init__(
        self, message: str, returncode: int, stdout: str = "", stderr: str = ""
    ):
        super().__init__(
            message, {"returncode": returncode, "stdout": stdout, "stderr": stderr}
        )
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr
