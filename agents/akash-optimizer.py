"""Akash optimizer bootstrap.

This process is intentionally strict about required configuration so the
container fails closed when Vault injection is missing or incomplete.
"""

from __future__ import annotations

import json
import logging
import os
import sys
from typing import Iterable


REQUIRED_ENV_VARS = (
    "AKASH_API_KEY",
    "SOLANA_RPC_URL",
    "GPU_CLUSTER_KEYS",
)

OPTIONAL_JSON_LISTS = (
    "DEPIN_HELIUM_HOTSPOT_KEYS",
    "GPU_CLUSTER_KEYS",
    "GRASS_NODE_KEYS",
    "X_API_KEYS",
    "FAILOVER_RPC_LIST",
)


def configure_logging() -> None:
    level_name = os.getenv("LOG_LEVEL", "INFO").upper()
    level = getattr(logging, level_name, logging.INFO)
    logging.basicConfig(
        level=level,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )


def require_env(keys: Iterable[str]) -> dict[str, str]:
    missing = [key for key in keys if not os.getenv(key)]
    if missing:
        raise RuntimeError(
            "Vault runtime injection did not populate required variables: "
            + ", ".join(sorted(missing))
        )

    return {key: os.environ[key] for key in keys}


def parse_json_list(name: str) -> list[str]:
    raw = os.getenv(name, "[]")
    try:
        decoded = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"{name} must be valid JSON: {exc}") from exc

    if not isinstance(decoded, list):
        raise RuntimeError(f"{name} must decode to a JSON list")

    return [str(item) for item in decoded]


def main() -> int:
    configure_logging()
    logger = logging.getLogger("akash-optimizer")
    required = require_env(REQUIRED_ENV_VARS)

    parsed_lists = {name: parse_json_list(name) for name in OPTIONAL_JSON_LISTS}
    logger.info(
        "Akash optimizer bootstrap complete: rpc_host=%s gpu_clusters=%d failover_rpcs=%d",
        required["SOLANA_RPC_URL"].split("/")[2] if "://" in required["SOLANA_RPC_URL"] else "configured",
        len(parsed_lists["GPU_CLUSTER_KEYS"]),
        len(parsed_lists["FAILOVER_RPC_LIST"]),
    )
    logger.info(
        "Vault runtime secrets are loaded; ready to attach Akash lease optimization logic."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001
        logging.getLogger("akash-optimizer").error("Startup failed: %s", exc)
        raise SystemExit(1) from exc