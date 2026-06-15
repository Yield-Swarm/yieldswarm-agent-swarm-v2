"""Telemetry ingestion pipeline → Mandelbrot / Tree of Life → YieldSwarm."""

from __future__ import annotations

import math
import uuid
from datetime import datetime, timezone

from kairo.db import db
from kairo.models.schemas import MandelbrotRouteOut, SignedTelemetryIn
from kairo.services.identity_service import IdentityService
from kairo.services.mandelbrot_router import route_telemetry
from kairo.services.signing_service import verify_telemetry_signature
from kairo.services.yieldswarm_emitter import YieldSwarmEmitter


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlon / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


class TelemetryPipeline:
    def __init__(self) -> None:
        self.identity = IdentityService()
        self.emitter = YieldSwarmEmitter()

    def _last_point(self, driver_id: str) -> tuple[float, float] | None:
        row = db.fetchone(
            """
            SELECT latitude, longitude FROM telemetry_events
            WHERE driver_id = ? ORDER BY recorded_at DESC LIMIT 1
            """,
            (driver_id,),
        )
        if not row:
            return None
        return row["latitude"], row["longitude"]

    def ingest(self, data: SignedTelemetryIn) -> dict:
        driver = self.identity.get_driver(data.payload.driver_id)
        if not driver:
            raise ValueError("Unknown driver_id")

        verified, p_hash = verify_telemetry_signature(data, driver["evm_address"])
        if not verified:
            raise ValueError("Telemetry signature verification failed")

        route: MandelbrotRouteOut = route_telemetry(
            data.payload.gps.latitude,
            data.payload.gps.longitude,
            p_hash,
        )

        distance_delta = 0.0
        last = self._last_point(data.payload.driver_id)
        if last:
            distance_delta = _haversine_km(
                last[0], last[1],
                data.payload.gps.latitude, data.payload.gps.longitude,
            )

        event_id = str(uuid.uuid4())
        db.insert(
            "telemetry_events",
            {
                "id": event_id,
                "driver_id": data.payload.driver_id,
                "recorded_at": data.payload.recorded_at.isoformat(),
                "latitude": data.payload.gps.latitude,
                "longitude": data.payload.gps.longitude,
                "speed_mps": data.payload.speed_mps,
                "acceleration_mps2": data.payload.acceleration_mps2,
                "heading_deg": data.payload.heading_deg,
                "route_segment_id": (
                    data.payload.route.segment_id if data.payload.route else None
                ),
                "payload_hash": p_hash,
                "signature_hex": data.signature_hex,
                "mandelbrot_shard": route.shard_id,
                "tree_of_life_node": route.tree_of_life_node,
                "verified": 1,
                "distance_delta_km": distance_delta,
            },
        )

        route_data = route.model_dump()
        harvest = self.emitter.emit(
            driver_id=data.payload.driver_id,
            event_id=event_id,
            payload_hash=p_hash,
            routing=route_data,
            distance_delta_km=distance_delta,
        )

        return {
            "event_id": event_id,
            "verified": True,
            "payload_hash": p_hash,
            "routing": route_data,
            "distance_delta_km": round(distance_delta, 6),
            "yieldswarm_status": "ingested",
            "yieldswarm_harvest": harvest,
        }

    def driver_stats(self, driver_id: str) -> dict:
        row = db.fetchone(
            """
            SELECT
                COUNT(*) AS signed_packets,
                SUM(verified) AS verified_packets,
                COALESCE(SUM(distance_delta_km), 0) AS total_distance_km,
                MAX(recorded_at) AS last_telemetry_at
            FROM telemetry_events WHERE driver_id = ?
            """,
            (driver_id,),
        ) or {}
        shards = db.fetchall(
            """
            SELECT DISTINCT mandelbrot_shard FROM telemetry_events
            WHERE driver_id = ? ORDER BY mandelbrot_shard
            """,
            (driver_id,),
        )
        nodes = db.fetchall(
            """
            SELECT tree_of_life_node, COUNT(*) AS cnt FROM telemetry_events
            WHERE driver_id = ? GROUP BY tree_of_life_node ORDER BY cnt DESC
            """,
            (driver_id,),
        )
        return {
            **row,
            "active_shards": [s["mandelbrot_shard"] for s in shards],
            "tree_nodes": [n["tree_of_life_node"] for n in nodes],
        }
