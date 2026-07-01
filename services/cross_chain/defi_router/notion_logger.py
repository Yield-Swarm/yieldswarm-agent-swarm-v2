"""Notion treasury logger — audit trail for every routed transaction."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from services.cross_chain.defi_router.models import NotionTxLog, RoutePlan, SimulationReport

NOTION_VERSION = "2022-06-28"


class NotionTreasuryLogger:
    """Logs DeFiRouter steps to a Notion database (Vault: NOTION_API_KEY)."""

    def __init__(
        self,
        api_key: Optional[str] = None,
        database_id: Optional[str] = None,
    ):
        self.api_key = api_key or os.getenv("NOTION_API_KEY", "")
        self.database_id = database_id or os.getenv("NOTION_TREASURY_DATABASE_ID", "")

    @property
    def configured(self) -> bool:
        return bool(self.api_key and self.database_id)

    def log_simulation(self, report: SimulationReport) -> Optional[Dict[str, Any]]:
        """Write simulation summary row to Notion."""
        if not self.configured:
            return {"skipped": True, "reason": "NOTION_API_KEY or NOTION_TREASURY_DATABASE_ID unset"}

        best = report.best_route
        props = {
            "Name": {"title": [{"text": {"content": f"DeFiRouter Sim ${report.portfolio_usd}"}}]},
            "Status": {"select": {"name": "HALTED" if report.circuit_breaker.triggered else "READY"}},
            "Portfolio USD": {"number": report.portfolio_usd},
            "Fees USD": {"number": best.total_fees_usd},
            "Fee %": {"number": best.fee_pct},
            "Retention %": {"number": best.retention_pct},
            "Strategy": {"select": {"name": best.strategy_name}},
            "Recommendation": {"rich_text": [{"text": {"content": report.circuit_breaker.recommendation[:2000]}}]},
        }
        return self._create_page(props)

    def log_transaction(self, entry: NotionTxLog) -> Optional[Dict[str, Any]]:
        if not self.configured:
            return {"skipped": True, "reason": "notion not configured"}

        props = {
            "Name": {"title": [{"text": {"content": entry.step[:100]}}]},
            "TX Hash": {"rich_text": [{"text": {"content": entry.tx_hash}}]},
            "Provider": {"select": {"name": entry.provider[:50]}},
            "Chain": {"select": {"name": entry.chain}},
            "Input USD": {"number": entry.input_usd},
            "Output USD": {"number": entry.output_usd},
            "Fee USD": {"number": entry.fee_usd},
            "Timestamp": {"date": {"start": entry.timestamp_iso}},
        }
        if entry.notes:
            props["Notes"] = {"rich_text": [{"text": {"content": entry.notes[:2000]}}]}
        return self._create_page(props)

    def log_route_steps(self, plan: RoutePlan, *, dry_run: bool = True) -> List[Dict[str, Any]]:
        results = []
        now = datetime.now(timezone.utc).isoformat()
        for i, step in enumerate(plan.steps, 1):
            entry = NotionTxLog(
                tx_hash="dry-run" if dry_run else "pending",
                step=f"Step {i}: {step.action} ({step.provider})",
                provider=step.provider,
                input_usd=step.input_usd,
                output_usd=step.output_usd,
                fee_usd=step.fee_usd + step.gas_usd,
                chain=step.from_chain,
                timestamp_iso=now,
                notes=step.notes,
            )
            results.append(self.log_transaction(entry) or {"skipped": True})
        return results

    def _create_page(self, properties: Dict[str, Any]) -> Dict[str, Any]:
        payload = {
            "parent": {"database_id": self.database_id},
            "properties": properties,
        }
        req = urllib.request.Request(
            "https://api.notion.com/v1/pages",
            data=json.dumps(payload).encode(),
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Notion-Version": NOTION_VERSION,
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                return json.loads(resp.read().decode())
        except urllib.error.HTTPError as exc:
            body = exc.read().decode() if exc.fp else ""
            return {"error": str(exc), "body": body}
