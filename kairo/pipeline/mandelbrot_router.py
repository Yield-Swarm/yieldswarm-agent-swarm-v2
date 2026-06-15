"""Route signed Kairo telemetry into the YieldSwarm Mandelbrot / Tree of Life."""

from __future__ import annotations

import hashlib
import json
import os
import urllib.request
from dataclasses import dataclass
from typing import Any, Optional

from kairo.identity.driver_wallet import verify_signature
from kairo.telemetry.schema import SignedTelemetry


# Tree of Life paths map to agent shard assignments (84 agents per shard, 120 shards).
TREE_PATHS = [
    "kether", "chokmah", "binah", "chesed", "geburah", "tiphereth",
    "netzach", "hod", "yesod", "malkuth",
]


@dataclass
class MandelbrotZone:
    zone_id: str
    iteration_depth: int
    tree_path: str
    shard_id: int
    reward_weight: float


def _mandelbrot_escape(lat: float, lng: float, max_iter: int = 64) -> tuple[int, str]:
    """Map geo coordinates to Mandelbrot iteration depth and zone label."""
    # Normalize lat/lng to complex plane [-2, 1] x [-1.5, 1.5]
    c_real = (lng + 180) / 90 - 2.0
    c_imag = lat / 60.0
    z_real, z_imag = 0.0, 0.0
    iteration = 0
    while z_real * z_real + z_imag * z_imag <= 4 and iteration < max_iter:
        z_real, z_imag = (
            z_real * z_real - z_imag * z_imag + c_real,
            2 * z_real * z_imag + c_imag,
        )
        iteration += 1
    zone_hash = hashlib.sha256(f"{c_real:.6f}:{c_imag:.6f}".encode()).hexdigest()[:12]
    return iteration, f"mb-{zone_hash}"


def _tree_path_for_zone(zone_id: str, driver_id: str) -> tuple[str, int]:
    """Assign a Tree of Life path and shard from zone + driver."""
    combined = f"{zone_id}:{driver_id}"
    digest = hashlib.sha256(combined.encode()).digest()
    path_idx = digest[0] % len(TREE_PATHS)
    shard_id = int.from_bytes(digest[1:3], "big") % 120
    return TREE_PATHS[path_idx], shard_id


def classify_telemetry(signed: SignedTelemetry) -> MandelbrotZone:
    """Classify a signed event into a Mandelbrot zone and Tree of Life shard."""
    tel = signed.telemetry
    if tel.location:
        depth, zone_id = _mandelbrot_escape(tel.location.lat, tel.location.lng)
    else:
        depth, zone_id = 0, "mb-unknown"

    tree_path, shard_id = _tree_path_for_zone(zone_id, tel.driver_id)
    reward_weight = min(1.0, (depth / 64) * (tel.distance_miles or 0.1))

    return MandelbrotZone(
        zone_id=zone_id,
        iteration_depth=depth,
        tree_path=tree_path,
        shard_id=shard_id,
        reward_weight=round(reward_weight, 4),
    )


class MandelbrotPipeline:
    """Verify, classify, and forward telemetry to YieldSwarm ingestion."""

    def __init__(
        self,
        ingest_url: Optional[str] = None,
        chromadb_url: Optional[str] = None,
    ) -> None:
        self.ingest_url = ingest_url or os.environ.get(
            "YIELDSWARM_TELEMETRY_INGEST_URL",
            "http://localhost:3001/api/kairo/telemetry",
        )
        self.chromadb_url = chromadb_url or os.environ.get(
            "CHROMADB_URL",
            "http://localhost:8100",
        )

    def process(self, signed: SignedTelemetry) -> dict[str, Any]:
        """Verify signature, classify, enrich, and forward."""
        from kairo.identity.driver_wallet import DriverIdentity

        identity = DriverIdentity(
            driver_id=signed.telemetry.driver_id,
            evm_address=signed.telemetry.evm_address,
            iotex_address=signed.telemetry.iotex_address,
            public_key_hex="",
        )
        if not verify_signature(identity, signed.telemetry.payload_for_signing(), signed.signature):
            raise ValueError("Invalid telemetry signature")

        zone = classify_telemetry(signed)
        signed.telemetry.mandelbrot_zone = zone.zone_id
        signed.telemetry.tree_of_life_path = zone.tree_path
        signed.telemetry.shard_id = zone.shard_id

        record = {
            "signed": signed.to_dict(),
            "classification": {
                "zone_id": zone.zone_id,
                "iteration_depth": zone.iteration_depth,
                "tree_path": zone.tree_path,
                "shard_id": zone.shard_id,
                "reward_weight": zone.reward_weight,
            },
        }
        self._forward(record)
        return record

    def _forward(self, record: dict[str, Any]) -> None:
        body = json.dumps(record).encode()
        req = urllib.request.Request(
            self.ingest_url,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                resp.read()
        except Exception:
            # Buffer locally on failure — sovereign loops will retry.
            outbox = os.environ.get("KAIRO_PIPELINE_OUTBOX", ".data/kairo/pipeline")
            os.makedirs(outbox, exist_ok=True)
            path = f"{outbox}/{record['signed']['telemetry']['timestamp']}.json"
            with open(path, "w", encoding="utf-8") as f:
                json.dump(record, f)
