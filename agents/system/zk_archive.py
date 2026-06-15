"""ZK-proof archival primitives for Arena snapshots."""

from __future__ import annotations

import hashlib
import json
import secrets
import time
from pathlib import Path
from typing import Dict, Iterable


def _hash_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def canonical_state_hash(snapshot: Dict[str, object]) -> str:
    serialized = json.dumps(snapshot, sort_keys=True, separators=(",", ":")).encode(
        "utf-8"
    )
    return _hash_bytes(serialized)


class ZKArchiveLedger:
    """Append-only archive with Schnorr-style proof of custody."""

    # A large Mersenne prime keeps arithmetic straightforward.
    P = (1 << 127) - 1
    G = 3

    def __init__(self, archive_file: Path | str, secret_seed: str = "arena-ledger-seed"):
        self.archive_file = Path(archive_file)
        self.archive_file.parent.mkdir(parents=True, exist_ok=True)
        raw_secret = _hash_bytes(secret_seed.encode("utf-8"))
        self.secret = (int(raw_secret, 16) % (self.P - 2)) + 1
        self.public_key = pow(self.G, self.secret, self.P)

    def _challenge(self, state_hash: str, t_value: int) -> int:
        h = _hash_bytes(f"{state_hash}:{t_value}".encode("utf-8"))
        return int(h, 16) % (self.P - 1)

    def prove(self, state_hash: str) -> Dict[str, int]:
        nonce = secrets.randbelow(self.P - 2) + 1
        t_value = pow(self.G, nonce, self.P)
        challenge = self._challenge(state_hash, t_value)
        response = (nonce + challenge * self.secret) % (self.P - 1)
        return {"t": t_value, "c": challenge, "s": response}

    def verify(self, state_hash: str, proof: Dict[str, int]) -> bool:
        t_value = int(proof["t"])
        challenge = int(proof["c"])
        response = int(proof["s"])
        if challenge != self._challenge(state_hash, t_value):
            return False
        lhs = pow(self.G, response, self.P)
        rhs = (t_value * pow(self.public_key, challenge, self.P)) % self.P
        return lhs == rhs

    def archive(self, snapshot: Dict[str, object], tags: Iterable[str] | None = None) -> Dict[str, object]:
        state_hash = canonical_state_hash(snapshot)
        proof = self.prove(state_hash)
        if not self.verify(state_hash, proof):
            raise RuntimeError("Generated proof failed verification")

        entry = {
            "record_id": _hash_bytes(f"{state_hash}:{time.time_ns()}".encode("utf-8")),
            "timestamp": int(time.time()),
            "state_hash": state_hash,
            "public_key": str(self.public_key),
            "proof": proof,
            "tags": sorted(set(tags or [])),
            "snapshot": snapshot,
        }
        with self.archive_file.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(entry, sort_keys=True) + "\n")
        return entry
