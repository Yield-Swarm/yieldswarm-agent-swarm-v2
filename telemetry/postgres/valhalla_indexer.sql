-- ValhallA performance analytics indexer schema
-- Apply: psql "$DATABASE_URL" -f telemetry/postgres/valhalla_indexer.sql

CREATE TABLE IF NOT EXISTS agents (
  id SERIAL PRIMARY KEY,
  agent_pubkey TEXT NOT NULL UNIQUE,
  agent_id INTEGER,
  risk_score_bps INTEGER NOT NULL DEFAULT 0,
  daily_spend_limit BIGINT NOT NULL DEFAULT 0,
  registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shard_vaults (
  id SERIAL PRIMARY KEY,
  shard_id SMALLINT NOT NULL UNIQUE,
  vault_pda TEXT NOT NULL,
  agent_authority TEXT NOT NULL,
  liquidity BIGINT NOT NULL DEFAULT 0,
  efficiency_bps INTEGER NOT NULL DEFAULT 0,
  apy_bps INTEGER NOT NULL DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cross_chain_events (
  id BIGSERIAL PRIMARY KEY,
  signature TEXT NOT NULL,
  slot BIGINT NOT NULL,
  kind SMALLINT NOT NULL,
  origin_chain_id BIGINT NOT NULL,
  asset_amount BIGINT NOT NULL,
  agent_pubkey TEXT NOT NULL,
  target_vault TEXT,
  bridge_message_hash TEXT,
  block_time TIMESTAMPTZ NOT NULL,
  raw_event JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cross_chain_events_block_time
  ON cross_chain_events (block_time DESC);

CREATE INDEX IF NOT EXISTS idx_cross_chain_events_agent
  ON cross_chain_events (agent_pubkey);

CREATE TABLE IF NOT EXISTS strategy_proposals (
  id BIGSERIAL PRIMARY KEY,
  proposal_id BIGINT NOT NULL,
  proposer TEXT NOT NULL,
  target_program TEXT NOT NULL,
  strategy_hash TEXT NOT NULL,
  spend_amount BIGINT NOT NULL,
  approval_count SMALLINT NOT NULL DEFAULT 0,
  executed BOOLEAN NOT NULL DEFAULT FALSE,
  signature TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  executed_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_strategy_proposals_proposal_id
  ON strategy_proposals (proposal_id);

CREATE TABLE IF NOT EXISTS agent_performance_daily (
  id BIGSERIAL PRIMARY KEY,
  agent_pubkey TEXT NOT NULL,
  day DATE NOT NULL,
  total_yield_lamports BIGINT NOT NULL DEFAULT 0,
  win_count INTEGER NOT NULL DEFAULT 0,
  loss_count INTEGER NOT NULL DEFAULT 0,
  apy_bps INTEGER NOT NULL DEFAULT 0,
  spend_lamports BIGINT NOT NULL DEFAULT 0,
  UNIQUE (agent_pubkey, day)
);

CREATE INDEX IF NOT EXISTS idx_agent_performance_daily_day
  ON agent_performance_daily (day DESC);

CREATE TABLE IF NOT EXISTS yield_routes (
  id BIGSERIAL PRIMARY KEY,
  protocol TEXT NOT NULL,
  route_label TEXT NOT NULL,
  apy_bps INTEGER NOT NULL,
  tvl_usd NUMERIC(18, 2),
  captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_yield_routes_protocol_captured
  ON yield_routes (protocol, captured_at DESC);

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_agent_win_rates AS
SELECT
  agent_pubkey,
  SUM(win_count)::NUMERIC / NULLIF(SUM(win_count + loss_count), 0) AS win_rate,
  SUM(total_yield_lamports) AS total_yield,
  AVG(apy_bps)::INTEGER AS avg_apy_bps
FROM agent_performance_daily
GROUP BY agent_pubkey;

CREATE TABLE IF NOT EXISTS treasury_registry_snapshots (
  id BIGSERIAL PRIMARY KEY,
  nexus_treasury TEXT NOT NULL,
  total_to_nexus BIGINT NOT NULL DEFAULT 0,
  total_to_mining BIGINT NOT NULL DEFAULT 0,
  paused_sweeps BOOLEAN NOT NULL DEFAULT FALSE,
  paused_inflows BOOLEAN NOT NULL DEFAULT FALSE,
  captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS treasury_route_events (
  id BIGSERIAL PRIMARY KEY,
  signature TEXT NOT NULL,
  route_destination SMALLINT NOT NULL,
  mining_root_kind SMALLINT NOT NULL,
  origin_chain_id BIGINT NOT NULL,
  asset_amount BIGINT NOT NULL,
  solana_recipient TEXT NOT NULL,
  external_address TEXT,
  block_time TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_treasury_route_events_block_time
  ON treasury_route_events (block_time DESC);

CREATE TABLE IF NOT EXISTS shard_sweep_events (
  id BIGSERIAL PRIMARY KEY,
  signature TEXT NOT NULL,
  shard_id SMALLINT NOT NULL,
  sweep_amount BIGINT NOT NULL,
  sweep_destination SMALLINT NOT NULL,
  mining_root_kind SMALLINT NOT NULL,
  shard_type SMALLINT NOT NULL,
  solana_recipient TEXT NOT NULL,
  block_time TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_shard_sweep_events_shard_id
  ON shard_sweep_events (shard_id, block_time DESC);
