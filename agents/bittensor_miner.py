#!/usr/bin/env python3
"""Bittensor miner with Ollama inference backend — axon on port 8091."""

from __future__ import annotations

import json
import os
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

STATUS_FILE = Path(os.environ.get("BITTENSOR_STATUS_FILE", "/run/bittensor/status.json"))
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "llama3.1:8b")
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434")


def write_status(**fields: object) -> None:
    STATUS_FILE.parent.mkdir(parents=True, exist_ok=True)
    base = {
        "running": True,
        "netuid": os.environ.get("BT_NETUID"),
        "network": os.environ.get("BT_NETWORK", "finney"),
        "axon_port": int(os.environ.get("BT_AXON_PORT", "8091")),
        "model": OLLAMA_MODEL,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    base.update(fields)
    STATUS_FILE.write_text(json.dumps(base, indent=2))


def ollama_generate(prompt: str) -> tuple[str, float]:
    payload = json.dumps({"model": OLLAMA_MODEL, "prompt": prompt, "stream": False}).encode()
    start = time.time()
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/generate",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = json.loads(resp.read())
    latency_ms = (time.time() - start) * 1000
    return data.get("response", ""), latency_ms


def run_miner() -> None:
    import bittensor as bt

    netuid = int(os.environ["BT_NETUID"])
    network = os.environ.get("BT_NETWORK", "finney")
    axon_port = int(os.environ.get("BT_AXON_PORT", "8091"))
    wallet_name = os.environ.get("BT_WALLET_NAME", "miner")
    hotkey_name = os.environ.get("BT_HOTKEY_NAME", "default")

    wallet = bt.wallet(name=wallet_name, hotkey=hotkey_name)
    subtensor = bt.subtensor(network=network)

    def forward(synapse: bt.Synapse) -> bt.Synapse:
        prompt = getattr(synapse, "prompt", None) or str(synapse)
        try:
            response, latency_ms = ollama_generate(prompt)
            write_status(
                hotkey=wallet.hotkey.ss58_address,
                last_challenge_at=datetime.now(timezone.utc).isoformat(),
                last_challenge_ms=round(latency_ms, 2),
                last_prompt_preview=prompt[:120],
            )
            # Record for telemetry server if importable
            try:
                from agents.bittensor_telemetry_server import record_inference

                record_inference(latency_ms)
            except ImportError:
                pass
            if hasattr(synapse, "response"):
                synapse.response = response
        except Exception as exc:
            write_status(last_error=str(exc))
        return synapse

    axon = bt.axon(wallet=wallet, port=axon_port)
    axon.attach(forward_fn=forward)
    axon.serve(netuid=netuid, subtensor=subtensor)
    axon.start()

    write_status(hotkey=wallet.hotkey.ss58_address, axon_started=True)
    print(f"Bittensor axon serving netuid={netuid} on :{axon_port}", flush=True)

    while True:
        time.sleep(30)
        write_status(hotkey=wallet.hotkey.ss58_address, heartbeat=True)


if __name__ == "__main__":
    if not os.environ.get("BT_NETUID"):
        raise SystemExit("BT_NETUID is required")
    run_miner()
