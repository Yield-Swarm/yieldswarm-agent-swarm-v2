/**
 * Shadow Chain (Solenoid 3) — Arena program adapter.
 */

import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');

export const ARENA_PROGRAM_ID = 'Arna1111111111111111111111111111111111111';
export const SWARM_OPS_PROGRAM_ID = 'Swrm1111111111111111111111111111111111111';
export const MAX_COMPETITORS = 521;

function runPython(script, args = []) {
  return new Promise((resolve, reject) => {
    const proc = spawn('python3', [script, ...args], { cwd: REPO_ROOT });
    let stdout = '';
    let stderr = '';
    proc.stdout.on('data', (d) => { stdout += d; });
    proc.stderr.on('data', (d) => { stderr += d; });
    proc.on('close', (code) => {
      if (code !== 0) {
        const err = new Error(stderr || `shadow cli exit ${code}`);
        err.status = 502;
        return reject(err);
      }
      try {
        resolve(JSON.parse(stdout));
      } catch {
        resolve({ raw: stdout });
      }
    });
  });
}

export async function getShadowStatus() {
  return {
    solenoid: 'shadow',
    name: 'Shadow Chain',
    program: 'arena',
    programId: ARENA_PROGRAM_ID,
    swarmOpsProgramId: SWARM_OPS_PROGRAM_ID,
    maxCompetitors: MAX_COMPETITORS,
    chain: "Kyle's chain",
    features: ['competition', 'reputation', 'rewards', 'zk_swarm_batch', 'swarm_ops_cpi'],
  };
}

export async function getVaultInjection(provider = 'akash') {
  const cli = path.join(REPO_ROOT, 'services', 'vault', 'cli.py');
  return runPython(cli, ['spec', provider, 'shadow']);
}

export async function ping() {
  try {
    const status = await getShadowStatus();
    return { live: true, source: 'shadow-chain', ...status };
  } catch (err) {
    return { live: false, source: 'shadow-chain', error: err.message };
  }
}
