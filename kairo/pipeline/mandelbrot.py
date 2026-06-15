"""Route signed Kairo telemetry into the Mandelbrot / Tree of Life architecture."""

from __future__ import annotations

import hashlib
import json
import math
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from kairo.telemetry.signer import SignedTelemetryBatch


# Tree of Life shard formula from architecture docs:
# 1×3×5×11×1111×1×3×8×9×11 = 10,080 agents across 120 crons
SHARD_COUNT = 120
AGENTS_PER_SHARD = 84


@dataclass
class MandelbrotContribution:
    driver_id: str
    batch_id: str
    mandelbrot_iterations: int
    escape_radius: float
    tree_of_life_path: List[int]
    shard_id: int
    emission_weight: float
    potential_reward_usd: float
    ingested_at: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "driver_id": self.driver_id,
            "batch_id": self.batch_id,
            "mandelbrot_iterations": self.mandelbrot_iterations,
            "escape_radius": self.escape_radius,
            "tree_of_life_path": self.tree_of_life_path,
            "shard_id": self.shard_id,
            "emission_weight": self.emission_weight,
            "potential_reward_usd": self.potential_reward_usd,
            "ingested_at": self.ingested_at,
        }


def _mandelbrot_escape(c_re: float, c_im: float, max_iter: int = 256) -> tuple[int, float]:
    z_re, z_im = 0.0, 0.0
    for i in range(max_iter):
        if z_re * z_re + z_im * z_im > 4.0:
            return i, math.sqrt(z_re * z_re + z_im * z_im)
        z_re, z_im = z_re * z_re - z_im * z_im + c_re, 2 * z_re * z_im + c_im
    return max_iter, 2.0


def _tree_of_life_path(seed: str, depth: int = 7) -> List[int]:
    """Binary Tree of Life path from telemetry digest (spec: binary + RNG generation)."""
    digest = hashlib.sha256(seed.encode()).digest()
    path = []
    for i in range(depth):
        path.append(digest[i] % 3)  # ternary branching per architecture
    return path


def ingest_signed_batch(batch: SignedTelemetryBatch) -> MandelbrotContribution:
    """Transform signed telemetry into a Mandelbrot/Tree-of-Life contribution record."""
    if not batch.points:
        raise ValueError("empty batch")

    last = batch.points[-1]
    # Map geo coordinates to Mandelbrot plane
    c_re = (last.latitude % 1.0) * 2.5 - 1.25
    c_im = (last.longitude % 1.0) * 2.5 - 1.25
    iterations, escape_r = _mandelbrot_escape(c_re, c_im)

    seed = f"{batch.driver_id}:{batch.batch_id}:{last.canonical_json()}"
    path = _tree_of_life_path(seed)
    shard_id = batch.node_shard % SHARD_COUNT

    # Emission weight scales with iterations and speed (DePIN contribution proxy)
    emission_weight = (iterations / 256.0) * (1.0 + min(last.speed_mps, 30.0) / 30.0)
    potential_reward = emission_weight * 0.05  # $0.05 base unit per contribution point

    return MandelbrotContribution(
        driver_id=batch.driver_id,
        batch_id=batch.batch_id,
        mandelbrot_iterations=iterations,
        escape_radius=escape_r,
        tree_of_life_path=path,
        shard_id=shard_id,
        emission_weight=round(emission_weight, 6),
        potential_reward_usd=round(potential_reward, 4),
        ingested_at=datetime.now(timezone.utc).isoformat(),
    )


class MandelbrotPipeline:
    """In-memory pipeline store; swap for ChromaDB/Postgres in production."""

    def __init__(self, store_path: Optional[str] = None):
        self.store_path = Path(store_path or ".data/kairo/mandelbrot.jsonl")
        self.store_path.parent.mkdir(parents=True, exist_ok=True)

    def ingest(self, batch: SignedTelemetryBatch) -> MandelbrotContribution:
        record = ingest_signed_batch(batch)
        with self.store_path.open("a") as f:
            f.write(json.dumps(record.to_dict()) + "\n")
        return record

    def driver_summary(self, driver_id: str) -> Dict[str, Any]:
        if not self.store_path.exists():
            return {"driver_id": driver_id, "batches": 0, "total_reward_usd": 0.0}

        batches = 0
        total_reward = 0.0
        total_weight = 0.0
        for line in self.store_path.read_text().splitlines():
            if not line.strip():
                continue
            row = json.loads(line)
            if row.get("driver_id") != driver_id:
                continue
            batches += 1
            total_reward += float(row.get("potential_reward_usd", 0))
            total_weight += float(row.get("emission_weight", 0))

        return {
            "driver_id": driver_id,
            "batches": batches,
            "total_emission_weight": round(total_weight, 4),
            "total_reward_usd": round(total_reward, 4),
            "shard_id": hash(driver_id) % SHARD_COUNT,
            "agents_per_shard": AGENTS_PER_SHARD,
        }
