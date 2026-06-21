"""Solenoid Registry — discover, monitor, and manage all solenoids (521-agent capacity)."""

from __future__ import annotations

import json
import os
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
CONFIG_PATH = REPO_ROOT / "config" / "nexus" / "solenoids.yaml"
STATE_PATH = Path(os.environ.get("NEXUS_REGISTRY_STATE", REPO_ROOT / ".run" / "nexus-registry.json"))
MAX_AGENTS = 521


@dataclass
class SolenoidRecord:
    key: str
    id: int
    name: str
    role: str
    status: str = "unknown"
    endpoint: str | None = None
    last_seen: str | None = None
    agent_count: int = 0
    program: str | None = None
    vault_policy: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class AgentSlot:
    agent_id: str
    solenoid: str
    shard_id: int
    status: str = "registered"
    registered_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


class SolenoidRegistry:
    def __init__(self, config_path: Path | None = None):
        self.config_path = config_path or CONFIG_PATH
        self._config = self._load_config()
        self._state = self._load_state()

    def _load_config(self) -> dict[str, Any]:
        if not self.config_path.is_file():
            return {"max_agents": MAX_AGENTS, "solenoids": {}}
        return yaml.safe_load(self.config_path.read_text(encoding="utf-8")) or {}

    def _load_state(self) -> dict[str, Any]:
        if not STATE_PATH.is_file():
            return {"agents": [], "solenoids": {}}
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))

    def _persist(self) -> None:
        STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
        STATE_PATH.write_text(json.dumps(self._state, indent=2), encoding="utf-8")

    def list_solenoids(self) -> list[SolenoidRecord]:
        cfg = self._config.get("solenoids", {})
        runtime = self._state.get("solenoids", {})
        out: list[SolenoidRecord] = []
        for key, meta in cfg.items():
            live = runtime.get(key, {})
            endpoint_env = meta.get("endpoint_env", "")
            endpoint = os.environ.get(endpoint_env, live.get("endpoint"))
            out.append(
                SolenoidRecord(
                    key=key,
                    id=int(meta.get("id", 0)),
                    name=str(meta.get("name", key)),
                    role=str(meta.get("role", "")),
                    status=live.get("status", "configured"),
                    endpoint=endpoint,
                    last_seen=live.get("last_seen"),
                    agent_count=int(live.get("agent_count", 0)),
                    program=meta.get("program"),
                    vault_policy=meta.get("vault_policy"),
                )
            )
        return out

    def heartbeat(self, solenoid_key: str, *, endpoint: str | None = None, agent_count: int = 0) -> dict[str, Any]:
        now = datetime.now(timezone.utc).isoformat()
        solenoids = self._state.setdefault("solenoids", {})
        row = solenoids.setdefault(solenoid_key, {})
        row["status"] = "online"
        row["last_seen"] = now
        if endpoint:
            row["endpoint"] = endpoint
        row["agent_count"] = agent_count
        self._persist()
        return {"ok": True, "solenoid": solenoid_key, "last_seen": now}

    def register_agent(self, agent_id: str, solenoid: str, shard_id: int) -> AgentSlot:
        agents: list[dict] = self._state.setdefault("agents", [])
        if len(agents) >= int(self._config.get("max_agents", MAX_AGENTS)):
            raise ValueError(f"registry full: max {MAX_AGENTS} agents")
        if any(a.get("agent_id") == agent_id for a in agents):
            raise ValueError(f"agent already registered: {agent_id}")
        slot = AgentSlot(agent_id=agent_id, solenoid=solenoid, shard_id=shard_id)
        agents.append(asdict(slot))
        self._persist()
        return slot

    def agent_count(self) -> int:
        return len(self._state.get("agents", []))

    def summary(self) -> dict[str, Any]:
        return {
            "max_agents": int(self._config.get("max_agents", MAX_AGENTS)),
            "registered_agents": self.agent_count(),
            "solenoids": [s.to_dict() for s in self.list_solenoids()],
            "treasury_manifest": str(self._config.get("treasury_manifest", "")),
        }
