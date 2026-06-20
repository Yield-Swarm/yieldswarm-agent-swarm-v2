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
