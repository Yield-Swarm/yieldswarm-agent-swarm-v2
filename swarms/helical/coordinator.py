#!/usr/bin/env python3
"""Helical coordinator — runs spiral IPC loop across all 4 swarms."""

from __future__ import annotations

import asyncio
import json
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO))

from swarms.helical.ipc_bridge import HelicalEnvelope, IPCBridge, SwarmId
from swarms.physical_core.engines.telemetry_engine import PhysicalCoreTelemetryEngine
from swarms.mining_pools.engines.pool_switcher import PoolSwitcher
from swarms.mining_pools.engines.marketing_circuit_breaker import MarketingCircuitBreaker
from swarms.mining_pools.integrations.alchemy_solana import AlchemySolanaPipeline
from swarms.cosmic_onboarding.engines.onboarding_service import CosmicOnboardingService
from swarms.mesh_engine.engines.mesh_service import MeshEngineService


async def main() -> None:
    bridge = IPCBridge()
    await bridge.connect()

    physical = PhysicalCoreTelemetryEngine()
    mining = PoolSwitcher()
    breaker = MarketingCircuitBreaker()
    alchemy = AlchemySolanaPipeline()
    cosmic = CosmicOnboardingService()
    mesh = MeshEngineService()

    physical_snap = physical.capture_snapshot()
    mining_state = mining.tick(physical_snap)
    breaker_state = breaker.check_health(mining_state)
    alchemy_state = alchemy.ingest_treasury(os.environ.get("TREASURY_SOLANA_ADDRESS", ""))

    await bridge.publish(
        HelicalEnvelope(swarm_id=SwarmId.PHYSICAL_CORE, epoch=1, phase=0, payload=physical_snap)
    )
    await bridge.publish(
        HelicalEnvelope(
            swarm_id=SwarmId.MINING_POOLS,
            epoch=1,
            phase=1,
            payload={**mining_state, "circuitBreaker": breaker_state, "alchemy": alchemy_state},
        )
    )
    cosmic_state = {
        "schemaVersion": "cosmic-onboarding/v1",
        "activeUsers": 0,
        "deityCount": 169,
        "houseCount": 24,
    }
    await bridge.publish(
        HelicalEnvelope(swarm_id=SwarmId.COSMIC_ONBOARDING, epoch=1, phase=2, payload=cosmic_state)
    )
    mesh_state = await mesh.ingest_helical(
        {"payload": {"priorSwarm": {"swarmId": "physical-core", "payload": physical_snap}}}
    )
    await bridge.publish(
        HelicalEnvelope(swarm_id=SwarmId.MESH_ENGINE, epoch=1, phase=3, payload=mesh_state)
    )

    tick = await bridge.spiral_tick()
    print(json.dumps({"coordinator": "ok", "spiral": tick.to_dict()}, indent=2))
    await bridge.close()


if __name__ == "__main__":
    asyncio.run(main())
