"""Agent runner — loads Vault-injected secrets and starts shard agents."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lib.secrets import init_secrets


def main() -> None:
    init_secrets()

    from agents.akash_optimizer import run
    from agents.chainlink_vault_manager import run as run_vault
    from agents.openclaw_scaler import run as run_scaler

    print("YieldSwarm AgentSwarm OS starting...")
    run()
    run_vault()
    run_scaler()


if __name__ == "__main__":
    main()
