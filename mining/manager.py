"""Unified mining manager — start/stop/monitor all miners."""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

from mining.config import load_mining_config
from mining.auth import MiningAuthService
from mining.rewards import RewardRouter
from mining.fleet import FleetRegistry
from mining.miners import MINER_REGISTRY, BaseMiner

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MINERS = ["bittensor", "monero", "etc", "grass", "helium"]


class UnifiedMiningManager:
    """Orchestrates all mining workloads from a single control plane."""

    def __init__(self, miners: Optional[List[str]] = None):
        self.config = load_mining_config()
        self.auth = MiningAuthService()
        self.rewards = RewardRouter()
        self.fleet = FleetRegistry(self.auth)
        self.run_dir = Path(self.config.run_dir)
        if not self.run_dir.is_absolute():
            self.run_dir = REPO_ROOT / self.run_dir
        self.run_dir.mkdir(parents=True, exist_ok=True)
        names = miners or DEFAULT_MINERS
        self.miners: Dict[str, BaseMiner] = {}
        for name in names:
            cls = MINER_REGISTRY.get(name)
            if cls:
                self.miners[name] = cls(self.config, self.run_dir)

    def list_miners(self) -> List[str]:
        return list(self.miners.keys())

    def status(self, name: Optional[str] = None) -> Dict[str, Any]:
        if name:
            miner = self.miners.get(name)
            if not miner:
                return {"ok": False, "error": f"unknown miner: {name}"}
            return {"ok": True, "miner": name, "status": miner.status().to_dict()}

        statuses = {n: m.status().to_dict() for n, m in self.miners.items()}
        running = sum(1 for s in statuses.values() if s["state"] == "running")
        return {
            "ok": True,
            "timestamp": int(time.time()),
            "dry_run": self.config.dry_run,
            "execution_capacity": self.config.execution_capacity,
            "auth": self.auth.bootstrap_context().to_dict(),
            "reward_routes": self.rewards.route_table(),
            "fleet": self.fleet.status(),
            "wallets": self.config.redacted(),
            "running_count": running,
            "total": len(statuses),
            "miners": statuses,
        }

    def start(self, name: Optional[str] = None) -> Dict[str, Any]:
        auth_ctx = self.auth.bootstrap_context()
        if not auth_ctx.ok:
            return {"ok": False, "error": auth_ctx.error, "auth": auth_ctx.to_dict()}

        targets = [name] if name else list(self.miners.keys())
        results = {}
        for n in targets:
            miner = self.miners.get(n)
            if not miner:
                results[n] = {"ok": False, "error": "unknown miner"}
                continue
            st = miner.start()
            results[n] = {"ok": st.state.value in ("running", "starting", "dry_run"), "status": st.to_dict()}
        self._persist_summary()
        return {"ok": True, "action": "start", "results": results}

    def stop(self, name: Optional[str] = None) -> Dict[str, Any]:
        targets = [name] if name else list(self.miners.keys())
        results = {}
        for n in targets:
            miner = self.miners.get(n)
            if not miner:
                results[n] = {"ok": False, "error": "unknown miner"}
                continue
            st = miner.stop()
            results[n] = {"ok": True, "status": st.to_dict()}
        self._persist_summary()
        return {"ok": True, "action": "stop", "results": results}

    def restart(self, name: Optional[str] = None) -> Dict[str, Any]:
        self.stop(name)
        return self.start(name)

    def write_configs(self) -> Dict[str, Any]:
        paths = {}
        for n, miner in self.miners.items():
            err = miner.validate()
            if err:
                paths[n] = {"ok": False, "error": err}
                continue
            cfg = miner.build_config()
            cfg = self.rewards.apply_to_miner_config(n, cfg)
            miner.config_file.write_text(json.dumps(cfg, indent=2))
            paths[n] = {"ok": True, "path": str(miner.config_file), "payout_wallet": cfg.get("payout_wallet")}
        return {"ok": True, "configs": paths, "reward_routes": self.rewards.route_table()}

    def deploy_production(self) -> Dict[str, Any]:
        """Bootstrap auth, connect fleet, write configs, start miners."""
        fleet = self.fleet.connect_all()
        if not fleet.get("ok"):
            return fleet
        configs = self.write_configs()
        start = self.start()
        return {
            "ok": start.get("ok", True),
            "phase": "production_deploy",
            "fleet": fleet,
            "configs": configs,
            "start": start,
            "reward_routes": self.rewards.route_table(),
        }

    def _persist_summary(self) -> None:
        summary = self.status()
        (self.run_dir / "mining-manager-status.json").write_text(json.dumps(summary, indent=2))


def run_manager_cli(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="YieldSwarm unified mining manager")
    parser.add_argument("command", choices=["start", "stop", "restart", "status", "config", "list", "deploy"])
    parser.add_argument("--miner", "-m", help="Single miner (bittensor|monero|etc|grass|helium)")
    parser.add_argument(
        "--capacity",
        type=float,
        default=None,
        help="Thread execution capacity bound 0.1–1.0 (default: EXECUTION_CAPACITY env or 0.80)",
    )
    parser.add_argument("--json", action="store_true", help="JSON output")
    args = parser.parse_args(argv)

    if args.capacity is not None:
        cap = max(0.1, min(1.0, args.capacity))
        os.environ["EXECUTION_CAPACITY"] = str(cap)

    mgr = UnifiedMiningManager()
    if args.command == "list":
        out = {"miners": mgr.list_miners()}
    elif args.command == "start":
        out = mgr.start(args.miner)
    elif args.command == "stop":
        out = mgr.stop(args.miner)
    elif args.command == "restart":
        out = mgr.restart(args.miner)
    elif args.command == "config":
        out = mgr.write_configs()
    elif args.command == "deploy":
        out = mgr.deploy_production()
    else:
        out = mgr.status(args.miner)

    if args.json:
        print(json.dumps(out, indent=2))
    else:
        print(json.dumps(out, indent=2))
    return 0 if out.get("ok", True) else 1


if __name__ == "__main__":
    raise SystemExit(run_manager_cli())
