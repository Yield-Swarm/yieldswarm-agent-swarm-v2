"""Cryptographic driver identity — IoTeX + EVM compatible secp256k1 keys.

Every Kairo driver receives a persistent dual-chain address derived from a single
secp256k1 keypair (BIP39 mnemonic → BIP44 m/44'/60'/0'/0/0). Private material is
encrypted at rest locally and optionally mirrored to HashiCorp Vault.
"""

from __future__ import annotations

import hashlib
import json
import os
import secrets
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt

from kairo.models.driver import DriverIdentity, utc_now

try:
    from eth_account import Account  # type: ignore

    Account.enable_unaudited_hdwallet_features()
except ImportError:
    Account = None  # type: ignore

CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
BECH32_CONST = 1
IOTEX_HRP = "io"
DEFAULT_DERIVATION_PATH = "m/44'/60'/0'/0/0"
WALLET_VERSION = 1


@dataclass(frozen=True)
class MnemonicBackup:
    """One-time recovery phrase shown to the driver at registration."""

    mnemonic: str
    derivation_path: str = DEFAULT_DERIVATION_PATH
    word_count: int = 12

    def to_public_dict(self) -> dict[str, Any]:
        return {
            "derivation_path": self.derivation_path,
            "word_count": self.word_count,
            "recovery_hint": "Store offline — shown once at registration",
        }


@dataclass
class RegistrationResult:
    """Result of driver registration including one-time mnemonic."""

    identity: DriverIdentity
    mnemonic_backup: MnemonicBackup
    vault_path: str | None = None

    def to_response(self, *, include_mnemonic: bool = True) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "identity": self.identity.to_public_dict(),
            "backup": self.mnemonic_backup.to_public_dict(),
            "vault_path": self.vault_path,
        }
        if include_mnemonic:
            payload["mnemonic"] = self.mnemonic_backup.mnemonic
        return payload


def _polymod(values: list[int]) -> int:
    generator = [0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3]
    chk = 1
    for value in values:
        top = chk >> 25
        chk = ((chk & 0x1FFFFFF) << 5) ^ value
        for i in range(5):
            if (top >> i) & 1:
                chk ^= generator[i]
    return chk


def _hrp_expand(hrp: str) -> list[int]:
    return [ord(x) >> 5 for x in hrp] + [0] + [ord(x) & 31 for x in hrp]


def _bech32_encode(hrp: str, data: bytes) -> str:
    converted = _convertbits(list(data), 8, 5, pad=True)
    combined = converted + _create_checksum(hrp, converted)
    return hrp + "1" + "".join(CHARSET[d] for d in combined)


def _convertbits(data: list[int], frombits: int, tobits: int, pad: bool) -> list[int]:
    acc = 0
    bits = 0
    ret: list[int] = []
    maxv = (1 << tobits) - 1
    for value in data:
        acc = (acc << frombits) | value
        bits += frombits
        while bits >= tobits:
            bits -= tobits
            ret.append((acc >> bits) & maxv)
    if pad and bits:
        ret.append((acc << (tobits - bits)) & maxv)
    return ret


def _create_checksum(hrp: str, data: list[int]) -> list[int]:
    values = _hrp_expand(hrp) + data
    polymod = _polymod(values + [0, 0, 0, 0, 0, 0]) ^ BECH32_CONST
    return [(polymod >> 5 * (5 - i)) & 31 for i in range(6)]


def _keccak256(data: bytes) -> bytes:
    try:
        return hashlib.new("keccak_256", data).digest()
    except ValueError:
        from Crypto.Hash import keccak

        digest = keccak.new(digest_bits=256)
        digest.update(data)
        return digest.digest()


_SECP256K1_ORDER = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141


def _private_key_from_seed(seed: bytes) -> ec.EllipticCurvePrivateKey:
    scalar = int.from_bytes(seed, "big") % _SECP256K1_ORDER
    if scalar == 0:
        scalar = 1
    return ec.derive_private_key(scalar, ec.SECP256K1())


def _public_key_bytes(private_key: ec.EllipticCurvePrivateKey) -> bytes:
    return private_key.public_key().public_bytes(
        encoding=serialization.Encoding.X962,
        format=serialization.PublicFormat.UncompressedPoint,
    )


def _identity_from_private_hex(
    private_hex: str,
    *,
    driver_id: str | None = None,
    derivation_path: str = DEFAULT_DERIVATION_PATH,
) -> DriverIdentity:
    private_value = int(private_hex, 16)
    private_key = ec.derive_private_key(private_value, ec.SECP256K1())
    public_key = _public_key_bytes(private_key)
    evm = evm_address_from_public_key(public_key)
    did = driver_id or f"kairo-{hashlib.sha256(evm.encode()).hexdigest()[:12]}"
    return DriverIdentity(
        driver_id=did,
        evm_address=evm,
        iotex_address=iotex_address_from_evm(evm),
        public_key_hex=public_key.hex(),
        encrypted_private_key=encrypt_private_key(private_hex),
        created_at=utc_now(),
    )


def evm_address_from_public_key(public_key: bytes) -> str:
    """Derive EVM address from uncompressed secp256k1 public key."""
    if public_key[0] == 4:
        public_key = public_key[1:]
    digest = _keccak256(public_key)
    return "0x" + digest[-20:].hex()


def iotex_address_from_evm(evm_address: str) -> str:
    """Encode the same 20-byte identity as an IoTeX Bech32 address (io1...)."""
    raw = bytes.fromhex(evm_address.removeprefix("0x"))
    return _bech32_encode(IOTEX_HRP, raw)


def _encryption_key() -> bytes:
    material = os.environ.get("KAIRO_IDENTITY_ENCRYPTION_KEY") or os.environ.get("WALLET_ENCRYPTION_KEY")
    if not material:
        if os.environ.get("NODE_ENV") == "production" or os.environ.get("KAIRO_REQUIRE_ENCRYPTION_KEY") == "1":
            raise RuntimeError(
                "KAIRO_IDENTITY_ENCRYPTION_KEY or WALLET_ENCRYPTION_KEY is required in production"
            )
        material = "yieldswarm-dev-kairo-key"
    return hashlib.sha256(material.encode("utf-8")).digest()


def _recovery_key(passphrase: str, salt: bytes) -> bytes:
    kdf = Scrypt(salt=salt, length=32, n=2**14, r=8, p=1)
    return kdf.derive(passphrase.encode("utf-8"))


def encrypt_blob(plaintext: str, key: bytes) -> str:
    aes = AESGCM(key)
    nonce = secrets.token_bytes(12)
    ciphertext = aes.encrypt(nonce, plaintext.encode("utf-8"), None)
    return json.dumps({"nonce": nonce.hex(), "ciphertext": ciphertext.hex()})


def decrypt_blob(blob: str, key: bytes) -> str:
    payload = json.loads(blob)
    aes = AESGCM(key)
    plaintext = aes.decrypt(bytes.fromhex(payload["nonce"]), bytes.fromhex(payload["ciphertext"]), None)
    return plaintext.decode("utf-8")


def encrypt_private_key(private_key_hex: str) -> str:
    return encrypt_blob(private_key_hex, _encryption_key())


def decrypt_private_key(blob: str) -> str:
    return decrypt_blob(blob, _encryption_key())


def encrypt_mnemonic(mnemonic: str, recovery_passphrase: str) -> str:
    salt = secrets.token_bytes(16)
    key = _recovery_key(recovery_passphrase, salt)
    encrypted = encrypt_blob(mnemonic, key)
    return json.dumps({"salt": salt.hex(), "encrypted": json.loads(encrypted)})


def decrypt_mnemonic(blob: str, recovery_passphrase: str) -> str:
    wrapper = json.loads(blob)
    salt = bytes.fromhex(wrapper["salt"])
    key = _recovery_key(recovery_passphrase, salt)
    return decrypt_blob(json.dumps(wrapper["encrypted"]), key)


def generate_driver_identity(driver_id: str | None = None) -> DriverIdentity:
    """Create a new random driver identity (no mnemonic — prefer register_driver)."""
    seed = secrets.token_bytes(32)
    private_key = _private_key_from_seed(seed)
    private_hex = private_key.private_numbers().private_value.to_bytes(32, "big").hex()
    return _identity_from_private_hex(private_hex, driver_id=driver_id)


def identity_from_mnemonic(
    mnemonic: str,
    *,
    passphrase: str = "",
    driver_id: str | None = None,
    derivation_path: str = DEFAULT_DERIVATION_PATH,
) -> DriverIdentity:
    """Recover or derive a driver identity from a BIP39 mnemonic phrase."""
    if Account is None:
        raise RuntimeError("eth-account required: pip install eth-account")

    account = Account.from_mnemonic(
        mnemonic.strip(),
        passphrase=passphrase,
        account_path=derivation_path,
    )
    return _identity_from_private_hex(
        account.key.hex(),
        driver_id=driver_id,
        derivation_path=derivation_path,
    )


def register_driver(
    driver_id: str | None = None,
    *,
    recovery_passphrase: str | None = None,
    store: "DriverStore | None" = None,
    mirror_vault: bool = True,
) -> RegistrationResult:
    """Register a new driver with BIP39 mnemonic backup and encrypted local storage."""
    if Account is None:
        raise RuntimeError("eth-account required: pip install eth-account")

    account, mnemonic = Account.create_with_mnemonic(num_words=12)
    identity = _identity_from_private_hex(account.key.hex(), driver_id=driver_id)
    backup = MnemonicBackup(mnemonic=mnemonic, derivation_path=DEFAULT_DERIVATION_PATH)

    wallet_store = store or DriverStore()
    wallet_store.save(identity, mnemonic=mnemonic, recovery_passphrase=recovery_passphrase)

    vault_path = None
    if mirror_vault:
        vault_path = _mirror_to_vault(identity.driver_id, account.key.hex(), mnemonic)

    return RegistrationResult(identity=identity, mnemonic_backup=backup, vault_path=vault_path)


def recover_driver(
    mnemonic: str,
    *,
    passphrase: str = "",
    driver_id: str | None = None,
    recovery_passphrase: str | None = None,
    store: "DriverStore | None" = None,
) -> DriverIdentity:
    """Recover a driver identity from mnemonic and persist to local store."""
    identity = identity_from_mnemonic(mnemonic, passphrase=passphrase, driver_id=driver_id)
    wallet_store = store or DriverStore()
    wallet_store.save(identity, mnemonic=mnemonic, recovery_passphrase=recovery_passphrase)
    return identity


def _mirror_to_vault(driver_id: str, private_key_hex: str, mnemonic: str) -> str | None:
    try:
        from kairo.identity.vault_store import store_driver_secrets

        return store_driver_secrets(driver_id, private_key_hex, mnemonic)
    except Exception:
        return None


class DriverStore:
    """Encrypted local storage for driver identities + optional mnemonic backup."""

    def __init__(self, root: Path | None = None) -> None:
        self.root = root or Path(os.environ.get("KAIRO_STORE_DIR", ".data/kairo"))
        self.root.mkdir(parents=True, exist_ok=True)
        (self.root / "wallets").mkdir(parents=True, exist_ok=True)
        self._index_path = self.root / "drivers.json"

    def _wallet_path(self, driver_id: str) -> Path:
        return self.root / "wallets" / f"{driver_id}.json"

    def _load_index(self) -> dict[str, Any]:
        if not self._index_path.exists():
            return {"version": WALLET_VERSION, "drivers": {}}
        return json.loads(self._index_path.read_text(encoding="utf-8"))

    def _save_index(self, index: dict[str, Any]) -> None:
        self._index_path.write_text(json.dumps(index, indent=2), encoding="utf-8")
        try:
            self._index_path.chmod(0o600)
        except OSError:
            pass

    def save(
        self,
        identity: DriverIdentity,
        *,
        mnemonic: str | None = None,
        recovery_passphrase: str | None = None,
    ) -> DriverIdentity:
        recovery_hint = identity.evm_address[-6:]
        encrypted_mnemonic = None
        if mnemonic and recovery_passphrase:
            encrypted_mnemonic = encrypt_mnemonic(mnemonic, recovery_passphrase)

        wallet_record = {
            "version": WALLET_VERSION,
            "driver_id": identity.driver_id,
            "evm_address": identity.evm_address,
            "iotex_address": identity.iotex_address,
            "public_key_hex": identity.public_key_hex,
            "created_at": identity.created_at,
            "derivation_path": DEFAULT_DERIVATION_PATH,
            "encrypted_private_key": identity.encrypted_private_key,
            "encrypted_mnemonic": encrypted_mnemonic,
            "recovery_hint": recovery_hint,
            "has_mnemonic_backup": bool(mnemonic),
        }

        wallet_path = self._wallet_path(identity.driver_id)
        wallet_path.write_text(json.dumps(wallet_record, indent=2), encoding="utf-8")
        try:
            wallet_path.chmod(0o600)
        except OSError:
            pass

        index = self._load_index()
        index["drivers"][identity.driver_id] = {
            k: v
            for k, v in wallet_record.items()
            if k not in ("encrypted_private_key", "encrypted_mnemonic")
        }
        self._save_index(index)
        return identity

    def get(self, driver_id: str) -> DriverIdentity | None:
        wallet_path = self._wallet_path(driver_id)
        if wallet_path.exists():
            row = json.loads(wallet_path.read_text(encoding="utf-8"))
            return DriverIdentity(
                driver_id=row["driver_id"],
                evm_address=row["evm_address"],
                iotex_address=row["iotex_address"],
                public_key_hex=row["public_key_hex"],
                encrypted_private_key=row["encrypted_private_key"],
                created_at=row["created_at"],
            )

        index = self._load_index()
        row = index.get("drivers", {}).get(driver_id)
        if not row:
            return None
        return DriverIdentity(**{k: row[k] for k in DriverIdentity.__dataclass_fields__ if k in row})

    def get_wallet_meta(self, driver_id: str) -> dict[str, Any] | None:
        wallet_path = self._wallet_path(driver_id)
        if not wallet_path.exists():
            return None
        row = json.loads(wallet_path.read_text(encoding="utf-8"))
        return {k: v for k, v in row.items() if k not in ("encrypted_private_key", "encrypted_mnemonic")}

    def unlock_mnemonic(self, driver_id: str, recovery_passphrase: str) -> str:
        wallet_path = self._wallet_path(driver_id)
        if not wallet_path.exists():
            raise KeyError(f"wallet not found: {driver_id}")
        row = json.loads(wallet_path.read_text(encoding="utf-8"))
        blob = row.get("encrypted_mnemonic")
        if not blob:
            raise ValueError("no encrypted mnemonic backup — use original recovery phrase")
        return decrypt_mnemonic(blob, recovery_passphrase)

    def get_by_address(self, evm_address: str) -> DriverIdentity | None:
        target = evm_address.lower()
        for row in self._load_index().get("drivers", {}).values():
            if row["evm_address"].lower() == target:
                return self.get(row["driver_id"])
        return None

    def list_public(self) -> list[dict[str, Any]]:
        return list(self._load_index().get("drivers", {}).values())
