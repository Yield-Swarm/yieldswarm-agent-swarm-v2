"""Mining fleet registry — Azure, Akash, and local instances."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from mining.auth import MiningAuthService


@dataclass
class FleetInstance:
    id: str
    provider: str  # azure | akash | local
    region: str = ""
    miners: List[str] = field(default_factory=list)
    wallet_scope: List[str] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "provider": self.provider,
            "region": self.region,
            "miners": self.miners,
            "wallet_scope": self.wallet_scope,
        }


def _parse_fleet(raw: str) -> List[FleetInstance]:
    if not raw or raw.strip() in ("", "[]"):
        return _default_fleet()
    try:
        items = json.loads(raw)
    except json.JSONDecodeError:
        return _default_fleet()

    fleet: List[FleetInstance] = []
    for i, row in enumerate(items if isinstance(items, list) else []):
        if not isinstance(row, dict):
            continue
        fleet.append(
            FleetInstance(
                id=row.get("id", f"{row.get('provider', 'node')}-{i + 1}"),
                provider=row.get("provider", "local"),
                region=row.get("region", os.getenv("AZURE_REGION", "us-central")),
                miners=row.get("miners", []),
                wallet_scope=row.get("wallet_scope", []),
            )
        )
    return fleet or _default_fleet()


def _default_fleet() -> List[FleetInstance]:
    """Sensible defaults when MINING_FLEET_INSTANCES unset."""
    instances: List[FleetInstance] = []

    if os.getenv("AKASH_OWNER_ADDRESS") or os.getenv("USE_VAULT_AKASH"):
        instances.append(
            FleetInstance(
                id="akash-gpu-1",
                provider="akash",
                region="global",
                miners=["bittensor"],
                wallet_scope=["tao"],
            )
        )

    if os.getenv("AZURE_CLIENT_ID") or os.getenv("AZURE_SUBSCRIPTION_ID"):
        instances.append(
            FleetInstance(
                id="azure-cpu-1",
                provider="azure",
                region=os.getenv("AZURE_REGION", "eastus"),
                miners=["monero", "etc"],
                wallet_scope=["xmr", "etc"],
            )
        )

    instances.append(
        FleetInstance(
            id="local-depin-1",
            provider="local",
            region="hq",
            miners=["grass", "helium"],
            wallet_scope=["grass", "helium"],
        )
    )

    return instances


class FleetRegistry:
    def __init__(self, auth: Optional[MiningAuthService] = None):
        self.auth = auth or MiningAuthService()
        self.instances = _parse_fleet(os.getenv("MINING_FLEET_INSTANCES", ""))

    def connect_all(self) -> Dict[str, Any]:
        """Authorize and issue tokens for each fleet instance."""
        ctx = self.auth.bootstrap_context()
        if not ctx.ok:
            return {"ok": False, "error": ctx.error, "auth": ctx.to_dict()}

        connected = []
        for inst in self.instances:
            try:
                token = self.auth.issue_token(inst.id, inst.provider)
                connected.append({**inst.to_dict(), "token_issued": True, "token_preview": token[:16] + "..."})
            except Exception as exc:  # noqa: BLE001
                connected.append({**inst.to_dict(), "token_issued": False, "error": str(exc)})

        return {
            "ok": True,
            "auth": ctx.to_dict(),
            "instance_count": len(connected),
            "instances": connected,
        }

    def miners_for_provider(self, provider: str) -> List[str]:
        names: List[str] = []
        for inst in self.instances:
            if inst.provider == provider:
                names.extend(inst.miners)
        return sorted(set(names))

    def status(self) -> Dict[str, Any]:
        return {
            "instances": [i.to_dict() for i in self.instances],
            "providers": sorted({i.provider for i in self.instances}),
            "total_miners": sorted({m for i in self.instances for m in i.miners}),
        }
