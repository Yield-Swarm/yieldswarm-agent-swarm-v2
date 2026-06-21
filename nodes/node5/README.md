# Node 5 — PyHackathon Stellar + Cosmos

Modular cross-chain node integrated with the YieldSwarm sovereign orchestrator.

See [docs/NODE5_STELLAR_COSMOS.md](../../docs/NODE5_STELLAR_COSMOS.md).

```python
from nodes.node5 import run_cycle
run_cycle(actions=["status", "balance"])
```

**Note:** The original `Node 5/` PyHackathon folder was not present in the repo at integration time. This package implements the production module structure. Drop legacy PyHackathon modules into `nodes/node5/legacy/` and re-export from `orchestrator.py` if needed.
