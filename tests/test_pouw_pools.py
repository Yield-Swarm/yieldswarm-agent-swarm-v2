"""Tests for PoWUoI mining pool launch (six coins)."""

from __future__ import annotations

import json
import os
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]


def test_pouw_registry_lists_six_coins():
    from mining.pouw_registry import list_pouw_coins, yieldswarm_coin_symbol

    coins = list_pouw_coins()
    assert len(coins) == 6
    symbols = {c.symbol for c in coins}
    assert symbols == {"PRL", "KRX", "ZANO", "QTC", "IRON", "TON"}
    assert yieldswarm_coin_symbol() == "PRL"


def test_pouw_miners_registered():
    from mining.miners import MINER_REGISTRY

    for name in ("prl", "krx", "zano", "qtc", "iron", "ton"):
        assert name in MINER_REGISTRY


def test_pool_switcher_tick():
    from swarms.mining_pools.engines.pool_switcher import PoolSwitcher

    state = PoolSwitcher().tick()
    assert state["attribution"]["treasurySplit"] == "50,30,15,5"
    assert state["schemaVersion"] == "mining-pools/v1"


def test_pouw_launcher_dry_run(monkeypatch: pytest.MonkeyPatch, tmp_path: Path):
    monkeypatch.setenv("MINING_ROOT_PRL", "29L3dA5XvXUthBJeanarcTij6e5fdtAD81PxQMfEEQQ9")
    monkeypatch.setenv("MINING_WALLET_KRX", "krx-wallet-test")
    monkeypatch.setenv("MINING_WALLET_ZANO", "zano-wallet-test")
    monkeypatch.setenv("MINING_WALLET_QTC", "qtc-wallet-test")
    monkeypatch.setenv("MINING_WALLET_IRON", "iron-wallet-test")
    monkeypatch.setenv("MINING_WALLET_TON", "ton-wallet-test")
    monkeypatch.setenv("MINING_DRY_RUN", "1")
    monkeypatch.setenv("MINING_RUN_DIR", str(tmp_path / "mining"))

    from mining.pouw_launcher import PouwPoolLauncher

    launcher = PouwPoolLauncher()
    result = launcher.launch()
    assert result["ok"] is True
    assert result["yieldswarm_coin"] == "PRL"
    assert len(result["enabled_coins"]) == 6

    state_path = Path(result["helical_state_path"])
    assert state_path.exists()
    state = json.loads(state_path.read_text(encoding="utf-8"))
    assert state["schemaVersion"] == "mining-pools/v1"
    assert state["ecosystem"] == "PoWUoI"
    assert len(state["pools"]) == 6
    prl = next(p for p in state["pools"] if p["coin"] == "PRL")
    assert prl["yieldswarmNative"] is True
    assert prl["status"] == "active"


def test_pouw_registry_default_pools():
    from mining.pouw_registry import list_pouw_coins

    prl = next(c for c in list_pouw_coins() if c.symbol == "PRL")
    assert prl.srbminer_algorithm == "pearlhash"
    assert prl.default_pool_url == "prl.2miners.com:1818"
    assert prl.algorithm == "ProgPowZ"

    iron = next(c for c in list_pouw_coins() if c.symbol == "IRON")
    assert iron.srbminer_algorithm == "fishhash"
    assert iron.algorithm == "FishHash"


def test_pearl_rejects_etc_pool_and_solana_wallet():
    import subprocess

    env = os.environ.copy()
    env["MINING_ROOT_PRL"] = "WXJ1EqmxfkpiYHaVm8SKGMbH6sRPXBJcHnpEpndBkg3"
    env["MINING_POOL_URL_PRL"] = "etc.2miners.com:1010"
    env["MINING_DRY_RUN"] = "1"

    proc = subprocess.run(
        ["bash", "scripts/mining/deploy-pearl-srbminer.sh"],
        cwd=REPO_ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert proc.returncode != 0
    assert "Ethereum Classic" in proc.stderr or "Ethereum Classic" in proc.stdout


def test_pearl_accepts_prl1_wallet_dry_run():
    import subprocess

    proc = subprocess.run(
        ["bash", "scripts/mining/deploy-pearl-srbminer.sh"],
        cwd=REPO_ROOT,
        env={
            **os.environ,
            "MINING_ROOT_PRL": "prl1p5d0pjdre96sv29dq9q8qpjtrrvkglr93efljk6p90w38qqacztgqnhvcjl",
            "PRL_WORKER_NAME": "16xH100-RunPod-Fleet1",
            "MINING_DRY_RUN": "1",
        },
        capture_output=True,
        text=True,
        check=False,
    )
    assert proc.returncode == 0
    assert "16xH100-RunPod-Fleet1" in proc.stdout
    assert "prl.2miners.com:1818" in proc.stdout


def test_render_akash_sdls(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("MINING_ROOT_PRL", "29L3dA5XvXUthBJeanarcTij6e5fdtAD81PxQMfEEQQ9")
    monkeypatch.setenv("MINING_WALLET_KRX", "krx-wallet-test")
    monkeypatch.setenv("MINING_WALLET_ZANO", "zano-wallet-test")
    monkeypatch.setenv("MINING_WALLET_QTC", "qtc-wallet-test")
    monkeypatch.setenv("MINING_WALLET_IRON", "iron-wallet-test")
    monkeypatch.setenv("MINING_WALLET_TON", "ton-wallet-test")

    from mining.pouw_launcher import PouwPoolLauncher

    sdls = PouwPoolLauncher().render_all_sdls()
    assert len(sdls) == 6
    prl_sdl = Path(sdls["PRL"])
    assert prl_sdl.exists()
    content = prl_sdl.read_text(encoding="utf-8")
    assert "PRL" in content
    assert "prl" in content
    assert "${POWU_SYMBOL}" not in content
