-- Solenoid DeFi pool cache + yield history (pillar 13_treasury_yield)
-- Apply: psql "$DATABASE_URL" -f telemetry/neon/schema-solenoid.sql

CREATE TABLE IF NOT EXISTS pool_cache (
  id BIGSERIAL PRIMARY KEY,
  chain_slug TEXT NOT NULL,
  pool_address TEXT NOT NULL,
  pool_name TEXT NOT NULL DEFAULT '',
  apr NUMERIC(12, 6) NOT NULL DEFAULT 0,
  tvl_usd NUMERIC(24, 2) NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (chain_slug, pool_address)
);

CREATE INDEX IF NOT EXISTS idx_pool_cache_updated_at ON pool_cache (updated_at DESC);

CREATE TABLE IF NOT EXISTS yield_history (
  id BIGSERIAL PRIMARY KEY,
  chain_slug TEXT NOT NULL,
  pool_address TEXT NOT NULL,
  apr NUMERIC(12, 6) NOT NULL DEFAULT 0,
  tvl_usd NUMERIC(24, 2) NOT NULL DEFAULT 0,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (chain_slug, pool_address, recorded_at)
);

CREATE INDEX IF NOT EXISTS idx_yield_history_recorded_at ON yield_history (recorded_at DESC);
