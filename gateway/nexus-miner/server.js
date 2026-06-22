/**
 * Nexus Multi-Mining Gateway — DePIN telemetry clearing loop.
 * Deploy to Render (Singapore). Secrets via Render dashboard / Vault — never commit.
 */
const express = require('express');
const { neon } = require('@neondatabase/serverless');
const { z } = require('zod');

const app = express();
app.use(express.json({ limit: '8kb' }));

const SHADOW_CHAIN_ID = process.env.SHADOW_CHAIN_ID || 'shadow-solenoid-3';
const EXECUTION_CAPACITY = Number(process.env.EXECUTION_CAPACITY || '0.80');
const SYNC_API_KEY = process.env.NEXUS_SYNC_API_KEY || process.env.MINING_API_KEY || '';

if (!process.env.DATABASE_URL) {
  console.error('CRITICAL: DATABASE_URL is required');
  process.exit(1);
}

const sql = neon(process.env.DATABASE_URL);

const DePINTelemetryValidator = z.object({
  email: z.string().email(),
  plan: z.string().default('Lite'),
  currentBalance: z.number().nonnegative().default(1000.0),
  geomines: z.number().int().nonnegative().default(0),
  geodrops: z.number().int().nonnegative().default(0),
  surveys: z.number().int().nonnegative().default(0),
  spentGeoclaims: z.number().nonnegative().default(0.0),
  spentGeodrops: z.number().nonnegative().default(0.0),
  spentSweepstakes: z.number().nonnegative().default(0.0),
  deviceId: z.string().optional(),
  source: z.string().optional(),
});

function requireSyncAuth(req, res, next) {
  if (!SYNC_API_KEY) return next();
  const header = req.get('authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : req.get('x-api-key');
  if (token !== SYNC_API_KEY) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  return next();
}

app.get('/healthz', (_req, res) => {
  res.status(200).json({
    status: 'ACTIVE',
    infrastructure: 'helix-nexus-chain-bridge',
    shadowChainId: SHADOW_CHAIN_ID,
    executionCapacity: EXECUTION_CAPACITY,
  });
});

app.get('/api/health', (_req, res) => {
  res.status(200).json({ ok: true, service: 'nexus-miner-gateway' });
});

app.post('/api/sync', requireSyncAuth, async (req, res) => {
  try {
    const validatedData = DePINTelemetryValidator.parse(req.body);

    const result = await sql`
      INSERT INTO yieldswarm_miner_profiles (
        email, current_plan, current_balance, geomines_all_time,
        geodrops_all_time, surveys_all_time, spent_geoclaims,
        spent_geodrops, spent_sweepstakes, device_id, source, last_synchronized
      ) VALUES (
        ${validatedData.email}, ${validatedData.plan}, ${validatedData.currentBalance},
        ${validatedData.geomines}, ${validatedData.geodrops}, ${validatedData.surveys},
        ${validatedData.spentGeoclaims}, ${validatedData.spentGeodrops}, ${validatedData.spentSweepstakes},
        ${validatedData.deviceId || null}, ${validatedData.source || null}, NOW()
      )
      ON CONFLICT (email) DO UPDATE SET
        current_plan = EXCLUDED.current_plan,
        current_balance = EXCLUDED.current_balance,
        geomines_all_time = yieldswarm_miner_profiles.geomines_all_time + EXCLUDED.geomines_all_time,
        geodrops_all_time = yieldswarm_miner_profiles.geodrops_all_time + EXCLUDED.geodrops_all_time,
        surveys_all_time = yieldswarm_miner_profiles.surveys_all_time + EXCLUDED.surveys_all_time,
        spent_geoclaims = EXCLUDED.spent_geoclaims,
        spent_geodrops = EXCLUDED.spent_geodrops,
        spent_sweepstakes = EXCLUDED.spent_sweepstakes,
        device_id = COALESCE(EXCLUDED.device_id, yieldswarm_miner_profiles.device_id),
        source = COALESCE(EXCLUDED.source, yieldswarm_miner_profiles.source),
        last_synchronized = NOW()
      RETURNING email, current_balance, last_synchronized;
    `;

    return res.status(200).json({ success: true, nodeSyncRecord: result[0] });
  } catch (err) {
    if (err instanceof z.ZodError) {
      return res.status(400).json({
        error: 'Telemetry framing constraint violated',
        violations: err.errors,
      });
    }
    console.error('Infrastructure synchronization runtime fault:', err);
    return res.status(500).json({ error: 'Internal cross-chain mining processing failure' });
  } finally {
    if (global.gc) global.gc();
  }
});

const PORT = Number(process.env.PORT || 10000);
app.listen(PORT, () => {
  console.log(
    `Nexus Multi-Mining Gateway live on port ${PORT} | shadow=${SHADOW_CHAIN_ID} capacity=${EXECUTION_CAPACITY}`,
  );
});
