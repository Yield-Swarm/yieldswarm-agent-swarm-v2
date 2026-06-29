"""Pro-rata yield distribution weighted by Runic Level and infra referrals."""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any


@dataclass
class YieldParticipant:
    user_id: str
    runic_level: int
    runic_xp: float
    referred_infra_usd: float
    leased_hardware_hashrate: float


class RunicYieldDistributor:
    """Split pool rewards by runic weight + infra contribution."""

    def weight(self, p: YieldParticipant) -> float:
        runic = math.log1p(p.runic_level) * (1.0 + p.runic_xp / 1e6)
        infra = math.sqrt(max(0.0, p.referred_infra_usd)) * 0.5
        hardware = math.log1p(max(0.0, p.leased_hardware_hashrate)) * 0.3
        return runic + infra + hardware

    def distribute(
        self,
        pool_usd: float,
        participants: list[YieldParticipant],
        *,
        treasury_split: str = "50,30,15,5",
    ) -> dict[str, Any]:
        weights = [self.weight(p) for p in participants]
        total = sum(weights) or 1.0
        bps = [int(x) for x in treasury_split.split(",")]
        split_frac = [b / sum(bps) for b in bps]
        allocations = []
        for p, w in zip(participants, weights):
            share = (w / total) * pool_usd
            allocations.append(
                {
                    "userId": p.user_id,
                    "runicLevel": p.runic_level,
                    "weight": round(w, 6),
                    "shareUsd": round(share, 4),
                    "sharePct": round(100.0 * w / total, 4),
                }
            )
        return {
            "schemaVersion": "runic-yield/v1",
            "poolUsd": pool_usd,
            "treasurySplit": treasury_split,
            "treasuryBuckets": {
                "coreTreasuryUsd": round(pool_usd * split_frac[0], 4),
                "growthTreasuryUsd": round(pool_usd * split_frac[1], 4),
                "insuranceTreasuryUsd": round(pool_usd * split_frac[2], 4),
                "opsTreasuryUsd": round(pool_usd * split_frac[3], 4),
            },
            "participantCount": len(participants),
            "allocations": sorted(allocations, key=lambda a: a["shareUsd"], reverse=True),
        }
