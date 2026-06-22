-- YieldSwarm Quest & Lottery Engine — PostgreSQL schema (God Prompt 3)
-- Apply: psql $DATABASE_URL -f services/quests/schema.sql

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── Users ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id    TEXT NOT NULL UNIQUE,
  email         TEXT,
  xp            BIGINT NOT NULL DEFAULT 0 CHECK (xp >= 0),
  level         INT NOT NULL DEFAULT 1 CHECK (level >= 1),
  referral_code TEXT UNIQUE DEFAULT encode(gen_random_bytes(6), 'hex'),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_level ON users (level DESC, xp DESC);

-- ── Nodes (extension / DePIN participants) ──────────────────────────────────
CREATE TABLE IF NOT EXISTS nodes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  node_key        TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'idle' CHECK (status IN ('active', 'idle', 'offline')),
  connection_streak_days INT NOT NULL DEFAULT 0,
  total_uptime_sec BIGINT NOT NULL DEFAULT 0,
  bandwidth_bytes  BIGINT NOT NULL DEFAULT 0,
  last_heartbeat  TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, node_key)
);

CREATE INDEX IF NOT EXISTS idx_nodes_status ON nodes (status, last_heartbeat DESC);

-- ── Quest definitions ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS quest_definitions (
  id            TEXT PRIMARY KEY,
  title         TEXT NOT NULL,
  description   TEXT,
  quest_type    TEXT NOT NULL DEFAULT 'daily' CHECK (quest_type IN ('daily', 'weekly', 'one_time')),
  xp_reward     INT NOT NULL DEFAULT 10,
  ticket_reward INT NOT NULL DEFAULT 0,
  criteria_json JSONB NOT NULL DEFAULT '{}',
  active        BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO quest_definitions (id, title, description, quest_type, xp_reward, ticket_reward, criteria_json)
VALUES
  ('maintain_24h_node', 'Maintain 24H Node Connection', 'Keep node active for 24 consecutive hours', 'daily', 120, 1, '{"min_uptime_sec": 86400}'),
  ('invite_verified_peer', 'Invite Verified Peer', 'Refer a peer who completes onboarding', 'daily', 80, 1, '{"min_referrals": 1}')
ON CONFLICT (id) DO NOTHING;

-- ── Quest progress ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS quest_progress (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  quest_id      TEXT NOT NULL REFERENCES quest_definitions(id),
  window_date   DATE NOT NULL DEFAULT CURRENT_DATE,
  progress_json JSONB NOT NULL DEFAULT '{}',
  completed_at  TIMESTAMPTZ,
  UNIQUE (user_id, quest_id, window_date)
);

-- ── Lottery drawings ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS lottery_drawings (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  window_date   DATE NOT NULL UNIQUE,
  vrf_seed_hash TEXT NOT NULL,
  winner_user_id UUID REFERENCES users(id),
  drawn_at      TIMESTAMPTZ,
  status        TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed', 'drawn'))
);

-- ── Lottery tickets (cryptographically verifiable entries) ──────────────────
CREATE TABLE IF NOT EXISTS lottery_tickets (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  drawing_id    UUID NOT NULL REFERENCES lottery_drawings(id) ON DELETE CASCADE,
  ticket_hash   TEXT NOT NULL UNIQUE,
  source        TEXT NOT NULL DEFAULT 'quest',
  issued_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lottery_tickets_drawing ON lottery_tickets (drawing_id);

-- ── Level curve: level = floor(sqrt(xp / 100)) + 1 ────────────────────────
CREATE OR REPLACE FUNCTION yieldswarm_level_for_xp(p_xp BIGINT)
RETURNS INT LANGUAGE sql IMMUTABLE AS $$
  SELECT GREATEST(1, FLOOR(SQRT(GREATEST(p_xp, 0)::numeric / 100))::int + 1);
$$;

-- ── Atomic quest completion + XP + tickets ──────────────────────────────────
CREATE OR REPLACE FUNCTION yieldswarm_complete_quest(
  p_user_id UUID,
  p_quest_id TEXT,
  p_window DATE DEFAULT CURRENT_DATE
) RETURNS TABLE (
  new_xp BIGINT,
  new_level INT,
  tickets_issued INT
) LANGUAGE plpgsql AS $$
DECLARE
  v_quest quest_definitions%ROWTYPE;
  v_xp BIGINT;
  v_level INT;
  v_drawing UUID;
  v_ticket_hash TEXT;
  v_tickets INT := 0;
BEGIN
  SELECT * INTO v_quest FROM quest_definitions WHERE id = p_quest_id AND active;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'quest_not_found: %', p_quest_id;
  END IF;

  INSERT INTO quest_progress (user_id, quest_id, window_date, progress_json, completed_at)
  VALUES (p_user_id, p_quest_id, p_window, '{"completed": true}', now())
  ON CONFLICT (user_id, quest_id, window_date) DO UPDATE
    SET completed_at = COALESCE(quest_progress.completed_at, now())
    WHERE quest_progress.completed_at IS NULL;

  IF NOT FOUND AND (SELECT completed_at FROM quest_progress
      WHERE user_id = p_user_id AND quest_id = p_quest_id AND window_date = p_window) IS NOT NULL THEN
    -- already completed earlier in this transaction path
    NULL;
  END IF;

  UPDATE users SET
    xp = xp + v_quest.xp_reward,
    level = yieldswarm_level_for_xp(xp + v_quest.xp_reward),
    updated_at = now()
  WHERE id = p_user_id
  RETURNING xp, level INTO v_xp, v_level;

  IF v_quest.ticket_reward > 0 THEN
    INSERT INTO lottery_drawings (window_date, vrf_seed_hash, status)
    VALUES (p_window, encode(digest(p_window::text || 'yieldswarm-vrf-stub', 'sha256'), 'hex'), 'open')
    ON CONFLICT (window_date) DO NOTHING;

    SELECT id INTO v_drawing FROM lottery_drawings WHERE window_date = p_window;

    FOR i IN 1..v_quest.ticket_reward LOOP
      v_ticket_hash := encode(digest(gen_random_uuid()::text || p_user_id::text || clock_timestamp()::text, 'sha256'), 'hex');
      INSERT INTO lottery_tickets (user_id, drawing_id, ticket_hash, source)
      VALUES (p_user_id, v_drawing, v_ticket_hash, p_quest_id);
      v_tickets := v_tickets + 1;
    END LOOP;
  END IF;

  RETURN QUERY SELECT v_xp, v_level, v_tickets;
END;
$$;
