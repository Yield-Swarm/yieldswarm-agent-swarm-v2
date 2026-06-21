/**
 * Nexus Chain (Solenoid 1) — central orchestration adapter.
 */

import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const NEXUS_CLI = path.join(REPO_ROOT, 'services', 'nexus', 'cli.py');

function runNexusCli(args) {
  return new Promise((resolve, reject) => {
    const proc = spawn('python3', [NEXUS_CLI, ...args], { cwd: REPO_ROOT });
    let stdout = '';
    let stderr = '';
    proc.stdout.on('data', (d) => { stdout += d; });
    proc.stderr.on('data', (d) => { stderr += d; });
    proc.on('close', (code) => {
      if (code !== 0) {
        const err = new Error(stderr || `nexus cli exit ${code}`);
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

export async function getNexusStatus() {
  return runNexusCli(['status']);
}

export async function listSolenoids() {
  return runNexusCli(['solenoids']);
}

export async function dispatchMessage(target, topic, payload = {}) {
  return runNexusCli(['dispatch', target, topic, JSON.stringify(payload)]);
}

export async function registerAgent(agentId, solenoid, shardId) {
  return runNexusCli(['register-agent', agentId, solenoid, String(shardId)]);
}

export async function multicloudLaunch(provider, workload = 'gpu-worker') {
  return runNexusCli(['multicloud', 'launch', provider, workload]);
}

export async function ping() {
  try {
    const status = await getNexusStatus();
    return { live: true, source: 'nexus-chain', ...status };
  } catch (err) {
    return { live: false, source: 'nexus-chain', error: err.message };
  }
}
