"""Kairo driver device — collect and submit signed telemetry."""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from typing import Any, Optional

from kairo.models.telemetry_packet import DriverTelemetrySample
from kairo.services.telemetry_pipeline import TelemetryPipeline


class DriverTelemetryClient:
    """Collect GPS samples locally and submit to Kairo API or in-process pipeline."""

    def __init__(
        self,
        driver_id: str,
        *,
        api_base: Optional[str] = None,
        pipeline: Optional[TelemetryPipeline] = None,
    ) -> None:
        self.driver_id = driver_id
        self.api_base = (api_base or "").rstrip("/")
        self.pipeline = pipeline or TelemetryPipeline()

    def collect(
        self,
        latitude: float,
        longitude: float,
        *,
        speed_kmh: float = 0.0,
        heading_deg: float = 0.0,
        distance_km: float = 0.0,
        duration_seconds: int = 0,
        ride_id: Optional[str] = None,
        trip_phase: str = "idle",
        fare_usd: float = 0.0,
    ) -> DriverTelemetrySample:
        identity = self.pipeline.drivers.get(self.driver_id)
        if not identity:
            raise KeyError(f"driver not registered: {self.driver_id}")

        return DriverTelemetrySample(
            driver_id=self.driver_id,
            evm_address=identity.evm_address,
            latitude=latitude,
            longitude=longitude,
            speed_kmh=speed_kmh,
            heading_deg=heading_deg,
            distance_km=distance_km,
            duration_seconds=duration_seconds,
            ride_id=ride_id,
            trip_phase=trip_phase,
            fare_usd=fare_usd,
        )

    def submit_sample(self, sample: DriverTelemetrySample) -> dict[str, Any]:
        if self.api_base:
            return self._post_remote(sample.to_dict())
        return self.pipeline.process_sample(sample.to_dict())

    def _post_remote(self, payload: dict[str, Any]) -> dict[str, Any]:
        url = f"{self.api_base}/api/telemetry"
        body = json.dumps(payload).encode()
        req = urllib.request.Request(
            url,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read().decode())
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode()
            raise RuntimeError(f"telemetry submit failed ({exc.code}): {detail}") from exc
