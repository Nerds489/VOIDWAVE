"""Wireless channel management and hopping."""
import asyncio
from typing import Callable

from voidwave.core.logging import get_logger

logger = get_logger(__name__)

# Channel frequencies
CHANNELS_2GHZ = list(range(1, 15))  # 1-14
CHANNELS_5GHZ = [
    36,
    40,
    44,
    48,
    52,
    56,
    60,
    64,
    100,
    104,
    108,
    112,
    116,
    120,
    124,
    128,
    132,
    136,
    140,
    144,
    149,
    153,
    157,
    161,
    165,
]
CHANNELS_6GHZ = list(range(1, 234, 4))  # 6GHz channels


class ChannelHopper:
    """Automated channel hopping for wireless scanning."""

    def __init__(
        self,
        interface: str,
        channels: list[int] | None = None,
        interval: float = 0.5,
        bands: list[str] | None = None,
    ) -> None:
        self.interface = interface
        self.interval = interval
        self._running = False
        self._task: asyncio.Task | None = None
        self._current_channel = 0
        self._on_channel_change: Callable[[int], None] | None = None

        # Determine channels
        if channels:
            self.channels = channels
        else:
            self.channels = self._get_channels_for_bands(bands or ["2.4GHz"])

    def _get_channels_for_bands(self, bands: list[str]) -> list[int]:
        """Get channel list for specified bands."""
        channels = []
        for band in bands:
            if "2.4" in band or "2g" in band.lower():
                channels.extend(CHANNELS_2GHZ[:13])  # Skip 14 for most regions
            if "5" in band or "5g" in band.lower():
                channels.extend(CHANNELS_5GHZ)
            if "6" in band or "6g" in band.lower():
                channels.extend(CHANNELS_6GHZ)
        return channels or CHANNELS_2GHZ[:13]

    @property
    def current_channel(self) -> int:
        return self._current_channel

    def on_channel_change(self, callback: Callable[[int], None]) -> None:
        """Register callback for channel changes."""
        self._on_channel_change = callback

    async def start(self) -> None:
        """Start channel hopping."""
        if self._running:
            return

        self._running = True
        self._task = asyncio.create_task(self._hop_loop())
        logger.info(f"Channel hopping started on {self.interface}")

    async def stop(self) -> None:
        """Stop channel hopping."""
        self._running = False
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        logger.info("Channel hopping stopped")

    async def set_channel(self, channel: int) -> bool:
        """Set interface to specific channel."""
        try:
            process = await asyncio.create_subprocess_exec(
                "iw",
                self.interface,
                "set",
                "channel",
                str(channel),
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.PIPE,
            )
            _, stderr = await process.communicate()

            if process.returncode == 0:
                self._current_channel = channel
                if self._on_channel_change:
                    self._on_channel_change(channel)
                return True

            logger.debug(f"Failed to set channel {channel}: {stderr.decode()}")
            return False

        except Exception as e:
            logger.error(f"Channel set error: {e}")
            return False

    async def _hop_loop(self) -> None:
        """Main channel hopping loop."""
        channel_idx = 0

        while self._running:
            channel = self.channels[channel_idx]
            await self.set_channel(channel)

            channel_idx = (channel_idx + 1) % len(self.channels)
            await asyncio.sleep(self.interval)
