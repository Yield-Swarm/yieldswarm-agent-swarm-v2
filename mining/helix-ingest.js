/**
 * mining/helix-ingest.js — ingest OpenClaw mining metrics into entropy-core (Pillar 5 + 7).
 */
'use strict';

const crypto = require('crypto');
const path = require('path');

const infra = require(path.join(__dirname, '..', 'src', 'infrastructure', 'entropy-core'));

const {
  HardenedAuditEngine,
  SymbioticEvolutionEngine,
  OmniDimensionalSafetyCanopy,
  MultiLingualSolenoidEngine,
} = infra;

function readStdin() {
  return new Promise((resolve) => {
    let data = '';
    process.stdin.on('data', (c) => (data += c));
    process.stdin.on('end', () => resolve(data));
  });
}

async function main() {
  const raw = await readStdin();
  if (!raw.trim()) return;

  const m = JSON.parse(raw);
  const audit = new HardenedAuditEngine();
  const evolution = new SymbioticEvolutionEngine();
  const canopy = new OmniDimensionalSafetyCanopy();
  const solenoid = new MultiLingualSolenoidEngine();

  const telemetry = {
    vram_used_bytes: Math.round((m.vramUsedGb || 0) * 1024 ** 3),
    gpu_temperature: m.tempC || 0,
    tokens_per_sec: Math.round((m.hashrateHps || m.gpuUtilPct || 0) * 10),
    timestamp: Date.now(),
  };

  const block = audit.registerExecutionBlock(
    {
      tenantHash: crypto.createHash('sha256').update(m.instanceId || 'openclaw').digest('hex'),
      payload: {
        source: 'openclaw-mining',
        cpuCoin: m.cpuCoin,
        gpuCoin: m.gpuCoin,
        provider: m.provider,
        creditBurnMode: m.creditBurnMode,
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
    m.instanceIndex || 1,
  );

  solenoid.incrementSolenoidLoop();
  const proof = solenoid.verifyMultilingualProof(
    5,
    'rust',
    JSON.stringify(m),
    m.instanceIndex || 0,
  );

  const out = {
    pillar5_entropy: block,
    pillar7_ancestral: {
      evolution: evolutionReport,
      safety,
      solenoidProof: proof.success,
    },
    stateChainHash: audit.stateChainHash,
  };

  const logPath = process.env.MINING_HELIX_LOG || '.run/mining-helix.jsonl';
  require('fs').appendFileSync(logPath, JSON.stringify(out) + '\n');
  process.stdout.write(JSON.stringify(out) + '\n');
}

main().catch((err) => {
  console.error('[helix-ingest]', err.message);
  process.exit(0);
});
