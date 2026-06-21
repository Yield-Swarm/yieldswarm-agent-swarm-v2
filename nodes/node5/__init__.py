"""
Node 5 — PyHackathon Stellar (XLM) + Cosmos SDK integration.

Production entrypoints:
  - :func:`nodes.node5.orchestrator.run_cycle` — sovereign loop tick
  - :class:`nodes.node5.stellar.client.StellarClient` — Horizon / payments
  - :class:`nodes.node5.cosmos.client.CosmosClient` — Cosmos REST queries
"""

from nodes.node5.config import Node5Config, load_node5_config
from nodes.node5.orchestrator import Node5Orchestrator, run_cycle

__all__ = [
    "Node5Config",
    "load_node5_config",
    "Node5Orchestrator",
    "run_cycle",
]

__version__ = "1.0.0"
