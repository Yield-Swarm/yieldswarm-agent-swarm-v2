"""Route users to 169 deity factions via plotra.xyz agent IDs."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[3]
DEITY_DIR = REPO_ROOT / "agents" / "system" / "manifests" / "deities"
PLOTRA_BASE = os.environ.get("PLOTRA_AGENT_BASE_URL", "https://plotra.xyz/agent")


class DeityRouter:
    """Deterministic deity assignment from user identity + house."""

    DEITY_COUNT = 169

    def __init__(self, deity_dir: Path | None = None) -> None:
        self.deity_dir = deity_dir or DEITY_DIR
        self._cache: dict[str, dict[str, Any]] = {}

    def _load_manifest(self, deity_id: str) -> dict[str, Any]:
        if deity_id in self._cache:
            return self._cache[deity_id]
        path = self.deity_dir / f"{deity_id}.json"
        if not path.exists():
            return {"manifest_id": deity_id, "domain": "unknown"}
        data = json.loads(path.read_text(encoding="utf-8"))
        data["plotra_agent_id"] = f"{PLOTRA_BASE}/{deity_id}"
        self._cache[deity_id] = data
        return data

    def deity_index(self, user_key: str, house_id: int) -> int:
        digest = hashlib.sha256(f"{user_key}:{house_id}".encode()).hexdigest()
        return int(digest[:8], 16) % self.DEITY_COUNT + 1

    def assign(self, user_key: str, house_id: int) -> dict[str, Any]:
        idx = self.deity_index(user_key, house_id)
        deity_id = f"sod-{idx:03d}"
        manifest = self._load_manifest(deity_id)
        clan_id = f"clan-{manifest.get('vector', 'helix')}-{house_id:02d}"
        return {
            "deityId": deity_id,
            "deityManifest": manifest.get("manifest_id", deity_id),
            "domain": manifest.get("domain", "alpha-oracle"),
            "metalSkin": manifest.get("metal_skin", "quartz-steel"),
            "plotraAgentId": manifest.get("plotra_agent_id"),
            "factionClanId": clan_id,
            "heartbeatSeconds": manifest.get("heartbeat_interval_seconds", 420),
        }
