"""PoWUoI pool miner — one worker per coin (PRL, KRX, ZANO, QTC, IRON, TON)."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Type

from mining.config import MiningConfig
from mining.miners.base import BaseMiner, MinerState, MinerStatus
from mining.pouw_registry import PouwCoin, list_pouw_coins

REPO_ROOT = Path(__file__).resolve().parents[2]


def _supervisor_script(config_path: str, symbol: str) -> str:
    return (
        "import json,time,os; "
        f"cfg=json.load(open({json.dumps(config_path)})); "
        f"print('[pouw-{symbol.lower()}] pool', cfg.get('pool_url'), "
        "'wallet', cfg.get('payout_wallet_redacted')); "
        "while True: time.sleep(int(os.environ.get('MINING_TICK_SECONDS','60')))"
    )


class PouwPoolMiner(BaseMiner):
    """Parameterized miner bound to a single PoWUoI coin."""

    coin: PouwCoin

    def __init__(self, config: MiningConfig, run_dir: Path, coin: PouwCoin):
        self.coin = coin
        self.name = coin.miner_name
        super().__init__(config, run_dir)

    def validate(self) -> Optional[str]:
        if not self.coin.enabled():
            return f"{self.coin.symbol} disabled via {self.coin.enabled_env}"
        wallet = self.coin.wallet()
        if not wallet:
            return f"{self.coin.wallet_env} or treasury manifest required for {self.coin.symbol}"
        return None

    def _wallet_display(self) -> str:
        w = self.coin.wallet()
        if not w:
            return f"vault:{self.coin.wallet_env}"
        if len(w) <= 12:
            return w
        return f"{w[:6]}…{w[-4:]}"

    def build_config(self) -> Dict[str, Any]:
        wallet = self.coin.wallet()
        pool = self.coin.pool_url()
        return {
            "miner": self.name,
            "ecosystem": "PoWUoI",
            "symbol": self.coin.symbol,
            "name": self.coin.name,
            "work_type": self.coin.work_type,
            "algorithm": self.coin.algorithm,
            "srbminer_algorithm": self.coin.srbminer_algorithm or None,
            "cloud": self.coin.cloud,
            "pool_url": pool,
            "payout_wallet": wallet,
            "payout_wallet_redacted": self._wallet_display(),
            "worker_name": self.coin.worker_name(),
            "wallet_worker": self.coin.wallet_worker(),
            "quote_usd_day": self.coin.quote_usd_day(),
            "gpu_profile": self.coin.gpu_profile,
            "deploy_sdl": str(REPO_ROOT / "deploy" / "akash" / "pouw-pool.sdl.yml"),
            "deploy_script": str(REPO_ROOT / "scripts" / "mining" / "deploy-pearl-srbminer.sh")
            if self.coin.symbol == "PRL"
            else str(REPO_ROOT / "scripts" / "mining" / "deploy-srbminer-pouw.sh"),
            "yieldswarm_native": self.coin.symbol == "PRL",
            "treasury_split": "50,30,15,5",
        }

    def start_command(self) -> List[str]:
        if self.coin.srbminer_algorithm and not self.config.dry_run:
            srb = os.getenv("SRBMINER_PATH", "SRBMiner-MULTI")
            pool = self.coin.pool_url()
            if pool and self.coin.wallet():
                cmd = [
                    srb,
                    "--algorithm",
                    self.coin.srbminer_algorithm,
                    "--pool",
                    pool,
                    "--wallet",
                    self.coin.wallet_worker(),
                    "--password",
                    "x",
                    "--disable-cpu",
                ]
                cmd.extend(list(self.coin.srbminer_extra_args))
                return cmd
        if self.coin.symbol == "PRL" and not self.config.dry_run:
            script = REPO_ROOT / "scripts" / "mining" / "deploy-pearl-srbminer.sh"
            if script.exists():
                return ["bash", str(script)]
        return [
            sys.executable,
            "-c",
            _supervisor_script(str(self.config_file), self.coin.symbol),
        ]

    def status(self) -> MinerStatus:
        base = super().status()
        cfg = self.build_config()
        base.metrics = {
            "symbol": self.coin.symbol,
            "algorithm": self.coin.algorithm,
            "cloud": self.coin.cloud,
            "pool_url": cfg.get("pool_url") or "unset",
            "quote_usd_day": cfg.get("quote_usd_day", 0),
            "yieldswarm_native": cfg.get("yieldswarm_native", False),
        }
        if base.state == MinerState.STOPPED and self.config.dry_run:
            err = self.validate()
            if err and self.coin.enabled():
                base.message = err
        return base


def build_pouw_miner_registry() -> Dict[str, Type[BaseMiner]]:
    """Factory map: miner name -> class with coin bound via closure."""

    registry: Dict[str, Type[BaseMiner]] = {}

    for coin in list_pouw_coins():

        def _make_cls(c: PouwCoin = coin) -> Type[BaseMiner]:
            class _BoundPouwMiner(PouwPoolMiner):
                def __init__(self, config: MiningConfig, run_dir: Path):
                    PouwPoolMiner.__init__(self, config, run_dir, c)

            _BoundPouwMiner.name = c.miner_name
            return _BoundPouwMiner

        registry[coin.miner_name] = _make_cls()

    return registry
