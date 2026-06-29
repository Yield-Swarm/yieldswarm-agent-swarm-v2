"""PoWUoI coin registry — six Akash cloud pools + optional ranch ZEC."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
REGISTRY_PATH = REPO_ROOT / "config" / "mining" / "pouw-coins.json"
TREASURY_MANIFEST = REPO_ROOT / "config" / "TREASURY_MANIFEST.json"


@dataclass(frozen=True)
class PouwCoin:
    symbol: str
    name: str
    work_type: str
    algorithm: str
    cloud: str
    wallet_env: str
    pool_url_env: str
    quote_env: str
    enabled_env: str
    default_pool_url: str
    gpu_profile: str
    treasury_manifest_key: str | None = None

    @property
    def miner_name(self) -> str:
        return self.symbol.lower()

    def wallet(self) -> str:
        direct = os.getenv(self.wallet_env, "").strip()
        if direct and direct not in ("[REDACTED]", ""):
            return direct
        if self.treasury_manifest_key:
            manifest = _load_treasury_manifest()
            roots = manifest.get("mining_roots", {})
            return str(roots.get(self.treasury_manifest_key, "") or "")
        if self.symbol == "PRL":
            return os.getenv("MINING_ROOT_PRL", "").strip()
        return ""

    def pool_url(self) -> str:
        return (
            os.getenv(self.pool_url_env, "").strip()
            or self.default_pool_url
            or os.getenv(f"{self.symbol}_POOL_URL", "").strip()
        )

    def quote_usd_day(self) -> float:
        raw = os.getenv(self.quote_env, "0") or "0"
        try:
            return float(raw)
        except ValueError:
            return 0.0

    def enabled(self) -> bool:
        flag = os.getenv(self.enabled_env, "true").lower()
        return flag in ("1", "true", "yes", "on")

    def to_dict(self) -> dict[str, Any]:
        wallet = self.wallet()
        return {
            "symbol": self.symbol,
            "name": self.name,
            "work_type": self.work_type,
            "algorithm": self.algorithm,
            "cloud": self.cloud,
            "wallet_env": self.wallet_env,
            "pool_url_env": self.pool_url_env,
            "wallet_configured": bool(wallet),
            "wallet_redacted": _redact_wallet(wallet),
            "pool_url": self.pool_url() or None,
            "quote_usd_day": self.quote_usd_day(),
            "enabled": self.enabled(),
            "gpu_profile": self.gpu_profile,
            "yieldswarm_native": self.symbol == yieldswarm_coin_symbol(),
        }


def _redact_wallet(wallet: str) -> str:
    if not wallet:
        return ""
    if len(wallet) <= 12:
        return wallet[:4] + "…"
    return f"{wallet[:6]}…{wallet[-4:]}"


def _load_treasury_manifest() -> dict[str, Any]:
    if not TREASURY_MANIFEST.exists():
        return {}
    try:
        return json.loads(TREASURY_MANIFEST.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def load_registry() -> dict[str, Any]:
    if not REGISTRY_PATH.exists():
        raise FileNotFoundError(f"PoWUoI registry missing: {REGISTRY_PATH}")
    return json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))


def yieldswarm_coin_symbol() -> str:
    data = load_registry()
    return str(data.get("yieldswarm_coin", "PRL")).upper()


def list_pouw_coins() -> list[PouwCoin]:
    data = load_registry()
    coins: list[PouwCoin] = []
    for row in data.get("coins", []):
        coins.append(
            PouwCoin(
                symbol=str(row["symbol"]).upper(),
                name=str(row["name"]),
                work_type=str(row["work_type"]),
                algorithm=str(row["algorithm"]),
                cloud=str(row["cloud"]),
                wallet_env=str(row["wallet_env"]),
                pool_url_env=str(row["pool_url_env"]),
                quote_env=str(row["quote_env"]),
                enabled_env=str(row.get("enabled_env", f"POUW_{row['symbol']}_ENABLED")),
                default_pool_url=str(row.get("default_pool_url", "")),
                gpu_profile=str(row.get("gpu_profile", "rtx3090")),
                treasury_manifest_key=row.get("treasury_manifest_key"),
            )
        )
    return coins


def list_enabled_coins() -> list[PouwCoin]:
    return [c for c in list_pouw_coins() if c.enabled()]
