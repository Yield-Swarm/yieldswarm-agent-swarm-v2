import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getPowYieldSnapshot } from './powYield.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const statePath = path.resolve(__dirname, '..', '..', '..', 'deploy', 'openclaw-test', 'state', 'instances.jsonl');

test('getPowYieldSnapshot returns treasury pillar snapshot', () => {
  const snap = getPowYieldSnapshot();
  assert.equal(snap.pillar, '13_treasury_yield');
  assert.ok(snap.instance_count >= 1);
  assert.ok(snap.totals.daily_burn_usd >= 0);
  assert.ok(snap.great_delta_split);
});

test('getPowYieldSnapshot reads instances.jsonl when present', () => {
  const dir = path.dirname(statePath);
  fs.mkdirSync(dir, { recursive: true });
  const prev = fs.existsSync(statePath) ? fs.readFileSync(statePath, 'utf8') : null;
  fs.writeFileSync(
    statePath,
    '{"instance":1,"provider":"akash","workload_mode":"dual-yield","status":"dry-run"}\n',
  );
  try {
    const snap = getPowYieldSnapshot();
    assert.equal(snap.instance_count, 1);
    assert.equal(snap.instances[0].provider, 'akash');
  } finally {
    if (prev) fs.writeFileSync(statePath, prev);
    else fs.unlinkSync(statePath);
  }
});
