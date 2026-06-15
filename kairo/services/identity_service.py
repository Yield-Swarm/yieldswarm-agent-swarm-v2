"""Dual-chain identity: secp256k1 keys compatible with EVM and IoTeX."""

from __future__ import annotations

import hashlib
import secrets
import uuid
from datetime import datetime, timezone

import bech32
from eth_account import Account
from eth_account.messages import encode_defunct
from eth_keys import keys

from kairo.db import db
from kairo.models.schemas import DriverIdentityOut, DriverRegisterIn, ServerKeygenOut


SECP256K1_N = int(
    "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141", 16
)


def evm_address_from_public_key(public_key_hex: str) -> str:
    pk_bytes = bytes.fromhex(public_key_hex.removeprefix("0x"))
    if pk_bytes[0] == 0x04 and len(pk_bytes) == 65:
        pk_bytes = pk_bytes[1:]
    pub = keys.PublicKey(pk_bytes)
    return pub.to_checksum_address()


def iotex_address_from_public_key(public_key_hex: str) -> str:
    """IoTeX uses the same secp256k1 key; address is bech32(io, ...) over 20-byte hash."""
    pk_bytes = bytes.fromhex(public_key_hex.removeprefix("0x"))
    if pk_bytes[0] == 0x04 and len(pk_bytes) == 65:
        pk_bytes = pk_bytes[1:]
    pub = keys.PublicKey(pk_bytes)
    addr_bytes = bytes.fromhex(pub.to_address().removeprefix("0x"))
    converted = bech32.convertbits(addr_bytes, 8, 5)
    if converted is None:
        raise ValueError("bech32 conversion failed")
    return bech32.bech32_encode("io", converted)


def verify_registration_signature(data: DriverRegisterIn) -> bool:
    """Prove the registrant controls the private key for public_key_hex."""
    evm_addr = evm_address_from_public_key(data.public_key_hex)
    message = (
        f"Kairo→YieldSwarm driver registration\n"
        f"kairo_user_id:{data.kairo_user_id}\n"
        f"evm:{evm_addr}\n"
    )
    msg = encode_defunct(text=message)
    recovered = Account.recover_message(
        msg, signature=bytes.fromhex(data.registration_signature_hex.removeprefix("0x"))
    )
    return recovered.lower() == evm_addr.lower()


def generate_license_key(driver_id: str) -> str:
    return f"KAIRO-YS-{driver_id[:8].upper()}-{secrets.token_hex(4).upper()}"


class IdentityService:
    def register_client_identity(self, data: DriverRegisterIn) -> DriverIdentityOut:
        if not verify_registration_signature(data):
            raise ValueError("Invalid registration signature")

        evm = evm_address_from_public_key(data.public_key_hex)
        iotex = iotex_address_from_public_key(data.public_key_hex)
        driver_id = str(uuid.uuid4())
        license_key = generate_license_key(driver_id)
        created = datetime.now(timezone.utc)

        existing = db.fetchone(
            "SELECT id FROM drivers WHERE kairo_user_id = ?", (data.kairo_user_id,)
        )
        if existing:
            raise ValueError(f"Kairo user already registered: {data.kairo_user_id}")

        db.insert(
            "drivers",
            {
                "id": driver_id,
                "kairo_user_id": data.kairo_user_id,
                "evm_address": evm,
                "iotex_address": iotex,
                "public_key_hex": data.public_key_hex.lower(),
                "created_at": created.isoformat(),
                "depin_helium_pubkey": data.depin_helium_pubkey,
                "depin_grass_node_id": data.depin_grass_node_id,
                "license_key": license_key,
                "metadata_json": __import__("json").dumps(data.metadata),
            },
        )
        return DriverIdentityOut(
            driver_id=driver_id,
            kairo_user_id=data.kairo_user_id,
            evm_address=evm,
            iotex_address=iotex,
            public_key_hex=data.public_key_hex.lower(),
            license_key=license_key,
            created_at=created,
            depin_helium_pubkey=data.depin_helium_pubkey,
            depin_grass_node_id=data.depin_grass_node_id,
        )

    def generate_server_identity(self, kairo_user_id: str) -> ServerKeygenOut:
        """Fallback: server-generated HD wallet (onboarding / dev only)."""
        Account.enable_unaudited_hdwallet_features()
        acct, mnemonic = Account.create_with_mnemonic()
        public_key_hex = "0x" + acct.key.public_key.to_bytes().hex()
        driver_id = str(uuid.uuid4())
        license_key = generate_license_key(driver_id)
        iotex = iotex_address_from_public_key(public_key_hex)
        created = datetime.now(timezone.utc).isoformat()

        db.insert(
            "drivers",
            {
                "id": driver_id,
                "kairo_user_id": kairo_user_id,
                "evm_address": acct.address,
                "iotex_address": iotex,
                "public_key_hex": public_key_hex,
                "created_at": created,
                "depin_helium_pubkey": None,
                "depin_grass_node_id": None,
                "license_key": license_key,
                "metadata_json": "{}",
            },
        )
        return ServerKeygenOut(
            driver_id=driver_id,
            mnemonic=mnemonic,
            evm_address=acct.address,
            iotex_address=iotex,
            public_key_hex=public_key_hex,
            license_key=license_key,
        )

    def get_driver(self, driver_id: str) -> dict | None:
        return db.fetchone("SELECT * FROM drivers WHERE id = ?", (driver_id,))

    def get_driver_by_kairo(self, kairo_user_id: str) -> dict | None:
        return db.fetchone(
            "SELECT * FROM drivers WHERE kairo_user_id = ?", (kairo_user_id,)
        )
