"""Backward-compatible wallet facade — delegates to kairo.services.identity."""

from __future__ import annotations

from typing import Optional

from kairo.models.driver import DriverIdentity
from kairo.services.identity import DriverStore, register_driver as _register_driver, recover_driver


def generate_driver_identity(
    device_fingerprint: Optional[str] = None,
    driver_id: Optional[str] = None,
) -> tuple[DriverIdentity, str]:
    """Legacy API — prefer register_driver(). Returns (identity, empty mnemonic)."""
    from kairo.services.identity import generate_driver_identity as _gen

    identity = _gen(driver_id)
    return identity, ""


def register_driver(
    device_fingerprint: Optional[str] = None,
    driver_id: Optional[str] = None,
    recovery_passphrase: Optional[str] = None,
) -> DriverIdentity:
    """Register driver with mnemonic backup; returns public identity only."""
    result = _register_driver(
        driver_id=driver_id,
        recovery_passphrase=recovery_passphrase,
    )
    return result.identity


def recover_from_mnemonic(
    mnemonic: str,
    *,
    driver_id: Optional[str] = None,
    recovery_passphrase: Optional[str] = None,
) -> DriverIdentity:
    return recover_driver(
        mnemonic,
        driver_id=driver_id,
        recovery_passphrase=recovery_passphrase,
    )


def get_driver(driver_id: str) -> Optional[DriverIdentity]:
    return DriverStore().get(driver_id)
