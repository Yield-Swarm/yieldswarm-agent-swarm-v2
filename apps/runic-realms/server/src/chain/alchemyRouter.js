/**
 * Dynamic Alchemy RPC router — loads all supported chains and routes compute jobs.
 */

import crypto from 'node:crypto';
import { ALCHEMY_CHAINS } from '../config/alchemy-chains.js';

const clients = new Map();
let alchemySdk = null;

async function loadAlchemySdk() {
  if (alchemySdk) return alchemySdk;
  try {
    alchemySdk = await import('alchemy-sdk');
    return alchemySdk;
  } catch {
    return null;
  }
}

export function getAlchemyApiKey() {
  return process.env.ALCHEMY_API_KEY || process.env.ALCHEMY_API_KEY_SECRET || '';
}

export function buildRpcUrl(subdomain) {
  const key = getAlchemyApiKey();
  if (!key) return null;
  return `https://${subdomain}.g.alchemy.com/v2/${key}`;
}

export function listChains(includeTestnets = false) {
  return ALCHEMY_CHAINS.filter((c) => includeTestnets || !c.testnet).map((c) => ({
    ...c,
    rpcUrl: buildRpcUrl(c.subdomain) ? '(configured)' : '(missing ALCHEMY_API_KEY)',
  }));
}

function pickChainForJob(jobId) {
  const hash = crypto.createHash('sha256').update(jobId).digest();
  const idx = hash.readUInt32BE(0) % ALCHEMY_CHAINS.length;
  return ALCHEMY_CHAINS[idx];
}

async function jsonRpc(rpcUrl, method, params = []) {
  const res = await fetch(rpcUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }),
    signal: AbortSignal.timeout(8000),
  });
  const json = await res.json();
  if (json.error) throw new Error(json.error.message || 'rpc_error');
  return json.result;
}

/**
 * Get or create cached Alchemy SDK client for a chain spec.
 */
export async function getAlchemyClient(chainSpec) {
  const key = getAlchemyApiKey();
  if (!key) return null;

  const cacheKey = chainSpec.id;
  if (clients.has(cacheKey)) return clients.get(cacheKey);

  const sdk = await loadAlchemySdk();
  if (!sdk) return null;

  const networkEnum = sdk.Network?.[networkKey(chainSpec.id)];
  if (!networkEnum) {
    return { rpcOnly: true, rpcUrl: buildRpcUrl(chainSpec.subdomain) };
  }

  const client = new sdk.Alchemy({ apiKey: key, network: networkEnum });
  clients.set(cacheKey, client);
  return client;
}

function networkKey(chainId) {
  const map = {
    'eth-mainnet': 'ETH_MAINNET',
    'eth-sepolia': 'ETH_SEPOLIA',
    'polygon-mainnet': 'MATIC_MAINNET',
    'polygon-amoy': 'MATIC_AMOY',
    'arb-mainnet': 'ARB_MAINNET',
    'arb-sepolia': 'ARB_SEPOLIA',
    'opt-mainnet': 'OPT_MAINNET',
    'opt-sepolia': 'OPT_SEPOLIA',
    'base-mainnet': 'BASE_MAINNET',
    'base-sepolia': 'BASE_SEPOLIA',
    'blast-mainnet': 'BLAST_MAINNET',
    'zksync-mainnet': 'ZKSYNC_MAINNET',
    'linea-mainnet': 'LINEA_MAINNET',
    'scroll-mainnet': 'SCROLL_MAINNET',
    'mantle-mainnet': 'MANTLE_MAINNET',
    'bnb-mainnet': 'BNB_MAINNET',
    'avax-mainnet': 'AVAX_MAINNET',
    'gnosis-mainnet': 'GNOSIS_MAINNET',
  };
  return map[chainId];
}

/**
 * Route a compute job to an Alchemy chain — returns block anchor + RPC metadata.
 */
export async function routeComputeJob(job) {
  const chain = pickChainForJob(job.id);
  const rpcUrl = buildRpcUrl(chain.subdomain);

  if (!rpcUrl) {
    return {
      chain: chain.id,
      chainId: chain.chainId,
      simulated: true,
      reason: 'ALCHEMY_API_KEY unset',
    };
  }

  try {
    const blockHex = await jsonRpc(rpcUrl, 'eth_blockNumber', []);
    const blockNumber = Number.parseInt(blockHex, 16);

    const client = await getAlchemyClient(chain);
    let alchemyBlock = blockNumber;
    if (client?.core?.getBlockNumber) {
      alchemyBlock = await client.core.getBlockNumber();
    }

    return {
      chain: chain.id,
      chainName: chain.name,
      chainId: chain.chainId,
      symbol: chain.symbol,
      blockNumber: alchemyBlock,
      rpcSubdomain: chain.subdomain,
      jobAnchor: `runic:${job.id}@${chain.id}:${alchemyBlock}`,
      simulated: false,
    };
  } catch (err) {
    return {
      chain: chain.id,
      chainId: chain.chainId,
      simulated: true,
      error: err.message,
    };
  }
}

/**
 * Health sweep across all mainnet Alchemy endpoints.
 */
export async function probeAllChains() {
  const mainnets = ALCHEMY_CHAINS.filter((c) => !c.testnet);
  const key = getAlchemyApiKey();
  if (!key) {
    return mainnets.map((c) => ({ id: c.id, live: false, reason: 'no_api_key' }));
  }

  return Promise.all(
    mainnets.map(async (c) => {
      const rpcUrl = buildRpcUrl(c.subdomain);
      try {
        const block = await jsonRpc(rpcUrl, 'eth_blockNumber', []);
        return { id: c.id, name: c.name, live: true, block: Number.parseInt(block, 16) };
      } catch (err) {
        return { id: c.id, name: c.name, live: false, error: err.message };
      }
    }),
  );
}
