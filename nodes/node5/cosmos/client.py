"""Cosmos SDK REST client for Node 5 (Akash and compatible chains)."""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any, Dict, Optional

from nodes.node5.config import CosmosConfig


@dataclass
class CosmosTxResult:
    ok: bool
    dry_run: bool
    tx_hash: Optional[str] = None
    amount: str = "0"
    denom: str = ""
    recipient: str = ""
    error: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "ok": self.ok,
            "dry_run": self.dry_run,
            "tx_hash": self.tx_hash,
            "amount": self.amount,
            "denom": self.denom,
            "recipient": self.recipient,
            "error": self.error,
        }


class CosmosClient:
    """Lightweight Cosmos bank-module client (no signing without cosmpy)."""

    def __init__(self, config: CosmosConfig, *, dry_run: bool = True):
        self.config = config
        self.dry_run = dry_run

    def status(self) -> Dict[str, Any]:
        return {
            "chain": "cosmos",
            "chain_id": self.config.chain_id,
            "rest_url": self.config.rest_url,
            "address": self.config.address or None,
            "configured": self.config.configured,
            "dry_run": self.dry_run,
            "cosmpy_available": self._cosmpy_available(),
        }

    def get_balance(self) -> Dict[str, Any]:
        if not self.config.address:
            return {"ok": False, "error": "COSMOS_ADDRESS not configured", "balance": 0.0}

        try:
            path = f"/cosmos/bank/v1beta1/balances/{self.config.address}"
            data = self._get(path)
            balances = data.get("balances", [])
            match = next((b for b in balances if b.get("denom") == self.config.denom), None)
            raw = int(match["amount"]) if match else 0
            # uakt → AKT (6 decimals)
            display = raw / 1_000_000 if self.config.denom == "uakt" else float(raw)
            return {
                "ok": True,
                "address": self.config.address,
                "denom": self.config.denom,
                "balance_raw": raw,
                "balance": display,
                "balances": balances,
            }
        except Exception as exc:  # noqa: BLE001
            return {"ok": False, "error": str(exc), "balance": 0.0}

    def submit_bank_send(
        self,
        *,
        amount: str,
        recipient: str,
        denom: Optional[str] = None,
    ) -> CosmosTxResult:
        use_denom = denom or self.config.denom
        if self.dry_run:
            return CosmosTxResult(
                ok=True,
                dry_run=True,
                amount=amount,
                denom=use_denom,
                recipient=recipient,
                tx_hash="dry-run-cosmos-send",
            )

        if not self.config.mnemonic:
            return CosmosTxResult(
                ok=False,
                dry_run=False,
                error="COSMOS_MNEMONIC required for live Cosmos transactions",
            )

        try:
            tx_hash = self._submit_via_cosmpy(amount=amount, recipient=recipient, denom=use_denom)
            return CosmosTxResult(
                ok=True,
                dry_run=False,
                amount=amount,
                denom=use_denom,
                recipient=recipient,
                tx_hash=tx_hash,
            )
        except ImportError:
            return CosmosTxResult(
                ok=False,
                dry_run=False,
                error="cosmpy not installed — pip install cosmpy for live Cosmos txs",
            )
        except Exception as exc:  # noqa: BLE001
            return CosmosTxResult(ok=False, dry_run=False, error=str(exc))

    def _get(self, path: str) -> Dict[str, Any]:
        url = f"{self.config.rest_url}{path}"
        with urllib.request.urlopen(url, timeout=12) as resp:
            return json.loads(resp.read().decode())

    def _cosmpy_available(self) -> bool:
        try:
            import cosmpy  # noqa: F401

            return True
        except ImportError:
            return False

    def _submit_via_cosmpy(self, *, amount: str, recipient: str, denom: str) -> str:
        # cosmpy signing is chain-specific; live path enabled when SDK + mnemonic present.
        # Operators extend with chain protobuf types per deployment.
        raise NotImplementedError(
            "Live Cosmos broadcast requires chain-specific cosmpy wiring — use dry_run or extend node5/cosmos/broadcast.py"
        )
