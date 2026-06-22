"""
Helix Nodes — file-backed store for node registry, tickets, and lottery state.
"""

from __future__ import annotations

import json
import os
import threading
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

_LOCK = threading.Lock()
_DEFAULT_ROOT = Path(os.environ.get("HELIX_NODES_STATE_DIR", ".run/helix-nodes"))


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _iso(dt: datetime) -> str:
    return dt.isoformat()


class HelixNodeStore:
    def __init__(self, root: Optional[Path] = None) -> None:
        self.root = root or _DEFAULT_ROOT
        self.root.mkdir(parents=True, exist_ok=True)
        self._nodes_path = self.root / "nodes.json"
        self._lottery_path = self.root / "lottery.json"
        self._load()

    def _load(self) -> None:
        with _LOCK:
            self._nodes = self._read_json(self._nodes_path, {"nodes": {}, "referrals": {}})
            self._lottery = self._read_json(
                self._lottery_path,
                {
                    "current_draw_id": "weekly-1",
                    "prize_pool_usd": 500.0,
                    "prizes": [
                        {"rank": 1, "label": "USDC", "amount_usd": 200},
                        {"rank": 2, "label": "SOL", "amount_usd": 150},
                        {"rank": 3, "label": "Cloud credits", "amount_usd": 100},
                        {"rank": 4, "label": "Token airdrop", "amount_usd": 50},
                    ],
                    "draws": [],
                },
            )

    @staticmethod
    def _read_json(path: Path, default: Dict[str, Any]) -> Dict[str, Any]:
        if not path.exists():
            return default
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return default

    def _save_nodes(self) -> None:
        self._nodes_path.write_text(json.dumps(self._nodes, indent=2), encoding="utf-8")

    def _save_lottery(self) -> None:
        self._lottery_path.write_text(json.dumps(self._lottery, indent=2), encoding="utf-8")

    def register(
        self,
        *,
        user_id: Optional[str] = None,
        referral_code: Optional[str] = None,
        platform: str = "extension",
    ) -> Dict[str, Any]:
        with _LOCK:
            node_id = f"hn-{uuid.uuid4().hex[:12]}"
            my_referral = node_id[-8:].upper()
            referrer_id = None
            if referral_code:
                ref = referral_code.strip().upper()
                for nid, node in self._nodes["nodes"].items():
                    if node.get("referral_code") == ref:
                        referrer_id = nid
                        self._nodes["referrals"][node_id] = nid
                        node["referral_count"] = int(node.get("referral_count", 0)) + 1
                        node["lottery_tickets"] = int(node.get("lottery_tickets", 0)) + 5
                        break

            now = _iso(_utcnow())
            record = {
                "node_id": node_id,
                "user_id": user_id or node_id,
                "platform": platform,
                "referral_code": my_referral,
                "referred_by": referrer_id,
                "lottery_tickets": 1,
                "points": 0,
                "streak_days": 0,
                "last_heartbeat": None,
                "last_accrual": now,
                "created_at": now,
                "status": "registered",
                "referral_count": 0,
                "actions": [],
            }
            self._nodes["nodes"][node_id] = record
            self._save_nodes()
            return dict(record)

    def get(self, node_id: str) -> Optional[Dict[str, Any]]:
        with _LOCK:
            node = self._nodes["nodes"].get(node_id)
            return dict(node) if node else None

    def heartbeat(
        self,
        node_id: str,
        *,
        extension_version: str = "0.1.0",
        tasks_completed: int = 0,
    ) -> Optional[Dict[str, Any]]:
        with _LOCK:
            node = self._nodes["nodes"].get(node_id)
            if not node:
                return None

            now = _utcnow()
            last_accrual = datetime.fromisoformat(node.get("last_accrual") or _iso(now))
            hours = max(0.0, (now - last_accrual).total_seconds() / 3600.0)
            tickets_per_hour = float(os.environ.get("HELIX_NODES_TICKETS_PER_HOUR", "1"))
            earned_tickets = int(hours * tickets_per_hour)
            if earned_tickets > 0:
                node["lottery_tickets"] = int(node.get("lottery_tickets", 0)) + earned_tickets
                node["points"] = int(node.get("points", 0)) + earned_tickets * 10
                node["last_accrual"] = _iso(now)

            node["last_heartbeat"] = _iso(now)
            node["extension_version"] = extension_version
            node["status"] = "online"
            node["tasks_completed"] = int(node.get("tasks_completed", 0)) + max(0, tasks_completed)
            self._save_nodes()
            return dict(node)

    def record_action(self, node_id: str, action: str) -> Optional[Dict[str, Any]]:
        bonuses = {
            "referral": 5,
            "share": 2,
            "repost": 2,
            "signup_friend": 3,
        }
        bonus = bonuses.get(action)
        if bonus is None:
            return None

        with _LOCK:
            node = self._nodes["nodes"].get(node_id)
            if not node:
                return None
            node["lottery_tickets"] = int(node.get("lottery_tickets", 0)) + bonus
            node["points"] = int(node.get("points", 0)) + bonus * 10
            actions: List[str] = list(node.get("actions") or [])
            actions.append(f"{action}:{_iso(_utcnow())}")
            node["actions"] = actions[-50:]
            self._save_nodes()
            return dict(node)

    def leaderboard(self, limit: int = 20) -> List[Dict[str, Any]]:
        with _LOCK:
            nodes = list(self._nodes["nodes"].values())
        nodes.sort(key=lambda n: int(n.get("lottery_tickets", 0)), reverse=True)
        return [
            {
                "node_id": n["node_id"],
                "lottery_tickets": n.get("lottery_tickets", 0),
                "points": n.get("points", 0),
                "status": n.get("status"),
                "referral_code": n.get("referral_code"),
            }
            for n in nodes[:limit]
        ]

    def summary(self) -> Dict[str, Any]:
        with _LOCK:
            nodes = list(self._nodes["nodes"].values())
        online = sum(1 for n in nodes if n.get("status") == "online")
        total_tickets = sum(int(n.get("lottery_tickets", 0)) for n in nodes)
        return {
            "registered_nodes": len(nodes),
            "online_nodes": online,
            "total_lottery_tickets": total_tickets,
            "dry_run": os.environ.get("HELIX_NODES_DRY_RUN", "1") != "0",
        }

    def lottery_current(self) -> Dict[str, Any]:
        with _LOCK:
            pool = dict(self._lottery)
            entries = [
                {"node_id": n["node_id"], "tickets": int(n.get("lottery_tickets", 0))}
                for n in self._nodes["nodes"].values()
                if int(n.get("lottery_tickets", 0)) > 0
            ]
        total_entries = sum(e["tickets"] for e in entries)
        return {
            "draw_id": pool.get("current_draw_id"),
            "prize_pool_usd": pool.get("prize_pool_usd"),
            "prizes": pool.get("prizes"),
            "entrant_count": len(entries),
            "total_tickets": total_entries,
            "dry_run": os.environ.get("HELIX_NODES_DRY_RUN", "1") != "0",
        }

    def lottery_draw(self) -> Dict[str, Any]:
        """Weighted random draw (simulated when HELIX_NODES_DRY_RUN=1)."""
        import random

        dry = os.environ.get("HELIX_NODES_DRY_RUN", "1") != "0"
        current = self.lottery_current()
        entries = []
        with _LOCK:
            for n in self._nodes["nodes"].values():
                t = int(n.get("lottery_tickets", 0))
                if t > 0:
                    entries.extend([n["node_id"]] * t)

        winners = []
        prizes = list(self._lottery.get("prizes") or [])
        pool = entries[:]
        for prize in prizes:
            if not pool:
                break
            winner = random.choice(pool)
            winners.append({"node_id": winner, **prize, "simulated": dry})
            pool = [x for x in pool if x != winner]

        result = {
            "draw_id": self._lottery.get("current_draw_id"),
            "winners": winners,
            "simulated": dry,
            "drawn_at": _iso(_utcnow()),
        }
        with _LOCK:
            draws = list(self._lottery.get("draws") or [])
            draws.append(result)
            self._lottery["draws"] = draws[-20:]
            self._save_lottery()
        return result


_store: Optional[HelixNodeStore] = None


def get_store() -> HelixNodeStore:
    global _store
    if _store is None:
        _store = HelixNodeStore()
    return _store
