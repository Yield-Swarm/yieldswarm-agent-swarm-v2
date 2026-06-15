"""Persistent cryptographic driver identity (IoTeX + EVM compatible)."""

from __future__ import annotations

import hashlib
import hmac
import secrets
from dataclasses import dataclass
from typing import Any

from eth_account import Account


IOTEX_HRP = "io"
CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"


def _polymod(values: list[int]) -> int:
    gen = [0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3]
    chk = 1
    for v in values:
        top = chk >> 25
        chk = ((chk & 0x1FFFFFF) << 5) ^ v
        for i in range(5):
            if (top >> i) & 1:
                chk ^= gen[i]
    return chk


def _hrp_expand(hrp: str) -> list[int]:
    ret: list[int] = []
    for c in hrp:
        ret.append(ord(c) >> 5)
    ret.append(0)
    for c in hrp:
        ret.append(ord(c) & 31)
    return ret


def _create_checksum(hrp: str, data: list[int]) -> list[int]:
    values = _hrp_expand(hrp) + data + [0, 0, 0, 0, 0, 0]
    mod = _polymod(values) ^ 1
    return [(mod >> (5 * (5 - p))) & 31 for p in range(6)]


def _bech32_encode(hrp: str, data: list[int]) -> str:
    combined = data + _create_checksum(hrp, data)
    return hrp + "1" + "".join(CHARSET[d] for d in combined)


def _to_words(data: bytes) -> list[int]:
    acc, bits, ret = 0, 0, []
    for byte in data:
        acc = (acc << 8) | byte
        bits += 8
        while bits >= 5:
            bits -= 5
            ret.append((acc >> bits) & 31)
    if bits:
        ret.append((acc << (5 - bits)) & 31)
    return ret


def evm_to_iotex_address(evm_address: str) -> str:
    raw = bytes.fromhex(evm_address.lower().removeprefix("0x"))
    return _bech32_encode(IOTEX_HRP, _to_words(raw))


@dataclass
class DriverIdentity:
    id: str
    evm_address: str
    iotex_address: str
    public_key: str
    key_fingerprint: str
    private_key: str


def key_fingerprint(private_key: str) -> str:
    return hmac.new(b"kairo-identity-v1", private_key.encode(), hashlib.sha256).hexdigest()[:16]


def generate_driver_identity() -> DriverIdentity:
    acct = Account.create()
    evm = acct.address
    iotex = evm_to_iotex_address(evm)
    return DriverIdentity(
        id=secrets.token_hex(16),
        evm_address=evm,
        iotex_address=iotex,
        public_key=acct.key.hex(),
        key_fingerprint=key_fingerprint(acct.key.hex()),
        private_key=acct.key.hex(),
    )
