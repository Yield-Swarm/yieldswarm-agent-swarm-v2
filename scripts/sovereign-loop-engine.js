#!/usr/bin/env node
/**
 * Sovereign Loop Engine — background daemon entrypoint (v1.1.0-RU).
 * Requires VAULT_SECRET_TOKEN and SOVEREIGN_LOOP_KEY.
 *
 * Usage: node scripts/sovereign-loop-engine.js
 */
'use strict';

const path = require('node:path');
const {
  getSovereignLoopManager,
  assertSovereignConfig,
} = require(path.join(__dirname, '..', 'src', 'infrastructure', 'SovereignLoopManager.js'));

async function loadTelemetry() {
  try {
    const sovereignPath = path.join(__dirname, '..', 'dashboard', 'state.json');
    const fs = require('node:fs/promises');
    const raw = await fs.readFile(sovereignPath, 'utf8');
    return { sovereign: JSON.parse(raw), helix: {} };
  } catch {
    return {};
  }
}

function main() {
  assertSovereignConfig();
  const mgr = getSovereignLoopManager();
  const intervalSec = Number(process.env.SOVEREIGN_LOOP_INTERVAL || 15);
  mgr.startBackgroundService(intervalSec * 1000, loadTelemetry);
  console.log(`[sovereign-loop-engine] v${mgr.version} running · ${intervalSec}s interval`);
}

main();
