"""Default event handlers for common operations."""
from voidwave.core.logging import get_logger
from voidwave.orchestration.events import Events, event_bus

logger = get_logger(__name__)


async def on_vulnerability_found(data: dict) -> None:
    """Handle vulnerability discovery."""
    severity = data.get("severity", "unknown")
    vuln_id = data.get("id", "unknown")
    title = data.get("title", "Unknown vulnerability")
    target = data.get("target", "")

    logger.warning(
        f"Vulnerability found: [{severity.upper()}] {vuln_id} - {title} on {target}"
    )

    # Store in database
    from voidwave.db.engine import get_db

    db = await get_db()
    await db.execute(
        """
        INSERT INTO audit_log (level, category, message, details)
        VALUES (?, ?, ?, ?)
        """,
        ("warning", "vulnerability", f"{vuln_id}: {title}", str(data)),
    )


async def on_credential_cracked(data: dict) -> None:
    """Handle cracked credential."""
    cred_type = data.get("type", "unknown")
    target = data.get("target", "")

    logger.info(f"Credential cracked: {cred_type} for {target}")

    # Store encrypted in loot table
    from voidwave.loot.storage import loot_storage

    await loot_storage.store(
        loot_type="credential",
        data=data,
        source_tool=data.get("tool", "unknown"),
    )


async def on_handshake_captured(data: dict) -> None:
    """Handle WPA handshake capture."""
    bssid = data.get("bssid", "")
    essid = data.get("essid", "")
    file_path = data.get("file", "")

    logger.info(f"Handshake captured: {essid} ({bssid}) -> {file_path}")

    # Store reference
    from voidwave.db.engine import get_db

    db = await get_db()
    await db.execute(
        """
        INSERT INTO loot (loot_type, encrypted_data, source_tool, metadata)
        VALUES (?, ?, ?, ?)
        """,
        (
            "handshake",
            file_path,
            "airodump-ng",
            str({"bssid": bssid, "essid": essid}),
        ),
    )


def register_default_handlers() -> None:
    """Register default event handlers."""
    event_bus.on(Events.VULNERABILITY_FOUND, on_vulnerability_found)
    event_bus.on(Events.CREDENTIAL_CRACKED, on_credential_cracked)
    event_bus.on(Events.HANDSHAKE_CAPTURED, on_handshake_captured)

    logger.info("Registered default event handlers")
