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

  // Treasury split policy (basis points). Used to project on-chain balance into
  // destination buckets when the on-chain split config is not directly readable.
  treasurySplitsBps: {
    operations: int(process.env.SPLIT_OPERATIONS_BPS, 2000), // 20%
    stakers: int(process.env.SPLIT_STAKERS_BPS, 3500), // 35%
    buyback: int(process.env.SPLIT_BUYBACK_BPS, 2500), // 25%
    treasuryReserve: int(process.env.SPLIT_RESERVE_BPS, 2000), // 20%
  },

  // Agent fleet sizing (mirrors .env.example defaults) used for the leaderboard.
  fleet: {
    totalAgents: int(process.env.AGENT_COUNT_TOTAL, 10080),
    cronShardCount: int(process.env.CRON_SHARD_COUNT, 120),
  },

  kairoApiUrl: (process.env.KAIRO_API_URL || 'http://localhost:3001').replace(/\/$/, ''),
};

export default config;
