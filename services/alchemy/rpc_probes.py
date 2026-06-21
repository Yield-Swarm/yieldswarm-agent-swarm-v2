"""JSON-RPC probes per chain family with retry and exponential backoff."""

from __future__ import annotations

import json
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Optional, Tuple

ZERO_EVM = "0x0000000000000000000000000000000000000000"
DEFAULT_TIMEOUT_S = 20.0
DEFAULT_RETRIES = 3
DEFAULT_BACKOFF_BASE_S = 0.5


@dataclass
class ProbeOutcome:
    ok: bool
    latency_ms: float
    chain_id: Optional[str] = None
    last_block: Optional[str] = None
    read_value: Optional[str] = None
    block_moving: Optional[bool] = None
    rate_limit_ok: Optional[bool] = None
    notes: List[str] = field(default_factory=list)
    error: Optional[str] = None


def _http_json_rpc(
    url: str,
    payload: Dict[str, Any],
    *,
    timeout_s: float = DEFAULT_TIMEOUT_S,
) -> Tuple[Dict[str, Any], float]:
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        method="POST",
    )
    started = time.perf_counter()
    with urllib.request.urlopen(req, timeout=timeout_s) as resp:
        raw = resp.read().decode("utf-8")
    latency_ms = (time.perf_counter() - started) * 1000.0
    return json.loads(raw), latency_ms


def with_retries(
    fn: Callable[[], ProbeOutcome],
    *,
    retries: int = DEFAULT_RETRIES,
    backoff_base_s: float = DEFAULT_BACKOFF_BASE_S,
) -> ProbeOutcome:
    last: Optional[ProbeOutcome] = None
    for attempt in range(retries):
        try:
            result = fn()
            if result.ok:
                return result
            last = result
        except Exception as exc:  # noqa: BLE001
            last = ProbeOutcome(ok=False, latency_ms=0.0, error=str(exc))
        if attempt < retries - 1:
            time.sleep(backoff_base_s * (2**attempt))
    return last or ProbeOutcome(ok=False, latency_ms=0.0, error="unknown failure")


def _rpc_call(
    url: str,
    method: str,
    params: Optional[List[Any]] = None,
    *,
    req_id: int = 1,
    timeout_s: float = DEFAULT_TIMEOUT_S,
) -> Tuple[Any, float]:
    payload = {"jsonrpc": "2.0", "id": req_id, "method": method, "params": params or []}
    data, latency_ms = _http_json_rpc(url, payload, timeout_s=timeout_s)
    if "error" in data:
        err = data["error"]
        msg = err.get("message", err) if isinstance(err, dict) else str(err)
        code = err.get("code") if isinstance(err, dict) else None
        raise RuntimeError(f"RPC error {code}: {msg}")
    return data.get("result"), latency_ms


def _light_rate_limit_probe(url: str, method: str, params: Optional[List[Any]] = None) -> bool:
    """Three rapid calls; pass if none return HTTP 429."""
    for i in range(3):
        try:
            _rpc_call(url, method, params, req_id=100 + i, timeout_s=10.0)
        except urllib.error.HTTPError as exc:
            if exc.code == 429:
                return False
        except Exception:
            pass
    return True


def probe_evm(url: str) -> ProbeOutcome:
    notes: List[str] = []
    total_latency = 0.0

    def run() -> ProbeOutcome:
        nonlocal total_latency
        chain_id, lat = _rpc_call(url, "eth_chainId")
        total_latency += lat
        block_hex, lat2 = _rpc_call(url, "eth_blockNumber", req_id=2)
        total_latency += lat2
        block_num = int(block_hex, 16) if isinstance(block_hex, str) else None

        time.sleep(0.35)
        block_hex_b, lat3 = _rpc_call(url, "eth_blockNumber", req_id=3)
        total_latency += lat3
        block_num_b = int(block_hex_b, 16) if isinstance(block_hex_b, str) else None
        moving = (
            block_num is not None
            and block_num_b is not None
            and block_num_b >= block_num
        )

        read_val: Optional[str] = None
        try:
            bal, lat4 = _rpc_call(
                url, "eth_getBalance", [ZERO_EVM, "latest"], req_id=4
            )
            total_latency += lat4
            read_val = str(bal)
        except Exception as exc:  # noqa: BLE001
            try:
                gas, lat4 = _rpc_call(url, "eth_gasPrice", req_id=4)
                total_latency += lat4
                read_val = str(gas)
                notes.append(f"eth_getBalance skipped: {exc}")
            except Exception as exc2:  # noqa: BLE001
                notes.append(f"read call failed: {exc2}")
                return ProbeOutcome(
                    ok=False,
                    latency_ms=total_latency,
                    chain_id=str(chain_id),
                    last_block=str(block_num),
                    block_moving=moving,
                    notes=notes,
                    error=str(exc2),
                )

        rate_ok = _light_rate_limit_probe(url, "eth_blockNumber")
        if not rate_ok:
            notes.append("rate-limit probe saw HTTP 429")

        return ProbeOutcome(
            ok=True,
            latency_ms=total_latency,
            chain_id=str(chain_id),
            last_block=str(block_num_b if block_num_b is not None else block_num),
            read_value=read_val,
            block_moving=moving,
            rate_limit_ok=rate_ok,
            notes=notes,
        )

    try:
        return with_retries(run)
    except Exception as exc:  # noqa: BLE001
        return ProbeOutcome(ok=False, latency_ms=total_latency, error=str(exc), notes=notes)


def probe_solana(url: str) -> ProbeOutcome:
    total_latency = 0.0

    def run() -> ProbeOutcome:
        nonlocal total_latency
        slot_a, lat = _rpc_call(url, "getSlot", req_id=1)
        total_latency += lat
        time.sleep(0.35)
        slot_b, lat2 = _rpc_call(url, "getSlot", req_id=2)
        total_latency += lat2
        bal, lat3 = _rpc_call(
            url,
            "getBalance",
            ["11111111111111111111111111111111"],
            req_id=3,
        )
        total_latency += lat3
        rate_ok = _light_rate_limit_probe(url, "getSlot")
        return ProbeOutcome(
            ok=True,
            latency_ms=total_latency,
            chain_id="solana",
            last_block=str(slot_b),
            read_value=str(bal),
            block_moving=slot_b >= slot_a,
            rate_limit_ok=rate_ok,
        )

    try:
        return with_retries(run)
    except Exception as exc:  # noqa: BLE001
        return ProbeOutcome(ok=False, latency_ms=total_latency, error=str(exc))


def probe_starknet(url: str) -> ProbeOutcome:
    total_latency = 0.0

    def run() -> ProbeOutcome:
        nonlocal total_latency
        chain_id, lat = _rpc_call(url, "starknet_chainId", req_id=1)
        total_latency += lat
        block, lat2 = _rpc_call(url, "starknet_blockNumber", req_id=2)
        total_latency += lat2
        time.sleep(0.35)
        block_b, lat3 = _rpc_call(url, "starknet_blockNumber", req_id=3)
        total_latency += lat3
        rate_ok = _light_rate_limit_probe(url, "starknet_blockNumber")
        return ProbeOutcome(
            ok=True,
            latency_ms=total_latency,
            chain_id=str(chain_id),
            last_block=str(block_b),
            block_moving=int(str(block_b), 0) >= int(str(block), 0) if block_b and block else None,
            rate_limit_ok=rate_ok,
        )

    try:
        return with_retries(run)
    except Exception as exc:  # noqa: BLE001
        return ProbeOutcome(ok=False, latency_ms=total_latency, error=str(exc))


def probe_bitcoin(url: str) -> ProbeOutcome:
    total_latency = 0.0

    def run() -> ProbeOutcome:
        nonlocal total_latency
        height, lat = _rpc_call(url, "getblockcount", req_id=1)
        total_latency += lat
        time.sleep(0.35)
        height_b, lat2 = _rpc_call(url, "getblockcount", req_id=2)
        total_latency += lat2
        return ProbeOutcome(
            ok=True,
            latency_ms=total_latency,
            chain_id="bitcoin",
            last_block=str(height_b),
            block_moving=height_b >= height,
            rate_limit_ok=_light_rate_limit_probe(url, "getblockcount"),
        )

    try:
        return with_retries(run)
    except Exception as exc:  # noqa: BLE001
        return ProbeOutcome(ok=False, latency_ms=total_latency, error=str(exc))


def probe_sui(url: str) -> ProbeOutcome:
    total_latency = 0.0

    def run() -> ProbeOutcome:
        nonlocal total_latency
        checkpoint, lat = _rpc_call(url, "sui_getLatestCheckpointSequenceNumber", req_id=1)
        total_latency += lat
        time.sleep(0.35)
        checkpoint_b, lat2 = _rpc_call(url, "sui_getLatestCheckpointSequenceNumber", req_id=2)
        total_latency += lat2
        return ProbeOutcome(
            ok=True,
            latency_ms=total_latency,
            chain_id="sui",
            last_block=str(checkpoint_b),
            block_moving=int(checkpoint_b) >= int(checkpoint),
            rate_limit_ok=_light_rate_limit_probe(url, "sui_getLatestCheckpointSequenceNumber"),
        )

    try:
        return with_retries(run)
    except Exception as exc:  # noqa: BLE001
        return ProbeOutcome(ok=False, latency_ms=total_latency, error=str(exc))


def probe_aptos(url: str) -> ProbeOutcome:
    total_latency = 0.0

    def run() -> ProbeOutcome:
        nonlocal total_latency
        ledger, lat = _rpc_call(url, "get_ledger_info", req_id=1)
        total_latency += lat
        block = None
        if isinstance(ledger, dict):
            block = ledger.get("block_height")
        return ProbeOutcome(
            ok=True,
            latency_ms=total_latency,
            chain_id="aptos",
            last_block=str(block) if block is not None else None,
            block_moving=block is not None,
            rate_limit_ok=_light_rate_limit_probe(url, "get_ledger_info"),
        )

    try:
        return with_retries(run)
    except Exception as exc:  # noqa: BLE001
        return ProbeOutcome(ok=False, latency_ms=total_latency, error=str(exc))


def probe_tron(url: str) -> ProbeOutcome:
    total_latency = 0.0

    def run() -> ProbeOutcome:
        nonlocal total_latency
        block, lat = _rpc_call(url, "eth_blockNumber", req_id=1)
        total_latency += lat
        return ProbeOutcome(
            ok=True,
            latency_ms=total_latency,
            chain_id="tron",
            last_block=str(int(block, 16)) if isinstance(block, str) else str(block),
            block_moving=True,
            rate_limit_ok=_light_rate_limit_probe(url, "eth_blockNumber"),
        )

    try:
        return with_retries(run)
    except Exception as exc:  # noqa: BLE001
        return ProbeOutcome(ok=False, latency_ms=total_latency, error=str(exc))


def probe_beacon(url: str) -> ProbeOutcome:
    """Beacon chains — best-effort via eth_chainId / eth_blockNumber."""
    return probe_evm(url)


def probe_network(url: str, rpc_family: str) -> ProbeOutcome:
    probes = {
        "evm": probe_evm,
        "solana": probe_solana,
        "starknet": probe_starknet,
        "bitcoin": probe_bitcoin,
        "sui": probe_sui,
        "aptos": probe_aptos,
        "tron": probe_tron,
        "beacon": probe_beacon,
    }
    probe = probes.get(rpc_family, probe_evm)
    return probe(url)
