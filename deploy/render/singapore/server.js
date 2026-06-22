const express = require('express');
const { neon } = require('@neondatabase/serverless');
const { z } = require('zod');
const { TelemetrySchema } = require('./lib/telemetrySchema');

const app = express();
app.use(express.json({ limit: '10kb' }));

if (!process.env.DATABASE_URL) {
  console.error('CRITICAL: DATABASE_URL environment token is missing.');
  process.exit(1);
}

const sql = neon(process.env.DATABASE_URL);
const MONITOR_EMAIL = process.env.MONITOR_EMAIL || 'ethyswarm@proton.me';
const BATCH_SIZE = Number(process.env.SYNC_BATCH_SIZE || 8);
const FLUSH_INTERVAL_MS = Number(process.env.SYNC_FLUSH_MS || 1500);
const INSTANCE = process.env.RENDER_INSTANCE_ID || 'helix-chain-node-sg';

const pending = [];
let flushTimer = null;
let flushing = false;

function scheduleFlush() {
  if (flushTimer) return;
  flushTimer = setTimeout(() => {
    flushTimer = null;
    void flushQueue();
  }, FLUSH_INTERVAL_MS);
}

async function upsertTelemetry(record) {
  return sql`
    INSERT INTO yieldswarm_miner_profiles (
      email, current_plan, current_balance, geomines_all_time,
      geodrops_all_time, surveys_all_time, spent_geoclaims,
      spent_geodrops, spent_sweepstakes, last_synchronized
    ) VALUES (
      ${record.email}, ${record.plan}, ${record.currentBalance},
      ${record.geomines}, ${record.geodrops}, ${record.surveys},
      ${record.spentGeoclaims}, ${record.spentGeodrops}, ${record.spentSweepstakes},
      NOW()
    )
    ON CONFLICT (email) DO UPDATE SET
      current_plan = EXCLUDED.current_plan,
      current_balance = EXCLUDED.current_balance,
      geomines_all_time = yieldswarm_miner_profiles.geomines_all_time + EXCLUDED.geomines_all_time,
      geodrops_all_time = yieldswarm_miner_profiles.geodrops_all_time + EXCLUDED.geodrops_all_time,
      surveys_all_time = yieldswarm_miner_profiles.surveys_all_time + EXCLUDED.surveys_all_time,
      spent_geoclaims = yieldswarm_miner_profiles.spent_geoclaims + EXCLUDED.spent_geoclaims,
      spent_geodrops = yieldswarm_miner_profiles.spent_geodrops + EXCLUDED.spent_geodrops,
      spent_sweepstakes = yieldswarm_miner_profiles.spent_sweepstakes + EXCLUDED.spent_sweepstakes,
      last_synchronized = NOW()
    RETURNING email, current_balance, last_synchronized;
  `;
}

async function flushQueue() {
  if (flushing || pending.length === 0) return;
  flushing = true;

  const batch = pending.splice(0, BATCH_SIZE);
  try {
    for (const record of batch) {
      await upsertTelemetry(record);
      if (record.email === MONITOR_EMAIL) {
        console.log(
          `[monitor] synced ${MONITOR_EMAIL} balance=${record.currentBalance} geomines=${record.geomines}`,
        );
      }
    }
  } catch (err) {
    console.error('Telemetry batch flush error:', err);
    pending.unshift(...batch);
    scheduleFlush();
  } finally {
    flushing = false;
    if (pending.length > 0) {
      scheduleFlush();
    }
    if (global.gc) {
      global.gc();
    }
  }
}

app.get('/healthz', (_req, res) => {
  res.status(200).json({
    status: 'HEALTHY',
    instance: INSTANCE,
    queueDepth: pending.length,
  });
});

app.post('/api/sync', (req, res) => {
  try {
    const validatedData = TelemetrySchema.parse(req.body);
    pending.push(validatedData);
    scheduleFlush();

    return res.status(202).json({
      success: true,
      queued: true,
      queueDepth: pending.length,
    });
  } catch (err) {
    if (err instanceof z.ZodError) {
      return res.status(400).json({
        error: 'Invalid structural metrics payload',
        details: err.errors,
      });
    }
    console.error('Telemetry Processing Error:', err);
    return res.status(500).json({ error: 'Internal cluster processing exception' });
  }
});

const PORT = process.env.PORT || 10000;
const server = app.listen(PORT, () => {
  console.log(`YieldSwarm Instance Live: Port ${PORT} | Region: Singapore`);
});

function shutdown() {
  server.close(() => {
    void flushQueue().finally(() => process.exit(0));
  });
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

module.exports = { app, TelemetrySchema, flushQueue, pending };
