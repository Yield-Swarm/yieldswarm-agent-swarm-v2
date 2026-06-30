"""Launch all six PoWUoI mining pools on Akash + emit helical mining-pools state."""

from __future__ import annotations

import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from mining.config import load_mining_config
from mining.manager import UnifiedMiningManager
from mining.pouw_registry import list_enabled_coins, list_pouw_coins, yieldswarm_coin_symbol
from swarms.mining_pools.engines.pool_switcher import PoolSwitcher

REPO_ROOT = Path(__file__).resolve().parents[1]
STATE_DIR = REPO_ROOT / ".data" / "mining-pools"
SDL_TEMPLATE = REPO_ROOT / "deploy" / "akash" / "pouw-pool.sdl.yml"
RENDER_DIR = REPO_ROOT / ".run" / "mining" / "akash-sdl"


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


class PouwPoolLauncher:
    """Orchestrate PoWUoI pool configs, local workers, and Akash SDL renders."""

    def __init__(self) -> None:
        self.config = load_mining_config()
        self.run_dir = Path(self.config.run_dir)
        if not self.run_dir.is_absolute():
            self.run_dir = REPO_ROOT / self.run_dir
        self.run_dir.mkdir(parents=True, exist_ok=True)
        RENDER_DIR.mkdir(parents=True, exist_ok=True)
        STATE_DIR.mkdir(parents=True, exist_ok=True)

    def _miner_names(self) -> list[str]:
        return [c.miner_name for c in list_enabled_coins()]

    def render_akash_sdl(self, symbol: str) -> Path:
        coin = next(c for c in list_pouw_coins() if c.symbol == symbol.upper())
        template = SDL_TEMPLATE.read_text(encoding="utf-8")
        image = os.environ.get("POWU_POOL_IMAGE", os.environ.get("DEPLOY_IMAGE", "ghcr.io/yield-swarm/agentswarm-akash:latest"))
        replacements = {
            "${POWU_SYMBOL}": coin.symbol,
            "${POWU_MINER_NAME}": coin.miner_name,
            "${POWU_ALGORITHM}": coin.algorithm,
            "${POWU_GPU_PROFILE}": coin.gpu_profile,
            "${POWU_POOL_IMAGE}": image,
            "${VAULT_ADDR}": os.environ.get("VAULT_ADDR", ""),
            "${VAULT_ROLE_ID}": os.environ.get("VAULT_ROLE_ID", ""),
            "${VAULT_SECRET_ID}": os.environ.get("VAULT_SECRET_ID", ""),
            "${VAULT_SKIP_VERIFY}": os.environ.get("VAULT_SKIP_VERIFY", "false"),
            "${MINING_POOL_URL}": coin.pool_url(),
            "${MINING_WALLET}": coin.wallet(),
        }
        rendered = template
        for key, value in replacements.items():
            rendered = rendered.replace(key, value)
        out = RENDER_DIR / f"pouw-{coin.symbol.lower()}.sdl.yml"
        out.write_text(rendered, encoding="utf-8")
        return out

    def render_all_sdls(self) -> dict[str, str]:
        paths: dict[str, str] = {}
        for coin in list_enabled_coins():
            paths[coin.symbol] = str(self.render_akash_sdl(coin.symbol))
        manifest_path = RENDER_DIR / "pouw-manifest.json"
        manifest_path.write_text(json.dumps(paths, indent=2), encoding="utf-8")
        return paths

    def deploy_akash(self, *, dry_run: bool | None = None) -> dict[str, Any]:
        """Render SDLs and optionally invoke deploy-full.sh per coin."""
        use_dry = self.config.dry_run if dry_run is None else dry_run
        sdls = self.render_all_sdls()
        results: dict[str, Any] = {}
        deploy_script = REPO_ROOT / "deploy" / "akash" / "deploy-full.sh"

        for symbol, sdl_path in sdls.items():
            if use_dry:
                results[symbol] = {"ok": True, "mode": "dry_run", "sdl": sdl_path}
                continue
            if not deploy_script.exists():
                results[symbol] = {"ok": False, "error": "deploy-full.sh missing"}
                continue
            env = os.environ.copy()
            env["AKASH_SDL_PATH"] = sdl_path
            env["POWU_SYMBOL"] = symbol
            try:
                proc = subprocess.run(
                    ["bash", str(deploy_script), "--skip-health"],
                    cwd=str(REPO_ROOT),
                    env=env,
                    capture_output=True,
                    text=True,
                    timeout=600,
                    check=False,
                )
                results[symbol] = {
                    "ok": proc.returncode == 0,
                    "sdl": sdl_path,
                    "returncode": proc.returncode,
                    "stdout_tail": proc.stdout[-500:] if proc.stdout else "",
                    "stderr_tail": proc.stderr[-500:] if proc.stderr else "",
                }
            except (subprocess.TimeoutExpired, OSError) as exc:
                results[symbol] = {"ok": False, "sdl": sdl_path, "error": str(exc)}

        return {"ok": all(r.get("ok") for r in results.values()) if results else True, "deployments": results}

    def helical_state(self) -> dict[str, Any]:
        physical_path = REPO_ROOT / ".data" / "physical-core" / "latest.json"
        physical: dict[str, Any] | None = None
        if physical_path.exists():
            physical = json.loads(physical_path.read_text(encoding="utf-8"))

        switcher_state = PoolSwitcher().tick(physical)
        pools = []
        for coin in list_pouw_coins():
            wallet = coin.wallet()
            pools.append(
                {
                    "poolId": f"pouw-{coin.symbol.lower()}",
                    "algorithm": coin.algorithm,
                    "coin": coin.symbol,
                    "status": "active" if coin.enabled() and wallet else "standby",
                    "hashrate": coin.quote_usd_day(),
                    "hashrateUnit": "H/s",
                    "workersOnline": 1 if coin.enabled() and wallet else 0,
                    "payoutAddress": wallet or "vault-managed",
                    "cloud": coin.cloud,
                    "yieldswarmNative": coin.symbol == yieldswarm_coin_symbol(),
                }
            )

        state = {
            "schemaVersion": "mining-pools/v1",
            "capturedAt": _utc_now(),
            "siteId": os.environ.get("PHYSICAL_CORE_SITE_ID", "carrizozo-nm-10ac"),
            "ecosystem": "PoWUoI",
            "yieldswarmCoin": yieldswarm_coin_symbol(),
            "pools": pools,
            "attribution": switcher_state.get("attribution", {}),
            "switcher": {
                "activeNetwork": switcher_state.get("activeNetwork"),
                "activeQuoteUsdDay": switcher_state.get("activeQuoteUsdDay"),
                "ranked": switcher_state.get("ranked", []),
            },
            "physicalCoreRef": switcher_state.get("physicalCoreRef"),
        }
        termux_path = REPO_ROOT / ".data" / "termux-fleet" / "latest.json"
        if termux_path.exists():
            try:
                state["termuxFleetRef"] = json.loads(termux_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                pass
        return state

    def write_state(self) -> Path:
        path = STATE_DIR / "latest.json"
        path.write_text(json.dumps(self.helical_state(), indent=2), encoding="utf-8")
        return path

    def launch(self, *, deploy_akash: bool = False) -> dict[str, Any]:
        """Write configs, start local supervisors, optionally deploy Akash leases."""
        mgr = UnifiedMiningManager(miners=self._miner_names())
        configs = mgr.write_configs()
        start = mgr.start()
        state_path = self.write_state()
        akash = self.deploy_akash() if deploy_akash else {"skipped": True}

        enabled = [c.to_dict() for c in list_enabled_coins()]
        return {
            "ok": configs.get("ok", True) and start.get("ok", True),
            "phase": "pouw_pool_launch",
            "ecosystem": "PoWUoI",
            "yieldswarm_coin": yieldswarm_coin_symbol(),
            "enabled_coins": enabled,
            "configs": configs,
            "start": start,
            "helical_state_path": str(state_path),
            "akash": akash,
            "dry_run": self.config.dry_run,
        }

    def status(self) -> dict[str, Any]:
        mgr = UnifiedMiningManager(miners=self._miner_names())
        return {
            "ok": True,
            "ecosystem": "PoWUoI",
            "yieldswarm_coin": yieldswarm_coin_symbol(),
            "coins": [c.to_dict() for c in list_pouw_coins()],
            "miners": mgr.status(),
            "helical_state": self.helical_state(),
        }


def run_launcher_cli(argv: list[str] | None = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="YieldSwarm PoWUoI pool launcher")
    parser.add_argument("command", choices=["launch", "status", "render-sdl", "state"])
    parser.add_argument("--deploy-akash", action="store_true", help="Deploy Akash leases (live)")
    parser.add_argument("--json", action="store_true", help="JSON output")
    args = parser.parse_args(argv)

    launcher = PouwPoolLauncher()
    if args.command == "launch":
        out = launcher.launch(deploy_akash=args.deploy_akash)
    elif args.command == "render-sdl":
        out = {"ok": True, "sdls": launcher.render_all_sdls()}
    elif args.command == "state":
        path = launcher.write_state()
        out = {"ok": True, "path": str(path), "state": launcher.helical_state()}
    else:
        out = launcher.status()

    if args.json or True:
        print(json.dumps(out, indent=2))
    return 0 if out.get("ok", True) else 1


if __name__ == "__main__":
    raise SystemExit(run_launcher_cli())
