"""FastAPI application for Kairo → YieldSwarm bridge."""

from __future__ import annotations

from datetime import datetime

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pathlib import Path

from kairo.config import settings
from kairo.models.schemas import (
    DashboardSummary,
    DriverIdentityOut,
    DriverPayQuote,
    DriverRegisterIn,
    ServerKeygenOut,
    SignedTelemetryIn,
)
from kairo.services.identity_service import IdentityService
from kairo.services.reward_service import RewardService
from kairo.services.telemetry_pipeline import TelemetryPipeline

app = FastAPI(
    title="Kairo → YieldSwarm Bridge",
    description="Signed telemetry ingress, Mandelbrot routing, DePIN rewards, 2x driver pay",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

identity_svc = IdentityService()
telemetry_svc = TelemetryPipeline()
reward_svc = RewardService()

DASHBOARD_PATH = Path(__file__).resolve().parent.parent / "dashboard" / "index.html"


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "kairo-yieldswarm-bridge"}


@app.get("/dashboard")
def dashboard_ui() -> FileResponse:
    if not DASHBOARD_PATH.exists():
        raise HTTPException(404, "Dashboard not found")
    return FileResponse(DASHBOARD_PATH)


# --- Driver identity ---

@app.post(f"{settings.api_prefix}/drivers/register", response_model=DriverIdentityOut)
def register_driver(data: DriverRegisterIn) -> DriverIdentityOut:
    try:
        return identity_svc.register_client_identity(data)
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc


@app.post(f"{settings.api_prefix}/drivers/generate", response_model=ServerKeygenOut)
def generate_driver(kairo_user_id: str) -> ServerKeygenOut:
    """Dev/onboarding: server-generated identity (prefer client-side keys in production)."""
    existing = identity_svc.get_driver_by_kairo(kairo_user_id)
    if existing:
        raise HTTPException(409, "Kairo user already registered")
    return identity_svc.generate_server_identity(kairo_user_id)


@app.get(f"{settings.api_prefix}/drivers/{{driver_id}}", response_model=DriverIdentityOut)
def get_driver(driver_id: str) -> DriverIdentityOut:
    row = identity_svc.get_driver(driver_id)
    if not row:
        raise HTTPException(404, "Driver not found")
    created = row["created_at"]
    if isinstance(created, str):
        created = datetime.fromisoformat(created.replace("Z", "+00:00"))
    return DriverIdentityOut(
        driver_id=row["id"],
        kairo_user_id=row["kairo_user_id"],
        evm_address=row["evm_address"],
        iotex_address=row["iotex_address"],
        public_key_hex=row["public_key_hex"],
        license_key=row["license_key"],
        created_at=created,
        depin_helium_pubkey=row.get("depin_helium_pubkey"),
        depin_grass_node_id=row.get("depin_grass_node_id"),
    )


# --- Telemetry ---

@app.post(f"{settings.api_prefix}/telemetry/ingest")
def ingest_telemetry(data: SignedTelemetryIn) -> dict:
    try:
        return telemetry_svc.ingest(data)
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc


@app.get(f"{settings.api_prefix}/telemetry/{{driver_id}}/stats")
def telemetry_stats(driver_id: str) -> dict:
    if not identity_svc.get_driver(driver_id):
        raise HTTPException(404, "Driver not found")
    return telemetry_svc.driver_stats(driver_id)


# --- Rewards & pay ---

@app.get(f"{settings.api_prefix}/rewards/{{driver_id}}/dashboard", response_model=DashboardSummary)
def rewards_dashboard(driver_id: str) -> DashboardSummary:
    try:
        return reward_svc.dashboard(driver_id)
    except ValueError as exc:
        raise HTTPException(404, str(exc)) from exc


@app.get(f"{settings.api_prefix}/rewards/{{driver_id}}/quote", response_model=DriverPayQuote)
def pay_quote(driver_id: str) -> DriverPayQuote:
    try:
        return reward_svc.pay_quote(driver_id)
    except ValueError as exc:
        raise HTTPException(404, str(exc)) from exc


@app.post(f"{settings.api_prefix}/payments/settle/{{driver_id}}")
def settle_payout(driver_id: str) -> dict:
    try:
        return reward_svc.settle_period(driver_id)
    except ValueError as exc:
        raise HTTPException(404, str(exc)) from exc
