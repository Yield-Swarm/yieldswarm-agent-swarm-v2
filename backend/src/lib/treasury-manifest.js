/**
 * Treasury Manifest loader — Nexus treasury + mining roots + IoTeX IOPAY hub.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const MANIFEST_PATH = path.join(repoRoot, 'config', 'treasury', 'TREASURY_MANIFEST.json');

/** @typedef {'iotex'|'btc_iopay'|'solana'|'base_etc'|'zec'|'prl'|'tao'|'base_hype'|'base_cbeth'|'base_btc'} YieldDestination */

let cachedManifest = null;

/**
 * Load manifest from disk (cached).
 * @returns {object}
 */
export function loadTreasuryManifest() {
  if (cachedManifest) return cachedManifest;
  const raw = fs.readFileSync(MANIFEST_PATH, 'utf8');
  cachedManifest = JSON.parse(raw);
  return cachedManifest;
}

/** Clear cache (tests). */
export function clearTreasuryManifestCache() {
  cachedManifest = null;
}

/**
 * Resolve destination address from manifest or environment overrides.
 * @param {YieldDestination} destination
 */
export function resolveYieldDestination(destination) {
  const manifest = loadTreasuryManifest();
  const envOverrides = {
    iotex: process.env.IOTEX_TREASURY || manifest.iotex_hub?.primary,
    btc_iopay: process.env.IOTEX_BTC_BRIDGE || manifest.iotex_hub?.btc_bridge,
    solana: process.env.NEXUS_TREASURY_SOLANA || manifest.nexus_treasury?.solana,
    base_etc: process.env.MINING_ROOT_BASE_ETC || manifest.mining_roots?.base_etc,
    zec: process.env.MINING_ROOT_ZEC || manifest.mining_roots?.zec,
    prl: process.env.MINING_ROOT_PRL || manifest.mining_roots?.prl,
    tao: process.env.MINING_ROOT_TAO || manifest.mining_roots?.tao,
    base_hype: process.env.MINING_ROOT_BASE_HYPE || manifest.mining_roots?.base_hype,
    base_cbeth: process.env.MINING_ROOT_BASE_CBETH || manifest.mining_roots?.base_cbeth,
    base_btc: process.env.MINING_ROOT_BASE_BTC || manifest.mining_roots?.base_btc,
  };

  const address = envOverrides[destination];
  if (!address) {
    throw new Error(`Unknown or unconfigured yield destination: ${destination}`);
  }
  return {
    destination,
    address,
    chain: destinationChain(destination),
    source: process.env[`MINING_ROOT_${destination.toUpperCase()}`] || process.env.IOTEX_TREASURY
      ? 'env'
      : 'manifest',
  };
}

/**
 * @param {YieldDestination} destination
 */
function destinationChain(destination) {
  const map = {
    iotex: 'iotex',
    btc_iopay: 'bitcoin',
    solana: 'solana',
    base_etc: 'ethereum',
    zec: 'zcash',
    prl: 'solana',
    tao: 'bittensor',
    base_hype: 'base',
    base_cbeth: 'base',
    base_btc: 'base',
  };
  return map[destination] || 'unknown';
}

/** IoTeX + IOPAY destinations supported by Helix Solenoid 2. */
export const IOTEX_YIELD_DESTINATIONS = ['iotex', 'btc_iopay'];

export function getIotexHubStatus() {
  const manifest = loadTreasuryManifest();
  const primary = resolveYieldDestination('iotex');
  const btcBridge = resolveYieldDestination('btc_iopay');
  return {
    configured: Boolean(primary.address && btcBridge.address),
    primary: primary.address,
    btcBridge: btcBridge.address,
    description: manifest.iotex_hub?.description,
    manifestVersion: manifest.version,
    updatedAt: manifest.updated_at,
  };
}

export default {
  loadTreasuryManifest,
  resolveYieldDestination,
  getIotexHubStatus,
  IOTEX_YIELD_DESTINATIONS,
};
