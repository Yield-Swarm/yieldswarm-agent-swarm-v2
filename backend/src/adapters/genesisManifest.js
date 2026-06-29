/**
 * Web5 Genesis Manifest adapter — reads config/genesis/web5-manifest.json
 * and merges live Helix genesis hash when available.
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadHelixState } from './helix.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const manifestPath = path.join(repoRoot, 'config', 'genesis', 'web5-manifest.json');

let cached = null;

export async function loadGenesisManifest() {
  if (cached) return cached;
  const raw = await fs.readFile(manifestPath, 'utf8');
  cached = JSON.parse(raw);
  return cached;
}

export async function getGenesisManifestLive() {
  const base = await loadGenesisManifest();
  const helix = await loadHelixState();
  return {
    ...base,
    live: {
      generated_at: new Date().toISOString(),
      helix_activated: helix.activated,
      helix_phase: helix.phase,
      genesis_hash: helix.genesisHash,
      yslr_phase: helix.yslr?.phase ?? 'pending',
    },
    equation_resolved: {
      symbol: base.equation.symbol,
      omega_tc: `Ω(${new Date().toISOString()})`,
      stewardship: base.motto,
    },
  };
}

export default { loadGenesisManifest, getGenesisManifestLive };
