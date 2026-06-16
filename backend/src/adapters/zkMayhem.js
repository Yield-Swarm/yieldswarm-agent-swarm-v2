/**
 * ZK Mayhem Mode status for Arena observability.
 * Exposes proof scheduler config + last cycle receipt without raw telemetry.
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const runDir = path.join(repoRoot, process.env.RUN_DIR || '.run');
const mutationReceipt = path.join(runDir, 'zk-mutation.json');
const circuitWasm = path.join(repoRoot, 'circuits', 'build', 'entropy_proof_js', 'entropy_proof.wasm');

export async function getZkMayhemStatus() {
  const enabled = process.env.ZK_MAYHEM_ENABLED !== '0';
  const minQuality = Number(process.env.ZK_MIN_ENTROPY_QUALITY || 0.5);
  const mutationIntervalMs = Number(process.env.ZK_MUTATION_INTERVAL_MS || 7 * 24 * 60 * 60 * 1000);

  let circuitBuilt = false;
  try {
    await fs.access(circuitWasm);
    circuitBuilt = true;
  } catch {
    circuitBuilt = false;
  }

  let lastCycle = null;
  try {
    const raw = await fs.readFile(mutationReceipt, 'utf8');
    lastCycle = JSON.parse(raw);
  } catch {
    lastCycle = null;
  }

  return {
    service: 'zk-mayhem',
    enabled,
    circuitBuilt,
    minEntropyQuality: minQuality,
    mutationIntervalMs,
    schedulerWebhook: Boolean(process.env.MUTATION_WEBHOOK_URL),
    lastCycle: lastCycle
      ? {
          at: lastCycle.at || lastCycle.emitted_at || null,
          commitment: lastCycle.commitment || lastCycle.seedProof?.commitment || null,
          quality: lastCycle.quality ?? lastCycle.entropyQuality ?? null,
          skipped: Boolean(lastCycle.skipped),
        }
      : null,
    pillars: ['D¹', 'E¹', 'ZK¹', 'O¹', 'A¹', 'S¹', 'U¹'],
    doc: 'docs/MAYHEM_14_PILLAR_ZK.md',
    generatedAt: new Date().toISOString(),
  };
}

export default { getZkMayhemStatus };
