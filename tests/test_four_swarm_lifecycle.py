"""Four-swarm mainnet lifecycle integration tests."""

from __future__ import annotations

import asyncio
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def test_env_template_count():
    text = (REPO / ".env.swarm.example").read_text()
    count = sum(1 for l in text.splitlines() if "=" in l and not l.strip().startswith("#"))
    assert count >= 250, f"expected 250+ vars, got {count}"


def test_physical_core_snapshot():
    from swarms.physical_core.engines.telemetry_engine import PhysicalCoreTelemetryEngine
    snap = PhysicalCoreTelemetryEngine().capture_snapshot()
    assert snap["asics"]["fleetSize"] == 30


def test_pool_switcher():
    from swarms.mining_pools.engines.pool_switcher import PoolSwitcher
    state = PoolSwitcher().tick()
    assert state["attribution"]["treasurySplit"] == "50,30,15,5"


def test_marketing_breaker():
    from swarms.mining_pools.engines.marketing_circuit_breaker import MarketingCircuitBreaker
    b = MarketingCircuitBreaker()
    health = b.check_health({"activeNetwork": "ZEC"})
    assert "healthy" in health


def test_cosmic_onboarding():
    from swarms.cosmic_onboarding.engines.onboarding_service import CosmicOnboardingService
    svc = CosmicOnboardingService()
    result = svc.onboard({
        "email": "test@yieldswarm.io",
        "birthDate": "1990-06-15",
        "birthTime": "14:30:00",
        "birthLatitude": 33.6417,
        "birthLongitude": -105.8772,
    })
    assert 1 <= result["house"]["houseId"] <= 24
    assert result["deity"]["deityId"].startswith("sod-")


def test_mesh_skills():
    from swarms.mesh_engine.engines.skill_progression import SkillProgressionEngine
    eng = SkillProgressionEngine()
    r = eng.ingest_event("player-1", "data_rift")
    assert r["leveledUp"] or r["newLevel"] >= 1


def test_ipc_bridge_spiral():
    async def run():
        from swarms.helical.ipc_bridge import IPCBridge, SwarmId
        bridge = IPCBridge()
        await bridge.connect()
        tick = await bridge.spiral_tick()
        assert tick.swarm_id == SwarmId.PHYSICAL_CORE
        await bridge.close()
    asyncio.run(run())


if __name__ == "__main__":
    test_env_template_count()
    test_physical_core_snapshot()
    test_pool_switcher()
    test_marketing_breaker()
    test_cosmic_onboarding()
    test_mesh_skills()
    test_ipc_bridge_spiral()
    print("all tests passed")
