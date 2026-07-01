#!/usr/bin/env python3
"""Heaven-Earth fusion bridge — maps edge earth state into shared-state heavenEarth.helix."""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
SHARED_STATE_PATH = REPO_ROOT / "yield-swarm-core" / "shared-state.json"
MASSIVE_STACK_PATH = REPO_ROOT / "artifacts" / "cloud-mining" / "massive-stack-status.json"
ALL_POOLS_PATH = REPO_ROOT / "artifacts" / "all-pools-status.json"
HELIX_STATE_PATH = REPO_ROOT / "dashboard" / "helix-state.json"
HELIX_API_URL = "http://127.0.0.1:8080/api/helix/status"

FUSION_SUCCESS_MESSAGE = (
    "Heaven-Earth fusion sync OK — helix tick merged into shared-state"
)


def _iso_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _read_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f"{json.dumps(payload, indent=2)}\n", encoding="utf-8")


def map_earth_state(
    massive: dict[str, Any],
    pools: dict[str, Any],
) -> dict[str, Any]:
    """Map physical/edge artifacts into heavenEarth.earth."""
    energy = massive.get("energy") or {}
    fleet = massive.get("miningFleet") or {}
    provider_blockers = list(massive.get("blockers") or [])
    wallet_blockers = list(fleet.get("walletBlockers") or [])
    blockers = provider_blockers + wallet_blockers

    return {
        "localXmr": bool(pools.get("localXmr", fleet.get("localXmr", False))),
        "poolsRunning": int(pools.get("poolsRunning", 0)),
        "cloudVmsPlanned": int(massive.get("cloudVmsPlanned", 0)),
        "solarSurplusKw": float(energy.get("solarSurplusKw", 0)),
        "hydroOnline": bool(energy.get("hydroOnline", False)),
        "blockers": blockers,
        "lastSyncAt": massive.get("updatedAt") or pools.get("updatedAt") or _iso_now(),
    }


def _helix_from_file() -> dict[str, Any]:
    state = _read_json(HELIX_STATE_PATH)
    if not state:
        return {}
    return {
        "phase": state.get("phase", "genesis-pending"),
        "activated": bool(state.get("activated", False)),
        "genesisHash": state.get("genesisHash"),
        "yslrPhase": (state.get("yslr") or {}).get("phase", "pending"),
    }


def _helix_from_api(timeout_s: float = 2.0) -> dict[str, Any]:
    try:
        req = urllib.request.Request(HELIX_API_URL, method="GET")
        with urllib.request.urlopen(req, timeout=timeout_s) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError):
        return {}


def build_helix_tick(
    earth: dict[str, Any],
    *,
    prior_tick: int = 0,
    helix_api: dict[str, Any] | None = None,
    helix_file: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Compose heavenEarth.helix snapshot from live helix sources + earth context."""
    api = helix_api if helix_api is not None else _helix_from_api()
    file_state = helix_file if helix_file is not None else _helix_from_file()

    phase = api.get("phase") or file_state.get("phase") or "genesis-pending"
    activated = bool(api.get("activated", file_state.get("activated", False)))
    readiness = api.get("readinessScore") or "0/8"

    return {
        "tick": prior_tick + 1,
        "phase": phase,
        "activated": activated,
        "readinessScore": readiness,
        "genesisHash": api.get("genesisHash") or file_state.get("genesisHash"),
        "yslrPhase": (api.get("yslr") or {}).get("phase") or file_state.get("yslrPhase"),
        "earthPoolsRunning": earth.get("poolsRunning", 0),
        "earthLocalXmr": earth.get("localXmr", False),
        "earthBlockerCount": len(earth.get("blockers") or []),
        "lastTickAt": _iso_now(),
        "source": "helix_bridge",
        "liveApi": bool(api),
    }


def load_shared_state() -> dict[str, Any]:
    state = _read_json(SHARED_STATE_PATH)
    heaven_earth = state.setdefault("heavenEarth", {})
    heaven_earth.setdefault("earth", {})
    heaven_earth.setdefault("helix", {})
    heaven_earth.setdefault("handoffBus", {})
    return state


def fusion_sync(
    *,
    fetch_api: bool = True,
) -> dict[str, Any]:
    """
    Read earth artifacts, build helix tick, merge into shared-state.
    Updates handoffBus when fusion sync succeeds.
    """
    massive = _read_json(MASSIVE_STACK_PATH)
    pools = _read_json(ALL_POOLS_PATH)
    earth = map_earth_state(massive, pools)

    shared = load_shared_state()
    prior_tick = int((shared.get("heavenEarth") or {}).get("helix", {}).get("tick", 0))

    helix_api = _helix_from_api() if fetch_api else {}
    helix_file = _helix_from_file()
    helix = build_helix_tick(
        earth,
        prior_tick=prior_tick,
        helix_api=helix_api,
        helix_file=helix_file,
    )

    now = _iso_now()
    shared["updatedAt"] = now
    shared["heavenEarth"]["earth"] = earth
    shared["heavenEarth"]["helix"] = helix
    shared["heavenEarth"]["handoffBus"] = {
        "synced": True,
        "lastMessage": FUSION_SUCCESS_MESSAGE,
        "lastSyncAt": now,
        "earthBlockers": earth.get("blockers") or [],
        "helixTick": helix.get("tick"),
    }

    _write_json(SHARED_STATE_PATH, shared)
    return shared


def main() -> int:
    try:
        result = fusion_sync()
        tick = result["heavenEarth"]["helix"]["tick"]
        print(f"[helix_bridge] fusion sync OK tick={tick}")
        print(result["heavenEarth"]["handoffBus"]["lastMessage"])
        return 0
    except Exception as exc:
        print(f"[helix_bridge] fusion sync failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
