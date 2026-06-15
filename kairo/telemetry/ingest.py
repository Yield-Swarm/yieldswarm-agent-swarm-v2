"""Signed telemetry ingestion — delegates to TelemetryPipeline."""

from __future__ import annotations

from typing import Any

from kairo.services.telemetry_pipeline import TelemetryPipeline

_pipeline: TelemetryPipeline | None = None


def _get_pipeline() -> TelemetryPipeline:
    global _pipeline
    if _pipeline is None:
        _pipeline = TelemetryPipeline()
    return _pipeline


def ingest_signed_event(raw: dict[str, Any]) -> tuple[dict[str, Any] | None, str | None]:
    try:
        result = _get_pipeline().submit(raw)
        return result, None
    except KeyError as exc:
        return None, str(exc)
    except ValueError as exc:
        return None, str(exc)
    except Exception as exc:
        return None, str(exc)


def ingest_sample(raw: dict[str, Any]) -> tuple[dict[str, Any] | None, str | None]:
    try:
        result = _get_pipeline().process_sample(raw)
        return result, None
    except (KeyError, ValueError) as exc:
        return None, str(exc)
    except Exception as exc:
        return None, str(exc)


def list_contributions(limit: int = 50) -> list[dict[str, Any]]:
    board = _get_pipeline().leaderboard(limit)
    return board.get("drivers", [])[:limit]
