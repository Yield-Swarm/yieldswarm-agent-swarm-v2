"""Persistence layer for Kairo bridge."""

from __future__ import annotations

import json
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator

from kairo.config import settings


def _utcnow() -> str:
    return datetime.now(timezone.utc).isoformat()


class Database:
    def __init__(self, path: str | None = None) -> None:
        self.path = path or settings.database_path
        Path(self.path).parent.mkdir(parents=True, exist_ok=True)
        self._init_schema()

    @contextmanager
    def connect(self) -> Iterator[sqlite3.Connection]:
        conn = sqlite3.connect(self.path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
            conn.commit()
        finally:
            conn.close()

    def _init_schema(self) -> None:
        with self.connect() as conn:
            conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS drivers (
                    id TEXT PRIMARY KEY,
                    kairo_user_id TEXT UNIQUE NOT NULL,
                    evm_address TEXT NOT NULL,
                    iotex_address TEXT NOT NULL,
                    public_key_hex TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    depin_helium_pubkey TEXT,
                    depin_grass_node_id TEXT,
                    license_key TEXT,
                    metadata_json TEXT DEFAULT '{}'
                );

                CREATE TABLE IF NOT EXISTS telemetry_events (
                    id TEXT PRIMARY KEY,
                    driver_id TEXT NOT NULL,
                    recorded_at TEXT NOT NULL,
                    latitude REAL NOT NULL,
                    longitude REAL NOT NULL,
                    speed_mps REAL NOT NULL,
                    acceleration_mps2 REAL NOT NULL,
                    heading_deg REAL,
                    route_segment_id TEXT,
                    payload_hash TEXT NOT NULL,
                    signature_hex TEXT NOT NULL,
                    mandelbrot_shard INTEGER NOT NULL,
                    tree_of_life_node TEXT NOT NULL,
                    verified INTEGER NOT NULL DEFAULT 0,
                    distance_delta_km REAL DEFAULT 0,
                    FOREIGN KEY (driver_id) REFERENCES drivers(id)
                );

                CREATE INDEX IF NOT EXISTS idx_telemetry_driver
                    ON telemetry_events(driver_id, recorded_at);

                CREATE TABLE IF NOT EXISTS contribution_ledger (
                    id TEXT PRIMARY KEY,
                    driver_id TEXT NOT NULL,
                    period_start TEXT NOT NULL,
                    period_end TEXT NOT NULL,
                    total_distance_km REAL NOT NULL,
                    signed_packets INTEGER NOT NULL,
                    mandelbrot_shards_json TEXT NOT NULL,
                    hnt_estimate_usd REAL NOT NULL,
                    grass_estimate_usd REAL NOT NULL,
                    akt_estimate_usd REAL NOT NULL,
                    pay_multiplier REAL NOT NULL DEFAULT 1.0,
                    base_pay_usd REAL NOT NULL,
                    total_pay_usd REAL NOT NULL,
                    payout_status TEXT NOT NULL DEFAULT 'pending',
                    created_at TEXT NOT NULL,
                    FOREIGN KEY (driver_id) REFERENCES drivers(id)
                );

                CREATE TABLE IF NOT EXISTS payout_events (
                    id TEXT PRIMARY KEY,
                    driver_id TEXT NOT NULL,
                    ledger_id TEXT,
                    amount_usd REAL NOT NULL,
                    multiplier REAL NOT NULL,
                    rail TEXT NOT NULL,
                    destination TEXT NOT NULL,
                    status TEXT NOT NULL DEFAULT 'quoted',
                    created_at TEXT NOT NULL,
                    FOREIGN KEY (driver_id) REFERENCES drivers(id)
                );
                """
            )

    def insert(self, table: str, row: dict[str, Any]) -> None:
        cols = ", ".join(row.keys())
        placeholders = ", ".join("?" for _ in row)
        with self.connect() as conn:
            conn.execute(
                f"INSERT INTO {table} ({cols}) VALUES ({placeholders})",
                tuple(row.values()),
            )

    def fetchone(self, query: str, params: tuple[Any, ...] = ()) -> dict[str, Any] | None:
        with self.connect() as conn:
            row = conn.execute(query, params).fetchone()
            return dict(row) if row else None

    def fetchall(self, query: str, params: tuple[Any, ...] = ()) -> list[dict[str, Any]]:
        with self.connect() as conn:
            return [dict(r) for r in conn.execute(query, params).fetchall()]

    def execute(self, query: str, params: tuple[Any, ...] = ()) -> None:
        with self.connect() as conn:
            conn.execute(query, params)


db = Database()
