"""Kairo model and service tests."""

from kairo.models.identity import create_identity, sign_message, verify_identity_payload
from kairo.models.telemetry import create_telemetry
from kairo.services.pipeline import route_telemetry, tree_of_life_projection
from kairo.services.rewards import calculate_ride_economics


def test_identity_create_and_sign():
    identity = create_identity()
    assert identity.evm_address.startswith("0x")
    assert identity.iotex_address.startswith("io1")

    signed = sign_message(identity.public_key_hex, "kairo-test")
    assert signed["signature"]


def test_telemetry_routing():
    event = create_telemetry(
        driver_id="drv-001",
        evm_address="0x" + "a" * 40,
        latitude=39.7392,
        longitude=-104.9903,
    )
    node = route_telemetry(event)
    assert 0 <= node.shard_id < 120
    assert node.reward_weight > 0


def test_ride_economics():
    event = create_telemetry("d", "0x" + "b" * 40, 0.0, 0.0)
    node = route_telemetry(event)
    econ = calculate_ride_economics(100.0, node)
    assert econ.customer_fee_usd == 1.0
    assert econ.driver_pay_usd > 50.0


def test_tree_of_life():
    projection = tree_of_life_projection({0: 10.0, 1: 20.0, 2: 5.0})
    assert "harmony_index" in projection
    assert len(projection["branches"]) == 10
