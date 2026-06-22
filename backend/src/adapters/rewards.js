/**
 * Rewards adapter — reshard / assemble / sweep orchestrator bridge.
 */

import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const REWARDS_CLI = path.join(REPO_ROOT, 'services', 'rewards', 'cli.py');

function runRewardsCli(args) {
  return new Promise((resolve, reject) => {
    const proc = spawn('python3', [REWARDS_CLI, ...args], {
      cwd: REPO_ROOT,
      env: { ...process.env, PYTHONPATH: REPO_ROOT },
    });
    let stdout = '';
    let stderr = '';
    proc.stdout.on('data', (d) => { stdout += d; });
    proc.stderr.on('data', (d) => { stderr += d; });
    proc.on('close', (code) => {
      if (code !== 0) {
        const err = new Error(stderr || `rewards cli exit ${code}`);
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

export async function getRewardsStatus() {
  return runRewardsCli(['status']);
}

export async function runRewardsSweep({ full = false } = {}) {
  return runRewardsCli([full ? 'full' : 'sweep']);
}

export async function runRewardsReshard() {
  return runRewardsCli(['reshard']);
}

export async function runRewardsAssemble() {
  return runRewardsCli(['assemble']);
}

export async function runRewardsFull() {
  return runRewardsCli(['full']);
}

export async function ping() {
  try {
    const status = await getRewardsStatus();
    return { live: true, source: 'rewards-orchestrator', ...status };
  } catch (err) {
    return { live: false, source: 'rewards-orchestrator', error: err.message };
  }
}
