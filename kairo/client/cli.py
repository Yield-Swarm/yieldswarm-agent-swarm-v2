#!/usr/bin/env python3
"""Kairo mobile client helper — register, sign, and submit telemetry."""

from __future__ import annotations

import argparse
import json
import sys
import uuid
from datetime import datetime, timezone

from eth_account import Account
from eth_keys import keys

from kairo.models.schemas import (
    DriverRegisterIn,
    GpsPoint,
    SignedTelemetryIn,
    TelemetryPayload,
)
from kairo.services.signing_service import sign_payload


def cmd_register(args: argparse.Namespace) -> None:
    Account.enable_unaudited_hdwallet_features()
    acct = Account.create()
    private_key = keys.PrivateKey(acct.key)
    pub_bytes = private_key.public_key.to_bytes()
    if len(pub_bytes) == 64:
        pub_bytes = b"\x04" + pub_bytes
    public_key_hex = "0x" + pub_bytes.hex()
    message = (
        f"Kairo→YieldSwarm driver registration\n"
        f"kairo_user_id:{args.kairo_user_id}\n"
        f"evm:{acct.address}\n"
    )
    from eth_account.messages import encode_defunct

    sig = acct.sign_message(encode_defunct(text=message))
    reg = DriverRegisterIn(
        kairo_user_id=args.kairo_user_id,
        public_key_hex=public_key_hex,
        registration_signature_hex="0x" + sig.signature.hex(),
        depin_helium_pubkey=args.helium,
        depin_grass_node_id=args.grass,
    )
    import urllib.request

    req = urllib.request.Request(
        f"{args.api}/api/v1/drivers/register",
        data=json.dumps(reg.model_dump()).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req) as resp:
        result = json.loads(resp.read())
    print(json.dumps(result, indent=2))
    if args.save_key:
        with open(args.save_key, "w") as f:
            json.dump({"private_key": acct.key.hex(), **result}, f)
        print(f"Key saved to {args.save_key}", file=sys.stderr)


def cmd_submit(args: argparse.Namespace) -> None:
    with open(args.key_file) as f:
        key_data = json.load(f)
    private_key = key_data["private_key"]
    driver_id = key_data["driver_id"]

    payload = TelemetryPayload(
        driver_id=driver_id,
        kairo_session_id=str(uuid.uuid4()),
        recorded_at=datetime.now(timezone.utc),
        gps=GpsPoint(latitude=args.lat, longitude=args.lon),
        speed_mps=args.speed,
        acceleration_mps2=args.accel,
        heading_deg=args.heading,
    )
    sig = sign_payload(payload, private_key)
    body = SignedTelemetryIn(payload=payload, signature_hex=sig)

    import urllib.request

    req = urllib.request.Request(
        f"{args.api}/api/v1/telemetry/ingest",
        data=json.dumps(body.model_dump(mode="json"), default=str).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req) as resp:
        print(json.dumps(json.loads(resp.read()), indent=2))


def main() -> None:
    parser = argparse.ArgumentParser(description="Kairo client CLI")
    parser.add_argument("--api", default="http://127.0.0.1:8090")
    sub = parser.add_subparsers(dest="cmd", required=True)

    reg = sub.add_parser("register", help="Register new driver identity")
    reg.add_argument("kairo_user_id")
    reg.add_argument("--helium", default=None)
    reg.add_argument("--grass", default=None)
    reg.add_argument("--save-key", default="kairo_driver_key.json")
    reg.set_defaults(func=cmd_register)

    subm = sub.add_parser("submit", help="Submit signed telemetry")
    subm.add_argument("key_file")
    subm.add_argument("--lat", type=float, required=True)
    subm.add_argument("--lon", type=float, required=True)
    subm.add_argument("--speed", type=float, default=12.5)
    subm.add_argument("--accel", type=float, default=0.5)
    subm.add_argument("--heading", type=float, default=90.0)
    subm.set_defaults(func=cmd_submit)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
