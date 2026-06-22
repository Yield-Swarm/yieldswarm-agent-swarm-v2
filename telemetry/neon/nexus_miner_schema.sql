-- Nexus Miner DePIN profiles — Singapore gateway persistence
-- Apply: psql "$DATABASE_URL" -f telemetry/neon/nexus_miner_schema.sql

CREATE TABLE IF NOT EXISTS yieldswarm_miner_profiles (
  email TEXT PRIMARY KEY,
  current_plan TEXT NOT NULL DEFAULT 'Lite',
  current_balance NUMERIC(12, 2) NOT NULL DEFAULT 1000.00,
  geomines_all_time INTEGER NOT NULL DEFAULT 0,
  geodrops_all_time INTEGER NOT NULL DEFAULT 0,
  surveys_all_time INTEGER NOT NULL DEFAULT 0,
  spent_geoclaims NUMERIC(12, 4) NOT NULL DEFAULT 0.0,
  spent_geodrops NUMERIC(12, 4) NOT NULL DEFAULT 0.0,
  spent_sweepstakes NUMERIC(12, 4) NOT NULL DEFAULT 0.0,
  device_id TEXT,
  source TEXT,
  last_synchronized TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_yieldswarm_miner_profiles_last_sync
  ON yieldswarm_miner_profiles (last_synchronized DESC);

CREATE INDEX IF NOT EXISTS idx_yieldswarm_miner_profiles_device_id
  ON yieldswarm_miner_profiles (device_id);
