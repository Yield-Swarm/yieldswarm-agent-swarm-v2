/**
 * Helix Nodes adapter — lightweight node registry + lottery tickets.
 */

import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const CLI = path.join(REPO_ROOT, 'services', 'helix_nodes', 'cli.py');

function runCli(args) {
  return new Promise((resolve, reject) => {
    const proc = spawn('python3', [CLI, ...args], {
      cwd: REPO_ROOT,
      env: { ...process.env, PYTHONPATH: REPO_ROOT },
    });
    let stdout = '';
    let stderr = '';
    proc.stdout.on('data', (d) => { stdout += d; });
    proc.stderr.on('data', (d) => { stderr += d; });
    proc.on('close', (code) => {
      if (code !== 0) {
        const err = new Error(stderr || `helix_nodes cli exit ${code}`);
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

export async function ping() {
  const summary = await runCli(['summary']);
  return { ok: true, strand: 'helix-nodes', ...summary };
}

export async function getSummary() {
  return runCli(['summary']);
}

export async function registerNode({ userId, referralCode, platform } = {}) {
  const args = ['register'];
  if (referralCode) args.push('--referral', referralCode);
  const node = await runCli(args);
  if (userId) node.user_id = userId;
  if (platform) node.platform = platform;
  return node;
}

export async function heartbeatNode(nodeId, meta = {}) {
  return runCli(['heartbeat', nodeId]);
}

export async function getLeaderboard() {
  return runCli(['leaderboard']);
}

export async function getLottery() {
  return runCli(['lottery']);
}

export async function drawLottery() {
  return runCli(['draw']);
}

export async function getNodeStatus(nodeId) {
  const { spawnSync } = await import('node:child_process');
  const script = `
import json, sys
from services.helix_nodes.store import get_store
n = get_store().get(sys.argv[1])
print(json.dumps(n or {"error":"not found"}))
`;
  const r = spawnSync('python3', ['-c', script, nodeId], {
    cwd: REPO_ROOT,
    env: { ...process.env, PYTHONPATH: REPO_ROOT },
    encoding: 'utf-8',
  });
  if (r.status !== 0) throw new Error(r.stderr || 'status failed');
  return JSON.parse(r.stdout);
}

export async function recordAction(nodeId, action) {
  const script = `
import json, sys
from services.helix_nodes.store import get_store
out = get_store().record_action(sys.argv[1], sys.argv[2])
print(json.dumps(out or {"error":"invalid action or node"}))
`;
  const { spawnSync } = await import('node:child_process');
  const r = spawnSync('python3', ['-c', script, nodeId, action], {
    cwd: REPO_ROOT,
    env: { ...process.env, PYTHONPATH: REPO_ROOT },
    encoding: 'utf-8',
  });
  if (r.status !== 0) throw new Error(r.stderr || 'action failed');
  const data = JSON.parse(r.stdout);
  if (data.error) {
    const err = new Error(data.error);
    err.status = 400;
    throw err;
  }
  return data;
}
