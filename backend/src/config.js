/**
 * Central configuration for the integration backend.
 *
 * Values come from the environment (see repo .env.example). Sensible defaults
 * are provided so the service boots and the Arena dashboard renders even before
 * real credentials/addresses are wired in. Each upstream adapter reports whether
 * it is using a live connection or a deterministic fallback so the dashboard can
 * surface connection health.
 */

function int(value, fallback) {
  const n = Number.parseInt(value ?? '', 10);
  return Number.isFinite(n) ? n : fallback;
}

function bool(value, fallback) {
  if (value === undefined || value === null || value === '') return fallback;
  return ['1', 'true', 'yes', 'on'].includes(String(value).toLowerCase());
}

function csv(value) {
  if (!value) return [];
  return String(value)
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

export const config = {
  port: int(process.env.PORT, 8080),
  host: process.env.HOST || '0.0.0.0',

  // Polling / cache behaviour
  cacheTtlMs: int(process.env.TELEMETRY_CACHE_TTL_MS, 15_000),
  upstreamTimeoutMs: int(process.env.UPSTREAM_TIMEOUT_MS, 6_000),
  httpRetries: int(process.env.HTTP_RETRIES, 2),
  httpRetryDelayMs: int(process.env.HTTP_RETRY_DELAY_MS, 400),
  cronJobsEnabled: bool(process.env.CRON_JOBS_ENABLED, true),

  akash: {
    // Akash Console indexer API — live network capacity + provider health and
    // owner deployment/lease lookups (public Cosmos REST nodes prune the market
    // module, so the indexer is the reliable source for lease telemetry).
    consoleApi: (process.env.AKASH_CONSOLE_API || 'https://console-api.akash.network/v1').replace(/\/$/, ''),
    // Owner (bech32 akash1...) whose leases/deployments we surface as workers.
    owner: process.env.AKASH_OWNER_ADDRESS || '',
    // Optional explicit deployment sequence numbers (DSEQ) to track.
    dseqs: csv(process.env.AKASH_DSEQ_LIST),
    enabled: bool(process.env.AKASH_ENABLED, true),
  },

  solana: {
    rpcUrl: process.env.SOLANA_RPC_URL || 'https://api.mainnet-beta.solana.com',
    // $APN mint (from .env.example) drives on-chain emission/supply telemetry.
    apnMint: process.env.APN_MINT_ADDRESS || '8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump',
    // Emission router program/account that distributes rewards on-chain.
    emissionRouter: process.env.EMISSION_ROUTER_ADDRESS || '',
    // Treasury wallet/PDA whose balance + splits we report.
    treasury: process.env.TREASURY_ADDRESS || '',
    enabled: bool(process.env.SOLANA_ENABLED, true),
  },

  // Optional EVM GreatDeltaEmissionRouter.sol read adapter (eth_call previewSplit/treasuries).
  evm: {
    rpcUrl: process.env.EVM_RPC_URL || process.env.MAINNET_RPC_URL || '',
    emissionRouter: process.env.EMISSION_ROUTER_EVM_ADDRESS || '',
    enabled: bool(process.env.EVM_ENABLED, false),
  },

  // Great Delta Emission Router split (50/30/15/5) — matches GreatDeltaEmissionRouter.sol
  treasurySplitsBps: {
    coreTreasury: int(process.env.SPLIT_CORE_BPS, 5000),       // 50%
    growthTreasury: int(process.env.SPLIT_GROWTH_BPS, 3000),   // 30%
    insuranceTreasury: int(process.env.SPLIT_INSURANCE_BPS, 1500), // 15%
    opsTreasury: int(process.env.SPLIT_OPS_BPS, 500),          // 5%
  },

  // Agent fleet sizing (mirrors .env.example defaults) used for the leaderboard.
  fleet: {
    totalAgents: int(process.env.AGENT_COUNT_TOTAL, 10080),
    cronShardCount: int(process.env.CRON_SHARD_COUNT, 120),
  },

  odysseus: {
    brainUrl: (process.env.ODYSSEUS_BRAIN_URL || process.env.ODYSSEUS_URL || 'http://127.0.0.1:8090').replace(/\/$/, ''),
    workspaceUrl: (process.env.ODYSSEUS_WORKSPACE_URL || 'http://127.0.0.1:7000').replace(/\/$/, ''),
    enabled: bool(process.env.ODYSSEUS_ENABLED, true),
  },

  inference: {
    rtx5090Endpoint:
      process.env.RTX5090_ENDPOINT ||
      'http://r4r35icmll0m7o.ingress.5090.mel.val.akash.pub:11434',
    h100Endpoint: process.env.H100_ENDPOINT || process.env.H100_OLLAMA_ENDPOINT || '',
    rtx5090Model: process.env.RTX5090_MODEL || 'qwen2.5:14b',
    h100Model: process.env.H100_MODEL || 'llama3.1:70b',
    telemetryPollMs: int(process.env.RTX5090_TELEMETRY_POLL_MS, 15_000),
    enabled: bool(process.env.INFERENCE_ROUTER_ENABLED, true),
  },

  // Helix Chain cross-execution layer (genesis + YSLR + emission bridge).
  helix: {
    enabled: bool(process.env.HELIX_CHAIN_ENABLED, false),
    bridgeKey: process.env.HELIX_CHAIN_BRIDGE_KEY || '',
    emissionRouter:
      process.env.YIELDSWARM_HELIX_EMISSION_ROUTER ||
      process.env.EMISSION_ROUTER_EVM_ADDRESS ||
      '',
    controlPlaneUrl:
      process.env.HELIX_CONTROL_PLANE_URL ||
      process.env.GREAT_DELTA_INGEST_URL ||
      '',
  },

  dex: {
    jupiterApiKey: process.env.JUPITER_API_KEY || '',
    jupiterBaseUrl: (process.env.JUPITER_API_URL || 'https://quote-api.jup.ag/v6').replace(/\/$/, ''),
    uniswapV4PoolManager: process.env.UNISWAP_V4_POOL_MANAGER || '',
    uniswapV4HookAddress: process.env.UNISWAP_V4_HOOK_ADDRESS || '',
    evmRpcUrl: process.env.EVM_RPC_URL || process.env.ETHEREUM_RPC_URL || '',
    slippageBps: int(process.env.SLIPPAGE_TOLERANCE, 50),
    enabled: bool(process.env.CROSS_CHAIN_MVP_ENABLED, true),
  },
};

export default config;
