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

# Cross-chain execution venues (God Prompt P — docs/CROSS_CHAIN_EXECUTION.md)
CROSS_CHAIN_VENUES = (
    "uniswap_v4",   # EVM hooks + Dutch auctions
    "jupiter",      # Solana swap aggregation
    "orca",         # Solana concentrated liquidity
    "raydium",      # Solana AMM pools
    "dydx",         # perpetual futures hedge + yield
    "pow_mining",   # Bittensor + altcoin PoW expansion
)

# All cross-chain gross revenue MUST pass through TREASURY_SPLIT_BPS before settlement
CROSS_CHAIN_DRY_RUN_DEFAULT = True
CROSS_CHAIN_LATENCY_GUARDRAIL_MS = LATENCY_GUARDRAIL_MS  # 80ms ingest guardrail

# ---------------------------------------------------------------------------
# 30-Day Maximum Compute Harvest Phase (docs/MULTI_CLOUD_30DAY_PLAN.md)
# Aggressive free-credit utilization — revenue-first, async, self-healing.
# Ethical guardrails: no stolen resources; council 9/14 for live spend; dry-run default.
# ---------------------------------------------------------------------------
HARVEST_PHASE_NAME = "maximum_compute_harvest_30d"
HARVEST_SCHEDULER_INTERVAL_MINUTES = 10
HARVEST_SOVEREIGN_INTERVAL_SECONDS = HEARTBEAT_SECONDS  # 420s heartbeat; 900s swarm tick
HARVEST_DRY_RUN_DEFAULT = True

# Provider priority — revenue > utilization (akash first for Bittensor)
HARVEST_PROVIDER_PRIORITY = (
    "akash",     # RTX 3090 Bittensor + inference — real revenue
    "vast",      # cheap GPU training burst
    "runpod",    # GPU training + inference
    "azure",     # Grass DePIN + CPU
    "gcp",       # Grass + training MIG
    "aws",       # training + batch
    "alibaba",   # filler capacity
)

HARVEST_WORKLOAD_PRIORITY = (
    "bittensor",   # highest ROI — TAO emissions
    "inference",   # agent marketplace revenue
    "training",    # model assets + paid jobs
    "grass",       # DePIN rewards
    "cpu_batch",   # lowest priority filler
)

# Async job queue invariants
HARVEST_MAX_JOB_ATTEMPTS = 3
HARVEST_MIGRATE_ON_FAILURE = True

# Sustainable philosophy (unchanged): harvest free credits aggressively but route
# all revenue through Great Delta; tear down idle spend; document for post-credit ops.
HARVEST_ETHOS = (
    "revenue_first",
    "async_self_healing",
    "great_delta_covenant",
    "council_gated_live_spend",
    "document_and_tear_down",
)

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
