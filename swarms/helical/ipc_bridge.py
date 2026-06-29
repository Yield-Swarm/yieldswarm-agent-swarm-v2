"""Helical IPC bridge — cross-swarm state bus (mining yields, runic levels, driving telemetry)."""

from __future__ import annotations

import asyncio
import json
import os
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path
from typing import Any, Callable, Awaitable

try:
    import redis.asyncio as aioredis
except ImportError:
    aioredis = None  # type: ignore


class SwarmId(str, Enum):
    PHYSICAL_CORE = "physical-core"
    MINING_POOLS = "mining-pools"
    COSMIC_ONBOARDING = "cosmic-onboarding"
    MESH_ENGINE = "mesh-engine"


CHANNEL_PREFIX = "yieldswarm:helical"
HEARTBEAT_SECONDS = int(os.environ.get("HELICAL_HEARTBEAT_SECONDS", "420"))


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass
class HelicalEnvelope:
    swarm_id: SwarmId
    epoch: int
    phase: int
    message_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    correlation_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    emitted_at: str = field(default_factory=_utc_now)
    site_id: str = "carrizozo-nm-10ac"
    treasury_split: str = "50,30,15,5"
    payload: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "schemaVersion": "helical-envelope/v1",
            "swarmId": self.swarm_id.value,
            "epoch": self.epoch,
            "phase": self.phase,
            "messageId": self.message_id,
            "correlationId": self.correlation_id,
            "emittedAt": self.emitted_at,
            "siteId": self.site_id,
            "treasurySplit": self.treasury_split,
            "payload": self.payload,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "HelicalEnvelope":
        return cls(
            swarm_id=SwarmId(data["swarmId"]),
            epoch=int(data["epoch"]),
            phase=int(data["phase"]),
            message_id=data.get("messageId", str(uuid.uuid4())),
            correlation_id=data.get("correlationId", str(uuid.uuid4())),
            emitted_at=data.get("emittedAt", _utc_now()),
            site_id=data.get("siteId", "carrizozo-nm-10ac"),
            treasury_split=data.get("treasurySplit", "50,30,15,5"),
            payload=data.get("payload", {}),
        )


Handler = Callable[[HelicalEnvelope], Awaitable[None] | None]


class IPCBridge:
    """Redis-backed pub/sub with file fallback for local dev."""

    def __init__(
        self,
        redis_url: str | None = None,
        fallback_dir: Path | None = None,
    ) -> None:
        self.redis_url = redis_url or os.environ.get("REDIS_URL", "redis://localhost:6379/0")
        self.fallback_dir = fallback_dir or Path(os.environ.get("IPC_FALLBACK_DIR", ".data/ipc"))
        self.fallback_dir.mkdir(parents=True, exist_ok=True)
        self._redis: Any = None
        self._handlers: dict[str, list[Handler]] = {}
        self._epoch = 0
        self._lock = asyncio.Lock()

    async def connect(self) -> None:
        if aioredis is None:
            return
        try:
            self._redis = aioredis.from_url(self.redis_url, decode_responses=True)
            await self._redis.ping()
        except Exception:
            self._redis = None

    async def close(self) -> None:
        if self._redis:
            await self._redis.aclose()

    def _channel(self, swarm_id: SwarmId | str) -> str:
        sid = swarm_id.value if isinstance(swarm_id, SwarmId) else swarm_id
        return f"{CHANNEL_PREFIX}:{sid}"

    def subscribe(self, swarm_id: SwarmId, handler: Handler) -> None:
        key = swarm_id.value
        self._handlers.setdefault(key, []).append(handler)

    async def publish(self, envelope: HelicalEnvelope) -> dict[str, Any]:
        data = envelope.to_dict()
        raw = json.dumps(data)
        if self._redis:
            await self._redis.publish(self._channel(envelope.swarm_id), raw)
            await self._redis.set(f"{CHANNEL_PREFIX}:latest:{envelope.swarm_id.value}", raw)
        else:
            path = self.fallback_dir / f"latest-{envelope.swarm_id.value}.json"
            path.write_text(json.dumps(data, indent=2), encoding="utf-8")
        for handler in self._handlers.get(envelope.swarm_id.value, []):
            result = handler(envelope)
            if asyncio.iscoroutine(result):
                await result
        return data

    async def get_latest(self, swarm_id: SwarmId) -> dict[str, Any] | None:
        if self._redis:
            raw = await self._redis.get(f"{CHANNEL_PREFIX}:latest:{swarm_id.value}")
            return json.loads(raw) if raw else None
        path = self.fallback_dir / f"latest-{swarm_id.value}.json"
        return json.loads(path.read_text()) if path.exists() else None

    async def spiral_tick(self) -> HelicalEnvelope:
        """Deterministic helical rotation: physical → mining → cosmic → mesh."""
        async with self._lock:
            self._epoch += 1
            phase = (self._epoch - 1) % 4
        order = [
            SwarmId.PHYSICAL_CORE,
            SwarmId.MINING_POOLS,
            SwarmId.COSMIC_ONBOARDING,
            SwarmId.MESH_ENGINE,
        ]
        swarm = order[phase]
        prior = await self.get_latest(order[(phase - 1) % 4])
        envelope = HelicalEnvelope(
            swarm_id=swarm,
            epoch=self._epoch,
            phase=phase,
            payload={"priorSwarm": prior, "tickAt": _utc_now()},
        )
        await self.publish(envelope)
        return envelope

    async def relay(
        self,
        source: SwarmId,
        target: SwarmId,
        payload: dict[str, Any],
        *,
        epoch: int | None = None,
    ) -> dict[str, Any]:
        envelope = HelicalEnvelope(
            swarm_id=target,
            epoch=epoch if epoch is not None else self._epoch,
            phase=list(SwarmId).index(target),
            correlation_id=payload.get("correlationId", str(uuid.uuid4())),
            payload={**payload, "relayedFrom": source.value},
        )
        return await self.publish(envelope)

    async def run_listener(self, swarm_id: SwarmId) -> None:
        if not self._redis:
            return
        pubsub = self._redis.pubsub()
        await pubsub.subscribe(self._channel(swarm_id))
        async for message in pubsub.listen():
            if message["type"] != "message":
                continue
            envelope = HelicalEnvelope.from_dict(json.loads(message["data"]))
            for handler in self._handlers.get(swarm_id.value, []):
                result = handler(envelope)
                if asyncio.iscoroutine(result):
                    await result

    async def run_heartbeat_loop(self) -> None:
        await self.connect()
        while True:
            await self.spiral_tick()
            await asyncio.sleep(HEARTBEAT_SECONDS)


async def _main() -> None:
    bridge = IPCBridge()
    await bridge.connect()

    async def on_physical(env: HelicalEnvelope) -> None:
        print(f"[ipc] physical-core epoch={env.epoch}")

    bridge.subscribe(SwarmId.PHYSICAL_CORE, on_physical)
    tick = await bridge.spiral_tick()
    print(json.dumps(tick.to_dict(), indent=2))
    await bridge.close()


if __name__ == "__main__":
    asyncio.run(_main())
