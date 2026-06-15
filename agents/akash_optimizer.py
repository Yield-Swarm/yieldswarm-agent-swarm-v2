"""Akash Optimizer Agent — secrets loaded at runtime via Vault."""

import os

from lib.secrets import init_secrets


def run() -> None:
    init_secrets()
    shard_id = os.environ.get("AGENT_SHARD_ID", "0")
    gpu_keys = os.environ.get("GPU_CLUSTER_KEYS", "[]")
    print(f"Akash Optimizer active — shard={shard_id}, gpu_keys_configured={gpu_keys != '[]'}")


if __name__ == "__main__":
    run()
