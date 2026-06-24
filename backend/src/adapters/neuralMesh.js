/**
 * Neural mesh registry — 14 elevators + external API catalog.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getSolenoidStatus, runAxisMatrix } from './solenoid.js';
import { getTeslaMeshStatus } from './teslaFleet.js';
import { getStarlinkStatus } from './starlink.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');

function loadApiRegistry() {
  const registryPath = path.join(repoRoot, 'config', 'neural_mesh', 'external_apis.yaml');
  if (!fs.existsSync(registryPath)) {
    return { version: 1, apis: [], total: 0 };
  }
  const raw = fs.readFileSync(registryPath, 'utf8');
  const apis = [];
  for (const line of raw.split('\n')) {
    const m = line.match(/^\s+-\s+id:\s+(\S+)/);
    if (m) apis.push(m[1]);
  }
  return { path: registryPath, apis, total: apis.length };
}

export function getNeuralMeshOverview() {
  const registry = loadApiRegistry();
  const solenoid = getSolenoidStatus();
  return {
    layer: 'PDs1_NEURAL_MESH',
    elevators: 14,
    solenoidMode: solenoid.layer,
    stateChainHash: solenoid.stateChainHash,
    triSolenoid: {
      nexus: { role: 'orchestration', env: 'NEXUS_CHAIN_URL' },
      helix: { role: 'cross_chain_yield', env: 'HELIX_CHAIN_URL' },
      shadow: { role: 'arena_competition', env: 'SHADOW_CHAIN_URL' },
    },
    physicalMesh: {
      tesla: getTeslaMeshStatus(),
      starlink: getStarlinkStatus(),
    },
    externalApis: registry,
    creditPoolUsd: 5408,
    timestamp: new Date().toISOString(),
  };
}

export async function runNeuralMeshMatrix(body = {}) {
  const payloads = body.payloads || body.pipelinePayloads;
  if (!payloads || payloads.length !== 14) {
    const defaultResult = await runAxisMatrix(body);
    return { ...defaultResult, source: 'quadrilateral_default_matrix' };
  }
  const result = await runAxisMatrix({ ...body, pipelinePayloads: payloads });
  return { ...result, source: 'neural_mesh_14_lane' };
}
