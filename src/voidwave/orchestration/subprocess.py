"""Async subprocess management with PTY support."""
import asyncio
import os
import pty
import signal
from dataclasses import dataclass, field
from typing import Any, AsyncIterator, Callable

from voidwave.core.logging import get_logger

logger = get_logger(__name__)


@dataclass
class ProcessConfig:
    """Configuration for subprocess execution."""

    timeout: int = 600
    use_pty: bool = False  # Force line-buffered output
    env: dict[str, str] = field(default_factory=dict)
    cwd: str | None = None
    shell: bool = False


@dataclass
class ProcessResult:
    """Result of subprocess execution."""

    command: list[str]
    exit_code: int
    stdout: str
    stderr: str
    duration: float
    timed_out: bool = False
    cancelled: bool = False


class SubprocessManager:
    """Manages async subprocess execution with streaming."""

    def __init__(self) -> None:
        self._processes: dict[str, asyncio.subprocess.Process] = {}
        self._semaphore = asyncio.Semaphore(10)  # Max concurrent processes

    async def execute(
        self,
        command: list[str],
        config: ProcessConfig | None = None,
        on_stdout: Callable[[str], None] | None = None,
        on_stderr: Callable[[str], None] | None = None,
    ) -> ProcessResult:
        """Execute a subprocess with output streaming."""
        config = config or ProcessConfig()
        process_id = f"{command[0]}_{id(command)}"

        async with self._semaphore:
            import time

            start_time = time.time()

            try:
                if config.use_pty:
                    result = await self._execute_with_pty(command, config, on_stdout)
                else:
                    result = await self._execute_standard(
                        command, config, on_stdout, on_stderr
                    )

                result.duration = time.time() - start_time
                return result

            except asyncio.TimeoutError:
                return ProcessResult(
                    command=command,
                    exit_code=-1,
                    stdout="",
                    stderr="Timeout",
                    duration=time.time() - start_time,
                    timed_out=True,
                )
            except asyncio.CancelledError:
                return ProcessResult(
                    command=command,
                    exit_code=-1,
                    stdout="",
                    stderr="Cancelled",
                    duration=time.time() - start_time,
                    cancelled=True,
                )
            finally:
                if process_id in self._processes:
                    del self._processes[process_id]

    async def _execute_standard(
        self,
        command: list[str],
        config: ProcessConfig,
        on_stdout: Callable[[str], None] | None,
        on_stderr: Callable[[str], None] | None,
    ) -> ProcessResult:
        """Standard subprocess execution."""
        env = {**os.environ, **config.env}

        process = await asyncio.create_subprocess_exec(
            *command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            env=env,
            cwd=config.cwd,
            start_new_session=True,
        )

        process_id = f"{command[0]}_{id(command)}"
        self._processes[process_id] = process

        stdout_lines = []
        stderr_lines = []

        async def read_stream(stream, lines, callback):
            while True:
                line = await stream.readline()
                if not line:
                    break
                decoded = line.decode().rstrip()
                lines.append(decoded)
                if callback:
                    callback(decoded)

        try:
            await asyncio.wait_for(
                asyncio.gather(
                    read_stream(process.stdout, stdout_lines, on_stdout),
                    read_stream(process.stderr, stderr_lines, on_stderr),
                ),
                timeout=config.timeout,
            )

            await process.wait()

        except asyncio.TimeoutError:
            await self._terminate_process(process)
            raise

        return ProcessResult(
            command=command,
            exit_code=process.returncode or 0,
            stdout="\n".join(stdout_lines),
            stderr="\n".join(stderr_lines),
            duration=0,  # Set by caller
        )

    async def _execute_with_pty(
        self,
        command: list[str],
        config: ProcessConfig,
        on_stdout: Callable[[str], None] | None,
    ) -> ProcessResult:
        """Execute with PTY for line-buffered output."""
        import subprocess

        master_fd, slave_fd = pty.openpty()

        env = {**os.environ, **config.env}

        process = subprocess.Popen(
            command,
            stdin=slave_fd,
            stdout=slave_fd,
            stderr=slave_fd,
            env=env,
            cwd=config.cwd,
            start_new_session=True,
        )
        os.close(slave_fd)

        output_lines = []

        try:
            loop = asyncio.get_event_loop()

            async def read_pty():
                while True:
                    try:
                        data = await loop.run_in_executor(
                            None, lambda: os.read(master_fd, 1024)
                        )
                        if not data:
                            break
                        decoded = data.decode()
                        for line in decoded.splitlines():
                            output_lines.append(line)
                            if on_stdout:
                                on_stdout(line)
                    except OSError:
                        break

            await asyncio.wait_for(read_pty(), timeout=config.timeout)
            process.wait()

        except asyncio.TimeoutError:
            os.killpg(os.getpgid(process.pid), signal.SIGTERM)
            raise
        finally:
            os.close(master_fd)

        return ProcessResult(
            command=command,
            exit_code=process.returncode or 0,
            stdout="\n".join(output_lines),
            stderr="",
            duration=0,
        )

    async def _terminate_process(self, process: asyncio.subprocess.Process) -> None:
        """Gracefully terminate a process."""
        try:
            pgid = os.getpgid(process.pid)
            os.killpg(pgid, signal.SIGTERM)
            await asyncio.sleep(2)
            if process.returncode is None:
                os.killpg(pgid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass

    async def cancel_all(self) -> None:
        """Cancel all running processes."""
        for process in self._processes.values():
            await self._terminate_process(process)
        self._processes.clear()


# Singleton manager
subprocess_manager = SubprocessManager()
