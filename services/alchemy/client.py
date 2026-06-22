"""
Vault-backed Alchemy multi-chain client (Python Rolodex).

Supports all networks in config/alchemy/christophers-first-app.json.
Optional SDK adapters: web3.py (EVM), solana-py (Solana).
"""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

from services.alchemy.manifest import (
    DEFAULT_NETWORK_IDS,
    AlchemyNetwork,
    get_network,
    list_networks,
)
from services.alchemy.vault_client import get_alchemy_api_key, mask_api_key, optional_api_key


@dataclass
class RpcPingResult:
    network_id: str
    family: str
    ok: bool
    latency_ms: float
    block_or_slot: Optional[str] = None
    error: Optional[str] = None


class AlchemyRolodex:
    """Multi-chain Alchemy RPC resolver — key from Vault, URLs built at runtime."""

    def __init__(self, api_key: Optional[str] = None, *, require_key: bool = True):
        if api_key:
            self._api_key = api_key
        elif require_key:
            self._api_key = get_alchemy_api_key()
        else:
            self._api_key = optional_api_key() or ""

    @property
    def api_key_mask(self) -> str:
        return mask_api_key(self._api_key)

    @property
    def configured(self) -> bool:
        return bool(self._api_key)

    def rpc_url(self, network_id: str) -> str:
        if not self._api_key:
            raise RuntimeError("ALCHEMY_API_KEY not configured")
        return get_network(network_id).build_url(self._api_key)

    def rpc_url_alias(self, alias: str) -> str:
        net_id = DEFAULT_NETWORK_IDS.get(alias)
        if not net_id:
            raise KeyError(f"unknown alias: {alias}")
        return self.rpc_url(net_id)

    def list_networks(self, *, family: Optional[str] = None) -> List[AlchemyNetwork]:
        nets = list_networks()
        if family:
            nets = [n for n in nets if n.family == family]
        return nets

    def resolve_defaults(self) -> Dict[str, str]:
        if not self._api_key:
            return {}
        out: Dict[str, str] = {}
        for alias, net_id in DEFAULT_NETWORK_IDS.items():
            try:
                out[alias] = self.rpc_url(net_id)
            except KeyError:
                continue
        return out

    def apply_env_defaults(self, *, overwrite: bool = False) -> List[str]:
        """Set process env RPC URLs from Alchemy defaults (explicit env wins by default)."""
        applied: List[str] = []
        env_map = {
            "SOLANA_RPC_URL": "solana",
            "ETHEREUM_RPC_URL": "ethereum",
            "EVM_RPC_URL": "ethereum",
            "BASE_RPC_URL": "base",
            "EVM_RPC_URL_8453": "base",
            "EVM_RPC_URL_137": "polygon",
            "EVM_RPC_URL_42161": "arbitrum",
            "SEPOLIA_RPC_URL": "ethereum_sepolia",
        }
        defaults = self.resolve_defaults()
        for env_key, alias in env_map.items():
            url = defaults.get(alias)
            if not url:
                continue
            if overwrite or not os.getenv(env_key):
                os.environ[env_key] = url
                applied.append(env_key)
        if self._api_key and (overwrite or not os.getenv("ALCHEMY_API_KEY")):
            os.environ["ALCHEMY_API_KEY"] = self._api_key
            applied.append("ALCHEMY_API_KEY")
        return applied

    def web3(self, network_id: str = "ethereum-mainnet"):
        """Return web3.Web3 HTTP provider for an EVM network."""
        try:
            from web3 import Web3
        except ImportError as exc:
            raise RuntimeError("pip install web3") from exc
        net = get_network(network_id)
        if net.family not in ("evm", "beacon"):
            raise ValueError(f"{network_id} is not EVM (family={net.family})")
        return Web3(Web3.HTTPProvider(self.rpc_url(network_id)))

    def solana_client(self, network_id: str = "solana-mainnet"):
        """Return solana.rpc.api.Client for Solana."""
        try:
            from solana.rpc.api import Client
        except ImportError as exc:
            raise RuntimeError("pip install solana") from exc
        net = get_network(network_id)
        if net.family != "solana":
            raise ValueError(f"{network_id} is not Solana")
        return Client(self.rpc_url(network_id))

    def json_rpc(self, network_id: str, method: str, params: Optional[List[Any]] = None) -> Any:
        url = self.rpc_url(network_id)
        payload = json.dumps(
            {"jsonrpc": "2.0", "id": 1, "method": method, "params": params or []}
        ).encode()
        req = urllib.request.Request(
            url,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode())
        if "error" in data:
            raise RuntimeError(data["error"])
        return data.get("result")

    def ping(self, network_id: str) -> RpcPingResult:
        import time

        net = get_network(network_id)
        started = time.perf_counter()
        try:
            if net.family == "solana":
                slot = self.json_rpc(network_id, "getSlot")
                block = str(slot)
            elif net.family == "starknet":
                block = str(self.json_rpc(network_id, "starknet_blockNumber"))
            elif net.family == "evm":
                block = str(int(self.json_rpc(network_id, "eth_blockNumber"), 16))
            else:
                block = str(self.json_rpc(network_id, "eth_blockNumber"))
            latency = (time.perf_counter() - started) * 1000.0
            return RpcPingResult(network_id, net.family, True, latency, block)
        except Exception as exc:  # noqa: BLE001
            latency = (time.perf_counter() - started) * 1000.0
            return RpcPingResult(network_id, net.family, False, latency, error=str(exc))

    def ping_defaults(self) -> List[RpcPingResult]:
        return [self.ping(net_id) for net_id in DEFAULT_NETWORK_IDS.values()]
