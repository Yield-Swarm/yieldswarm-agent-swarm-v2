"""Termux edge fleet — 8 multi-mining daemon instances on Android."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
FLEET_CONFIG = REPO_ROOT / "config" / "mining" / "termux-fleet.json"
STATE_DIR = REPO_ROOT / ".data" / "termux-fleet"


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _load_fleet_config() -> dict[str, Any]:
    if not FLEET_CONFIG.exists():
        raise FileNotFoundError(f"Termux fleet config missing: {FLEET_CONFIG}")
    return json.loads(FLEET_CONFIG.read_text(encoding="utf-8"))


@dataclass(frozen=True)
class TermuxInstance:
    index: int
    instance_id: str
    coin: str
    worker_name: str
    device_id: str
    ram_mb: int
    storage_gb: int
    run_dir: Path

    def to_dict(self) -> dict[str, Any]:
        return {
            "index": self.index,
            "instanceId": self.instance_id,
            "coin": self.coin,
            "workerName": self.worker_name,
            "deviceId": self.device_id,
            "ramMb": self.ram_mb,
            "storageGb": self.storage_gb,
            "runDir": str(self.run_dir),
            "platform": "android",
        }


class TermuxFleet:
    """Manage N Termux mining instances (default 8 × 16GB / 128GB profile)."""

    def __init__(self) -> None:
        self.cfg = _load_fleet_config()
        defaults = self.cfg.get("defaults", {})
        self.instance_count = int(os.environ.get("TERMUX_INSTANCE_COUNT", defaults.get("instance_count", 8)))
        self.ram_mb = int(os.environ.get("TERMUX_RAM_MB", defaults.get("ram_mb_per_instance", 16384)))
        self.storage_gb = int(os.environ.get("TERMUX_STORAGE_GB", defaults.get("storage_gb_per_instance", 128)))
        self.tick_seconds = int(os.environ.get("MINING_TICK_SECONDS", defaults.get("tick_seconds", 60)))
        run_base = os.environ.get("TERMUX_RUN_DIR", defaults.get("run_dir", ".run/termux"))
        self.run_base = Path(run_base)
        if not self.run_base.is_absolute():
            self.run_base = REPO_ROOT / self.run_base
        self.run_base.mkdir(parents=True, exist_ok=True)
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        rotation = self.cfg.get("coin_rotation", ["prl", "krx", "zano", "qtc", "iron", "ton", "grass", "monero"])
        self.coin_rotation = [str(c).lower() for c in rotation]

    def _prefix(self) -> str:
        return os.environ.get("TERMUX_FLEET_PREFIX", "termux")

    def instances(self) -> list[TermuxInstance]:
        out: list[TermuxInstance] = []
        for i in range(1, self.instance_count + 1):
            coin = self.coin_rotation[(i - 1) % len(self.coin_rotation)]
            inst_id = f"{self._prefix()}-{i:02d}"
            out.append(
                TermuxInstance(
                    index=i,
                    instance_id=inst_id,
                    coin=coin,
                    worker_name=f"{inst_id}-worker",
                    device_id=f"grass-{inst_id}",
                    ram_mb=self.ram_mb,
                    storage_gb=self.storage_gb,
                    run_dir=self.run_base / f"instance-{i:02d}",
                )
            )
        return out

    def write_instance_config(self, inst: TermuxInstance) -> Path:
        inst.run_dir.mkdir(parents=True, exist_ok=True)
        cfg: dict[str, Any] = {
            "schemaVersion": "termux-fleet/v1",
            "instance": inst.to_dict(),
            "ecosystem": "PoWUoI",
            "mode": "edge_supervisor",
            "tickSeconds": self.tick_seconds,
            "grass": {
                "platform": "android",
                "multiplier": 3.0,
                "device_id": inst.device_id,
                "network": os.environ.get("TERMUX_NETWORK", "mobile_data"),
            },
            "note": "GPU PoW hashes on cloud H100 fleet; Termux runs DePIN + edge telemetry.",
        }
        if inst.coin == "grass":
            cfg["workload"] = "grass_lineup"
            cfg["wallet_env"] = "GRASS_NODE_KEYS"
        elif inst.coin == "monero":
            cfg["workload"] = "xmrig_cpu"
            cfg["wallet_env"] = "MONERO_WALLET_ADDRESS"
            cfg["xmrig_path"] = os.environ.get("XMRIG_PATH", "xmrig")
        else:
            cfg["workload"] = "pouw_supervisor"
            cfg["wallet_env"] = f"MINING_WALLET_{inst.coin.upper()}" if inst.coin != "prl" else "MINING_ROOT_PRL"
            cfg["pool_url_env"] = f"MINING_POOL_URL_{inst.coin.upper()}"

        path = inst.run_dir / "instance-config.json"
        path.write_text(json.dumps(cfg, indent=2), encoding="utf-8")
        return path

    def _start_supervisor_process(self, inst: TermuxInstance, cfg_path: Path) -> subprocess.Popen[Any]:
        log_file = inst.run_dir / "supervisor.log"
        code = f"""
import json, os, pathlib, time
cfg_path = {str(cfg_path)!r}
tick = int(os.environ.get("MINING_TICK_SECONDS", "{self.tick_seconds}"))
while True:
    cfg = json.load(open(cfg_path, encoding="utf-8"))
    inst = cfg.get("instance", {{}})
    print(f"[termux-{{inst.get('instanceId')}}] tick {{cfg.get('workload')}} coin={{inst.get('coin')}}")
    pathlib.Path(cfg_path).with_name("last-tick.txt").write_text(str(time.time()))
    time.sleep(tick)
"""
        return subprocess.Popen(
            [sys.executable, "-c", code],
            stdout=open(log_file, "a", encoding="utf-8"),
            stderr=subprocess.STDOUT,
            cwd=str(inst.run_dir),
            start_new_session=True,
        )

    def start_instance(self, inst: TermuxInstance, *, dry_run: bool) -> dict[str, Any]:
        cfg_path = self.write_instance_config(inst)
        pid_file = inst.run_dir / "supervisor.pid"

        if dry_run:
            return {
                "ok": True,
                "mode": "dry_run",
                "instanceId": inst.instance_id,
                "coin": inst.coin,
                "config": str(cfg_path),
            }

        if pid_file.exists():
            try:
                pid = int(pid_file.read_text().strip())
                os.kill(pid, 0)
                return {"ok": True, "instanceId": inst.instance_id, "state": "already_running", "pid": pid}
            except (OSError, ValueError):
                pid_file.unlink(missing_ok=True)

        proc = self._start_supervisor_process(inst, cfg_path)
        pid_file.write_text(str(proc.pid))
        return {
            "ok": True,
            "instanceId": inst.instance_id,
            "coin": inst.coin,
            "pid": proc.pid,
            "log": str(inst.run_dir / "supervisor.log"),
        }

    def stop_instance(self, inst: TermuxInstance) -> dict[str, Any]:
        pid_file = inst.run_dir / "supervisor.pid"
        if not pid_file.exists():
            return {"ok": True, "instanceId": inst.instance_id, "state": "stopped"}
        try:
            pid = int(pid_file.read_text().strip())
            os.kill(pid, 15)
        except (OSError, ValueError):
            pass
        pid_file.unlink(missing_ok=True)
        return {"ok": True, "instanceId": inst.instance_id, "state": "stopped"}

    def fleet_state(self) -> dict[str, Any]:
        rows = []
        for inst in self.instances():
            tick_file = inst.run_dir / "last-tick.txt"
            last_tick = None
            if tick_file.exists():
                try:
                    last_tick = float(tick_file.read_text().strip())
                except ValueError:
                    pass
            pid = None
            pid_file = inst.run_dir / "supervisor.pid"
            if pid_file.exists():
                try:
                    pid = int(pid_file.read_text().strip())
                except ValueError:
                    pass
            rows.append({**inst.to_dict(), "pid": pid, "lastTick": last_tick, "alive": bool(pid and self._pid_alive(pid))})

        return {
            "schemaVersion": "termux-fleet/v1",
            "capturedAt": _utc_now(),
            "platform": "termux",
            "instanceCount": self.instance_count,
            "ramMbPerInstance": self.ram_mb,
            "storageGbPerInstance": self.storage_gb,
            "instances": rows,
            "coinRotation": self.coin_rotation,
        }

    def _pid_alive(self, pid: int) -> bool:
        try:
            os.kill(pid, 0)
            return True
        except OSError:
            return False

    def write_state(self) -> Path:
        path = STATE_DIR / "latest.json"
        path.write_text(json.dumps(self.fleet_state(), indent=2), encoding="utf-8")
        return path

    def launch(self, *, dry_run: bool | None = None) -> dict[str, Any]:
        use_dry = dry_run if dry_run is not None else os.environ.get("MINING_DRY_RUN", "1").lower() in ("1", "true", "yes")
        results = [self.start_instance(inst, dry_run=use_dry) for inst in self.instances()]
        state_path = self.write_state()
        return {
            "ok": all(r.get("ok") for r in results),
            "phase": "termux_fleet_launch",
            "instanceCount": self.instance_count,
            "dryRun": use_dry,
            "results": results,
            "statePath": str(state_path),
        }

    def stop_all(self) -> dict[str, Any]:
        results = [self.stop_instance(inst) for inst in self.instances()]
        self.write_state()
        return {"ok": True, "action": "stop", "results": results}

    def daemon(self) -> None:
        """Foreground daemon: wake-lock friendly tick loop for all instances."""
        print(f"[termux-fleet] daemon starting {self.instance_count} instances (tick={self.tick_seconds}s)")
        self.launch(dry_run=False)
        try:
            while True:
                self.write_state()
                time.sleep(self.tick_seconds)
        except KeyboardInterrupt:
            print("[termux-fleet] stopping...")
            self.stop_all()


def run_cli(argv: list[str] | None = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="YieldSwarm Termux edge mining fleet")
    parser.add_argument("command", choices=["launch", "stop", "status", "daemon", "config"])
    parser.add_argument("--live", action="store_true")
    parser.add_argument("--json", action="store_true", default=True)
    args = parser.parse_args(argv)

    fleet = TermuxFleet()
    if args.command == "launch":
        out = fleet.launch(dry_run=not args.live)
    elif args.command == "stop":
        out = fleet.stop_all()
    elif args.command == "daemon":
        if not args.live:
            os.environ.setdefault("MINING_DRY_RUN", "0")
        fleet.daemon()
        return 0
    elif args.command == "config":
        paths = []
        for inst in fleet.instances():
            paths.append(str(fleet.write_instance_config(inst)))
        out = {"ok": True, "configs": paths}
    else:
        out = {"ok": True, "fleet": fleet.fleet_state()}

    print(json.dumps(out, indent=2))
    return 0 if out.get("ok", True) else 1


if __name__ == "__main__":
    raise SystemExit(run_cli())
