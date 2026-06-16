/**
 * ZK Circuit Registry — versioned circuit artifacts (ZK¹ Task 39).
 * @module src/infrastructure/zk-circuit-registry
 */

import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '../..');

/** @type {Record<string, import('./zk-types.js').CircuitManifest>} */
export const CIRCUIT_REGISTRY = Object.freeze({
  '1.0.0': {
    version: '1.0.0',
    name: 'entropy_proof',
    publicSignals: ['entropySeed'],
    privateSignals: [
      'gpuTempScaled', 'vramScaled', 'powerScaled',
      'inferenceTpsScaled', 'packetLossScaled',
      'tokenId', 'nonce', 'nodeProfile',
    ],
    wasmPath: path.join(REPO_ROOT, 'circuits/artifacts/entropy_proof_js/entropy_proof.wasm'),
    zkeyPath: path.join(REPO_ROOT, 'circuits/artifacts/entropy_proof_final.zkey'),
    vkeyPath: path.join(REPO_ROOT, 'circuits/artifacts/verification_key.json'),
    maxProveMs: 30_000,
  },
});

export function resolveCircuit(version = '1.0.0') {
  const manifest = CIRCUIT_REGISTRY[version];
  if (!manifest) throw new Error(`Unknown circuit version: ${version}`);
  return manifest;
}

export function listCircuitVersions() {
  return Object.keys(CIRCUIT_REGISTRY);
}

export default { CIRCUIT_REGISTRY, resolveCircuit, listCircuitVersions };
