-- Instance B — GP7 indexer schema (PostgreSQL / Neon)
CREATE TABLE IF NOT EXISTS agent_yield_events (
  id BIGSERIAL PRIMARY KEY,
  signature TEXT NOT NULL UNIQUE,
  program_id TEXT NOT NULL,
  agent_pubkey TEXT,
  shard_id SMALLINT,
  gross_lamports BIGINT NOT NULL DEFAULT 0,
  net_lamports BIGINT NOT NULL DEFAULT 0,
  apy_bps INTEGER,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_agent_yield_agent ON agent_yield_events(agent_pubkey);
CREATE INDEX idx_agent_yield_shard ON agent_yield_events(shard_id);

CREATE TABLE IF NOT EXISTS cross_chain_harvests (
  id BIGSERIAL PRIMARY KEY,
  origin_chain TEXT NOT NULL,
  dest_chain TEXT NOT NULL DEFAULT 'solana',
  asset_mint TEXT,
  amount BIGINT NOT NULL,
  bridge_tx TEXT,
  treasury_pda TEXT,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cross_chain_origin ON cross_chain_harvests(origin_chain);

CREATE TABLE IF NOT EXISTS iotex_yield_events (
  id BIGSERIAL PRIMARY KEY,
  signature TEXT NOT NULL UNIQUE,
  destination TEXT NOT NULL,
  amount BIGINT NOT NULL,
  source_chain_id INTEGER,
  iotex_treasury TEXT,
  btc_bridge_hash TEXT,
  relayer_pubkey TEXT,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_iotex_yield_destination ON iotex_yield_events(destination);

CREATE TABLE IF NOT EXISTS shard_snapshots (
  id BIGSERIAL PRIMARY KEY,
  shard_id BIGINT NOT NULL,
  total_assets BIGINT NOT NULL DEFAULT 0,
  target_weight_bps SMALLINT,
  coordinator_pda TEXT,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_shard_snapshots_shard ON shard_snapshots(shard_id);
