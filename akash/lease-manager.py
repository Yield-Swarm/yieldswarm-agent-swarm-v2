#!/usr/bin/env python3
"""Akash GPU lease manager.

Production supervisor for RTX 3090 GPU workers running on the Akash network.

What it does, on every cycle (default: every 60 seconds):
  1. Reads the tracked worker fleet from a JSON state file.
  2. Health-checks each worker URL (HTTP and/or TCP) with retries.
  3. For any worker that is dead beyond the failure threshold, it provisions a
     replacement by calling ``akash-deploy.sh deploy`` -- which finds the best
     available RTX 3090 provider, opens a lease, sends the manifest, and returns
     the new worker URL.
  4. Optionally closes the dead lease to stop paying for it.
  5. Updates the frontend telemetry (a JSON file the dashboard reads, the
     rendered HTML page, and an optional webhook) with the new worker URLs.

It can run as:
  * a one-shot pass        ->  ``lease-manager.py --once``      (ideal for cron)
  * a long-lived daemon    ->  ``lease-manager.py``             (background/systemd)

All configuration comes from the environment (optionally via a .env file). See
akash-lease-manager.env.example for the full list.
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import signal
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent

# Dual-service SDL presets (swarm-flux-miner + backend)
DEPLOY_PROFILES: dict[str, dict[str, Any]] = {
    "miner": {
        "sdl": SCRIPT_DIR / "swarm-flux-miner.yml",
        "gpu": "h100",
        "bid_max": "100000",
        "role": "swarm-flux-miner",
        "health_path": "/healthz",
    },
    "backend": {
        "sdl": SCRIPT_DIR / "backend.yml",
        "gpu": "",  # CPU-only
        "bid_max": "1500",
        "role": "integration-backend",
        "health_path": "/api/health",
    },
}
LEASES_STATE_FILE = SCRIPT_DIR / "state" / "leases.json"


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
def _load_dotenv() -> None:
    """Load simple KEY=VALUE lines from .env files without overriding the env."""
    for candidate in (SCRIPT_DIR / ".env", SCRIPT_DIR.parent / ".env",
                      Path(os.environ.get("AKASH_ENV_FILE", ""))):
        if not candidate or not candidate.is_file():
            continue
        for raw in candidate.read_text().splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.split(" #", 1)[0].strip().strip('"').strip("'")
            os.environ.setdefault(key, value)


def _env(name: str, default: str) -> str:
    return os.environ.get(name, default)


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, str(default)))
    except (TypeError, ValueError):
        return default


def _env_bool(name: str, default: bool) -> bool:
    return os.environ.get(name, str(default)).strip().lower() in {"1", "true", "yes", "on"}


@dataclass
class Config:
    deploy_script: str
    state_file: Path
    telemetry_json: Path
    telemetry_html: Path
    telemetry_webhook: str
    log_file: str
    pid_file: Path
    interval_seconds: int
    health_timeout: int
    health_path: str
    health_retries: int
    health_retry_delay: int
    failure_threshold: int
    deploy_timeout: int
    desired_workers: int
    close_dead_leases: bool
    dry_run: bool

    @classmethod
    def from_env(cls) -> "Config":
        default_deploy = str(SCRIPT_DIR.parent / "scripts" / "akash-deploy-with-vault.sh")
        arena_hook = _env("ARENA_TELEMETRY_URL", _env("TELEMETRY_WEBHOOK", ""))
        return cls(
            deploy_script=_env("AKASH_DEPLOY_SCRIPT", default_deploy),
            state_file=Path(_env("LEASE_STATE_FILE", str(SCRIPT_DIR / "state" / "workers.json"))),
            telemetry_json=Path(_env("TELEMETRY_JSON", str(SCRIPT_DIR / "telemetry" / "telemetry.json"))),
            telemetry_html=Path(_env("TELEMETRY_HTML", str(SCRIPT_DIR / "telemetry" / "index.html"))),
            telemetry_webhook=arena_hook or _env("TELEMETRY_WEBHOOK", ""),
            log_file=_env("LEASE_MANAGER_LOG", ""),
            pid_file=Path(_env("LEASE_MANAGER_PIDFILE", str(SCRIPT_DIR / "state" / "lease-manager.pid"))),
            interval_seconds=_env_int("HEALTH_CHECK_INTERVAL", 60),
            health_timeout=_env_int("HEALTH_TIMEOUT", 10),
            health_path=_env("HEALTH_PATH", "/healthz"),
            health_retries=_env_int("HEALTH_RETRIES", 3),
            health_retry_delay=_env_int("HEALTH_RETRY_DELAY", 5),
            failure_threshold=_env_int("FAILURE_THRESHOLD", 2),
            deploy_timeout=_env_int("DEPLOY_TIMEOUT", 600),
            desired_workers=_env_int("DESIRED_WORKERS", 1),
            close_dead_leases=_env_bool("CLOSE_DEAD_LEASES", True),
            dry_run=_env_bool("DRY_RUN", False),
        )


# ---------------------------------------------------------------------------
# Worker model + state persistence
# ---------------------------------------------------------------------------
@dataclass
class Worker:
    id: str
    url: str
    dseq: str = ""
    provider: str = ""
    price: Any = None
    status: str = "unknown"          # healthy | unhealthy | provisioning | dead
    consecutive_failures: int = 0
    last_ok: str = ""
    last_checked: str = ""
    created: str = ""
    replaced_count: int = 0
    extra_uris: list[str] = field(default_factory=list)

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "Worker":
        known = {f for f in cls.__dataclass_fields__}  # type: ignore[attr-defined]
        return cls(**{k: v for k, v in d.items() if k in known})


class State:
    def __init__(self, path: Path):
        self.path = path
        self.workers: list[Worker] = []
        self.load()

    def load(self) -> None:
        if self.path.is_file():
            try:
                data = json.loads(self.path.read_text())
                self.workers = [Worker.from_dict(w) for w in data.get("workers", [])]
            except (json.JSONDecodeError, TypeError) as exc:
                logging.warning("could not parse state file %s: %s", self.path, exc)
                self.workers = []

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "updated": _now(),
            "workers": [asdict(w) for w in self.workers],
        }
        tmp = self.path.with_suffix(self.path.suffix + ".tmp")
        tmp.write_text(json.dumps(payload, indent=2))
        tmp.replace(self.path)


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ---------------------------------------------------------------------------
# Health checking
# ---------------------------------------------------------------------------
def _normalize_url(url: str, health_path: str) -> str:
    if "://" not in url:
        url = "http://" + url
    if health_path:
        return url.rstrip("/") + "/" + health_path.lstrip("/")
    return url


def _http_check(url: str, timeout: int) -> bool:
    req = urllib.request.Request(url, method="GET", headers={"User-Agent": "akash-lease-manager/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310 (trusted internal URL)
            return 200 <= resp.status < 400
    except urllib.error.HTTPError as exc:
        # A 4xx/5xx still means the host is reachable; treat 5xx as unhealthy.
        return exc.code < 500
    except (urllib.error.URLError, socket.timeout, ConnectionError, OSError):
        return False


def _tcp_check(url: str, timeout: int) -> bool:
    target = url.split("://", 1)[-1].split("/", 1)[0]
    host, _, port_s = target.partition(":")
    port = int(port_s) if port_s.isdigit() else (443 if url.startswith("https") else 80)
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def check_worker_health(worker: Worker, cfg: Config) -> bool:
    """Return True if the worker is healthy, with retries."""
    probe = _normalize_url(worker.url, cfg.health_path)
    for attempt in range(1, cfg.health_retries + 1):
        if _http_check(probe, cfg.health_timeout) or _tcp_check(worker.url, cfg.health_timeout):
            return True
        if attempt < cfg.health_retries:
            logging.debug("health probe %s failed (attempt %d/%d)", probe, attempt, cfg.health_retries)
            time.sleep(cfg.health_retry_delay)
    return False


# ---------------------------------------------------------------------------
# Vault integration (deploy-host credentials)
# ---------------------------------------------------------------------------
def _load_vault_akash_config() -> None:
    """Load Akash wallet + RPC from Vault KV when configured."""
    if not _env_bool("VAULT_LOAD_AKASH", True):
        return
    if not os.environ.get("VAULT_ADDR"):
        return
    root = SCRIPT_DIR.parent
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))
    try:
        from lib.secrets import KV_MOUNT_DEFAULT, _read_kv_path, _approle_login
        import hvac  # noqa: F401
    except ImportError:
        logging.debug("lib.secrets/hvac unavailable — skipping Vault config load")
        return

    token = os.environ.get("VAULT_TOKEN") or _approle_login()
    if token:
        os.environ.setdefault("VAULT_TOKEN", token)

    data = _read_kv_path(KV_MOUNT_DEFAULT, "runtime/akash")
    mapping = {
        "key_name": "AKASH_KEY_NAME",
        "mnemonic": "AKASH_WALLET_MNEMONIC",
        "node": "AKASH_NODE",
        "chain_id": "AKASH_CHAIN_ID",
    }
    for src, dst in mapping.items():
        if data.get(src) and not os.environ.get(dst):
            os.environ[dst] = str(data[src])
    if data:
        logging.info("loaded Akash deploy config from Vault (runtime/akash)")


# ---------------------------------------------------------------------------
# Akash deploy integration
# ---------------------------------------------------------------------------
def provision_worker(cfg: Config, *, sdl: Path | None = None, bid_max: str | None = None,
                     gpu_model: str | None = None) -> dict[str, Any] | None:
    """Call akash-deploy.sh to provision a worker. Returns lease info."""
    env = os.environ.copy()
    if sdl:
        env["AKASH_SDL_FILE"] = str(sdl)
    if bid_max:
        env["AKASH_MAX_BID_PRICE"] = bid_max.lstrip("u").replace("uakt", "").strip() or bid_max
    if gpu_model:
        env["AKASH_GPU_MODEL"] = gpu_model

    if cfg.dry_run:
        role = gpu_model or "worker"
        logging.info("[dry-run] would run: %s deploy %s", cfg.deploy_script, env.get("AKASH_SDL_FILE", ""))
        return {
            "ok": True,
            "dseq": f"dry-{int(time.time())}",
            "provider": "akash1dryrunprovider",
            "price": int(env.get("AKASH_MAX_BID_PRICE", "0") or 0),
            "uris": [f"http://dry-run-{role}-{int(time.time())}.example"],
            "worker_url": f"http://dry-run-{role}-{int(time.time())}.example",
            "role": role,
        }

    cmd = ["bash", cfg.deploy_script, "deploy"]
    if sdl:
        cmd.append(str(sdl))
    logging.info("provisioning worker via %s (gpu=%s bid_max=%s)",
                 " ".join(cmd), env.get("AKASH_GPU_MODEL"), env.get("AKASH_MAX_BID_PRICE"))
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True,
            timeout=cfg.deploy_timeout, check=False, env=env,
        )
    except subprocess.TimeoutExpired:
        logging.error("akash-deploy.sh deploy timed out after %ds", cfg.deploy_timeout)
        return None

    if result.returncode != 0:
        logging.error("akash-deploy.sh deploy failed (rc=%d): %s",
                      result.returncode, result.stderr.strip()[-2000:])
        return None

    # The deploy command prints JSON as the last JSON object on stdout.
    info = _extract_last_json(result.stdout)
    if not info or not info.get("ok"):
        logging.error("could not parse deploy output: %s", result.stdout.strip()[-2000:])
        return None
    logging.info("provisioned worker dseq=%s provider=%s url=%s",
                 info.get("dseq"), info.get("provider"), info.get("worker_url"))
    return info


def _parse_bid_max(raw: str) -> str:
    """Normalize '100000uakt' -> '100000'."""
    return raw.lower().replace("uakt", "").strip()


def deploy_profile(cfg: Config, profile: str, *, gpu: str | None = None,
                   bid_max: str | None = None) -> dict[str, Any]:
    """Deploy miner or backend SDL and persist to leases.json."""
    preset = DEPLOY_PROFILES.get(profile)
    if not preset:
        raise ValueError(f"unknown deploy profile: {profile}")

    sdl = Path(preset["sdl"])
    if not sdl.is_file():
        raise FileNotFoundError(f"SDL not found: {sdl}")

    info = provision_worker(
        cfg,
        sdl=sdl,
        bid_max=bid_max or preset["bid_max"],
        gpu_model=gpu or preset.get("gpu") or None,
    )
    if not info:
        raise RuntimeError(f"deploy failed for profile={profile}")

    info["role"] = preset["role"]
    info["profile"] = profile
    info["deployed_at"] = _now()
    _record_lease(info)
    return info


def _load_leases_state() -> dict[str, Any]:
    path = Path(_env("LEASES_STATE_FILE", str(LEASES_STATE_FILE)))
    if not path.is_file():
        return {"version": 1, "leases": []}
    return json.loads(path.read_text(encoding="utf-8"))


def _save_leases_state(data: dict[str, Any]) -> None:
    path = Path(_env("LEASES_STATE_FILE", str(LEASES_STATE_FILE)))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def _record_lease(info: dict[str, Any]) -> None:
    state = _load_leases_state()
    leases: list[dict[str, Any]] = state.setdefault("leases", [])
    # Replace existing lease for same profile
    leases = [l for l in leases if l.get("profile") != info.get("profile")]
    leases.append(info)
    state["leases"] = leases
    state["updated_at"] = _now()
    _save_leases_state(state)
    logging.info("recorded lease profile=%s dseq=%s url=%s",
                 info.get("profile"), info.get("dseq"), info.get("worker_url"))


def print_leases_status() -> int:
    state = _load_leases_state()
    print(json.dumps(state, indent=2))
    return 0


def close_lease(cfg: Config, dseq: str) -> None:
    if not dseq or cfg.dry_run:
        logging.info("[dry-run] would close lease dseq=%s", dseq)
        return
    cmd = ["bash", cfg.deploy_script, "close", dseq]
    logging.info("closing dead lease dseq=%s", dseq)
    try:
        result = subprocess.run(cmd, capture_output=True, text=True,
                                timeout=cfg.deploy_timeout, check=False)
        if result.returncode != 0:
            logging.warning("failed to close lease dseq=%s: %s", dseq, result.stderr.strip()[-500:])
    except subprocess.TimeoutExpired:
        logging.warning("close lease dseq=%s timed out", dseq)


def _extract_last_json(text: str) -> dict[str, Any] | None:
    """Find the last top-level JSON object in a blob of text."""
    depth = 0
    start = -1
    candidates: list[str] = []
    for i, ch in enumerate(text):
        if ch == "{":
            if depth == 0:
                start = i
            depth += 1
        elif ch == "}":
            if depth > 0:
                depth -= 1
                if depth == 0 and start != -1:
                    candidates.append(text[start:i + 1])
    for blob in reversed(candidates):
        try:
            return json.loads(blob)
        except json.JSONDecodeError:
            continue
    return None


# ---------------------------------------------------------------------------
# Telemetry
# ---------------------------------------------------------------------------
def update_telemetry(cfg: Config, state: State) -> None:
    healthy = [w for w in state.workers if w.status == "healthy"]
    payload = {
        "service": "akash-gpu-fleet",
        "gpu_model": _env("AKASH_GPU_MODEL", "rtx3090"),
        "updated": _now(),
        "summary": {
            "total": len(state.workers),
            "healthy": len(healthy),
            "unhealthy": len([w for w in state.workers if w.status != "healthy"]),
            "desired": cfg.desired_workers,
        },
        "worker_urls": [w.url for w in healthy],
        "workers": [
            {
                "id": w.id,
                "url": w.url,
                "status": w.status,
                "provider": w.provider,
                "dseq": w.dseq,
                "last_ok": w.last_ok,
                "last_checked": w.last_checked,
                "replaced_count": w.replaced_count,
            }
            for w in state.workers
        ],
    }

    cfg.telemetry_json.parent.mkdir(parents=True, exist_ok=True)
    tmp = cfg.telemetry_json.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(payload, indent=2))
    tmp.replace(cfg.telemetry_json)
    logging.info("telemetry written: %d healthy / %d total workers",
                 payload["summary"]["healthy"], payload["summary"]["total"])

    _render_html(cfg, payload)
    _push_webhook(cfg, payload)


def _render_html(cfg: Config, payload: dict[str, Any]) -> None:
    rows = []
    for w in payload["workers"]:
        color = "live" if w["status"] == "healthy" else "critical"
        url = w["url"]
        link = f'<a href="{url}" target="_blank" style="color:inherit">{url}</a>'
        rows.append(
            f'<tr><td>{w["id"]}</td><td class="{color}">{w["status"]}</td>'
            f'<td>{link}</td><td>{w["provider"] or "-"}</td>'
            f'<td>{w["dseq"] or "-"}</td><td>{w["replaced_count"]}</td>'
            f'<td>{w["last_ok"] or "-"}</td></tr>'
        )
    table = "\n".join(rows) or '<tr><td colspan="7">no workers tracked</td></tr>'
    s = payload["summary"]
    html = f"""<!DOCTYPE html>
<html><head><title>Akash GPU Fleet Telemetry</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="30">
<style>
body{{font-family:monospace;background:#000;color:#0f0;padding:20px}}
h1{{color:#0f0}} .live{{color:#0f0}} .critical{{color:#f00}}
.card{{background:#111;border:1px solid #0f0;padding:15px;margin:10px 0;border-radius:8px}}
table{{width:100%;border-collapse:collapse}}
th,td{{border:1px solid #0f0;padding:8px;text-align:left;font-size:13px;word-break:break-all}}
th{{background:#0f0;color:#000}}
.muted{{color:#0a0}}
</style></head><body>
<h1>Akash GPU Fleet ({payload['gpu_model'].upper()})</h1>
<div class="card">
  <p>Healthy: <span class="live">{s['healthy']}</span> /
     Total: {s['total']} /
     Desired: {s['desired']} /
     Unhealthy: <span class="critical">{s['unhealthy']}</span></p>
  <p class="muted">Last updated: {payload['updated']} (auto-refresh 30s)</p>
</div>
<div class="card">
<table>
<tr><th>ID</th><th>Status</th><th>Worker URL</th><th>Provider</th>
    <th>DSEQ</th><th>Replaced</th><th>Last OK</th></tr>
{table}
</table>
</div>
<p class="muted">Managed by lease-manager.py - auto-failover to best RTX 3090 provider.</p>
</body></html>
"""
    cfg.telemetry_html.parent.mkdir(parents=True, exist_ok=True)
    tmp = cfg.telemetry_html.with_suffix(".html.tmp")
    tmp.write_text(html)
    tmp.replace(cfg.telemetry_html)


def _push_webhook(cfg: Config, payload: dict[str, Any]) -> None:
    if not cfg.telemetry_webhook:
        return
    if cfg.dry_run:
        logging.info("[dry-run] would POST telemetry to %s", cfg.telemetry_webhook)
        return
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        cfg.telemetry_webhook, data=data, method="POST",
        headers={"Content-Type": "application/json", "User-Agent": "akash-lease-manager/1.0"},
    )
    try:
        with urllib.request.urlopen(req, timeout=cfg.health_timeout) as resp:  # noqa: S310
            logging.info("telemetry webhook POST -> %s", resp.status)
    except (urllib.error.URLError, socket.timeout, OSError) as exc:
        logging.warning("telemetry webhook failed: %s", exc)


# ---------------------------------------------------------------------------
# Reconciliation cycle
# ---------------------------------------------------------------------------
def reconcile(cfg: Config, state: State) -> None:
    changed = False

    # 1. Health-check existing workers.
    for worker in state.workers:
        worker.last_checked = _now()
        healthy = check_worker_health(worker, cfg)
        if healthy:
            if worker.status != "healthy":
                logging.info("worker %s recovered: %s", worker.id, worker.url)
            worker.status = "healthy"
            worker.consecutive_failures = 0
            worker.last_ok = _now()
        else:
            worker.consecutive_failures += 1
            worker.status = "unhealthy"
            logging.warning("worker %s unhealthy (%d/%d): %s",
                            worker.id, worker.consecutive_failures,
                            cfg.failure_threshold, worker.url)
        changed = True

    # 2. Replace workers that have failed beyond the threshold.
    for worker in state.workers:
        if worker.status == "healthy":
            continue
        if worker.consecutive_failures < cfg.failure_threshold:
            continue

        logging.error("worker %s is DEAD; provisioning replacement", worker.id)
        worker.status = "dead"
        info = provision_worker(cfg)
        if not info:
            logging.error("replacement provisioning failed for %s; will retry next cycle", worker.id)
            continue

        old_dseq = worker.dseq
        worker.url = info.get("worker_url") or (info.get("uris") or [worker.url])[0]
        worker.dseq = str(info.get("dseq", ""))
        worker.provider = info.get("provider", "")
        worker.price = info.get("price")
        worker.extra_uris = info.get("uris", []) or []
        worker.status = "healthy"
        worker.consecutive_failures = 0
        worker.created = _now()
        worker.last_ok = _now()
        worker.replaced_count += 1
        changed = True
        logging.info("worker %s replaced -> %s (provider=%s)", worker.id, worker.url, worker.provider)

        if cfg.close_dead_leases and old_dseq:
            close_lease(cfg, old_dseq)

    # 3. Scale up to the desired worker count if we are short.
    while len([w for w in state.workers if w.status in {"healthy", "provisioning"}]) < cfg.desired_workers:
        new_id = f"gpu-{len(state.workers) + 1}-{int(time.time())}"
        logging.info("fleet below desired size; provisioning new worker %s", new_id)
        info = provision_worker(cfg)
        if not info:
            logging.error("scale-up provisioning failed; will retry next cycle")
            break
        state.workers.append(Worker(
            id=new_id,
            url=info.get("worker_url") or (info.get("uris") or [""])[0],
            dseq=str(info.get("dseq", "")),
            provider=info.get("provider", ""),
            price=info.get("price"),
            extra_uris=info.get("uris", []) or [],
            status="healthy",
            last_ok=_now(),
            created=_now(),
        ))
        changed = True

    if changed:
        state.save()
    update_telemetry(cfg, state)


# ---------------------------------------------------------------------------
# Runtime: logging, signals, pidfile, loop
# ---------------------------------------------------------------------------
_RUNNING = True


def _handle_signal(signum, _frame):  # noqa: ANN001
    global _RUNNING
    logging.info("received signal %s; shutting down after current cycle", signum)
    _RUNNING = False


def _setup_logging(cfg: Config) -> None:
    handlers: list[logging.Handler] = [logging.StreamHandler(sys.stdout)]
    if cfg.log_file:
        Path(cfg.log_file).parent.mkdir(parents=True, exist_ok=True)
        handlers.append(logging.FileHandler(cfg.log_file))
    level = logging.DEBUG if _env_bool("DEBUG", False) else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%SZ",
        handlers=handlers,
    )


def _write_pidfile(cfg: Config) -> None:
    cfg.pid_file.parent.mkdir(parents=True, exist_ok=True)
    cfg.pid_file.write_text(str(os.getpid()))


def _remove_pidfile(cfg: Config) -> None:
    try:
        cfg.pid_file.unlink()
    except FileNotFoundError:
        pass


def main(argv: list[str] | None = None) -> int:
    _load_dotenv()
    _load_vault_akash_config()
    parser = argparse.ArgumentParser(description="Akash GPU lease manager / auto-failover supervisor")
    parser.add_argument("--once", action="store_true", help="run a single reconcile pass and exit (cron mode)")
    parser.add_argument("--interval", type=int, help="override health-check interval in seconds")
    parser.add_argument("--dry-run", action="store_true", help="do not call Akash; simulate provisioning")
    parser.add_argument("--add-worker", metavar="URL", help="register a worker URL in state and exit")
    parser.add_argument("--add-dseq", metavar="DSEQ", default="", help="DSEQ to associate with --add-worker")
    parser.add_argument("--add-provider", metavar="PROVIDER", default="", help="provider for --add-worker")
    parser.add_argument("--status", action="store_true", help="print current fleet state as JSON and exit")
    parser.add_argument("--deploy", choices=sorted(DEPLOY_PROFILES.keys()),
                        help="deploy dual-service SDL (miner=H100, backend=CPU) and exit")
    parser.add_argument("--gpu", default="", help="override GPU model for --deploy miner (default: h100)")
    parser.add_argument("--bid-max", default="", metavar="UAKT",
                        help="max bid price e.g. 100000uakt or 1500uakt")
    parser.add_argument("--leases", action="store_true",
                        help="print dual-service leases.json state and exit")
    args = parser.parse_args(argv)

    cfg = Config.from_env()
    if args.interval:
        cfg.interval_seconds = args.interval
    if args.dry_run:
        cfg.dry_run = True

    _setup_logging(cfg)
    state = State(cfg.state_file)

    if args.leases:
        return print_leases_status()

    if args.deploy:
        try:
            bid = _parse_bid_max(args.bid_max) if args.bid_max else None
            gpu = args.gpu or None
            info = deploy_profile(cfg, args.deploy, gpu=gpu, bid_max=bid)
            print(json.dumps({"ok": True, "lease": info}, indent=2))
            return 0
        except Exception as exc:
            logging.exception("deploy failed")
            print(json.dumps({"ok": False, "error": str(exc)}))
            return 1

    if args.status:
        print(json.dumps({"workers": [asdict(w) for w in state.workers]}, indent=2))
        return 0

    if args.add_worker:
        wid = f"gpu-{len(state.workers) + 1}-{int(time.time())}"
        state.workers.append(Worker(
            id=wid, url=args.add_worker, dseq=args.add_dseq,
            provider=args.add_provider, status="unknown", created=_now(),
        ))
        state.save()
        update_telemetry(cfg, state)
        logging.info("registered worker %s -> %s", wid, args.add_worker)
        return 0

    signal.signal(signal.SIGINT, _handle_signal)
    signal.signal(signal.SIGTERM, _handle_signal)

    logging.info("akash lease-manager starting (interval=%ds, desired=%d, dry_run=%s)",
                 cfg.interval_seconds, cfg.desired_workers, cfg.dry_run)

    if args.once:
        try:
            reconcile(cfg, state)
        except Exception:  # noqa: BLE001 - never crash a cron run silently
            logging.exception("reconcile pass failed")
            return 1
        return 0

    _write_pidfile(cfg)
    try:
        while _RUNNING:
            cycle_start = time.monotonic()
            try:
                reconcile(cfg, state)
            except Exception:  # noqa: BLE001 - keep the daemon alive across errors
                logging.exception("reconcile cycle failed; continuing")
            elapsed = time.monotonic() - cycle_start
            sleep_for = max(1.0, cfg.interval_seconds - elapsed)
            # Sleep in small slices so signals are handled promptly.
            slept = 0.0
            while _RUNNING and slept < sleep_for:
                time.sleep(min(1.0, sleep_for - slept))
                slept += 1.0
    finally:
        _remove_pidfile(cfg)
        logging.info("lease-manager stopped")
    return 0


if __name__ == "__main__":
    sys.exit(main())
