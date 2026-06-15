CREATE TABLE IF NOT EXISTS great_delta_telemetry (
  id BIGSERIAL PRIMARY KEY,
  stream TEXT NOT NULL DEFAULT 'great-delta',
  event TEXT NOT NULL,
  agent_id TEXT,
  latency_ms NUMERIC(8,3) NOT NULL,
  within_80ms_guardrail BOOLEAN NOT NULL,
  treasury_split TEXT NOT NULL DEFAULT '50,30,15,5',
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_great_delta_telemetry_created_at
  ON great_delta_telemetry (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_great_delta_telemetry_event
  ON great_delta_telemetry (event);
