/**
 * Alchemy RPC endpoint resolver — Christopher's First App
 * API key via ALCHEMY_API_KEY env / Vault yieldswarm/data/integrations/alchemy
 * Never commit the API key; URLs are built at runtime.
 */

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const MANIFEST_PATH = path.resolve(__dirname, '..', '..', '..', 'config', 'alchemy', 'christophers-first-app.json');

let _manifest = null;

export function loadAlchemyManifest() {
  if (_manifest) return _manifest;
  _manifest = JSON.parse(readFileSync(MANIFEST_PATH, 'utf8'));
  return _manifest;
}

export function getAlchemyApiKey() {
  return process.env.ALCHEMY_API_KEY || '';
}

/**
 * Build HTTPS RPC URL for a manifest network id.
 * @param {string} networkId e.g. ethereum-mainnet, solana-mainnet
 * @param {string} [apiKey] defaults to ALCHEMY_API_KEY
 */
export function alchemyRpcUrl(networkId, apiKey = getAlchemyApiKey()) {
  if (!apiKey) return '';
  const manifest = loadAlchemyManifest();
  const net = manifest.networks[networkId];
  if (!net) return '';

  const key = apiKey.trim();
  if (net.url_pattern === 'starknet_v0_10') {
    return `https://${net.host}/starknet/version/rpc/v0_10/${key}`;
  }
  return `https://${net.host}/v2/${key}`;
}

/** Primary YieldSwarm chain defaults when env RPC URLs are unset. */
export const ALCHEMY_DEFAULT_NETWORK_IDS = {
  solana: 'solana-mainnet',
  solanaDevnet: 'solana-devnet',
  ethereum: 'ethereum-mainnet',
  ethereumSepolia: 'ethereum-sepolia',
  base: 'base-mainnet',
  baseSepolia: 'base-sepolia',
  polygon: 'polygon-mainnet',
  arbitrum: 'arbitrum-mainnet',
  optimism: 'op-mainnet',
  avalanche: 'avalanche-mainnet',
};

export function resolveAlchemyDefaults(apiKey = getAlchemyApiKey()) {
  if (!apiKey) return {};
  const out = {};
  for (const [alias, networkId] of Object.entries(ALCHEMY_DEFAULT_NETWORK_IDS)) {
    const url = alchemyRpcUrl(networkId, apiKey);
    if (url) out[alias] = url;
  }
  return out;
}

export function listAlchemyEndpoints(apiKey = getAlchemyApiKey(), { revealUrls = false } = {}) {
  const manifest = loadAlchemyManifest();
  const endpoints = [];
  for (const [id, net] of Object.entries(manifest.networks)) {
    const fullUrl = apiKey ? alchemyRpcUrl(id, apiKey) : null;
    endpoints.push({
      id,
      name: net.name,
      family: net.family,
      chain_id: net.chain_id ?? null,
      host: net.host,
      enabled: net.enabled !== false,
      https_url: revealUrls ? fullUrl : (fullUrl ? fullUrl.replace(apiKey, '***REDACTED***') : null),
    });
  }
  return {
    app: manifest.app,
    api_key_configured: Boolean(apiKey),
    api_key_env: manifest.api_key_env,
    count: endpoints.length,
    endpoints,
  };
}

export function applyAlchemyRpcEnvDefaults() {
  const key = getAlchemyApiKey();
  if (!key) return { applied: false };

  const urls = resolveAlchemyDefaults(key);
  const mappings = [
    ['SOLANA_RPC_URL', urls.solana],
    ['ETHEREUM_RPC_URL', urls.ethereum],
    ['EVM_RPC_URL', urls.ethereum],
    ['MAINNET_RPC_URL', urls.ethereum],
    ['BASE_RPC_URL', urls.base],
    ['EVM_RPC_URL_1', urls.ethereum],
    ['EVM_RPC_URL_8453', urls.base],
    ['EVM_RPC_URL_137', urls.polygon],
    ['EVM_RPC_URL_42161', urls.arbitrum],
    ['SEPOLIA_RPC_URL', urls.ethereumSepolia],
  ];

  const applied = [];
  for (const [envKey, url] of mappings) {
    if (url && !process.env[envKey]) {
      process.env[envKey] = url;
      applied.push(envKey);
    }
  }
  return { applied: true, keys: applied };
}
