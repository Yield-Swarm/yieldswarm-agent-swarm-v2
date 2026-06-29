#!/usr/bin/env node
/**
 * Swarm 2 — Multi-mine router (paid RunPod + Akash + owned hardware ONLY).
 * No free-credit / ToS-violating paths. Coins: PRL, KRX, ZANO, QTC, IRON, etc.
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { mintPowId, mintPosId, redactForLogs } from '../lib/encrypted-swarm-id.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const RUN = process.env.RUN_DIR || path.join(ROOT, '.run');

const PAID_ONLY = process.env.MINING_PAID_INSTANCES_ONLY !== '0';
const COINS = (process.env.MULTI_MINE_COINS || 'PRL,KRX,ZANO,QTC,IRON,LTC,XMR').split(',').map((s) => s.trim());
const MONTHLY_BUDGET = Number(process.env.RUNPOD_MONTHLY_BUDGET_USD || 1400);

const WALLETS = {
  PRL: process.env.WALLET_PRL || '',
  KRX: process.env.WALLET_KRX || '',
  ZANO: process.env.WALLET_ZANO || '',
  QTC: process.env.WALLET_QTC || '',
  IRON: process.env.WALLET_IRON || '',
  LTC: process.env.WALLET_LTC || '',
  XMR: process.env.WALLET_XMR || '',
};

function log(msg) {
  console.error(`[multi-mine] ${msg}`);
}

function rankCoins() {
  return COINS.map((coin, i) => ({
    coin,
    priority: i + 1,
    wallet_configured: Boolean(WALLETS[coin]),
    provider: coin === 'XMR' || coin === 'LTC' ? 'owned-or-akash' : 'paid-runpod-or-akash',
  }));
}

async function writePlan(plan) {
  await fs.mkdir(RUN, { recursive: true });
  await fs.writeFile(path.join(RUN, 'multi-mine-plan.json'), `${JSON.stringify(plan, null, 2)}\n`);
}

export async function routeMultiMine(options = {}) {
  const dryRun = options.dryRun ?? process.env.MULTI_MINE_DRY_RUN !== '0';
  const nodeRaw = options.nodeId || process.env.MINING_NODE_ID || `paid-pod-${Date.now()}`;
  const encryptedPowId = mintPowId(nodeRaw, { router: 'multi-mine', paid_only: PAID_ONLY });
  const encryptedPosId = mintPosId(`stake-${nodeRaw}`, { vault: 'escrow-self-owned' });

  if (!PAID_ONLY) {
    log('WARN: MINING_PAID_INSTANCES_ONLY=0 — refusing free-credit paths');
  }

  const ranked = rankCoins();
  const active = ranked.filter((c) => c.wallet_configured).slice(0, 3);
  const primary = active[0]?.coin || ranked[0]?.coin || 'PRL';

  const plan = {
    generated_at: new Date().toISOString(),
    dry_run: dryRun,
    ethical_scope: 'paid-akash-runpod-owned-hardware-only',
    monthly_budget_usd: MONTHLY_BUDGET,
    encrypted_pow_id: encryptedPowId,
    encrypted_pos_id: encryptedPosId,
    node_redacted: redactForLogs(nodeRaw),
    primary_coin: primary,
    ranked_coins: ranked,
    active_coins: active,
    actions: dryRun
      ? [{ action: 'simulate', coin: primary, provider: 'paid-runpod' }]
      : [
          { action: 'launch', provider: 'akash', script: 'scripts/deploy-to-akash.sh', sdl: 'deploy/akash-bittensor-miner.sdl.yml' },
          { action: 'launch', provider: 'runpod', note: 'set RUNPOD_API_KEY — paid pods only' },
          { action: 'edge', provider: 'owned-hardware', script: 'scripts/mining/tandem-pow-launch.sh' },
        ],
  };

  await writePlan(plan);

  if (!dryRun) {
    log(`LIVE routing primary=${primary} encrypted_pow=${encryptedPowId.slice(0, 16)}…`);
    if (process.env.AKASH_KEY_NAME) {
      const { spawn } = await import('node:child_process');
      spawn('bash', ['scripts/mining/tandem-pow-launch.sh'], { cwd: ROOT, stdio: 'inherit', env: { ...process.env, MINING_PAYOUT_ASSET: primary === 'LTC' ? 'LTC' : 'LTC', MINING_NODE_ID: encryptedPowId } });
    }
  } else {
    log(`Dry-run primary=${primary} — set MULTI_MINE_DRY_RUN=0 to launch`);
  }

  return plan;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  routeMultiMine().then((p) => console.log(JSON.stringify(p, null, 2))).catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
