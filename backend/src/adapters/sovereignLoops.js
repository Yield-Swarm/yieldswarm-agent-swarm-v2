/**
 * Sovereign loops telemetry adapter — merges runtime state with live overlays.
 */

import { getSovereignState } from './sovereign.js';
import { getHelixDeltaTelemetry } from './helixDeltaV5.js';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const infraPath = path.resolve(__dirname, '..', '..', '..', 'src', 'infrastructure');
const { getSovereignLoopManager } = require(path.join(infraPath, 'SovereignLoopManager.js'));

export async function getSovereignLoopsTelemetry() {
  const [sovereign, helix] = await Promise.all([
    getSovereignState(),
    Promise.resolve().then(() => getHelixDeltaTelemetry()),
  ]);

  const manager = getSovereignLoopManager();
  manager.ingestTelemetry({ sovereign, helix });

  return {
    generatedAt: new Date().toISOString(),
    ...manager.snapshot(),
    solenoid: { ring: 1, quadrant: 'Sovereign Core Matrix' },
  };
}

export function forceSovereignRebalance() {
  return getSovereignLoopManager().forceRebalance();
}

export function forceSovereignReplicate() {
  return getSovereignLoopManager().forceReplicate();
}

export function triggerSovereignPatch() {
  return getSovereignLoopManager().triggerPatch();
}

export default {
  getSovereignLoopsTelemetry,
  forceSovereignRebalance,
  forceSovereignReplicate,
  triggerSovereignPatch,
};
