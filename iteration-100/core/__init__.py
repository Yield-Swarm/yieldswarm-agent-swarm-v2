"""Iteration 100 — Sovereign Self-Governed Core.

A runnable, dependency-free reference implementation of the YieldSwarm
"sovereign core loop": autonomous agent mutation, self-healing Akash leases,
dynamic treasury rebalancing, and the Great Delta Grid marketplace router.

Everything here runs on the Python standard library so it can execute on a
bare VM, a Vercel/Azure function, or an Akash worker without extra packages.
Where a real external API (Akash RPC, Chainlink price feeds, provider bids)
would normally be called, the module reads from the environment first and
falls back to a deterministic-but-evolving simulation so the loop is always
observable end to end.
"""

__all__ = ["VAULT_TARGET_USD", "ITERATION", "HOURS_PER_TICK", "DAYS_PER_YEAR"]

ITERATION = 100

# The sovereign objective: grow the self-governed treasury to $5,000,000.
VAULT_TARGET_USD = 5_000_000.0

# One tick of the sovereign loop represents one operating day. Revenue,
# lease opex, and treasury yield are all accrued over this window.
HOURS_PER_TICK = 24.0
DAYS_PER_YEAR = 365.0
