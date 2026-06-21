"""Orchestrate multi-chain Alchemy RPC smoke tests."""

from __future__ import annotations

import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from typing import List, Optional

from services.alchemy.network_registry import AlchemyNetwork, load_networks, partition_networks
from services.alchemy.rpc_probes import ProbeOutcome, probe_network
from services.alchemy.vault_client import get_alchemy_api_key, mask_api_key, validate_key_prefix


@dataclass
class ChainCheckResult:
    network: AlchemyNetwork
    status: str  # pass | fail
    latency_ms: float
    chain_id: Optional[str] = None
    last_block: Optional[str] = None
    notes: str = ""
    error: Optional[str] = None
    checks: dict = field(default_factory=dict)


@dataclass
class SmokeTestReport:
    started_at: str
    finished_at: str
    api_key_mask: str
    prefix_warning: Optional[str]
    total: int
    passed: int
    failed: int
    mainnet_results: List[ChainCheckResult]
    testnet_results: List[ChainCheckResult]

    @property
    def failed_chains(self) -> List[ChainCheckResult]:
        return [r for r in self.mainnet_results + self.testnet_results if r.status == "fail"]


def _format_notes(outcome: ProbeOutcome) -> str:
    parts = []
    if outcome.block_moving is False:
        parts.append("block not advancing")
    if outcome.rate_limit_ok is False:
        parts.append("rate limited (429)")
    if outcome.notes:
        parts.extend(outcome.notes)
    if outcome.error:
        parts.append(outcome.error)
    return "; ".join(parts) if parts else "ok"


def check_one(network: AlchemyNetwork, api_key: str) -> ChainCheckResult:
    url = network.rpc_url(api_key)
    outcome = probe_network(url, network.rpc_family)
    status = "pass" if outcome.ok else "fail"
    return ChainCheckResult(
        network=network,
        status=status,
        latency_ms=round(outcome.latency_ms, 1),
        chain_id=outcome.chain_id,
        last_block=outcome.last_block,
        notes=_format_notes(outcome),
        error=outcome.error,
        checks={
            "chainId": outcome.chain_id,
            "lastBlock": outcome.last_block,
            "readCall": outcome.read_value,
            "blockMoving": outcome.block_moving,
            "rateLimitOk": outcome.rate_limit_ok,
        },
    )


def run_smoke_test(
    *,
    networks: Optional[List[AlchemyNetwork]] = None,
    api_key: Optional[str] = None,
    max_workers: int = 8,
    progress: bool = True,
) -> SmokeTestReport:
    key = api_key or get_alchemy_api_key()
    prefix_warning = validate_key_prefix(key)
    nets = networks if networks is not None else load_networks()
    mainnets, testnets = partition_networks(nets)

    started = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    def run_batch(batch: List[AlchemyNetwork]) -> List[ChainCheckResult]:
        results: List[ChainCheckResult] = []
        with ThreadPoolExecutor(max_workers=max_workers) as pool:
            futures = {pool.submit(check_one, n, key): n for n in batch}
            done = 0
            total = len(batch)
            for fut in as_completed(futures):
                results.append(fut.result())
                done += 1
                if progress:
                    net = futures[fut]
                    print(f"[{done}/{total}] {net.name}", flush=True)
        results.sort(key=lambda r: r.network.name)
        return results

    mainnet_results = run_batch(mainnets)
    testnet_results = run_batch(testnets)
    finished = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    all_results = mainnet_results + testnet_results
    passed = sum(1 for r in all_results if r.status == "pass")

    return SmokeTestReport(
        started_at=started,
        finished_at=finished,
        api_key_mask=mask_api_key(key),
        prefix_warning=prefix_warning,
        total=len(all_results),
        passed=passed,
        failed=len(all_results) - passed,
        mainnet_results=mainnet_results,
        testnet_results=testnet_results,
    )
