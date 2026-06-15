"""Mandelbrot / Tree of Life routing for signed Kairo telemetry."""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any, Mapping, Sequence

# Eleven sephiroth on the Tree of Life — maps telemetry dimensions to reward shards.
TREE_OF_LIFE_NODES: tuple[str, ...] = (
    "kether",      # peak signal quality
    "chokmah",     # velocity / momentum
    "binah",       # route efficiency
    "chesed",      # distance contributed
    "geburah",     # safety / hard braking inverse
    "tiphereth",   # balanced driving score
    "netzach",     # uptime / online minutes
    "hod",         # data freshness
    "yesod",       # network mesh participation
    "daat",        # anomaly-free telemetry
    "malkuth",     # settlement / earth — payout weight
)


@dataclass(frozen=True)
class MandelbrotScore:
    escape_iterations: int
    max_iterations: int
    c_real: float
    c_imag: float
    stability_bps: int
    tree_node: str
    reward_weight: float

    def to_dict(self) -> dict[str, Any]:
        return {
            "escape_iterations": self.escape_iterations,
            "max_iterations": self.max_iterations,
            "c_real": self.c_real,
            "c_imag": self.c_imag,
            "stability_bps": self.stability_bps,
            "tree_node": self.tree_node,
            "reward_weight": self.reward_weight,
        }


def _entropy_seed(driver_id: str, payload: Mapping[str, Any]) -> int:
    blob = json.dumps({"driver_id": driver_id, "payload": payload}, sort_keys=True)
    return int(hashlib.sha256(blob.encode()).hexdigest()[:16], 16)


def evaluate_mandelbrot(
    driver_id: str,
    payload: Mapping[str, Any],
    *,
    max_iterations: int = 48,
) -> MandelbrotScore:
    """Evaluate Mandelbrot escape iterations — mirrors GreatDeltaEmissionRouter PoW."""
    entropy = _entropy_seed(driver_id, payload)
    c_real = (entropy % 3_000_001) / 1_000_000 - 2.0
    c_imag = ((entropy // 3_000_001) % 3_000_001) / 1_000_000 - 1.5

    z_real = 0.0
    z_imag = 0.0
    escape = max_iterations

    for i in range(max_iterations):
        real_sq = z_real * z_real
        imag_sq = z_imag * z_imag
        z_real = real_sq - imag_sq + c_real
        z_imag = 2 * z_real * z_imag + c_imag
        if abs(z_real) > 2 or abs(z_imag) > 2:
            escape = i + 1
            break

    stability_bps = int((escape / max_iterations) * 10_000)
    node_index = escape % len(TREE_OF_LIFE_NODES)
    reward_weight = round(stability_bps / 10_000 * _telemetry_bonus(payload), 6)

    return MandelbrotScore(
        escape_iterations=escape,
        max_iterations=max_iterations,
        c_real=round(c_real, 6),
        c_imag=round(c_imag, 6),
        stability_bps=stability_bps,
        tree_node=TREE_OF_LIFE_NODES[node_index],
        reward_weight=reward_weight,
    )


def _telemetry_bonus(payload: Mapping[str, Any]) -> float:
    speed = float(payload.get("speed_mps") or 0)
    distance = float(payload.get("odometer_m") or 0)
    speed_factor = min(speed / 30.0, 1.0) if speed > 0 else 0.2
    distance_factor = min(distance / 50_000.0, 1.0) if distance else 0.1
    return 0.5 + 0.3 * speed_factor + 0.2 * distance_factor


def route_to_tree(
    driver_id: str,
    signed_batches: Sequence[Mapping[str, Any]],
) -> list[dict[str, Any]]:
    """Route a batch of signed telemetry into Tree of Life nodes for ChromaDB ingest."""
    routed: list[dict[str, Any]] = []
    for signed in signed_batches:
        payload = signed.get("payload") or {}
        score = evaluate_mandelbrot(driver_id, payload)
        routed.append(
            {
                "driver_id": driver_id,
                "tree_node": score.tree_node,
                "mandelbrot": score.to_dict(),
                "telemetry": payload,
                "signature": signed.get("signature"),
                "collection": f"yieldswarm_tree_{score.tree_node}",
            }
        )
    return routed
