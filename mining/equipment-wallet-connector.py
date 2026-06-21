# Mining Equipment Wallet Connector
# Delegates to unified mining manager for wallet routing + status.

import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

from mining.manager import UnifiedMiningManager

print("[mining] equipment-wallet-connector → unified mining manager")
mgr = UnifiedMiningManager()
configs = mgr.write_configs()
status = mgr.status()
print(f"[mining] wallets: {status.get('wallets')}")
print(f"[mining] fleet: {status.get('running_count')}/{status.get('total')} running")

if os.getenv("MINING_AUTO_START", "").lower() in ("1", "true", "yes"):
    mgr.start()
