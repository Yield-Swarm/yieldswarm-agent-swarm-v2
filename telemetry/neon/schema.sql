-- YieldSwarm Neon telemetry — Mandelbrot bot + Helix Chain snapshots
-- Apply: psql "$DATABASE_URL" -f telemetry/neon/schema.sql
-- Or: python3 -m services.neon_store --migrate

CREATE TABLE IF NOT EXISTS mandelbrot_telemetry (
  id BIGSERIAL PRIMARY KEY,
  telemetry_id TEXT NOT NULL,
  driver_id TEXT NOT NULL,
  evm_address TEXT,
  shard_id INTEGER,
  branch INTEGER,
  leaf INTEGER,
  mandelbrot_score INTEGER,
  reward_weight NUMERIC(12, 4),
  speed_kmh NUMERIC(8, 2),
  signed_at TIMESTAMPTZ,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  tree JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mandelbrot_telemetry_created_at
  ON mandelbrot_telemetry (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_mandelbrot_telemetry_driver_id
  ON mandelbrot_telemetry (driver_id);

CREATE INDEX IF NOT EXISTS idx_mandelbrot_telemetry_shard_id
  ON mandelbrot_telemetry (shard_id);

CREATE TABLE IF NOT EXISTS helix_chain_snapshots (
  id BIGSERIAL PRIMARY KEY,
  phase TEXT NOT NULL,
  activated BOOLEAN NOT NULL DEFAULT FALSE,
  genesis_hash TEXT,
  readiness_score TEXT,
  yslr_phase TEXT,
  sovereign_progress NUMERIC(8, 4),
  treasury_nav_usd NUMERIC(18, 2),
  snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_helix_chain_snapshots_created_at
  ON helix_chain_snapshots (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_helix_chain_snapshots_phase
  ON helix_chain_snapshots (phase);
