"""Dynamic multi-pool switcher — Akash cloud PoUW + ranch Z15 Equihash."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any


NETWORKS = {
    "PRL": {"name": "Pearl", "work_type": "pouw", "cloud": "akash", "algorithm": "ProgPowZ"},
    "KRX": {"name": "Keryx", "work_type": "pouw", "cloud": "akash", "algorithm": "BlockDAG"},
    "ZANO": {"name": "Zano", "work_type": "pouw", "cloud": "akash", "algorithm": "ProgPowZ"},
    "QTC": {"name": "Qitcoin", "work_type": "pouw", "cloud": "akash", "algorithm": "Qhash"},
    "IRON": {"name": "Iron Fish", "work_type": "pouw", "cloud": "akash", "algorithm": "FishHash"},
    "TON": {"name": "TON", "work_type": "pouw", "cloud": "akash", "algorithm": "ton"},
    "ZEC": {"name": "Zcash", "work_type": "equihash", "cloud": "ranch", "algorithm": "equihash"},
}


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass
class PoolQuote:
    network: str
    estimated_usd_per_day: float
    hashrate_unit: str
    source: str


class PoolSwitcher:
    """Profitability matrix + automatic pool rotation."""

    def __init__(self) -> None:
        self.whattomine_url = os.environ.get("WHATTOMINE_API_URL", "")
        self.active_network = os.environ.get("MINING_ACTIVE_NETWORK", "ZEC")
        self.ranch_only = os.environ.get("MINING_RANCH_NETWORKS", "ZEC").split(",")
        self.akash_networks = os.environ.get("MINING_AKASH_NETWORKS", "PRL,KRX,ZANO,QTC,IRON,TON").split(",")
        self.disable_runpod = os.environ.get("DISABLE_RUNPOD_MINING", "true").lower() in ("1", "true", "yes")
        self.route_cloud = os.environ.get("ROUTE_CLOUD_COMPUTE_TO", "CHERRY_SERVERS_BARE_METAL")

    def _fetch_json(self, url: str) -> dict[str, Any] | None:
        if not url:
            return None
        try:
            with urllib.request.urlopen(url, timeout=15) as resp:
                return json.loads(resp.read().decode())
        except (urllib.error.URLError, json.JSONDecodeError, OSError):
            return None

    def quote_network(self, symbol: str) -> PoolQuote:
        meta = NETWORKS.get(symbol, {})
        base = float(os.environ.get(f"MINING_QUOTE_USD_{symbol}", "0") or 0)
        solar_kw = float(os.environ.get("SOLAR_YIELD_WATTS", "0") or 0) / 1000.0
        if symbol == "ZEC" and solar_kw > 0:
            base += solar_kw * 0.15
        return PoolQuote(
            network=symbol,
            estimated_usd_per_day=round(base, 4),
            hashrate_unit="GH/s" if meta.get("algorithm") == "equihash" else "H/s",
            source="ranch" if symbol in self.ranch_only else self.route_cloud,
        )

    def rank_pools(self) -> list[PoolQuote]:
        symbols = list(NETWORKS.keys())
        quotes = [self.quote_network(s) for s in symbols]
        return sorted(quotes, key=lambda q: q.estimated_usd_per_day, reverse=True)

    def select_best(self) -> dict[str, Any]:
        ranked = self.rank_pools()
        best = ranked[0]
        prev = self.active_network
        self.active_network = best.network
        return {
            "schemaVersion": "mining-pools/v1",
            "capturedAt": _utc_now(),
            "previousNetwork": prev,
            "activeNetwork": best.network,
            "activeQuoteUsdDay": best.estimated_usd_per_day,
            "route": best.source,
            "ranked": [
                {"network": q.network, "usdDay": q.estimated_usd_per_day, "source": q.source}
                for q in ranked[:5]
            ],
            "akashNetworks": [s.strip() for s in self.akash_networks if s.strip()],
            "ranchNetworks": [s.strip() for s in self.ranch_only if s.strip()],
            "disableRunpodMining": self.disable_runpod,
        }

    def tick(self, physical_payload: dict[str, Any] | None = None) -> dict[str, Any]:
        if physical_payload:
            solar = physical_payload.get("solar", {})
            watts = float(solar.get("productionKw", 0)) * 1000
            os.environ["SOLAR_YIELD_WATTS"] = str(watts)
            asics = physical_payload.get("asics", {})
            os.environ["MINING_QUOTE_USD_ZEC"] = str(
                float(asics.get("aggregateHashrateGh", 0)) * 0.012
            )
        state = self.select_best()
        split = [0.5, 0.3, 0.15, 0.05]
        est = state["activeQuoteUsdDay"]
        state["attribution"] = {
            "treasurySplit": "50,30,15,5",
            "estimatedUsd24h": est,
            "coreTreasuryUsd": round(est * split[0], 4),
            "growthTreasuryUsd": round(est * split[1], 4),
            "insuranceTreasuryUsd": round(est * split[2], 4),
            "opsTreasuryUsd": round(est * split[3], 4),
        }
        if physical_payload:
            state["physicalCoreRef"] = {
                "aggregateHashrateGh": physical_payload.get("asics", {}).get("aggregateHashrateGh"),
                "solarProductionKw": physical_payload.get("solar", {}).get("productionKw"),
            }
        return state
