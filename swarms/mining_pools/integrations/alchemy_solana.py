"""Alchemy Solana enterprise grant pipeline — on-chain tx indexing with budget tracking."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from datetime import datetime, timezone
from typing import Any


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


class AlchemySolanaPipeline:
    """Pull Solana mainnet data via Alchemy; track $25k grant consumption."""

    def __init__(self) -> None:
        self.api_key = os.environ.get("ALCHEMY_API_KEY", "")
        self.grant_balance = float(os.environ.get("ALCHEMY_SOL_GRANT_BALANCE", "25000"))
        self.rpc_url = os.environ.get(
            "ALCHEMY_SOLANA_RPC_URL",
            f"https://solana-mainnet.g.alchemy.com/v2/{self.api_key}" if self.api_key else "",
        )
        self._cu_used = float(os.environ.get("ALCHEMY_CU_USED_ESTIMATE", "0"))

    def _rpc(self, method: str, params: list[Any] | None = None) -> dict[str, Any]:
        if not self.rpc_url:
            raise EnvironmentError("ALCHEMY_SOLANA_RPC_URL or ALCHEMY_API_KEY required")
        body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params or []}).encode()
        req = urllib.request.Request(
            self.rpc_url,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode())
        if "error" in data:
            raise RuntimeError(data["error"])
        self._cu_used += 1.0
        return data

    def get_slot(self) -> int:
        result = self._rpc("getSlot")
        return int(result["result"])

    def get_signatures(self, address: str, limit: int = 10) -> list[dict[str, Any]]:
        result = self._rpc(
            "getSignaturesForAddress",
            [address, {"limit": limit}],
        )
        return result.get("result", [])

    def ingest_treasury(self, treasury_address: str) -> dict[str, Any]:
        if not treasury_address:
            treasury_address = os.environ.get("TREASURY_SOLANA_ADDRESS", "")
        signatures: list[dict[str, Any]] = []
        if treasury_address:
            try:
                signatures = self.get_signatures(treasury_address, limit=25)
            except (urllib.error.URLError, RuntimeError, OSError):
                signatures = []
        remaining = max(0.0, self.grant_balance - self._cu_used * 0.0001)
        return {
            "schemaVersion": "alchemy-solana/v1",
            "capturedAt": _utc_now(),
            "slot": self.get_slot() if self.rpc_url else 0,
            "treasuryAddress": treasury_address,
            "recentSignatures": len(signatures),
            "signatures": signatures[:5],
            "grantBalanceUsd": self.grant_balance,
            "cuUsedEstimate": self._cu_used,
            "grantRemainingUsd": round(remaining, 2),
        }
