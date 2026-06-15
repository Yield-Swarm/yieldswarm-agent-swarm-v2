"""Sync Akash RTX 3090 worker state from live lease URLs into the model router."""

from __future__ import annotations

import json
import os
import re
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Dict, List, Optional

from services.yieldswarm_model_router import WorkerState

REPO_ROOT = Path(__file__).resolve().parents[1]
LEASE_ENV_PATH = Path(os.getenv("AKASH_LEASE_ENV", REPO_ROOT / ".run" / "akash-lease.env"))
HEALTH_PATH = os.getenv("AKASH_WORKER_HEALTH_PATH", "/healthz")
PROBE_TIMEOUT = float(os.getenv("AKASH_WORKER_PROBE_TIMEOUT", "4"))


def _parse_env_file(path: Path) -> Dict[str, str]:
    if not path.is_file():
        return {}
    values: Dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        values[key.strip()] = val.strip().strip('"').strip("'")
    return values


def _worker_urls_from_env() -> List[str]:
    urls: List[str] = []
    lease = _parse_env_file(LEASE_ENV_PATH)
    raw = os.getenv("AKASH_WORKER_URLS") or lease.get("AKASH_WORKER_URLS", "")
    if raw:
        urls.extend(u.strip() for u in raw.split(",") if u.strip())
    json_raw = os.getenv("YIELDSWARM_AKASH_WORKERS")
    if json_raw:
        try:
            for item in json.loads(json_raw):
                uri = item.get("provider_uri") or item.get("url")
                if uri:
                    urls.append(str(uri).rstrip("/"))
        except json.JSONDecodeError:
            pass
    seen: set[str] = set()
    deduped: List[str] = []
    for url in urls:
        if url not in seen:
            seen.add(url)
            deduped.append(url)
    return deduped


def _probe_worker(url: str) -> Dict[str, Any]:
    """HTTP health probe; returns health_score and optional queue hints."""
    health_url = url.rstrip("/") + HEALTH_PATH
    started = time.time()
    try:
        req = urllib.request.Request(health_url, headers={"Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=PROBE_TIMEOUT) as resp:  # noqa: S310
            latency_ms = (time.time() - started) * 1000
            body = resp.read().decode("utf-8", errors="replace")
            score = 1.0 if resp.status < 400 else 0.4
            queue_depth = 0
            try:
                data = json.loads(body)
                if isinstance(data, dict):
                    queue_depth = int(data.get("queue_depth") or data.get("queueDepth") or 0)
                    if data.get("status") in {"degraded", "error"}:
                        score = 0.5
            except json.JSONDecodeError:
                pass
            if latency_ms > 2000:
                score = max(0.3, score - 0.2)
            return {"live": True, "health_score": score, "queue_depth": queue_depth, "latency_ms": latency_ms}
    except Exception as exc:
        return {"live": False, "health_score": 0.1, "queue_depth": 99, "error": str(exc)}


def _worker_id_from_url(url: str, index: int) -> str:
    match = re.search(r"([a-z0-9-]+)\.akash", url, re.I)
    if match:
        return f"akash-rtx3090-{match.group(1)[:12]}"
    return f"akash-rtx3090-{index}"


def _ollama_base_url(worker_url: str) -> str:
    """Derive Ollama OpenAI-compatible base for LiteLLM."""
    explicit = os.getenv("AKASH_OLLAMA_BASE_URL")
    if explicit:
        return explicit.rstrip("/")
    port = os.getenv("AKASH_OLLAMA_PORT", "11434")
    parsed = worker_url.rstrip("/")
    if parsed.startswith("http"):
        # Same host, Ollama port (internal Akash sidecar pattern).
        return re.sub(r":\d+$", f":{port}", parsed) if re.search(r":\d+$", parsed) else f"{parsed}:{port}"
    return f"http://{parsed}:{port}"


def sync_workers_from_akash(*, probe: bool = True) -> List[WorkerState]:
    """Build WorkerState list from live Akash lease URLs."""
    urls = _worker_urls_from_env()
    if not urls:
        return []

    workers: List[WorkerState] = []
    for index, url in enumerate(urls, start=1):
        probe_result = _probe_worker(url) if probe else {"live": True, "health_score": 0.8, "queue_depth": 0}
        health = float(probe_result.get("health_score", 0.5))
        queue = int(probe_result.get("queue_depth", 0))
        if not probe_result.get("live", False):
            health = min(health, 0.35)
            queue = max(queue, 8)

        workers.append(
            WorkerState(
                worker_id=_worker_id_from_url(url, index),
                provider_uri=url.rstrip("/"),
                gpu_model=os.getenv("AKASH_GPU_MODEL", "RTX 3090"),
                queue_depth=queue,
                health_score=health,
                great_delta_signal=0.15 + health * 0.5,
            )
        )
    return workers


def sync_workers_json(*, probe: bool = True) -> str:
    """JSON blob suitable for YIELDSWARM_AKASH_WORKERS env injection."""
    workers = sync_workers_from_akash(probe=probe)
    payload = [
        {
            "worker_id": w.worker_id,
            "provider_uri": w.provider_uri,
            "gpu_model": w.gpu_model,
            "queue_depth": w.queue_depth,
            "health_score": w.health_score,
            "great_delta_signal": w.great_delta_signal,
            "ollama_base_url": _ollama_base_url(w.provider_uri),
        }
        for w in workers
    ]
    return json.dumps(payload)


def primary_ollama_base_url() -> Optional[str]:
    """Best Akash Ollama endpoint for LiteLLM AKASH_OLLAMA_BASE_URL."""
    workers = sync_workers_from_akash(probe=True)
    if not workers:
        return None
    best = sorted(workers, key=lambda w: (-w.health_score, w.queue_depth))[0]
    return _ollama_base_url(best.provider_uri)
