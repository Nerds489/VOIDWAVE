"""Tests for wireless utilities."""

import pytest


class TestMacValidation:
    """Test MAC address validation."""

    def test_valid_mac_uppercase(self):
        """Valid uppercase MAC should pass."""
        from voidwave.wireless.mac import validate_mac

        assert validate_mac("AA:BB:CC:DD:EE:FF")

    def test_valid_mac_lowercase(self):
        """Valid lowercase MAC should pass."""
        from voidwave.wireless.mac import validate_mac

        assert validate_mac("aa:bb:cc:dd:ee:ff")

    def test_valid_mac_mixed_case(self):
        """Valid mixed case MAC should pass."""
        from voidwave.wireless.mac import validate_mac

        assert validate_mac("Aa:Bb:Cc:Dd:Ee:Ff")

    def test_invalid_mac_wrong_separator(self):
        """Wrong separator should fail."""
        from voidwave.wireless.mac import validate_mac

        assert not validate_mac("AA-BB-CC-DD-EE-FF")

    def test_invalid_mac_too_short(self):
        """Too short MAC should fail."""
        from voidwave.wireless.mac import validate_mac

        assert not validate_mac("AA:BB:CC:DD:EE")

    def test_invalid_mac_too_long(self):
        """Too long MAC should fail."""
        from voidwave.wireless.mac import validate_mac

        assert not validate_mac("AA:BB:CC:DD:EE:FF:GG")

    def test_invalid_mac_bad_characters(self):
        """Invalid hex characters should fail."""
        from voidwave.wireless.mac import validate_mac

        assert not validate_mac("GG:HH:II:JJ:KK:LL")


class TestMacGeneration:
    """Test MAC address generation."""

    def test_generate_random_mac(self):
        """Random MAC should be valid."""
        from voidwave.wireless.mac import generate_mac, validate_mac

        mac = generate_mac()

        assert validate_mac(mac)

    def test_generate_vendor_mac(self):
        """Vendor MAC should use vendor OUI."""
        from voidwave.wireless.mac import generate_mac, validate_mac

        mac = generate_mac(vendor="apple")

        assert validate_mac(mac)
        # Apple OUIs start with specific prefixes
        prefix = mac[:8].upper()
        assert prefix in ["00:03:93", "00:05:02", "00:0A:27", "00:0A:95", "00:0D:93"]

    def test_random_mac_locally_administered(self):
        """Random MAC should have locally administered bit set."""
        from voidwave.wireless.mac import generate_mac

        mac = generate_mac(vendor="random")
        first_byte = int(mac.split(":")[0], 16)

        # Locally administered bit (bit 1) should be set
        assert first_byte & 0x02 == 0x02

    def test_random_mac_unicast(self):
        """Random MAC should be unicast (not multicast)."""
        from voidwave.wireless.mac import generate_mac

        mac = generate_mac(vendor="random")
        first_byte = int(mac.split(":")[0], 16)

        # Multicast bit (bit 0) should be clear
        assert first_byte & 0x01 == 0x00

    def test_generate_mac_uniqueness(self):
        """Generated MACs should be unique."""
        from voidwave.wireless.mac import generate_mac

        macs = {generate_mac() for _ in range(100)}

        # With proper randomness, 100 MACs should all be unique
        assert len(macs) == 100


class TestGetMac:
    """Test MAC address retrieval."""

    @pytest.mark.asyncio
    async def test_get_current_mac_invalid_interface(self):
        """Invalid interface should return None."""
        from voidwave.wireless.mac import get_current_mac

        result = await get_current_mac("nonexistent0")

        assert result is None

    @pytest.mark.asyncio
    async def test_get_permanent_mac_invalid_interface(self):
        """Invalid interface should return None."""
        from voidwave.wireless.mac import get_permanent_mac

        result = await get_permanent_mac("nonexistent0")

        assert result is None
