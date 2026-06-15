import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  activateHelixChain,
  getHelixStatus,
  loadHelixState,
  saveHelixState,
} from './helix.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const statePath = path.join(repoRoot, 'dashboard', 'helix-state.json');
let backup = null;

before(async () => {
  try {
    backup = await fs.readFile(statePath, 'utf8');
  } catch {
    backup = null;
  }
  await saveHelixState({
    activated: false,
    phase: 'genesis-pending',
    genesisHash: null,
    activatedAt: null,
    yslr: { phase: 'pending', signalsProcessed: 0, lastSignalAt: null },
    tracks: {},
    receipts: [],
  });
});

after(async () => {
  if (backup !== null) {
    await fs.writeFile(statePath, backup, 'utf8');
  }
});

describe('helix adapter', () => {
  it('returns genesis-pending before activation', async () => {
    const status = await getHelixStatus();
    assert.equal(status.service, 'helix-chain');
    assert.equal(status.phase, 'genesis-pending');
  });

  it('activates and writes genesis hash', async () => {
    const result = await activateHelixChain({ source: 'test' });
    assert.equal(result.ok, true);
    assert.match(result.genesisHash, /^[a-f0-9]{64}$/);

    const state = await loadHelixState();
    assert.equal(state.activated, true);
    assert.equal(state.phase, 'genesis-active');
    assert.equal(state.genesisHash, result.genesisHash);
  });

  it('reports activated status after genesis', async () => {
    const status = await getHelixStatus();
    assert.equal(status.activated, true);
    assert.equal(status.phase, 'genesis-active');
    assert.ok(status.onChainReceipts);
  });
});
