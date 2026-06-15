"""Route signed Kairo telemetry into the YieldSwarm Mandelbrot / Tree of Life mesh."""

from __future__ import annotations

import json
import math
import os
from pathlib import Path
from typing import Any

from kairo.models.driver import SignedTelemetry


def _mandelbrot_escape(cx: float, cy: float, max_iter: int = 32) -> int:
    x = y = 0.0
    for i in range(max_iter):
        if x * x + y * y > 4:
            return i
        x, y = x * x - y * y + cx, 2 * x * y + cy
    return max_iter


def _tree_coordinates(packet: SignedTelemetry, shard_count: int = 120) -> dict[str, Any]:
    """Map telemetry into Tree-of-Life coordinates (shard + branch + leaf)."""
    lat = float(packet.payload.get("latitude", 0.0))
    lon = float(packet.payload.get("longitude", 0.0))
    speed = float(packet.payload.get("speed_kmh", 0.0))

    shard = int(abs(hash(packet.driver_id)) % shard_count)
    branch = int((lon + 180) / 360 * 84) % 84
    leaf = int((lat + 90) / 180 * 84) % 84
    mandelbrot_score = _mandelbrot_escape(lon / 180.0, lat / 90.0)

    return {
        "shard_id": shard,
        "branch": branch,
        "leaf": leaf,
        "mandelbrot_score": mandelbrot_score,
        "speed_kmh": speed,
        "reward_weight": round((mandelbrot_score + 1) * math.log1p(speed + 1), 4),
    }


class MandelbrotPipeline:
    """Persist signed packets and index them for the swarm reward engine."""

    def __init__(self, root: Path | None = None) -> None:
        self.root = root or Path(os.environ.get("KAIRO_STORE_DIR", ".data/kairo"))
        self.root.mkdir(parents=True, exist_ok=True)
        self._packets = self.root / "telemetry_packets.jsonl"
        self._tree_index = self.root / "tree_index.json"

    def ingest(self, packet: SignedTelemetry) -> dict[str, Any]:
        coords = _tree_coordinates(packet)
        record = {
            "telemetry_id": packet.telemetry_id,
            "driver_id": packet.driver_id,
            "evm_address": packet.evm_address,
            "signed_at": packet.signed_at,
            "payload": packet.payload,
            "signature": packet.signature,
            "tree": coords,
        }

        with self._packets.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record) + "\n")

        index = self._load_index()
        driver_stats = index["drivers"].setdefault(
            packet.driver_id,
            {
                "driver_id": packet.driver_id,
                "evm_address": packet.evm_address,
                "packets": 0,
                "distance_km": 0.0,
                "drive_seconds": 0,
                "mandelbrot_nodes": 0,
                "reward_weight": 0.0,
                "last_contribution_at": None,
            },
        )
        driver_stats["packets"] += 1
        driver_stats["distance_km"] += float(packet.payload.get("distance_km", 0.0))
        driver_stats["drive_seconds"] += int(packet.payload.get("duration_seconds", 0))
        driver_stats["mandelbrot_nodes"] += 1
        driver_stats["reward_weight"] += coords["reward_weight"]
        driver_stats["last_contribution_at"] = packet.signed_at

        tree_key = f"{coords['shard_id']}:{coords['branch']}:{coords['leaf']}"
        index["tree_nodes"][tree_key] = index["tree_nodes"].get(tree_key, 0) + 1
        self._save_index(index)

        # Optional ChromaDB fan-out when Odysseus memory mesh is available.
        try:
            from agents.odysseus_memory import record_driver_telemetry  # type: ignore

            record_driver_telemetry(record)
        except Exception:
            pass

        return record

    def _load_index(self) -> dict[str, Any]:
        if not self._tree_index.exists():
            return {"drivers": {}, "tree_nodes": {}}
        return json.loads(self._tree_index.read_text(encoding="utf-8"))

    def _save_index(self, index: dict[str, Any]) -> None:
        self._tree_index.write_text(json.dumps(index, indent=2), encoding="utf-8")

    def driver_stats(self, driver_id: str) -> dict[str, Any] | None:
        index = self._load_index()
        return index["drivers"].get(driver_id)

    def all_driver_stats(self) -> list[dict[str, Any]]:
        index = self._load_index()
        return list(index["drivers"].values())

    def tree_summary(self) -> dict[str, Any]:
        index = self._load_index()
        return {
            "node_count": len(index["tree_nodes"]),
            "driver_count": len(index["drivers"]),
            "top_nodes": sorted(
                index["tree_nodes"].items(),
                key=lambda item: item[1],
                reverse=True,
            )[:10],
        }
