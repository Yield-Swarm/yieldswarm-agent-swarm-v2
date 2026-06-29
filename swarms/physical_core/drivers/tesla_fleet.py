"""Tesla Fleet API driver — vehicle kinematics → helical telemetry streams.

Credentials via environment (never committed):
  TESLA_CLIENT_ID, TESLA_CLIENT_SECRET, TESLA_REFRESH_TOKEN
  TESLA_FLEET_VINS (comma-separated, max 4)
"""

from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any


TESLA_AUTH_URL = "https://auth.tesla.com/oauth2/v3/token"
TESLA_FLEET_BASE = os.environ.get("TESLA_FLEET_API_BASE", "https://fleet-api.prd.na.vn.cloud.tesla.com")


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass
class TeslaCredentials:
    client_id: str
    client_secret: str
    refresh_token: str

    @classmethod
    def from_env(cls) -> "TeslaCredentials":
        client_id = os.environ.get("TESLA_CLIENT_ID", "")
        client_secret = os.environ.get("TESLA_CLIENT_SECRET", "")
        refresh_token = os.environ.get("TESLA_REFRESH_TOKEN", "")
        if not all([client_id, client_secret, refresh_token]):
            raise EnvironmentError(
                "TESLA_CLIENT_ID, TESLA_CLIENT_SECRET, TESLA_REFRESH_TOKEN required"
            )
        return cls(client_id=client_id, client_secret=client_secret, refresh_token=refresh_token)


class TeslaFleetDriver:
    """Poll Tesla Fleet API and emit physical-core vehicle telemetry."""

    def __init__(self, creds: TeslaCredentials | None = None) -> None:
        self.creds = creds or TeslaCredentials.from_env()
        self._access_token: str | None = None
        self._token_expires_at: float = 0.0
        raw = os.environ.get("TESLA_FLEET_VINS", "")
        self.vins = [v.strip() for v in raw.split(",") if v.strip()][:4]

    def _refresh_access_token(self) -> str:
        if self._access_token and time.time() < self._token_expires_at - 60:
            return self._access_token

        body = urllib.parse.urlencode(
            {
                "grant_type": "refresh_token",
                "client_id": self.creds.client_id,
                "client_secret": self.creds.client_secret,
                "refresh_token": self.creds.refresh_token,
            }
        ).encode()
        req = urllib.request.Request(
            TESLA_AUTH_URL,
            data=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
        self._access_token = data["access_token"]
        self._token_expires_at = time.time() + int(data.get("expires_in", 3600))
        return self._access_token

    def _api_get(self, path: str) -> dict[str, Any]:
        token = self._refresh_access_token()
        url = f"{TESLA_FLEET_BASE}{path}"
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read().decode())
        except urllib.error.HTTPError as exc:
            body = exc.read().decode() if exc.fp else ""
            raise RuntimeError(f"Tesla API {path} failed: {exc.code} {body}") from exc

    def list_vehicles(self) -> list[dict[str, Any]]:
        payload = self._api_get("/api/1/vehicles")
        return payload.get("response", [])

    def vehicle_data(self, vehicle_id: str) -> dict[str, Any]:
        return self._api_get(f"/api/1/vehicles/{vehicle_id}/vehicle_data")

    @staticmethod
    def _mmorpg_bridge(speed_kmh: float, throttle: float, brake: float) -> dict[str, Any]:
        """Map real-world driving metrics to RuneScape-style skill XP events."""
        xp = max(0.0, speed_kmh * 0.1)
        if brake > 0.5:
            event = "precision_braking"
            skill = "efficiency"
            xp += 2.0
        elif throttle > 70:
            event = "power_accel"
            skill = "driving"
            xp += 1.5
        else:
            event = "cruise_explore"
            skill = "exploration"
        return {"skillMatrix": skill, "xpDelta": round(xp, 2), "eventType": event}

    def sample_vehicle(self, vehicle_id: str, vin: str) -> dict[str, Any]:
        data = self.vehicle_data(vehicle_id)
        drive = data.get("response", {}).get("drive_state", {})
        vehicle = data.get("response", {}).get("vehicle_state", {})
        speed_kmh = float(drive.get("speed") or 0) * 1.60934 if drive.get("speed") else 0.0
        throttle = float(vehicle.get("pedal_position") or 0)
        brake = 1.0 if vehicle.get("brake_pedal") else 0.0

        return {
            "vin": vin,
            "vehicleId": vehicle_id,
            "capturedAt": _utc_now(),
            "kinematics": {
                "speedKmh": round(speed_kmh, 2),
                "headingDeg": float(drive.get("heading") or 0),
                "latitude": float(drive.get("latitude") or 0),
                "longitude": float(drive.get("longitude") or 0),
                "accelLongMps2": None,
                "accelLatMps2": None,
                "yawRateDps": None,
            },
            "driverInputs": {
                "throttlePercent": round(throttle, 1),
                "brakePressure": brake,
                "steeringAngleDeg": None,
            },
            "mmorpgBridge": self._mmorpg_bridge(speed_kmh, throttle, brake),
        }

    def poll_fleet(self) -> list[dict[str, Any]]:
        vehicles = self.list_vehicles()
        if self.vins:
            vehicles = [v for v in vehicles if v.get("vin") in self.vins]
        samples = []
        for v in vehicles[:4]:
            vid = str(v.get("id_s") or v.get("id", ""))
            vin = v.get("vin", "")
            if not vid:
                continue
            samples.append(self.sample_vehicle(vid, vin))
        return samples
