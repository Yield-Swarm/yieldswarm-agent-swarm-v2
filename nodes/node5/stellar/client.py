"""Stellar (XLM) client — wraps stellar-sdk when installed."""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any, Dict, Optional

from nodes.node5.config import StellarConfig


@dataclass
class StellarPaymentResult:
    ok: bool
    dry_run: bool
    tx_hash: Optional[str] = None
    amount: str = "0"
    destination: str = ""
    error: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "ok": self.ok,
            "dry_run": self.dry_run,
            "tx_hash": self.tx_hash,
            "amount": self.amount,
            "destination": self.destination,
            "error": self.error,
        }


class StellarClient:
    """Horizon-backed Stellar operations for Node 5."""

    def __init__(self, config: StellarConfig, *, dry_run: bool = True):
        self.config = config
        self.dry_run = dry_run

    def status(self) -> Dict[str, Any]:
        return {
            "chain": "stellar",
            "network": self.config.network,
            "horizon_url": self.config.horizon_url,
            "public_key": self.config.public_key or None,
            "configured": self.config.configured,
            "dry_run": self.dry_run,
            "sdk_available": self._sdk_available(),
        }

    def get_balance(self) -> Dict[str, Any]:
        if not self.config.public_key:
            return {"ok": False, "error": "STELLAR_PUBLIC_KEY not configured", "balance_xlm": 0.0}

        try:
            url = f"{self.config.horizon_url}/accounts/{self.config.public_key}"
            with urllib.request.urlopen(url, timeout=12) as resp:
                data = json.loads(resp.read().decode())
            balances = data.get("balances", [])
            native = next((b for b in balances if b.get("asset_type") == "native"), None)
            xlm = float(native["balance"]) if native else 0.0
            return {
                "ok": True,
                "public_key": self.config.public_key,
                "balance_xlm": xlm,
                "balances": balances,
            }
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                return {"ok": True, "public_key": self.config.public_key, "balance_xlm": 0.0, "funded": False}
            return {"ok": False, "error": f"horizon HTTP {exc.code}", "balance_xlm": 0.0}
        except Exception as exc:  # noqa: BLE001
            return {"ok": False, "error": str(exc), "balance_xlm": 0.0}

    def submit_payment(
        self,
        *,
        amount: str,
        destination: Optional[str] = None,
        memo: str = "",
    ) -> StellarPaymentResult:
        dest = destination or self.config.destination
        if not dest:
            return StellarPaymentResult(
                ok=False,
                dry_run=self.dry_run,
                error="destination required (STELLAR_DESTINATION_ADDRESS)",
            )

        if self.dry_run:
            return StellarPaymentResult(
                ok=True,
                dry_run=True,
                amount=amount,
                destination=dest,
                tx_hash="dry-run-stellar-payment",
            )

        if not self.config.configured:
            return StellarPaymentResult(
                ok=False,
                dry_run=False,
                error="STELLAR_SECRET_KEY and STELLAR_PUBLIC_KEY required for live payments",
            )

        try:
            tx_hash = self._submit_via_sdk(amount=amount, destination=dest, memo=memo)
            return StellarPaymentResult(
                ok=True,
                dry_run=False,
                amount=amount,
                destination=dest,
                tx_hash=tx_hash,
            )
        except Exception as exc:  # noqa: BLE001
            return StellarPaymentResult(ok=False, dry_run=False, error=str(exc))

    def _sdk_available(self) -> bool:
        try:
            import stellar_sdk  # noqa: F401

            return True
        except ImportError:
            return False

    def _submit_via_sdk(self, *, amount: str, destination: str, memo: str) -> str:
        from stellar_sdk import Keypair, Network, Server, TransactionBuilder, Asset

        server = Server(self.config.horizon_url)
        source = Keypair.from_secret(self.config.secret_key)
        account = server.load_account(source.public_key)

        network_passphrase = (
            Network.TESTNET_NETWORK_PASSPHRASE
            if self.config.network == "testnet"
            else Network.PUBLIC_NETWORK_PASSPHRASE
        )

        tx = (
            TransactionBuilder(
                source_account=account,
                network_passphrase=network_passphrase,
                base_fee=100,
            )
            .append_payment_op(destination=destination, amount=amount, asset=Asset.native())
            .set_timeout(30)
        )
        if memo:
            tx = tx.add_text_memo(memo[:28])

        built = tx.build()
        built.sign(source)
        response = server.submit_transaction(built)
        return response.get("hash", "")
