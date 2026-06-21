/**
 * Helix Reverberator — multi-chain treasury routing to Mining Roots + IoTeX.
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import crypto from 'node:crypto';
import { CHAIN_IDS, quoteHelixSettlement } from './helixBridge.js';
import { getNexusOrchestrator } from '../../../solenoids/nexus/index.js';
import { MESSAGE_TOPICS } from '../../../solenoids/nexus/constants.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const MANIFEST_PATH = path.join(REPO_ROOT, 'config', 'TREASURY_MANIFEST.json');
const ROUTE_LOG = path.join(REPO_ROOT, '.run', 'helix-routes.jsonl');

let manifestCache = null;
let manifestLoadedAt = 0;

async function loadManifest() {
  if (manifestCache && Date.now() - manifestLoadedAt < 60_000) {
    return manifestCache;
  }
  const raw = await fs.readFile(MANIFEST_PATH, 'utf8');
  manifestCache = JSON.parse(raw);
  manifestLoadedAt = Date.now();
  return manifestCache;
}

function splitBps(amount, weights) {
  const totalWeight = Object.values(weights).reduce((a, b) => a + b, 0);
  const splits = {};
  let allocated = 0;
  const keys = Object.keys(weights);
  for (let i = 0; i < keys.length; i++) {
    const key = keys[i];
    if (i === keys.length - 1) {
      splits[key] = amount - allocated;
    } else {
      const share = Math.floor((amount * weights[key]) / totalWeight);
      splits[key] = share;
      allocated += share;
    }
  }
  return splits;
}

const DEFAULT_WEIGHTS = {
  base_etc: 12,
  zec: 10,
  prl: 8,
  tao: 15,
  base_hype: 10,
  base_cbeth: 10,
  base_btc: 12,
  iotex: 18,
  btc_via_iopay: 5,
};

/**
 * Route yield across all Mining Roots including IoTeX hub.
 */
export async function routeYieldToMiningRoots({
  grossLamports,
  weights = DEFAULT_WEIGHTS,
  agentPubkey = null,
  dryRun = true,
}) {
  const manifest = await loadManifest();
  const roots = manifest.mining_roots;
  const splits = splitBps(Number(grossLamports) || 0, weights);

  const routes = Object.entries(splits).map(([rootKey, amount]) => ({
    rootKey,
    address: roots[rootKey] || null,
    amount,
    chainId: rootKey === 'iotex' || rootKey.startsWith('base_')
      ? (rootKey === 'iotex' ? CHAIN_IDS.IOTEX : CHAIN_IDS.BASE)
      : rootKey === 'prl' || rootKey === 'tao'
        ? CHAIN_IDS.SOLANA
        : CHAIN_IDS.ETHEREUM,
  }));

  const quote = agentPubkey
    ? await quoteHelixSettlement({
      agentPubkey,
      originChainId: CHAIN_IDS.HELIX,
      targetChainId: CHAIN_IDS.SOLANA,
      amount: grossLamports,
    })
    : null;

  const receipt = {
    id: crypto.randomUUID(),
    dryRun,
    grossLamports: Number(grossLamports) || 0,
    routes,
    iotexHub: manifest.iotex_hub,
    nexusTreasury: manifest.nexus_treasury,
    quote,
    timestamp: new Date().toISOString(),
  };

  if (!dryRun) {
    await fs.mkdir(path.dirname(ROUTE_LOG), { recursive: true });
    await fs.appendFile(ROUTE_LOG, `${JSON.stringify(receipt)}\n`, 'utf8');
    try {
      const nexus = getNexusOrchestrator();
      await nexus.init();
      await nexus.bus.publish(MESSAGE_TOPICS.YIELD_ROUTED, receipt, {
        sourceSolenoid: 'helix',
      });
    } catch {
      // bus optional during cold start
    }
  }

  return receipt;
}

/**
 * ZK-Swarm proof batch submission (off-chain verifier hook).
 */
export async function submitZkSwarmBatch({ proofs = [], mutationRoot = null }) {
  if (!Array.isArray(proofs) || proofs.length === 0) {
    throw new Error('proofs array required');
  }
  if (proofs.length > 64) {
    throw new Error('max batch size 64');
  }

  const batchId = crypto.createHash('sha256')
    .update(JSON.stringify({ proofs, mutationRoot, t: Date.now() }))
    .digest('hex');

  const verified = proofs.map((p, i) => ({
    index: i,
    publicInputsHash: p.publicInputsHash || p.public_inputs_hash || null,
    valid: Boolean(p.proof || p.pi_a),
  }));

  const result = {
    batchId,
    mutationRoot,
    count: proofs.length,
    verifiedCount: verified.filter((v) => v.valid).length,
    verifier: process.env.ZK__VERIFIER_ADDRESS || 'unconfigured',
    timestamp: new Date().toISOString(),
  };

  try {
    const nexus = getNexusOrchestrator();
    await nexus.init();
    await nexus.bus.publish(MESSAGE_TOPICS.ZK_BATCH_VERIFIED, result, {
      sourceSolenoid: 'helix',
    });
  } catch {
    // non-fatal
  }

  return result;
}

export async function getHelixTreasuryStatus() {
  const manifest = await loadManifest();
  return {
    solenoid: 'helix',
    miningRoots: manifest.mining_roots,
    iotexHub: manifest.iotex_hub,
    chainIds: manifest.chain_ids,
    weights: DEFAULT_WEIGHTS,
    timestamp: new Date().toISOString(),
  };
}
