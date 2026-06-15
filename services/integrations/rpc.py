"""Multi-provider RPC failover — Infura, Ankr, QuickNode."""

from __future__ import annotations

import json
import os
from typing import Any

from services.integrations.config import CouncilIntegrationConfig, load_council_config
from services.integrations.http_util import http_json


def build_failover_rpc_list(config: CouncilIntegrationConfig | None = None) -> list[str]:
    cfg = config or load_council_config()
    endpoints: list[str] = []

    for url in (
        cfg.quicknode_rpc_url,
        cfg.infura_sol_mainnet_rpc,
        cfg.ankr_rpc_multichain,
        os.getenv("ETHEREUM_RPC_URL"),
        os.getenv("SOLANA_RPC_URL"),
    ):
        if url and url not in endpoints:
            endpoints.append(url)

    raw = os.getenv("FAILOVER_RPC_LIST")
    if raw:
        try:
            extra = json.loads(raw)
            if isinstance(extra, list):
                for item in extra:
                    if isinstance(item, str) and item not in endpoints:
                        endpoints.append(item)
        except json.JSONDecodeError:
            pass
    return endpoints


def probe_rpc(url: str) -> dict[str, Any]:
    if not url:
        return {"configured": False, "live": False, "error": "missing url"}
    payload = {"jsonrpc": "2.0", "id": 1, "method": "getHealth", "params": []}
    try:
        status, body = http_json(url, method="POST", body=payload, timeout=6.0)
    except Exception as exc:  # noqa: BLE001
        return {"configured": True, "live": False, "error": str(exc)}

    live = status == 200 and isinstance(body, dict)
    if not live and status == 200:
        # Ethereum-style chains respond to eth_blockNumber
        eth_payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}
        try:
            status, body = http_json(url, method="POST", body=eth_payload, timeout=6.0)
            live = status == 200 and isinstance(body, dict) and "result" in body
        except Exception as exc:  # noqa: BLE001
            return {"configured": True, "live": False, "error": str(exc)}

    return {"configured": True, "live": live, "status_code": status}


def rpc_health(config: CouncilIntegrationConfig | None = None) -> dict[str, Any]:
    cfg = config or load_council_config()
    providers: dict[str, Any] = {}

    if cfg.quicknode_rpc_url:
        providers["quicknode"] = probe_rpc(cfg.quicknode_rpc_url)
    else:
        providers["quicknode"] = {"configured": bool(cfg.quicknode_api_key), "live": False}

    if cfg.infura_sol_mainnet_rpc:
        providers["infura"] = probe_rpc(cfg.infura_sol_mainnet_rpc)
    else:
        providers["infura"] = {
            "configured": bool(cfg.infura_project_id or cfg.infura_api_key),
            "live": False,
        }

    if cfg.ankr_rpc_multichain:
        providers["ankr"] = probe_rpc(cfg.ankr_rpc_multichain)
    else:
        providers["ankr"] = {"configured": bool(cfg.ankr_api_key), "live": False}

    failover = build_failover_rpc_list(cfg)
    return {
        "providers": providers,
        "failover_count": len(failover),
        "primary": failover[0] if failover else None,
    }
