/**
 * Mining fleet adapter — reads Python mining manager state + env wallets.
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const statusPath = path.join(repoRoot, '.run', 'mining', 'mining-manager-status.json');

function walletRoutes() {
  const envMap = [
    ['tao', ['MINING_ROOT_TAO', 'TAO_WALLET_ADDRESS']],
    ['sol', ['NEXUS_TREASURY_SOLANA', 'TREASURY_ADDRESS']],
    ['etc', ['MINING_ROOT_BASE_ETC', 'ETC_WALLET_ADDRESS']],
    ['xmr', ['MONERO_WALLET_ADDRESS', 'XMR_WALLET_ADDRESS']],
    ['zec', ['MINING_ROOT_ZEC']],
    ['iotex', ['IOTEX_TREASURY']],
    ['btc', ['MINING_ROOT_BASE_BTC', 'IOTEX_BTC_BRIDGE']],
  ];

  const routes = {};
  for (const [coin, keys] of envMap) {
    for (const key of keys) {
      const val = process.env[key];
      if (val && val !== '[REDACTED]') {
        routes[coin] = { wallet: val, source_env: key };
        break;
      }
    }
  }
  return routes;
}

export async function readMiningStatus() {
  try {
    const raw = await fs.readFile(statusPath, 'utf8');
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

export function getMiningAuthSummary() {
  const master = Boolean(process.env.AGENTSWARM_MASTER_KEY && process.env.AGENTSWARM_MASTER_KEY !== '[REDACTED]');
  const vault = Boolean(process.env.VAULT_ADDR);
  const skip = ['1', 'true', 'yes'].includes(String(process.env.MINING_AUTH_SKIP || '').toLowerCase());
  return {
    ok: master || vault || skip,
    master_key_configured: master,
    vault_configured: vault,
    auth_skip: skip,
    mode: process.env.AUTH_MODE || 'vault-approle',
  };
}

export function getRewardRoutes() {
  return {
    routes: walletRoutes(),
    configured_count: Object.keys(walletRoutes()).length,
  };
}

export function runMiningCommand(command, extraArgs = []) {
  return new Promise((resolve, reject) => {
    const child = spawn('python3', ['-m', 'mining', command, '--json', ...extraArgs], {
      cwd: repoRoot,
      env: { ...process.env, PYTHONPATH: repoRoot },
    });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (d) => { stdout += d; });
    child.stderr.on('data', (d) => { stderr += d; });
    child.on('close', (code) => {
      try {
        const parsed = JSON.parse(stdout || '{}');
        resolve({ code, data: parsed, stderr });
      } catch {
        resolve({ code, data: { ok: code === 0, raw: stdout, stderr }, stderr });
      }
    });
    child.on('error', reject);
  });
}

export default {
  readMiningStatus,
  getMiningAuthSummary,
  getRewardRoutes,
  runMiningCommand,
};
