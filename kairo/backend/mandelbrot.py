"""Route signed driver telemetry into the YieldSwarm Mandelbrot / Tree of Life mesh.

Each driver identity maps to a fractal shard via its fingerprint. Telemetry
events are appended to the shard ledger and forwarded to Odysseus ChromaDB
when configured.
"""

from __future__ import annotations

import json
import os
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional


@dataclass
class MandelbrotShard:
    shard_id: str
    depth: int
    branch: str  # helix | tree | root
    events: List[Dict[str, Any]] = field(default_factory=list)
    total_contribution_score: float = 0.0


def _shard_store() -> Path:
    root = Path(os.environ.get("KAIRO_MANDELBROT_STORE", ".data/kairo/mandelbrot"))
    root.mkdir(parents=True, exist_ok=True)
    return root


def fingerprint_to_shard(fingerprint: str, depth: int = 7) -> MandelbrotShard:
    """Map a 16-char fingerprint into a Mandelbrot quadrant + helix branch."""
    # Use fingerprint nibbles to pick quadrant (Tree of Life sephira index 1-10)
    sephira = (int(fingerprint[:2], 16) % 10) + 1
    helix = (int(fingerprint[2:4], 16) % 3) + 1
    branch = ["root", "helix", "tree"][helix % 3]
    shard_id = f"m{depth}-s{sephira:02d}-h{helix}-{fingerprint[:8]}"
    return MandelbrotShard(shard_id=shard_id, depth=depth, branch=branch)


def contribution_score(event: Dict[str, Any]) -> float:
    """Score telemetry contribution for reward estimation."""
    distance_km = float(event.get("distanceKm", 0))
    duration_min = float(event.get("durationMin", 0))
    data_quality = float(event.get("dataQuality", 1.0))
    base = distance_km * 0.01 + duration_min * 0.005
    return round(base * data_quality, 6)


def ingest_event(
    driver_id: str,
    fingerprint: str,
    payload: Dict[str, Any],
    signature: str,
) -> Dict[str, Any]:
    """Append a signed telemetry event to the appropriate Mandelbrot shard."""
    shard = fingerprint_to_shard(fingerprint)
    score = contribution_score(payload)
    record = {
        "driverId": driver_id,
        "fingerprint": fingerprint,
        "shardId": shard.shard_id,
        "branch": shard.branch,
        "timestamp": time.time(),
        "payload": payload,
        "signature": signature,
        "contributionScore": score,
    }
    shard.events.append(record)
    shard.total_contribution_score += score
    _persist_shard(shard)
    _forward_to_odysseus(record)
    return {
        "accepted": True,
        "shardId": shard.shard_id,
        "branch": shard.branch,
        "contributionScore": score,
        "totalShardScore": shard.total_contribution_score,
        "eventCount": len(shard.events),
    }


def _persist_shard(shard: MandelbrotShard) -> None:
    path = _shard_store() / f"{shard.shard_id}.json"
    data = {
        "shardId": shard.shard_id,
        "depth": shard.depth,
        "branch": shard.branch,
        "totalContributionScore": shard.total_contribution_score,
        "events": shard.events[-500:],  # cap local ledger
    }
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def load_shard_stats(driver_id: str, fingerprint: str) -> Dict[str, Any]:
    shard = fingerprint_to_shard(fingerprint)
    path = _shard_store() / f"{shard.shard_id}.json"
    if not path.exists():
        return {
            "driverId": driver_id,
            "shardId": shard.shard_id,
            "branch": shard.branch,
            "eventCount": 0,
            "totalContributionScore": 0.0,
            "estimatedRewardUsd": 0.0,
        }
    data = json.loads(path.read_text(encoding="utf-8"))
    driver_events = [e for e in data.get("events", []) if e.get("driverId") == driver_id]
    total_score = sum(e.get("contributionScore", 0) for e in driver_events)
    # Rough DePIN reward estimate: $0.02 per contribution point
    reward_rate = float(os.environ.get("KAIRO_DEPIN_REWARD_RATE", "0.02"))
    return {
        "driverId": driver_id,
        "shardId": shard.shard_id,
        "branch": shard.branch,
        "eventCount": len(driver_events),
        "totalContributionScore": round(total_score, 4),
        "estimatedRewardUsd": round(total_score * reward_rate, 4),
    }


def _forward_to_odysseus(record: Dict[str, Any]) -> None:
    """Best-effort forward to Odysseus memory mesh."""
    chroma_url = os.environ.get("ODYSSEUS_CHROMA_URL", "")
    if not chroma_url:
        return
    try:
        import urllib.request

        req = urllib.request.Request(
            f"{chroma_url.rstrip('/')}/api/v1/kairo/telemetry",
            data=json.dumps(record).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        urllib.request.urlopen(req, timeout=5)  # noqa: S310
    except Exception:
        pass  # non-blocking; local shard is source of truth
