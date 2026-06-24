-- DePIN miner profiles + geomining telemetry (Neon / Postgres)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS yieldswarm_miner_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    current_plan VARCHAR(50) DEFAULT 'Lite',
    current_balance NUMERIC(20, 2) DEFAULT 1000.00,
    all_time_redeems NUMERIC(20, 2) DEFAULT 0.00,
    all_time_collected NUMERIC(20, 2) DEFAULT 0.00,
    geomines_all_time INT DEFAULT 0,
    geodrops_all_time INT DEFAULT 0,
    surveys_all_time INT DEFAULT 0,
    spent_geoclaims NUMERIC(20, 2) DEFAULT 0.00,
    spent_geodrops NUMERIC(20, 2) DEFAULT 0.00,
    spent_sweepstakes NUMERIC(20, 2) DEFAULT 0.00,
    last_synchronized TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_miner_email ON yieldswarm_miner_profiles(email);

CREATE TABLE IF NOT EXISTS yieldswarm_checklist_state (
    email VARCHAR(255) PRIMARY KEY REFERENCES yieldswarm_miner_profiles(email),
    intro_json JSONB NOT NULL DEFAULT '{}',
    intro_complete BOOLEAN DEFAULT FALSE,
    daily_json JSONB NOT NULL DEFAULT '{}',
    streak_days INT DEFAULT 0,
    daily_completed_days INT DEFAULT 0,
    last_daily_utc DATE,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
