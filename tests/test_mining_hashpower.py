"""Tests for mining hashpower and profitability modules."""

from __future__ import annotations

import json
from pathlib import Path

from mining.hashpower import fleet_hashpower_report, gpu_tier_from_name
from mining.profitability import profitability_report, top_coins_for_tier


def test_gpu_tier_detection():
    assert gpu_tier_from_name("NVIDIA H100 SXM") == "h100_sxm"
    assert gpu_tier_from_name("NVIDIA B200") == "b200"


def test_fleet_hashpower_report():
    report = fleet_hashpower_report()
    assert report["pod_count"] >= 3
    assert report["totals"]["est_kaspa_ghs"] >= 10


def test_profitability_report():
    report = profitability_report("h100_sxm")
    assert report["hardware_tier"] == "h100_sxm"
    assert len(report["top_coins"]) >= 1
    assert report["top_coins"][0]["coin"] in ("KAS", "QUBIC", "ALPH")


def test_coin_rankings_file_valid_json():
    path = Path(__file__).resolve().parents[1] / "config" / "mining" / "coin-rankings.json"
    data = json.loads(path.read_text())
    assert "rankings" in data
    assert len(data["rankings"]) >= 4
