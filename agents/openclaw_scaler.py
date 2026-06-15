"""OpenClaw Scaler Agent — scales agent interfaces across cloud credits."""

import os

from lib.secrets import init_secrets


def run() -> None:
    init_secrets()
    shard = os.environ.get("AGENT_SHARD_ID", "0")
    print(f"OpenClaw Scaler active — shard={shard}")


if __name__ == "__main__":
    run()
