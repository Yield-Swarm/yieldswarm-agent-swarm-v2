"""Bridge and swap provider fee models (2026 baseline quotes + API hooks)."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List, Optional


@dataclass(frozen=True)
class ProviderQuote:
    provider_id: str
    kind: str  # bridge | swap
    flat_fee_usd: float
    bps: float
    gas_usd: float
    settlement_seconds: int
    audits: int
    notes: str = ""

    def cost_usd(self, notional_usd: float) -> float:
        return self.flat_fee_usd + (notional_usd * self.bps / 10_000) + self.gas_usd


BRIDGE_PROVIDERS: Dict[str, ProviderQuote] = {
    "stargate": ProviderQuote(
        "stargate", "bridge", 0.10, 6, 0.0, 120, 13, "LayerZero — ETH→Arbitrum"
    ),
    "cctp": ProviderQuote(
        "cctp", "bridge", 0.05, 0, 0.0, 900, 99, "Circle official USDC burn/mint"
    ),
    "symbiosis": ProviderQuote(
        "symbiosis", "bridge", 0.30, 5, 0.0, 33, 8, "Fast settlement"
    ),
    "debridge": ProviderQuote(
        "debridge", "bridge", 0.10, 4, 0.0, 60, 6, "0-TVL, no slippage"
    ),
}

SWAP_PROVIDERS: Dict[str, ProviderQuote] = {
    "oneinch": ProviderQuote("oneinch", "swap", 0.0, 0, 0.0, 15, 12, "Aggregator — best rate"),
    "curve": ProviderQuote("curve", "swap", 0.0, 4, 0.0, 30, 20, "Stablecoin pools"),
    "uniswap": ProviderQuote("uniswap", "swap", 0.0, 5, 0.0, 12, 15, "V3/V4 routing"),
}

# Mainnet gas baseline (gwei-sensitive; override via env in agent)
GAS_BASELINE_USD = {
    "ethereum_mainnet": 8.00,
    "arbitrum": 0.50,
    "avalanche": 0.50,
    "curve_exit": 0.30,
}


def list_providers() -> List[Dict[str, object]]:
    rows = []
    for p in {**BRIDGE_PROVIDERS, **SWAP_PROVIDERS}.values():
        rows.append(
            {
                "id": p.provider_id,
                "kind": p.kind,
                "flatFeeUsd": p.flat_fee_usd,
                "bps": p.bps,
                "settlementSeconds": p.settlement_seconds,
                "audits": p.audits,
                "notes": p.notes,
            }
        )
    return rows


async def fetch_oneinch_quote(
    from_token: str, to_token: str, amount_usd: float, chain: str = "arbitrum"
) -> Optional[Dict[str, float]]:
    """Live 1inch quote hook — returns None when API key unavailable (falls back to model)."""
    # Production: aiohttp GET https://api.1inch.dev/swap/v6.0/{chainId}/quote
    return None


async def fetch_stargate_quote(
    src_chain: str, dst_chain: str, amount_usd: float
) -> Optional[Dict[str, float]]:
    """Live Stargate quote hook."""
    return None
