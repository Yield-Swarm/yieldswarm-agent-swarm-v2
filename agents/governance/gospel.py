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

# ---------------------------------------------------------------------------
# RPC Mesh — Alchemy Christopher's First App (docs/RPC_ALCHEMY_STUDY.md)
# Backend auto-fills unset SOL/ETH/Base/Polygon/Arbitrum env at load.
# ---------------------------------------------------------------------------
ALCHEMY_APP_NAME = "Christopher's First App"
RPC_MESH_API_KEY_ENV = "ALCHEMY_API_KEY"
RPC_MESH_NETWORK_COUNT = 164
RPC_MESH_MANIFEST = "config/alchemy/christophers-first-app.json"

RPC_MESH_PRIMARY_NETWORK_IDS = (
    "solana-mainnet",
    "ethereum-mainnet",
    "base-mainnet",
    "polygon-mainnet",
    "arbitrum-mainnet",
    "ethereum-sepolia",
    "op-mainnet",
    "avalanche-mainnet",
)

RPC_MESH_AUTO_ENV_KEYS = (
    "SOLANA_RPC_URL",
    "ETHEREUM_RPC_URL",
    "EVM_RPC_URL",
    "MAINNET_RPC_URL",
    "BASE_RPC_URL",
    "EVM_RPC_URL_8453",
    "EVM_RPC_URL_137",
    "EVM_RPC_URL_42161",
    "SEPOLIA_RPC_URL",
)

# ---------------------------------------------------------------------------
# Mining covenant — community pools + Bittensor (config/TREASURY_MANIFEST.json)
# All gross mining/DEX revenue routes through TREASURY_SPLIT_BPS.
# ---------------------------------------------------------------------------
MINING_ROOT_MANIFEST = "config/TREASURY_MANIFEST.json"
NEXUS_TREASURY_SOLANA = "kuTcpVPbdC8oYB6gkT2s5tZKzsBsG1hHe7C9zhRpXSN"
IOTEX_MINING_ROOT = "0x8f3d03e4c0f36670aa1b6f1e7befa85d50c3a567"
BTC_IOPAY_BRIDGE = "bc1qssmlvhth0sm4xslnvf5a7nlv038u3txkc3l0u8"

BITTENSOR_DEFAULT_NETUID = 1
BITTENSOR_DEFAULT_NETWORK = "finney"
BITTENSOR_DEPLOY_SDL = "deploy/akash-bittensor-miner.sdl.yml"
BITTENSOR_VAULT_POLICY = "bittensor-runtime"

MINING_COVENANT_ETHOS = (
    "point_payouts_at_treasury_manifest",
    "great_delta_before_settlement",
    "akash_bittensor_first_in_harvest",
    "rotate_exposed_rpc_keys",
)

# ---------------------------------------------------------------------------
# Rewards strand — reshard / assemble / sweep (docs/REWARDS_RESHARD_SWEEP.md)
# ---------------------------------------------------------------------------
REWARDS_DRY_RUN_DEFAULT = True
REWARDS_SHARD_COUNT = 120
REWARDS_MANIFEST = "config/TREASURY_MANIFEST.json"
REWARDS_RUN_DIR = ".run"
REWARDS_PHASES = ("reshard", "assemble", "sweep")

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
