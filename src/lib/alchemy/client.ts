/**
 * Alchemy SDK Rolodex — TypeScript / Viem bridge (Christopher's First App).
 * API key via ALCHEMY_API_KEY env / Vault-injected agent.env — never commit keys.
 */

import { readFileSync } from 'node:fs';
import path from 'node:path';
import { createPublicClient, http, type Chain, type PublicClient } from 'viem';
import {
  arbitrum,
  avalanche,
  base,
  baseSepolia,
  celo,
  gnosis,
  linea,
  mainnet,
  optimism,
  polygon,
  scroll,
  sepolia,
} from 'viem/chains';

const MANIFEST_PATH = path.join(
  process.cwd(),
  'config',
  'alchemy',
  'christophers-first-app.json',
);

type NetworkRow = {
  name: string;
  host: string;
  family: string;
  chain_id?: number;
  url_pattern?: string;
  enabled?: boolean;
};

type Manifest = {
  app: string;
  api_key_env: string;
  networks: Record<string, NetworkRow>;
};

let _manifest: Manifest | null = null;

export function loadManifest(): Manifest {
  if (_manifest) return _manifest;
  _manifest = JSON.parse(readFileSync(MANIFEST_PATH, 'utf8')) as Manifest;
  return _manifest;
}

export function getAlchemyApiKey(): string {
  return process.env.ALCHEMY_API_KEY || '';
}

export function alchemyRpcUrl(networkId: string, apiKey = getAlchemyApiKey()): string {
  if (!apiKey) return '';
  const net = loadManifest().networks[networkId];
  if (!net || net.enabled === false) return '';
  if (net.url_pattern === 'starknet_v0_10') {
    return `https://${net.host}/starknet/version/rpc/v0_10/${apiKey}`;
  }
  return `https://${net.host}/v2/${apiKey}`;
}

/** Viem chain map for primary YieldSwarm EVM networks */
const VIEM_BY_NETWORK_ID: Record<string, Chain> = {
  'ethereum-mainnet': mainnet,
  'ethereum-sepolia': sepolia,
  'base-mainnet': base,
  'base-sepolia': baseSepolia,
  'polygon-mainnet': polygon,
  'arbitrum-mainnet': arbitrum,
  'op-mainnet': optimism,
  'avalanche-mainnet': avalanche,
  'linea-mainnet': linea,
  'scroll-mainnet': scroll,
  'gnosis-mainnet': gnosis,
  'celo-mainnet': celo,
};

export function createAlchemyPublicClient(
  networkId: string,
  apiKey = getAlchemyApiKey(),
): PublicClient | null {
  const chain = VIEM_BY_NETWORK_ID[networkId];
  const url = alchemyRpcUrl(networkId, apiKey);
  if (!chain || !url) return null;
  return createPublicClient({
    chain,
    transport: http(url),
  });
}

export function listAlchemyNetworks(family?: string) {
  const manifest = loadManifest();
  return Object.entries(manifest.networks)
    .filter(([, n]) => n.enabled !== false)
    .filter(([, n]) => !family || n.family === family)
    .map(([id, n]) => ({
      id,
      name: n.name,
      family: n.family,
      chain_id: n.chain_id ?? null,
      host: n.host,
    }));
}

export const ALCHEMY_DEFAULT_ALIASES = {
  solana: 'solana-mainnet',
  ethereum: 'ethereum-mainnet',
  base: 'base-mainnet',
  polygon: 'polygon-mainnet',
  arbitrum: 'arbitrum-mainnet',
  optimism: 'op-mainnet',
} as const;

export function resolveDefaultRpcUrls(apiKey = getAlchemyApiKey()) {
  const out: Record<string, string> = {};
  for (const [alias, networkId] of Object.entries(ALCHEMY_DEFAULT_ALIASES)) {
    const url = alchemyRpcUrl(networkId, apiKey);
    if (url) out[alias] = url;
  }
  return out;
}
