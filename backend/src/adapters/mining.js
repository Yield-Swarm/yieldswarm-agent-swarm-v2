/**
 * OpenClaw pure-credit mining telemetry — Helix Pillar 5 (entropy) + Pillar 7 (ancestral).
 */

import { createRequire } from 'node:module';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const require = createRequire(import.meta.url);
const infraPath = path.join(repoRoot, 'src', 'infrastructure', 'entropy-core.js');

const {
  HardenedAuditEngine,
  SymbioticEvolutionEngine,
  OmniDimensionalSafetyCanopy,
} = require(infraPath);

const helixLog = path.join(repoRoot, process.env.MINING_HELIX_LOG || '.run/mining-helix.jsonl');
const metricsStore = [];

export function ingestMiningTelemetry(body = {}) {
  const audit = new HardenedAuditEngine();
  const evolution = new SymbioticEvolutionEngine();
  const canopy = new OmniDimensionalSafetyCanopy();

  const telemetry = {
    vram_used_bytes: Math.round((Number(body.vramUsedGb) || 0) * 1024 ** 3),
    gpu_temperature: Number(body.tempC) || 0,
    tokens_per_sec: Math.round((Number(body.hashrateHps) || Number(body.gpuUtilPct) || 0) * 10),
    timestamp: Date.now(),
  };

  const entropyBlock = audit.registerExecutionBlock(
    {
      tenantHash: body.instanceId || 'openclaw',
      payload: {
        source: body.source || 'openclaw-mining',
        cpuCoin: body.cpuCoin,
        gpuCoin: body.gpuCoin,
        provider: body.provider,
        creditBurnMode: body.creditBurnMode !== false,
      },
    },
    telemetry,
  );

  const evolutionReport = evolution.evaluateAndMutate(
    { gpu_temperature: telemetry.gpu_temperature },
    telemetry.tokens_per_sec,
  );

  const safety = canopy.evaluateSystemHealth(
    {
      gpu_temperature: telemetry.gpu_temperature,
      vram_allocated_bytes: telemetry.vram_used_bytes,
    },
    Number(body.instanceIndex) || 1,
  );

  const record = {
    accepted: true,
    instanceId: body.instanceId,
    provider: body.provider,
    pillar5: entropyBlock,
    pillar7: { evolution: evolutionReport, safety },
    ingestedAt: new Date().toISOString(),
  };

  metricsStore.push(record);
  if (metricsStore.length > 500) metricsStore.shift();

  fs.appendFile(helixLog, `${JSON.stringify(record)}\n`).catch(() => {});

  return record;
}

export function getMiningSummary() {
  const instances = new Set(metricsStore.map((r) => r.instanceId).filter(Boolean));
  const avgTemp =
    metricsStore.length === 0
      ? 0
      : metricsStore.reduce((s, r) => s + (r.pillar7?.safety ? 0 : 0), 0);

  const temps = metricsStore.map((r) => {
    const t = r.pillar7?.evolution ? 0 : 0;
    return t;
  });

  let tempSum = 0;
  let tempCount = 0;
  for (const r of metricsStore) {
    const block = r.pillar5;
    if (block?.hardwareMetrics?.temp) {
      tempSum += block.hardwareMetrics.temp;
      tempCount += 1;
    }
  }

  return {
    service: 'openclaw-mining',
    activeInstances: instances.size,
    samplesInMemory: metricsStore.length,
    avgTempC: tempCount ? tempSum / tempCount : null,
    creditBurnMode: true,
    pillars: ['P5_entropy_core', 'P7_ancestral_layer'],
    lastIngestedAt: metricsStore.at(-1)?.ingestedAt ?? null,
    generatedAt: new Date().toISOString(),
  };
}

export function applyMiningThrottle(body = {}) {
  return {
    accepted: true,
    throttled: true,
    temp: body.temp,
    status: body.status || 'THERMAL_LIMIT',
    at: new Date().toISOString(),
  };
}

export default { ingestMiningTelemetry, getMiningSummary, applyMiningThrottle };
