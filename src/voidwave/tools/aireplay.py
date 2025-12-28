"""Aireplay-ng wireless packet injection wrapper with all attack modes."""
from __future__ import annotations

import re
from enum import Enum
from typing import Any, ClassVar

from pydantic import BaseModel

from voidwave.core.logging import get_logger
from voidwave.orchestration.events import Events, event_bus
from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper

logger = get_logger(__name__)


class AttackMode(str, Enum):
    """Aireplay-ng attack modes."""

    DEAUTH = "deauth"  # -0: Deauthentication
    FAKEAUTH = "fakeauth"  # -1: Fake authentication
    INTERACTIVE = "interactive"  # -2: Interactive packet replay
    ARPREPLAY = "arpreplay"  # -3: ARP request replay
    CHOPCHOP = "chopchop"  # -4: KoreK chopchop attack
    FRAGMENT = "fragment"  # -5: Fragmentation attack
    CAFFE_LATTE = "caffe_latte"  # -6: Caffe-latte attack
    CFRAG = "cfrag"  # -7: Client-oriented fragmentation
    MIGMODE = "migmode"  # -8: WPA Migration Mode
    TEST = "test"  # -9: Injection test


class AireplayConfig(BaseModel):
    """Aireplay-ng specific configuration."""

    default_deauth_count: int = 10
    ignore_negative_ack: bool = False
    retry_count: int = 3
    packet_per_second: int = 10


class AireplayTool(BaseToolWrapper):
    """Aireplay-ng wireless packet injection wrapper with all attack modes."""

    TOOL_BINARY: ClassVar[str] = "aireplay-ng"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="aireplay-ng",
        version="1.0.0",
        description="Wireless packet injection and replay attacks",
        author="VOIDWAVE",
        plugin_type=PluginType.TOOL,
        capabilities=[Capability.WIRELESS_ATTACK],
        requires_root=True,
        external_tools=["aireplay-ng"],
        config_schema=AireplayConfig,
    )

    # Attack mode flags
    ATTACK_FLAGS = {
        AttackMode.DEAUTH: "--deauth",
        AttackMode.FAKEAUTH: "--fakeauth",
        AttackMode.INTERACTIVE: "--interactive",
        AttackMode.ARPREPLAY: "--arpreplay",
        AttackMode.CHOPCHOP: "--chopchop",
        AttackMode.FRAGMENT: "--fragment",
        AttackMode.CAFFE_LATTE: "--caffe-latte",
        AttackMode.CFRAG: "--cfrag",
        AttackMode.MIGMODE: "--migmode",
        AttackMode.TEST: "--test",
    }

    def __init__(self, aireplay_config: AireplayConfig | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self.aireplay_config = aireplay_config or AireplayConfig()

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build aireplay-ng command.

        Args:
            target: The wireless interface (e.g., wlan0mon)
            options: Command options including:
                - attack: Attack mode (AttackMode enum value or string)
                - bssid: Target access point BSSID (-a)
                - client: Target client MAC (-c)
                - source: Source MAC for fakeauth (-h)
                - count: Packet count for deauth (0 = continuous)
                - delay: Delay between packets
                - essid: ESSID for fakeauth (-e)
                - keepalive: Keepalive interval for fakeauth (-q)
                - reassoc: Reassociation timing for fakeauth (-Q)
                - read_file: Read packets from pcap file (-r)
        """
        cmd = []

        # Get attack mode
        attack = options.get("attack", AttackMode.DEAUTH)
        if isinstance(attack, str):
            attack = AttackMode(attack)

        # Attack-specific command building
        if attack == AttackMode.DEAUTH:
            cmd.extend(self._build_deauth_command(options))
        elif attack == AttackMode.FAKEAUTH:
            cmd.extend(self._build_fakeauth_command(options))
        elif attack == AttackMode.ARPREPLAY:
            cmd.extend(self._build_arpreplay_command(options))
        elif attack == AttackMode.CHOPCHOP:
            cmd.extend(self._build_chopchop_command(options))
        elif attack == AttackMode.FRAGMENT:
            cmd.extend(self._build_fragment_command(options))
        elif attack == AttackMode.CAFFE_LATTE:
            cmd.extend(self._build_caffe_latte_command(options))
        elif attack == AttackMode.INTERACTIVE:
            cmd.extend(self._build_interactive_command(options))
        elif attack == AttackMode.TEST:
            cmd.extend(self._build_test_command(options))
        else:
            # Generic attack flag
            flag = self.ATTACK_FLAGS.get(attack, "--deauth")
            count = options.get("count", self.aireplay_config.default_deauth_count)
            cmd.extend([flag, str(count)])

        # Common options
        # Target AP BSSID
        bssid = options.get("bssid")
        if bssid:
            cmd.extend(["-a", bssid])

        # Target client MAC
        client = options.get("client")
        if client:
            cmd.extend(["-c", client])

        # Source MAC (spoof)
        source = options.get("source")
        if source:
            cmd.extend(["-h", source])

        # Ignore negative ACK
        if options.get("ignore_negative", self.aireplay_config.ignore_negative_ack):
            cmd.append("-x")

        # Read from file
        read_file = options.get("read_file")
        if read_file:
            cmd.extend(["-r", str(read_file)])

        # Interface (target)
        cmd.append(target)

        return cmd

    def _build_deauth_command(self, options: dict[str, Any]) -> list[str]:
        """Build deauthentication attack command."""
        count = options.get("count", self.aireplay_config.default_deauth_count)
        return ["--deauth", str(count)]

    def _build_fakeauth_command(self, options: dict[str, Any]) -> list[str]:
        """Build fake authentication attack command."""
        cmd = []

        delay = options.get("delay", 0)
        cmd.extend(["--fakeauth", str(delay)])

        # ESSID
        essid = options.get("essid")
        if essid:
            cmd.extend(["-e", essid])

        # Keepalive
        keepalive = options.get("keepalive")
        if keepalive:
            cmd.extend(["-q", str(keepalive)])

        # Reassociation
        reassoc = options.get("reassoc")
        if reassoc:
            cmd.extend(["-Q", str(reassoc)])

        return cmd

    def _build_arpreplay_command(self, options: dict[str, Any]) -> list[str]:
        """Build ARP replay attack command."""
        cmd = ["--arpreplay"]

        # Packets per second
        pps = options.get("pps", self.aireplay_config.packet_per_second)
        cmd.extend(["-x", str(pps)])

        # Min/max packet size filtering
        min_size = options.get("min_size")
        if min_size:
            cmd.extend(["-m", str(min_size)])

        max_size = options.get("max_size")
        if max_size:
            cmd.extend(["-n", str(max_size)])

        return cmd

    def _build_chopchop_command(self, options: dict[str, Any]) -> list[str]:
        """Build KoreK chopchop attack command."""
        cmd = ["--chopchop"]

        # Frame control match
        fc = options.get("frame_control")
        if fc:
            cmd.extend(["-F", fc])

        return cmd

    def _build_fragment_command(self, options: dict[str, Any]) -> list[str]:
        """Build fragmentation attack command."""
        cmd = ["--fragment"]

        # Keep IV
        if options.get("keep_iv"):
            cmd.append("-k")

        return cmd

    def _build_caffe_latte_command(self, options: dict[str, Any]) -> list[str]:
        """Build Caffe-Latte attack command."""
        cmd = ["--caffe-latte"]

        # Number of packets
        count = options.get("count")
        if count:
            cmd.extend(["-N", str(count)])

        return cmd

    def _build_interactive_command(self, options: dict[str, Any]) -> list[str]:
        """Build interactive packet replay command."""
        cmd = ["--interactive"]

        # Destination MAC filter
        dest = options.get("dest_mac")
        if dest:
            cmd.extend(["-d", dest])

        # Broadcast filter
        if options.get("broadcast"):
            cmd.append("-b")

        return cmd

    def _build_test_command(self, options: dict[str, Any]) -> list[str]:
        """Build injection test command."""
        cmd = ["--test"]

        # Broadcast probe requests
        if options.get("broadcast_probe"):
            cmd.append("-B")

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse aireplay-ng output."""
        result = {
            "raw_output": output,
            "success": False,
            "packets_sent": 0,
            "acks_received": 0,
            "injection_working": False,
            "auth_status": None,
            "errors": [],
        }

        lines = output.strip().split('\n')

        for line in lines:
            # Deauth packet count
            deauth_match = re.search(
                r'Sending (\d+) directed DeAuth.*(\d+) ACKs',
                line
            )
            if deauth_match:
                result["packets_sent"] = int(deauth_match.group(1))
                result["acks_received"] = int(deauth_match.group(2))
                result["success"] = True
                continue

            # Broadcast deauth
            broadcast_match = re.search(
                r'Sending DeAuth.*to broadcast',
                line
            )
            if broadcast_match:
                result["success"] = True
                result["packets_sent"] += 1
                continue

            # Injection test result
            injection_match = re.search(
                r'Injection is working!',
                line,
                re.IGNORECASE
            )
            if injection_match:
                result["injection_working"] = True
                result["success"] = True
                continue

            # Fake auth success
            auth_success = re.search(
                r'Association successful',
                line,
                re.IGNORECASE
            )
            if auth_success:
                result["auth_status"] = "associated"
                result["success"] = True
                continue

            # Auth failure
            auth_fail = re.search(
                r'(Association failed|Attack was unsuccessful)',
                line,
                re.IGNORECASE
            )
            if auth_fail:
                result["auth_status"] = "failed"
                result["errors"].append(line.strip())
                continue

            # ARP replay stats
            arp_match = re.search(
                r'Got (\d+) ARP requests.*sent (\d+) packets',
                line
            )
            if arp_match:
                result["arp_captured"] = int(arp_match.group(1))
                result["packets_sent"] = int(arp_match.group(2))
                result["success"] = True
                continue

            # General packet sent
            sent_match = re.search(r'sent (\d+) packet', line)
            if sent_match:
                result["packets_sent"] = int(sent_match.group(1))
                continue

            # Errors
            if "error" in line.lower() or "failed" in line.lower():
                result["errors"].append(line.strip())

        return result

    async def deauth_attack(
        self,
        interface: str,
        bssid: str,
        client: str | None = None,
        count: int = 10,
        continuous: bool = False,
    ) -> dict[str, Any]:
        """Perform deauthentication attack.

        Args:
            interface: Monitor mode interface
            bssid: Target access point BSSID
            client: Target client MAC (None = broadcast)
            count: Number of deauth packets (0 = continuous)
            continuous: If True, send continuously until stopped

        Returns:
            Attack results including packets sent and ACKs received
        """
        options = {
            "attack": AttackMode.DEAUTH,
            "bssid": bssid,
            "count": 0 if continuous else count,
        }

        if client:
            options["client"] = client

        result = await self.execute(interface, options)

        # Emit event
        await event_bus.emit(Events.DEAUTH_SENT, {
            "bssid": bssid,
            "client": client or "broadcast",
            "count": result.data.get("packets_sent", count),
        })

        return result.data

    async def fakeauth_attack(
        self,
        interface: str,
        bssid: str,
        source_mac: str,
        essid: str,
        delay: int = 0,
        keepalive: int | None = None,
    ) -> dict[str, Any]:
        """Perform fake authentication attack.

        Args:
            interface: Monitor mode interface
            bssid: Target access point BSSID
            source_mac: Source MAC to use (your MAC)
            essid: Target network ESSID
            delay: Delay between auth attempts
            keepalive: Keepalive interval (seconds)

        Returns:
            Attack results including authentication status
        """
        options = {
            "attack": AttackMode.FAKEAUTH,
            "bssid": bssid,
            "source": source_mac,
            "essid": essid,
            "delay": delay,
        }

        if keepalive:
            options["keepalive"] = keepalive

        result = await self.execute(interface, options)
        return result.data

    async def arpreplay_attack(
        self,
        interface: str,
        bssid: str,
        source_mac: str,
        pps: int = 10,
    ) -> dict[str, Any]:
        """Perform ARP request replay attack.

        Args:
            interface: Monitor mode interface
            bssid: Target access point BSSID
            source_mac: Source MAC address
            pps: Packets per second

        Returns:
            Attack results including captured ARPs and packets sent
        """
        options = {
            "attack": AttackMode.ARPREPLAY,
            "bssid": bssid,
            "source": source_mac,
            "pps": pps,
        }

        result = await self.execute(interface, options)
        return result.data

    async def injection_test(
        self,
        interface: str,
        bssid: str | None = None,
    ) -> dict[str, Any]:
        """Test packet injection capability.

        Args:
            interface: Monitor mode interface
            bssid: Optional AP to test against

        Returns:
            Test results including injection status
        """
        options = {
            "attack": AttackMode.TEST,
            "broadcast_probe": True,
        }

        if bssid:
            options["bssid"] = bssid

        result = await self.execute(interface, options)
        return result.data

    async def fragment_attack(
        self,
        interface: str,
        bssid: str,
        source_mac: str,
    ) -> dict[str, Any]:
        """Perform fragmentation attack to obtain PRGA.

        Args:
            interface: Monitor mode interface
            bssid: Target access point BSSID
            source_mac: Source MAC address

        Returns:
            Attack results
        """
        options = {
            "attack": AttackMode.FRAGMENT,
            "bssid": bssid,
            "source": source_mac,
        }

        result = await self.execute(interface, options)
        return result.data

    async def chopchop_attack(
        self,
        interface: str,
        bssid: str,
        source_mac: str,
    ) -> dict[str, Any]:
        """Perform KoreK chopchop attack to decrypt WEP.

        Args:
            interface: Monitor mode interface
            bssid: Target access point BSSID
            source_mac: Source MAC address

        Returns:
            Attack results
        """
        options = {
            "attack": AttackMode.CHOPCHOP,
            "bssid": bssid,
            "source": source_mac,
        }

        result = await self.execute(interface, options)
        return result.data
