/**
 * Treasury manifest loader — config/TREASURY_MANIFEST.json + env overrides.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '../../..');
const DEFAULT_PATH = path.join(REPO_ROOT, 'config/TREASURY_MANIFEST.json');

let cached = null;

function readManifestFile(filePath = process.env.TREASURY_MANIFEST_PATH || DEFAULT_PATH) {
  if (cached && filePath === DEFAULT_PATH) return cached;
  const raw = fs.readFileSync(filePath, 'utf8');
  const parsed = JSON.parse(raw);
  if (filePath === DEFAULT_PATH) cached = parsed;
  return parsed;
}

export function getTreasuryManifest() {
  const base = readManifestFile();
  return {
    ...base,
    nexus_treasury: {
      ...base.nexus_treasury,
      solana:
        process.env.NEXUS_TREASURY_SOLANA ||
        process.env.TREASURY_SOLANA_ADDRESS ||
        base.nexus_treasury.solana,
    },
    mining_roots: {
      ...base.mining_roots,
      base_etc: process.env.MINING_ROOT_BASE_ETC || base.mining_roots.base_etc,
      zec: process.env.MINING_ROOT_ZEC || base.mining_roots.zec,
      prl: process.env.MINING_ROOT_PRL || base.mining_roots.prl,
      tao: process.env.MINING_ROOT_TAO || base.mining_roots.tao,
      base_hype: process.env.MINING_ROOT_BASE_HYPE || base.mining_roots.base_hype,
      base_cbeth: process.env.MINING_ROOT_BASE_CBETH || base.mining_roots.base_cbeth,
      base_btc: process.env.MINING_ROOT_BASE_BTC || base.mining_roots.base_btc,
      iotex: process.env.IOTEX_TREASURY || base.mining_roots.iotex,
      btc_via_iopay: process.env.IOTEX_BTC_BRIDGE || base.mining_roots.btc_via_iopay,
    },
    iotex_hub: {
      ...base.iotex_hub,
      primary: process.env.IOTEX_TREASURY || base.iotex_hub.primary,
      btc_bridge: process.env.IOTEX_BTC_BRIDGE || base.iotex_hub.btc_bridge,
    },
  };
}

export function getIotexHub() {
  const manifest = getTreasuryManifest();
  return {
    ...manifest.iotex_hub,
    btc_bridge_hash: createHash('sha256')
      .update(manifest.iotex_hub.btc_bridge, 'utf8')
      .digest('hex'),
    mining_root_iotex: manifest.mining_roots.iotex,
    mining_root_btc: manifest.mining_roots.btc_via_iopay,
  };
}

export function listMiningRoots() {
  const { mining_roots: roots } = getTreasuryManifest();
  return Object.entries(roots).map(([asset, address]) => ({ asset, address }));
}
