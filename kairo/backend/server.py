"""Kairo driver API — identity, signed telemetry, contribution dashboard."""

from __future__ import annotations

import os
from typing import Any, Dict, Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from . import identity, mandelbrot, telemetry

app = FastAPI(title="Kairo Driver API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.environ.get("KAIRO_CORS_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class CreateIdentityRequest(BaseModel):
    driverId: Optional[str] = None


class TelemetryRequest(BaseModel):
    driverId: str
    lat: float
    lng: float
    speedKmh: float = 0
    distanceKm: float = 0
    durationMin: float = 0
    tripId: Optional[str] = None
    dataQuality: float = Field(default=1.0, ge=0, le=1)
    signature: Optional[str] = None
    timestamp: Optional[float] = None


class SignRequest(BaseModel):
    driverId: str
    message: str


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "kairo-driver-api"}


@app.post("/api/v1/drivers/identity")
def create_identity(req: CreateIdentityRequest) -> dict:
    ident, _pk = identity.create_driver_identity(req.driverId)
    fp = identity.identity_fingerprint(ident)
    shard = mandelbrot.fingerprint_to_shard(fp)
    return {
        **ident.to_public_dict(),
        "fingerprint": fp,
        "mandelbrotShard": shard.shard_id,
        "helixBranch": shard.branch,
    }


@app.get("/api/v1/drivers/{driver_id}/identity")
def get_identity(driver_id: str) -> dict:
    ident = identity.load_identity(driver_id)
    if not ident:
        raise HTTPException(404, "driver not found")
    fp = identity.identity_fingerprint(ident)
    stats = mandelbrot.load_shard_stats(driver_id, fp)
    return {**ident.to_public_dict(), "fingerprint": fp, "contribution": stats}


@app.post("/api/v1/drivers/sign")
def sign_message(req: SignRequest) -> dict:
    try:
        return identity.sign_message(req.driverId, req.message)
    except KeyError as exc:
        raise HTTPException(404, str(exc)) from exc


@app.post("/api/v1/telemetry")
def ingest_telemetry(req: TelemetryRequest) -> dict:
    payload: Dict[str, Any] = req.model_dump(exclude={"signature"})
    try:
        return telemetry.submit_telemetry(req.driverId, payload, req.signature)
    except KeyError as exc:
        raise HTTPException(404, str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc


@app.get("/api/v1/drivers/{driver_id}/contribution")
def driver_contribution(driver_id: str) -> dict:
    ident = identity.load_identity(driver_id)
    if not ident:
        raise HTTPException(404, "driver not found")
    fp = identity.identity_fingerprint(ident)
    return mandelbrot.load_shard_stats(driver_id, fp)


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("KAIRO_API_PORT", "8100"))
    uvicorn.run("kairo.backend.server:app", host="0.0.0.0", port=port, reload=False)
