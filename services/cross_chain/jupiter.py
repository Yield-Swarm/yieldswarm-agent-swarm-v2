"""Jupiter aggregator client — quote + swap transaction build (Solana MVP)."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

DEFAULT_JUPITER_BASE = "https://quote-api.jup.ag/v6"
SOL_MINT = "So11111111111111111111111111111111111111112"
USDC_MINT = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"


class JupiterClient:
    def __init__(
        self,
        *,
        base_url: str | None = None,
        api_key: str | None = None,
        slippage_bps: int | None = None,
    ) -> None:
        self.base_url = (base_url or os.getenv("JUPITER_API_URL") or DEFAULT_JUPITER_BASE).rstrip("/")
        self.api_key = api_key or os.getenv("JUPITER_API_KEY")
        self.slippage_bps = slippage_bps if slippage_bps is not None else int(os.getenv("SLIPPAGE_TOLERANCE", "50"))

    def _headers(self) -> dict[str, str]:
        headers = {"Accept": "application/json"}
        if self.api_key:
            headers["x-api-key"] = self.api_key
        return headers

    def quote(
        self,
        *,
        input_mint: str,
        output_mint: str,
        amount: int,
        swap_mode: str = "ExactIn",
    ) -> dict[str, Any]:
        params = urllib.parse.urlencode(
            {
                "inputMint": input_mint,
                "outputMint": output_mint,
                "amount": str(amount),
                "slippageBps": str(self.slippage_bps),
                "swapMode": swap_mode,
            }
        )
        url = f"{self.base_url}/quote?{params}"
        request = urllib.request.Request(url, headers=self._headers(), method="GET")
        try:
            with urllib.request.urlopen(request, timeout=12) as response:
                body = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            return {"ok": False, "error": f"HTTP {exc.code}", "detail": detail}
        except Exception as exc:  # noqa: BLE001
            return {"ok": False, "error": str(exc)}

        out_amount = int(body.get("outAmount") or 0)
        in_amount = int(body.get("inAmount") or amount)
        price_impact = float(body.get("priceImpactPct") or 0)
        return {
            "ok": True,
            "provider": "jupiter",
            "input_mint": input_mint,
            "output_mint": output_mint,
            "in_amount": in_amount,
            "out_amount": out_amount,
            "price_impact_pct": price_impact,
            "route_plan_steps": len(body.get("routePlan") or []),
            "quote": body,
        }

    def build_swap(
        self,
        *,
        quote: dict[str, Any],
        user_public_key: str,
        dry_run: bool = True,
    ) -> dict[str, Any]:
        if dry_run:
            return {
                "ok": True,
                "status": "dry_run",
                "provider": "jupiter",
                "user_public_key": user_public_key,
                "message": "Swap transaction not broadcast — dry_run=true",
            }

        payload = {
            "quoteResponse": quote.get("quote") or quote,
            "userPublicKey": user_public_key,
            "wrapAndUnwrapSol": True,
        }
        request = urllib.request.Request(
            f"{self.base_url}/swap",
            data=json.dumps(payload).encode("utf-8"),
            headers={**self._headers(), "Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                body = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            return {"ok": False, "error": f"HTTP {exc.code}", "detail": detail}
        except Exception as exc:  # noqa: BLE001
            return {"ok": False, "error": str(exc)}

        return {"ok": True, "status": "built", "provider": "jupiter", "swap": body}


def jupiter_health() -> dict[str, Any]:
    client = JupiterClient()
    configured = bool(client.api_key or os.getenv("SOLANA_RPC_URL"))
    probe = client.quote(input_mint=SOL_MINT, output_mint=USDC_MINT, amount=1_000_000)
    return {
        "service": "jupiter",
        "configured": configured,
        "live": probe.get("ok") is True,
        "base_url": client.base_url,
        "slippage_bps": client.slippage_bps,
    }
