-- SWARM 3: Cosmic Account Onboarding schema

CREATE TABLE IF NOT EXISTS cosmic_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  birth_date DATE NOT NULL,
  birth_time TIME NOT NULL,
  birth_latitude DOUBLE PRECISION NOT NULL,
  birth_longitude DOUBLE PRECISION NOT NULL,
  birth_timezone TEXT NOT NULL DEFAULT 'UTC',
  kyc_verified BOOLEAN NOT NULL DEFAULT FALSE,
  house_id INTEGER NOT NULL CHECK (house_id BETWEEN 1 AND 24),
  house_name TEXT NOT NULL,
  eastern_sign TEXT,
  western_sign TEXT,
  deity_id TEXT NOT NULL,
  deity_manifest TEXT NOT NULL,
  plotra_agent_id TEXT,
  runic_level INTEGER NOT NULL DEFAULT 1 CHECK (runic_level BETWEEN 1 AND 99),
  runic_xp DOUBLE PRECISION NOT NULL DEFAULT 0,
  referred_infra_usd DOUBLE PRECISION NOT NULL DEFAULT 0,
  leased_hardware_hashrate DOUBLE PRECISION NOT NULL DEFAULT 0,
  faction_clan_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cosmic_users_deity ON cosmic_users(deity_id);
CREATE INDEX IF NOT EXISTS idx_cosmic_users_house ON cosmic_users(house_id);
CREATE INDEX IF NOT EXISTS idx_cosmic_users_runic ON cosmic_users(runic_level DESC);

CREATE TABLE IF NOT EXISTS cosmic_referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES cosmic_users(id),
  referee_id UUID REFERENCES cosmic_users(id),
  infra_contribution_usd DOUBLE PRECISION NOT NULL DEFAULT 0,
  hardware_lease_gh DOUBLE PRECISION NOT NULL DEFAULT 0,
  yield_weight DOUBLE PRECISION NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
