"""FastAPI application — physical control center orchestration daemon."""

from __future__ import annotations

import asyncio
import logging
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Any

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse

from services.control_center.aggregator import aggregation_loop
from services.control_center.config import HOST, PORT, WS_BROADCAST_SEC
from services.control_center.config import REPO_ROOT
from services.control_center.encrypted_id import mint_pow_id, mint_powui_id, redact
from services.control_center.models import DeviceRecord, DeviceStatsIn, DeviceStatus
from services.control_center.state import state

log = logging.getLogger("control_center")
_stop_event: asyncio.Event | None = None
_agg_task: asyncio.Task | None = None
_ws_clients: set[WebSocket] = set()


@asynccontextmanager
async def lifespan(app: FastAPI):  # noqa: ARG001
    global _stop_event, _agg_task
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(message)s")
    _stop_event = asyncio.Event()
    _agg_task = asyncio.create_task(aggregation_loop(_stop_event))
    broadcaster = asyncio.create_task(_ws_broadcast_loop(_stop_event))
    log.info("control center started host=%s port=%s", HOST, PORT)
    yield
    _stop_event.set()
    if _agg_task:
        await _agg_task
    broadcaster.cancel()
    log.info("control center shutdown complete")


app = FastAPI(
    title="YieldSwarm Physical Control Center",
    description="Unified local infrastructure orchestration — mining, edge workers, displays",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def dashboard() -> FileResponse:
    """Multi-display control center UI."""
    return FileResponse(REPO_ROOT / "dashboard" / "control-center.html")


@app.get("/health")
async def health() -> dict[str, str]:
    snap = await state.snapshot()
    return {
        "status": "ok",
        "service": "control-center",
        "devices": str(snap.device_count),
        "online": str(snap.online_count),
    }


@app.get("/api/state")
async def get_state() -> dict[str, Any]:
    return (await state.snapshot()).model_dump()


@app.post("/api/telemetry/device-stats")
async def ingest_device_stats(payload: DeviceStatsIn) -> dict[str, Any]:
    """Accept telemetry from phone farms, laptops, edge worker stubs."""
    pow_id = payload.encrypted_pow_id or mint_pow_id(payload.device_id, {"kind": payload.kind})
    ui_id = payload.encrypted_powui_id or mint_powui_id(payload.device_id, {"surface": "control-center"})

    record = DeviceRecord(
        device_id=payload.device_id,
        kind=payload.kind,
        status=DeviceStatus.ONLINE if payload.network_ok else DeviceStatus.DEGRADED,
        hash_rate_mhs=payload.hash_rate_mhs,
        latency_ms=payload.latency_ms,
        cpu_percent=payload.cpu_percent,
        memory_percent=payload.memory_percent,
        network_ok=payload.network_ok,
        temp_c=payload.temp_c,
        encrypted_pow_id=pow_id,
        encrypted_powui_id=ui_id,
        last_seen_at=datetime.now(timezone.utc).isoformat(),
        source="push",
    )
    await state.upsert(record)
    await _broadcast_snapshot()
    return {
        "accepted": True,
        "device_id_redacted": redact(payload.device_id),
        "encrypted_pow_id": pow_id,
        "encrypted_powui_id": ui_id,
    }


@app.websocket("/api/ws/stream")
async def ws_stream(websocket: WebSocket) -> None:
    """Real-time infrastructure broadcast for multi-display dashboards."""
    await websocket.accept()
    _ws_clients.add(websocket)
    try:
        snap = await state.snapshot()
        await websocket.send_json({"type": "snapshot", "data": snap.model_dump()})
        while True:
            try:
                await asyncio.wait_for(websocket.receive_text(), timeout=WS_BROADCAST_SEC * 2)
            except asyncio.TimeoutError:
                snap = await state.snapshot()
                await websocket.send_json({"type": "tick", "data": snap.model_dump()})
    except WebSocketDisconnect:
        pass
    except Exception as exc:
        log.debug("ws client error: %s", exc)
    finally:
        _ws_clients.discard(websocket)


async def _broadcast_snapshot() -> None:
    if not _ws_clients:
        return
    snap = await state.snapshot()
    message = {"type": "update", "data": snap.model_dump()}
    dead: list[WebSocket] = []
    for ws in list(_ws_clients):
        try:
            await ws.send_json(message)
        except Exception:
            dead.append(ws)
    for ws in dead:
        _ws_clients.discard(ws)


async def _ws_broadcast_loop(stop_event: asyncio.Event) -> None:
    while not stop_event.is_set():
        try:
            await _broadcast_snapshot()
        except Exception:
            log.exception("ws broadcast failed")
        try:
            await asyncio.wait_for(stop_event.wait(), timeout=WS_BROADCAST_SEC)
        except asyncio.TimeoutError:
            continue


def main() -> None:
    import uvicorn

    uvicorn.run(
        "services.control_center.main:app",
        host=HOST,
        port=PORT,
        reload=False,
        log_level="info",
    )


if __name__ == "__main__":
    main()
