"""Kairo API — driver identity, signed telemetry, Mandelbrot pipeline."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Dict

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from kairo.identity.driver import (
    create_driver_identity,
    load_identity_store,
    save_identity,
    verify_driver_signature,
)
from kairo.pipeline.mandelbrot import MandelbrotPipeline
from kairo.telemetry.signer import TelemetryPoint, sign_telemetry_batch

app = FastAPI(title="Kairo API", version="1.0.0")
pipeline = MandelbrotPipeline()
IDENTITY_STORE = Path(os.environ.get("KAIRO_IDENTITY_STORE", ".data/kairo/identities.json"))


class RegisterDriverRequest(BaseModel):
    external_id: str = Field(..., description="Opaque driver identifier (phone hash, etc.)")
    node_shard: int = 0


class TelemetryIngestRequest(BaseModel):
    driver_id: str
    private_key_hex: str
    points: list[Dict[str, Any]]
    node_shard: int = 0


@app.get("/health")
def health() -> Dict[str, str]:
    return {"status": "ok", "service": "kairo"}


@app.post("/drivers/register")
def register_driver(req: RegisterDriverRequest) -> Dict[str, Any]:
    identity, private_key = create_driver_identity(
        driver_external_id=req.external_id,
        node_shard=req.node_shard,
    )
    save_identity(IDENTITY_STORE, identity)
    return {
        "identity": identity.to_dict(),
        "private_key_hex": private_key,
        "warning": "Store private_key_hex in Vault immediately; never commit it.",
    }


@app.get("/drivers/{driver_id}")
def get_driver(driver_id: str) -> Dict[str, Any]:
    store = load_identity_store(IDENTITY_STORE)
    identity = store.get(driver_id)
    if not identity:
        raise HTTPException(404, "driver not found")
    summary = pipeline.driver_summary(driver_id)
    return {"identity": identity.to_dict(), "contribution": summary}


@app.post("/telemetry/ingest")
def ingest_telemetry(req: TelemetryIngestRequest) -> Dict[str, Any]:
    points = [TelemetryPoint(**p) for p in req.points]
    batch = sign_telemetry_batch(
        driver_id=req.driver_id,
        private_key_hex=req.private_key_hex,
        points=points,
        node_shard=req.node_shard,
    )
    record = pipeline.ingest(batch)
    return {"batch": batch.to_dict(), "contribution": record.to_dict()}


@app.get("/dashboard/summary")
def dashboard_summary() -> Dict[str, Any]:
    """Aggregate contribution stats for the Kairo dashboard."""
    store_path = pipeline.store_path
    drivers: Dict[str, Dict[str, float]] = {}
    total_reward = 0.0
    if store_path.exists():
        import json

        for line in store_path.read_text().splitlines():
            if not line.strip():
                continue
            row = json.loads(line)
            did = row["driver_id"]
            drivers.setdefault(did, {"batches": 0, "reward_usd": 0.0})
            drivers[did]["batches"] += 1
            drivers[did]["reward_usd"] += float(row.get("potential_reward_usd", 0))
            total_reward += float(row.get("potential_reward_usd", 0))

    return {
        "driver_count": len(drivers),
        "total_potential_reward_usd": round(total_reward, 4),
        "drivers": [
            {"driver_id": k, **v} for k, v in sorted(drivers.items(), key=lambda x: -x[1]["reward_usd"])
        ],
    }
