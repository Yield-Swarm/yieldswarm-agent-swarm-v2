"""Collect, sign, and batch driver telemetry for the YieldSwarm pipeline."""

from __future__ import annotations

import json
import os
import time
import uuid
from pathlib import Path
from typing import Any, Iterator, Optional

from kairo.identity.driver_wallet import DriverIdentity, create_driver_identity, sign_message
from kairo.telemetry.schema import DrivingTelemetry, GeoPoint, SignedTelemetry


class TelemetryCollector:
    """Ingests raw driving events, signs them, and buffers for pipeline export."""

    def __init__(
        self,
        driver_id: str,
        private_key: Optional[bytes] = None,
        outbox_dir: Optional[Path] = None,
    ) -> None:
        self.identity, self._private_key = (
            (create_driver_identity(driver_id)[0], private_key)
            if private_key
            else create_driver_identity(driver_id)
        )
        self.outbox_dir = outbox_dir or Path(
            os.environ.get("KAIRO_TELEMETRY_OUTBOX", ".data/kairo/outbox"),
        )
        self.outbox_dir.mkdir(parents=True, exist_ok=True)
        self._session_id = str(uuid.uuid4())

    @property
    def driver_identity(self) -> DriverIdentity:
        return self.identity

    def record(
        self,
        *,
        lat: float,
        lng: float,
        speed_mph: Optional[float] = None,
        heading_deg: Optional[float] = None,
        distance_miles: Optional[float] = None,
        duration_sec: Optional[int] = None,
        vehicle_id: Optional[str] = None,
        accuracy_m: Optional[float] = None,
        extra: Optional[dict[str, Any]] = None,
    ) -> SignedTelemetry:
        telemetry = DrivingTelemetry(
            driver_id=self.identity.driver_id,
            evm_address=self.identity.evm_address,
            iotex_address=self.identity.iotex_address,
            session_id=self._session_id,
            location=GeoPoint(lat=lat, lng=lng, accuracy_m=accuracy_m),
            speed_mph=speed_mph,
            heading_deg=heading_deg,
            distance_miles=distance_miles,
            duration_sec=duration_sec,
            vehicle_id=vehicle_id,
            extra=extra or {},
        )
        payload = telemetry.payload_for_signing()
        signature = sign_message(self._private_key, payload)
        signed = SignedTelemetry(telemetry=telemetry, signature=signature)
        self._persist(signed)
        return signed

    def _persist(self, signed: SignedTelemetry) -> None:
        ts = int(time.time() * 1000)
        path = self.outbox_dir / f"{self.identity.driver_id}-{ts}.json"
        path.write_text(json.dumps(signed.to_dict(), indent=2), encoding="utf-8")

    def pending_batch(self, limit: int = 100) -> list[SignedTelemetry]:
        """Read unsigned-exported events from the outbox."""
        results: list[SignedTelemetry] = []
        for path in sorted(self.outbox_dir.glob("*.json"))[:limit]:
            data = json.loads(path.read_text(encoding="utf-8"))
            tel = data["telemetry"]
            loc = tel.get("location")
            telemetry = DrivingTelemetry(
                driver_id=tel["driver_id"],
                evm_address=tel["evm_address"],
                iotex_address=tel["iotex_address"],
                timestamp=tel["timestamp"],
                session_id=tel.get("session_id", ""),
                location=GeoPoint(**loc) if loc else None,
                speed_mph=tel.get("speed_mph"),
                heading_deg=tel.get("heading_deg"),
                distance_miles=tel.get("distance_miles"),
                duration_sec=tel.get("duration_sec"),
                vehicle_id=tel.get("vehicle_id"),
                shard_id=tel.get("shard_id", 0),
                mandelbrot_zone=tel.get("mandelbrot_zone"),
                tree_of_life_path=tel.get("tree_of_life_path"),
                extra=tel.get("extra", {}),
            )
            results.append(
                SignedTelemetry(
                    telemetry=telemetry,
                    signature=data["signature"],
                    signature_scheme=data.get("signature_scheme", "eip191"),
                ),
            )
        return results

    def mark_exported(self, paths: Iterator[Path]) -> None:
        for path in paths:
            path.unlink(missing_ok=True)
