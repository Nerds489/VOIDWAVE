"""Built-in chain definitions."""

from voidwave.chaining.builtin.scanning import register_scanning_chains
from voidwave.chaining.builtin.wireless import register_wireless_chains
from voidwave.chaining.builtin.credentials import register_credential_chains


def register_all_builtin_chains() -> None:
    """Register all built-in chains with the registry."""
    register_scanning_chains()
    register_wireless_chains()
    register_credential_chains()
