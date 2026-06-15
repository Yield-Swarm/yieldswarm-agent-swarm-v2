"""Tests for Kairo cryptographic identity and pipeline."""

from __future__ import annotations

import pytest

eth_account = pytest.importorskip("eth_account")

from kairo.identity.driver_wallet import (
    create_driver_identity,
    sign_message,
    verify_signature,
)
from kairo.payments.fees import RideFare, calculate_earnings
from kairo.pipeline.mandelbrot_router import classify_telemetry
from kairo.telemetry.schema import DrivingTelemetry, GeoPoint, SignedTelemetry


def test_driver_identity_deterministic():
    id1, key1 = create_driver_identity("driver-abc")
    id2, key2 = create_driver_identity("driver-abc")
    assert id1.evm_address == id2.evm_address
    assert id1.iotex_address == id2.iotex_address
    assert key1 == key2


def test_sign_and_verify():
    identity, private_key = create_driver_identity("driver-test")
    payload = {"driver_id": "driver-test", "action": "telemetry"}
    sig = sign_message(private_key, payload)
    assert verify_signature(identity, payload, sig)


def test_mandelbrot_classification():
    identity, _ = create_driver_identity("driver-geo")
    tel = DrivingTelemetry(
        driver_id=identity.driver_id,
        evm_address=identity.evm_address,
        iotex_address=identity.iotex_address,
        location=GeoPoint(lat=39.7392, lng=-104.9903),
        distance_miles=5.0,
    )
    signed = SignedTelemetry(telemetry=tel, signature="0x00")
    zone = classify_telemetry(signed)
    assert zone.zone_id.startswith("mb-")
    assert 0 <= zone.shard_id < 120
    assert zone.tree_path in (
        "kether", "chokmah", "binah", "chesed", "geburah", "tiphereth",
        "netzach", "hod", "yesod", "malkuth",
    )


def test_earnings_2x_driver_pay():
    fare = RideFare(
        base_fare_usd=__import__("decimal").Decimal("5.00"),
        distance_miles=__import__("decimal").Decimal("3.0"),
        duration_min=__import__("decimal").Decimal("10"),
    )
    breakdown = calculate_earnings("ride-1", "driver-1", fare)
    assert breakdown.driver_bonus_usd > 0
    assert breakdown.gross_earnings_usd > breakdown.base_pay_usd
