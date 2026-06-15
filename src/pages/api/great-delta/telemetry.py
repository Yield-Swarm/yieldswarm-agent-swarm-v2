from datetime import datetime, timezone
from time import perf_counter

from fastapi import FastAPI
from pydantic import BaseModel


MAX_LATENCY_MS = 80
HEARTBEAT_SECONDS = 420
TREASURY_SPLIT = {"vault": 50, "operations": 30, "ecosystem": 15, "sovereignReserve": 5}

app = FastAPI(title="YieldSwarm Great Delta API", version="0.1.0")


class TelemetryEvent(BaseModel):
    event: str = "heartbeat"
    source: str = "worker"
    sentAt: str | None = None


@app.get("/api/great-delta/health")
def health() -> dict:
    return {
        "status": "ok",
        "service": "great-delta-api",
        "guardrailMs": MAX_LATENCY_MS,
        "heartbeatSeconds": HEARTBEAT_SECONDS,
        "treasurySplit": TREASURY_SPLIT,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.post("/api/great-delta/telemetry")
def telemetry(event: TelemetryEvent) -> dict:
    started = perf_counter()
    response = {
        "accepted": True,
        "event": event.event,
        "source": event.source,
        "sentAt": event.sentAt,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    elapsed_ms = (perf_counter() - started) * 1000
    response["guardrail"] = {
        "maxMs": MAX_LATENCY_MS,
        "elapsedMs": round(elapsed_ms, 3),
        "withinGuardrail": elapsed_ms <= MAX_LATENCY_MS,
    }
    return response


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8080)
