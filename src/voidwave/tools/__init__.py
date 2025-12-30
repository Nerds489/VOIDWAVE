"""Built-in tool wrappers for VOIDWAVE.

This module provides wrappers for external security tools used by VOIDWAVE.
Each wrapper inherits from BaseToolWrapper and implements:
- build_command(): Construct command-line arguments
- parse_output(): Parse tool output into structured data
"""

from voidwave.tools.airodump import AirodumpConfig, AirodumpTool
from voidwave.tools.aireplay import AireplayConfig, AireplayTool, AttackMode
from voidwave.tools.base import BaseToolWrapper, ToolExecution
from voidwave.tools.ffuf import FfufConfig, FfufTool
from voidwave.tools.gobuster import GobusterConfig, GobusterTool
from voidwave.tools.hashcat import HashcatConfig, HashcatTool
from voidwave.tools.hydra import HydraConfig, HydraTool
from voidwave.tools.john import JohnConfig, JohnTool
from voidwave.tools.masscan import MasscanConfig, MasscanTool
from voidwave.tools.nikto import NiktoConfig, NiktoTool
from voidwave.tools.nmap import NmapConfig, NmapTool
from voidwave.tools.nuclei import NucleiConfig, NucleiTool
from voidwave.tools.reaver import ReaverConfig, ReaverTool
from voidwave.tools.sqlmap import SqlmapConfig, SqlmapTool
from voidwave.tools.subfinder import SubfinderConfig, SubfinderTool
from voidwave.tools.tcpdump import TcpdumpConfig, TcpdumpTool
from voidwave.tools.wash import WashConfig, WashTool
from voidwave.tools.whatweb import WhatWebConfig, WhatWebTool

__all__ = [
    # Base classes
    "BaseToolWrapper",
    "ToolExecution",
    # Wireless tools
    "AirodumpTool",
    "AirodumpConfig",
    "AireplayTool",
    "AireplayConfig",
    "AttackMode",
    "ReaverTool",
    "ReaverConfig",
    "WashTool",
    "WashConfig",
    # Network scanning
    "NmapTool",
    "NmapConfig",
    "MasscanTool",
    "MasscanConfig",
    # Password cracking
    "HashcatTool",
    "HashcatConfig",
    "HydraTool",
    "HydraConfig",
    "JohnTool",
    "JohnConfig",
    # Packet capture
    "TcpdumpTool",
    "TcpdumpConfig",
    # Web reconnaissance
    "GobusterTool",
    "GobusterConfig",
    "NiktoTool",
    "NiktoConfig",
    "WhatWebTool",
    "WhatWebConfig",
    "NucleiTool",
    "NucleiConfig",
    "FfufTool",
    "FfufConfig",
    # OSINT
    "SubfinderTool",
    "SubfinderConfig",
    # Exploitation
    "SqlmapTool",
    "SqlmapConfig",
]
