/**
 * Ludacris Mayhem Mode — full-stack live wire status.
 * Connects Nexus + Helix + Shadow + ZK Mayhem + 14 pillars.
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getZkMayhemStatus } from './zkMayhem.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const STATE_PATH = path.join(REPO_ROOT, '.run', 'ludacris-mayhem.json');

export function isMayhemLive() {
  return process.env.LUDACRIS_MAYHEM_MODE === '1'
    || String(process.env.MAYHEM_MODE_ENABLED || '').toLowerCase() === 'true';
}

export async function loadMayhemState() {
  try {
    const raw = await fs.readFile(STATE_PATH, 'utf8');
    return JSON.parse(raw);
  } catch {
    return { activated: false, wiredAt: null, pillars: 0, receipts: [] };
  }
}

export async function saveMayhemState(state) {
  await fs.mkdir(path.dirname(STATE_PATH), { recursive: true });
  await fs.writeFile(STATE_PATH, `${JSON.stringify(state, null, 2)}\n`, 'utf8');
  return state;
}

export async function getLudacrisMayhemStatus() {
  const state = await loadMayhemState();
  const zk = await getZkMayhemStatus();
  const treasuryLive = process.env.LUDACRIS_TREASURY_LIVE === '1'
    || process.env.CROSS_CHAIN_DRY_RUN === '0';

  return {
    mode: 'ludacris_mayhem',
    tagline: 'Move fast · prove entropy · route yield',
    activated: state.activated || isMayhemLive(),
    wiredAt: state.wiredAt,
    pillarsWired: state.pillars ?? 0,
    solenoids: ['nexus', 'helix', 'shadow'],
    zkMayhem: zk,
    flags: {
      mayhem: isMayhemLive(),
      zk_enabled: zk.enabled,
      cross_chain_dry_run: process.env.CROSS_CHAIN_DRY_RUN !== '0',
      treasury_live: treasuryLive,
      network_lockdown: String(process.env.NETWORK_LOCKDOWN_MODE || '').toLowerCase() === 'true',
    },
    lastReceipts: (state.receipts || []).slice(-5),
    timestamp: new Date().toISOString(),
  };
}

export async function activateLudacrisMayhem({ source = 'api' } = {}) {
  const state = await loadMayhemState();
  state.activated = true;
  state.wiredAt = new Date().toISOString();
  state.source = source;
  state.pillars = 14;
  await saveMayhemState(state);
  return getLudacrisMayhemStatus();
}

export async function recordWireReceipt(receipt) {
  const state = await loadMayhemState();
  state.receipts = [...(state.receipts || []), receipt].slice(-50);
  await saveMayhemState(state);
}
