/**
 * Quadrilateral Helix Phase 1 — solenoid router + oracle bridge adapter.
 * Bridges CommonJS infrastructure modules into the ESM backend.
 */

import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const require = createRequire(import.meta.url);

const infraPath = path.join(repoRoot, 'src', 'infrastructure');
const { QuadrilateralSolenoidRouter } = require(path.join(infraPath, 'odysseus-router.js'));
const { TelemetryValidationBridge } = require(path.join(infraPath, 'oracle-bridge.js'));
const solenoidEngine = require(path.join(infraPath, 'solenoid-engine.js'));

const router = new QuadrilateralSolenoidRouter();
const telemetryBridge = new TelemetryValidationBridge();

/** @type {{ throttled: boolean, lastThrottleAt: string | null, lastTemp: number | null }} */
const throttleState = {
  throttled: false,
  lastThrottleAt: null,
  lastTemp: null,
};

/** @type {{ prunedAt: string | null, pruneCount: number }} */
const contextState = {
  prunedAt: null,
  pruneCount: 0,
};

const PILLAR_NAMES = [
  '01_greek_vaults',
  '02_infra_oracles',
  '03_zk_mayhem_core',
  '04_akash_gpu_workers',
  '05_arena_leaderboard',
  '06_cross_chain_exec',
  '07_depin_orchestration',
  '08_emission_routing',
  '09_agentswarm_os',
  '10_security_tee_mpc',
  '11_telemetry_observability',
  '12_governance',
  '13_treasury_yield',
  '14_valhalla_portal',
];

function buildDefaultPillarPayloads() {
  return PILLAR_NAMES.map((name, index) => ({
    data: { pillar: name, index: index + 1 },
    prompt: `Validate pillar ${index + 1}: ${name}`,
    nonce: 0,
  }));
}

export function getSolenoidStatus() {
  const engineStatus = solenoidEngine.getStatus();
  return {
    layer: 'PDs1_QUADRILATERAL_AXIS',
    pillars: PILLAR_NAMES.length,
    throttle: { ...throttleState },
    context: { ...contextState },
    activeContexts: router.contexts.size,
    stateChainHash: router.solenoidEngine.stateChainHash,
    currentPillarIndex: router.solenoidEngine.currentPillarIndex,
    activeSolenoidMode: engineStatus.activeSolenoidMode,
    activeDimension: engineStatus.activeDimension,
    pillarElevators: engineStatus.pillarElevators,
    timestamp: new Date().toISOString(),
  };
}

export function shiftSolenoidMode(targetMode) {
  if (targetMode === 'PENTAGRAM') {
    return { success: true, ...solenoidEngine.shiftToPentagramSolenoid() };
  }
  if (targetMode === '14X_ELEVATORS') {
    return { success: true, ...solenoidEngine.launchPillarElevators() };
  }
  if (targetMode === 'QUADRILATERAL') {
    solenoidEngine.activeSolenoidMode = 'QUADRILATERAL';
    solenoidEngine.activeDimension = 2;
    return {
      success: true,
      newConfigurationMode: solenoidEngine.activeSolenoidMode,
      dimensionLevel: solenoidEngine.activeDimension,
      stateAnchor: solenoidEngine.stateChainHash,
    };
  }
  return { success: false, error: 'UNKNOWN_SOLENOID_MODE', targetMode };
}

export async function ingestSsePoolEvent(body = {}) {
  return solenoidEngine.ingestSseEvent(body);
}

export async function getPentagramRiskSnapshot() {
  const pool = await solenoidEngine.getPool();
  if (!pool) {
    return { live: false, pools: [], mode: solenoidEngine.activeSolenoidMode };
  }
  const client = await pool.connect();
  try {
    const { rows } = await client.query(
      'SELECT chain_slug, pool_address, pool_name, apr, tvl_usd FROM pool_cache ORDER BY updated_at DESC LIMIT 50',
    );
    const pools = rows.map((row) => solenoidEngine.scorePoolRisk(row));
    return {
      live: true,
      mode: solenoidEngine.activeSolenoidMode,
      dimension: solenoidEngine.activeDimension,
      pools,
      timestamp: new Date().toISOString(),
    };
  } finally {
    client.release();
  }
}

export function applyThrottle(body = {}) {
  throttleState.throttled = true;
  throttleState.lastThrottleAt = new Date().toISOString();
  throttleState.lastTemp = Number(body.temp) || null;
  return {
    accepted: true,
    status: body.status || 'THERMAL_LIMIT_EXCEEDED',
    throttled: true,
    temp: throttleState.lastTemp,
    timestamp: throttleState.lastThrottleAt,
  };
}

export function pruneContext(body = {}) {
  contextState.prunedAt = new Date().toISOString();
  contextState.pruneCount += 1;
  return {
    accepted: true,
    force: Boolean(body.force),
    prunedAt: contextState.prunedAt,
    pruneCount: contextState.pruneCount,
  };
}

export function ingestTelemetryPulse(body = {}) {
  const pillarId = body.pillarId ?? body.id ?? '1';
  const pillarContext = {
    id: String(pillarId),
    namespaceHash: body.namespaceHash || `PILLAR_${pillarId}`,
    name: body.name || PILLAR_NAMES[Number(pillarId) - 1] || 'unknown',
  };

  const metrics = body.metrics || body;
  const result = telemetryBridge.processMetricPulse(pillarContext, {
    gpu_temperature: metrics.gpu_temperature ?? metrics.temp ?? 0,
    vram_used_bytes: metrics.vram_used_bytes ?? metrics.vram ?? 0,
    tokens_per_sec: metrics.tokens_per_sec ?? 0,
    timestamp: Date.now(),
  });

  return {
    pillar: pillarContext.name,
    pillarId: pillarContext.id,
    ...result,
  };
}

export async function runAxisMatrix(body = {}) {
  const tenantConfig = {
    id: body.tenantId || body.tenant?.id || 'yieldswarm-default',
    tier: body.tier ?? 1,
    fleetVin: body.fleetVin || body.tenant?.fleetVin,
  };

  const pipelinePayloads = body.pipelinePayloads || buildDefaultPillarPayloads();
  const telemetry = body.telemetry ||
    body.hardware || {
      gpu_temperature: 72,
      vram_allocated_bytes: 24_000_000_000,
      tokens_per_sec: 1200,
      battery_level: 85,
      grid_frequency: 60.0,
    };

  const targetLocale = body.locale || body.targetLocale || 'en';

  const matrix = await router.processAxisMatrix(
    tenantConfig,
    pipelinePayloads,
    telemetry,
    targetLocale,
  );

  return {
    tenantId: tenantConfig.id,
    ...matrix,
    throttle: { ...throttleState },
  };
}
