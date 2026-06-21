"""Partner profit share — Jack the Dab Lad 3%."""

from __future__ import annotations

import os
from typing import Any, Dict, List


DEFAULT_PARTNERS = [
    {"id": "jack", "name": "Jack the Dab Lad", "bps": 300, "wallet_env": "JACK_PROFIT_WALLET"},
    {"id": "zeeve", "name": "Zeeve", "bps": 300, "wallet_env": "ZEEVE_PROFIT_WALLET"},
]


def load_partners() -> List[Dict[str, Any]]:
    partners = []
    for p in DEFAULT_PARTNERS:
        wallet = os.environ.get(p["wallet_env"], "")
        partners.append({**p, "wallet": wallet, "configured": bool(wallet)})
    return partners


def allocate_revenue(total_usd: float) -> Dict[str, Any]:
    partners = load_partners()
    allocations = []
    for p in partners:
        amount = total_usd * (p["bps"] / 10_000)
        allocations.append({**p, "amount_usd": round(amount, 2)})
    partner_total = sum(a["amount_usd"] for a in allocations)
    return {
        "total_usd": total_usd,
        "partner_total_usd": round(partner_total, 2),
        "remainder_usd": round(total_usd - partner_total, 2),
        "allocations": allocations,
    }
