-- YieldSwarm DePIN / geomining miner profiles (Neon Serverless Postgres)
-- Apply: psql "$DATABASE_URL" -f deploy/render/singapore/schema.sql

CREATE TABLE IF NOT EXISTS yieldswarm_miner_profiles (
  email TEXT PRIMARY KEY,
  current_plan TEXT NOT NULL DEFAULT 'Lite',
  current_balance NUMERIC(18, 2) NOT NULL DEFAULT 1000.00,
  geomines_all_time BIGINT NOT NULL DEFAULT 0,
  geodrops_all_time BIGINT NOT NULL DEFAULT 0,
  surveys_all_time BIGINT NOT NULL DEFAULT 0,
  spent_geoclaims NUMERIC(18, 4) NOT NULL DEFAULT 0.0,
  spent_geodrops NUMERIC(18, 4) NOT NULL DEFAULT 0.0,
  spent_sweepstakes NUMERIC(18, 4) NOT NULL DEFAULT 0.0,
  last_synchronized TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_yieldswarm_miner_profiles_last_synchronized
  ON yieldswarm_miner_profiles (last_synchronized DESC);
