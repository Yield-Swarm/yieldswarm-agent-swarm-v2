"""Internal gospel constants — YieldSwarm v2 Trident / Layer-35 blueprint."""

from __future__ import annotations

# 14-Council Kimiclaw origin governance
COUNCIL_SEATS = 14
CONSENSUS_THRESHOLD = (9, 14)  # 9/14 threshold for gated writes

# Non-negotiable invariants (docs/YieldSwarm_v1_v2_Trident_Layer35_Blueprint.md)
TREASURY_SPLIT_BPS = (5000, 3000, 1500, 500)  # 50/30/15/5
LATENCY_GUARDRAIL_MS = 80
HEARTBEAT_SECONDS = 420

# Gospel regions -> compute character
GOSPEL_REGIONS = (
    "latin_america",  # low-latency tactical compute
    "africa",  # adaptive exploration compute
    "asia_pacific",  # high-throughput stable compute
)

# Four brewing fundamentals -> runtime knobs
GOSPEL_FUNDAMENTALS = (
    "proportion",  # scope sizing
    "grind",  # compute load / batching granularity
    "water",  # runtime spend / cloud cost envelope
    "freshness",  # vector acceleration / cache recency
)

GOVERNANCE_MODEL_COUNT = 100

# Sovereign governance delta target (agents/iteration_100_sovereign_loops.py)
GOVERNANCE_DELTA_TARGET = 0.82

COUNCIL_ROLES = (
    ("deity-001", "Kimiclaw", "head_of_consensus_council"),
    ("deity-002", "Council Seat 02", "primary_deity"),
    ("deity-003", "Council Seat 03", "primary_deity"),
    ("deity-004", "Council Seat 04", "primary_deity"),
    ("deity-005", "Council Seat 05", "primary_deity"),
    ("deity-006", "Council Seat 06", "primary_deity"),
    ("deity-007", "Council Seat 07", "primary_deity"),
    ("deity-008", "Council Seat 08", "primary_deity"),
    ("deity-009", "Council Seat 09", "primary_deity"),
    ("deity-010", "Council Seat 10", "supporting_deity"),
    ("deity-011", "Council Seat 11", "supporting_deity"),
    ("deity-012", "Council Seat 12", "supporting_deity"),
    ("deity-013", "Council Seat 13", "supporting_deity"),
    ("deity-014", "Council Seat 14", "supporting_deity"),
)
