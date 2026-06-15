"""
Signed telemetry ingestion — delegates to kairo.services pipeline when available.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

_PIPELINE = Path(__file__).resolve().parents[1] / "data" / "pipeline"


def ingest_signed_event(raw: dict[str, Any]) -> tuple[dict[str, Any] | None, str | None]:
    try:
        from kairo.services.identity import DriverStore
        from kairo.services.mandelbrot_pipeline import MandelbrotPipeline
        from kairo.services.signing import verify_telemetry

        store = DriverStore(_PIPELINE.parent / "drivers")
        pipeline = MandelbrotPipeline(_PIPELINE)
        identity = store.get(raw.get("driver_id", ""))
        if not identity:
            return None, "unknown driver_id"
        if not verify_telemetry(raw, identity.public_key_hex):
            return None, "invalid signature"
        record = pipeline.ingest(raw)
        return record, None
    except Exception as exc:
        return None, str(exc)


def list_contributions(limit: int = 50) -> list[dict[str, Any]]:
    from kairo.services.mandelbrot_pipeline import MandelbrotPipeline

    pipeline = MandelbrotPipeline(_PIPELINE)
    out = []
    for driver_id in list(pipeline._contributions.keys())[:limit]:
        stats = pipeline.driver_stats(driver_id)
        if stats:
            out.append(stats)
    return out
