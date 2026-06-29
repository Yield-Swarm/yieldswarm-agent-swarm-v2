"""SWARM 4 orchestrator — mesh + skills + agent training loop."""

from __future__ import annotations

import asyncio
from typing import Any

from swarms.mesh_engine.engines.agent_spawner import AgentSpawner
from swarms.mesh_engine.engines.layer_mesh import LayerMesh
from swarms.mesh_engine.engines.skill_progression import SkillProgressionEngine


class MeshEngineService:
    def __init__(self) -> None:
        self.mesh = LayerMesh()
        self.skills = SkillProgressionEngine()
        self.agents = AgentSpawner()

    async def ingest_helical(self, envelope: dict[str, Any]) -> dict[str, Any]:
        payload = envelope.get("payload", {})
        prior = payload.get("priorSwarm") or {}
        prior_payload = prior.get("payload", prior) if isinstance(prior, dict) else {}

        results: dict[str, Any] = {"mesh": self.mesh.snapshot()}

        if "vehicles" in prior_payload or prior.get("swarmId") == "physical-core":
            vehicles = prior_payload.get("vehicles", [])
            for v in vehicles:
                bridge = v.get("mmorpgBridge", {})
                player_id = v.get("vehicleId", "fleet-anon")
                evt = bridge.get("eventType", "cruise_explore")
                xp = bridge.get("xpDelta", 5.0)
                skill_result = self.skills.ingest_event(player_id, evt, xp)
                mesh_event = {
                    "agentIndex": hash(player_id) % 10080,
                    "eventType": evt,
                    "xpDelta": xp,
                    "source": "physical-core",
                }
                mesh_result = await self.mesh.inject_telemetry(mesh_event)
                train_result = await self.agents.apply_human_telemetry(mesh_event)
                results["lastInteraction"] = {
                    "skill": skill_result,
                    "mesh": mesh_result,
                    "training": train_result,
                }

        if prior.get("swarmId") == "mining-pools" or "activeNetwork" in prior_payload:
            net = prior_payload.get("activeNetwork", "ZEC")
            skill_result = self.skills.ingest_event("treasury", "pool_switch")
            await self.mesh.inject_telemetry(
                {"agentIndex": 0, "eventType": "pool_switch", "source": net}
            )
            results["miningSkill"] = skill_result

        results["agents"] = self.agents.stats()
        return results

    async def run_tick(self) -> dict[str, Any]:
        await self.agents.materialize()
        shard = asyncio.get_event_loop().time() % 120
        await self.agents.heartbeat_shard(int(shard))
        return self.mesh.snapshot()
