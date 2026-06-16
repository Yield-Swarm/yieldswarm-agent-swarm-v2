"""Neon Postgres telemetry sink — Mandelbrot driver mesh + Helix Chain snapshots.

When DATABASE_URL is unset, events append to JSONL under NEON_FALLBACK_DIR so
local dev and CI stay green without a live Neon project.
"""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
SCHEMA_PATH = REPO_ROOT / "telemetry" / "neon" / "schema.sql"
FALLBACK_DIR = Path(os.environ.get("NEON_FALLBACK_DIR", ".data/neon"))


def neon_logging_enabled() -> bool:
    return os.environ.get("NEON_LOG_ENABLED", "true").lower() in ("1", "true", "yes")


def database_url() -> str | None:
    url = os.environ.get("DATABASE_URL", "").strip()
    if url.startswith("postgres"):
        return url
    return None


def _fallback_path(stream: str) -> Path:
    FALLBACK_DIR.mkdir(parents=True, exist_ok=True)
    return FALLBACK_DIR / f"{stream}.jsonl"


def _append_fallback(stream: str, row: dict[str, Any]) -> str:
    path = _fallback_path(stream)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(row, default=str) + "\n")
    return str(path)


def _connect():
    import psycopg  # type: ignore

    return psycopg.connect(database_url())


def ensure_schema() -> bool:
    """Apply telemetry/neon/schema.sql when DATABASE_URL is configured."""
    url = database_url()
    if not url:
        return False
    sql = SCHEMA_PATH.read_text(encoding="utf-8")
    with _connect() as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
        conn.commit()
    return True


def log_mandelbrot(record: dict[str, Any]) -> dict[str, Any]:
    """Persist one Mandelbrot-routed Kairo telemetry record."""
    if not neon_logging_enabled():
        return {"ok": False, "skipped": True, "reason": "NEON_LOG_ENABLED=false"}

    tree = record.get("tree") or {}
    row = {
        "telemetry_id": record.get("telemetry_id"),
        "driver_id": record.get("driver_id"),
        "evm_address": record.get("evm_address"),
        "shard_id": tree.get("shard_id"),
        "branch": tree.get("branch"),
        "leaf": tree.get("leaf"),
        "mandelbrot_score": tree.get("mandelbrot_score"),
        "reward_weight": tree.get("reward_weight"),
        "speed_kmh": tree.get("speed_kmh"),
        "signed_at": record.get("signed_at"),
        "payload": record.get("payload") or {},
        "tree": tree,
        "logged_at": datetime.now(timezone.utc).isoformat(),
    }

    url = database_url()
    if not url:
        path = _append_fallback("mandelbrot_telemetry", row)
        return {"ok": True, "sink": "file", "path": path, "telemetry_id": row["telemetry_id"]}

    with _connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO mandelbrot_telemetry (
                  telemetry_id, driver_id, evm_address, shard_id, branch, leaf,
                  mandelbrot_score, reward_weight, speed_kmh, signed_at, payload, tree
                ) VALUES (
                  %(telemetry_id)s, %(driver_id)s, %(evm_address)s, %(shard_id)s,
                  %(branch)s, %(leaf)s, %(mandelbrot_score)s, %(reward_weight)s,
                  %(speed_kmh)s, %(signed_at)s, %(payload)s::jsonb, %(tree)s::jsonb
                )
                RETURNING id
                """,
                {
                    **row,
                    "payload": json.dumps(row["payload"]),
                    "tree": json.dumps(row["tree"]),
                },
            )
            neon_id = cur.fetchone()[0]
        conn.commit()
    return {"ok": True, "sink": "neon", "id": neon_id, "telemetry_id": row["telemetry_id"]}


def log_helix(snapshot: dict[str, Any]) -> dict[str, Any]:
    """Persist one Helix Chain status snapshot."""
    if not neon_logging_enabled():
        return {"ok": False, "skipped": True, "reason": "NEON_LOG_ENABLED=false"}

    sovereign = snapshot.get("sovereign") or {}
    receipts = snapshot.get("onChainReceipts") or {}
    row = {
        "phase": snapshot.get("phase") or "unknown",
        "activated": bool(snapshot.get("activated")),
        "genesis_hash": snapshot.get("genesisHash"),
        "readiness_score": snapshot.get("readinessScore"),
        "yslr_phase": (snapshot.get("yslr") or {}).get("phase"),
        "sovereign_progress": sovereign.get("progress"),
        "treasury_nav_usd": receipts.get("treasuryNavUsd"),
        "snapshot": snapshot,
        "logged_at": datetime.now(timezone.utc).isoformat(),
    }

    url = database_url()
    if not url:
        path = _append_fallback("helix_chain_snapshots", row)
        return {"ok": True, "sink": "file", "path": path, "phase": row["phase"]}

    with _connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO helix_chain_snapshots (
                  phase, activated, genesis_hash, readiness_score, yslr_phase,
                  sovereign_progress, treasury_nav_usd, snapshot
                ) VALUES (
                  %(phase)s, %(activated)s, %(genesis_hash)s, %(readiness_score)s,
                  %(yslr_phase)s, %(sovereign_progress)s, %(treasury_nav_usd)s,
                  %(snapshot)s::jsonb
                )
                RETURNING id
                """,
                {**row, "snapshot": json.dumps(row["snapshot"])},
            )
            neon_id = cur.fetchone()[0]
        conn.commit()
    return {"ok": True, "sink": "neon", "id": neon_id, "phase": row["phase"]}


def recent_counts() -> dict[str, int]:
    """Row counts for health checks (file fallback counts JSONL lines)."""
    url = database_url()
    if url:
        with _connect() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) FROM mandelbrot_telemetry")
                mandelbrot = int(cur.fetchone()[0])
                cur.execute("SELECT COUNT(*) FROM helix_chain_snapshots")
                helix = int(cur.fetchone()[0])
        return {"mandelbrot_telemetry": mandelbrot, "helix_chain_snapshots": helix}

    counts: dict[str, int] = {}
    for stream in ("mandelbrot_telemetry", "helix_chain_snapshots"):
        path = _fallback_path(stream)
        if not path.exists():
            counts[stream] = 0
            continue
        with path.open(encoding="utf-8") as handle:
            counts[stream] = sum(1 for _ in handle)
    return counts


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="Neon telemetry store utilities")
    parser.add_argument("--migrate", action="store_true", help="Apply telemetry/neon/schema.sql")
    parser.add_argument("--counts", action="store_true", help="Print row counts")
    args = parser.parse_args()

    if args.migrate:
        if ensure_schema():
            print(json.dumps({"ok": True, "migrated": True}))
        else:
            print(json.dumps({"ok": False, "error": "DATABASE_URL not set"}))
        return

    if args.counts:
        print(json.dumps({"ok": True, "counts": recent_counts()}))
        return

    parser.print_help()


if __name__ == "__main__":
    main()
