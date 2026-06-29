"""Antminer Z15 Pro Equihash fleet monitor — per-unit hashrate and thermal matrix."""

from __future__ import annotations

import json
import os
import socket
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass
class AsicEndpoint:
    unit_id: str
    host: str
    port: int = 4028

    @classmethod
    def from_env_prefix(cls, index: int) -> "AsicEndpoint | None":
        host = os.environ.get(f"Z15_HOST_{index:02d}")
        if not host:
            return None
        port = int(os.environ.get(f"Z15_PORT_{index:02d}", "4028"))
        return cls(unit_id=f"z15-{index:02d}", host=host, port=port)


class Z15AsicMonitor:
    """Query miner APIs (cgminer/bmminer JSON-RPC or HTTP summary) for fleet matrix."""

    FLEET_SIZE = 30

    def __init__(self, endpoints: list[AsicEndpoint] | None = None) -> None:
        if endpoints is not None:
            self.endpoints = endpoints
        else:
            self.endpoints = []
            for i in range(1, self.FLEET_SIZE + 1):
                ep = AsicEndpoint.from_env_prefix(i)
                if ep:
                    self.endpoints.append(ep)

    def _query_summary_http(self, ep: AsicEndpoint) -> dict[str, Any]:
        url = f"http://{ep.host}:{ep.port}/cgi-bin/summary.cgi"
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read().decode())

    def _query_socket(self, ep: AsicEndpoint, command: str = "summary") -> dict[str, Any]:
        payload = json.dumps({"command": command}).encode()
        with socket.create_connection((ep.host, ep.port), timeout=5) as sock:
            sock.sendall(payload)
            raw = b""
            while True:
                chunk = sock.recv(4096)
                if not chunk:
                    break
                raw += chunk
                if raw.endswith(b"\x00"):
                    break
        return json.loads(raw.decode().rstrip("\x00"))

    def poll_unit(self, ep: AsicEndpoint) -> dict[str, Any]:
        try:
            summary = self._query_socket(ep)
            summ = summary.get("SUMMARY", [{}])[0]
            hashrate = float(summ.get("GHS 5s") or summ.get("MHS 5s", 0)) / (
                1.0 if "GHS" in summ else 1000.0
            )
            return {
                "unitId": ep.unit_id,
                "status": "mining" if hashrate > 0 else "idle",
                "hashrateGh": round(hashrate, 3),
                "powerW": summ.get("Power"),
                "chipTempC": summ.get("Temperature"),
                "pool": summ.get("Pool"),
                "worker": summ.get("Worker"),
            }
        except (urllib.error.URLError, OSError, json.JSONDecodeError, KeyError, IndexError):
            return {
                "unitId": ep.unit_id,
                "status": "offline",
                "hashrateGh": 0.0,
                "powerW": None,
                "chipTempC": None,
                "pool": None,
                "worker": None,
            }

    def poll_fleet(self) -> dict[str, Any]:
        units = [self.poll_unit(ep) for ep in self.endpoints]
        if not units:
            units = [
                {
                    "unitId": f"z15-{i:02d}",
                    "status": "offline",
                    "hashrateGh": 0.0,
                    "powerW": None,
                    "chipTempC": None,
                    "pool": None,
                    "worker": None,
                }
                for i in range(1, self.FLEET_SIZE + 1)
            ]
        aggregate = sum(u.get("hashrateGh", 0) for u in units)
        return {
            "fleetSize": self.FLEET_SIZE,
            "algorithm": "equihash",
            "model": "antminer-z15-pro",
            "aggregateHashrateGh": round(aggregate, 3),
            "units": units,
        }
