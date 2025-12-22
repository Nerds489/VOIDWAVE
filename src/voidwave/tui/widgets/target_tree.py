"""Target hierarchy tree widget."""
from dataclasses import dataclass
from typing import ClassVar

from textual.widgets import Tree
from textual.widgets.tree import TreeNode


@dataclass
class TargetNode:
    """Target tree node data."""

    target_type: str  # network, host, service, vuln
    value: str
    status: str = "pending"  # pending, scanning, completed
    metadata: dict | None = None


class TargetTree(Tree[TargetNode]):
    """Hierarchical tree view of discovered targets."""

    DEFAULT_CSS: ClassVar[str] = """
    TargetTree {
        height: 100%;
        border: solid $border-dim;
        background: $surface;
    }
    """

    def __init__(self, *args, **kwargs) -> None:
        super().__init__("Targets", *args, **kwargs)
        self._networks: dict[str, TreeNode] = {}
        self._hosts: dict[str, TreeNode] = {}

    def add_network(self, cidr: str) -> TreeNode:
        """Add a network to the tree."""
        if cidr in self._networks:
            return self._networks[cidr]

        node_data = TargetNode(target_type="network", value=cidr)
        node = self.root.add(f"🌐 {cidr}", data=node_data)
        self._networks[cidr] = node
        return node

    def add_host(self, ip: str, network: str | None = None, hostname: str | None = None) -> TreeNode:
        """Add a host to the tree."""
        if ip in self._hosts:
            return self._hosts[ip]

        label = f"💻 {ip}"
        if hostname:
            label += f" ({hostname})"

        node_data = TargetNode(
            target_type="host",
            value=ip,
            metadata={"hostname": hostname},
        )

        # Add under network if specified
        if network and network in self._networks:
            parent = self._networks[network]
        else:
            parent = self.root

        node = parent.add(label, data=node_data)
        self._hosts[ip] = node
        return node

    def add_service(self, host_ip: str, port: int, service: str, version: str | None = None) -> TreeNode | None:
        """Add a service under a host."""
        if host_ip not in self._hosts:
            return None

        host_node = self._hosts[host_ip]

        label = f"📦 {port}/{service}"
        if version:
            label += f" [{version}]"

        node_data = TargetNode(
            target_type="service",
            value=f"{port}/{service}",
            metadata={"port": port, "service": service, "version": version},
        )

        return host_node.add(label, data=node_data)

    def add_vulnerability(self, host_ip: str, vuln_id: str, severity: str, title: str) -> TreeNode | None:
        """Add a vulnerability finding."""
        if host_ip not in self._hosts:
            return None

        host_node = self._hosts[host_ip]

        severity_icons = {
            "critical": "🔴",
            "high": "🟠",
            "medium": "🟡",
            "low": "🔵",
            "info": "⚪",
        }
        icon = severity_icons.get(severity.lower(), "⚪")

        label = f"{icon} {vuln_id}: {title}"

        node_data = TargetNode(
            target_type="vuln",
            value=vuln_id,
            metadata={"severity": severity, "title": title},
        )

        return host_node.add(label, data=node_data)

    def update_status(self, target_type: str, value: str, status: str) -> None:
        """Update status of a target node."""
        status_indicators = {
            "pending": "⏳",
            "scanning": "🔄",
            "completed": "✅",
            "failed": "❌",
        }

        node = None
        if target_type == "network":
            node = self._networks.get(value)
        elif target_type == "host":
            node = self._hosts.get(value)

        if node and node.data:
            node.data.status = status
            # Update visual indicator
            indicator = status_indicators.get(status, "")
            # Re-render would go here in full implementation
