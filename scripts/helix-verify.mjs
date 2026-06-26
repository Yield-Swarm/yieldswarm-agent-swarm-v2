#!/usr/bin/env node
/**
 * Helix activate + routes smoke test (works on Windows PowerShell, Linux, Termux).
 * Usage: npm run prod:backend &  npm run helix:verify
 */
const PORT = process.env.PORT || '8080';
const BASE = `http://127.0.0.1:${PORT}`;

async function post(path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = { raw: text };
  }
  if (!res.ok) throw new Error(`${path} HTTP ${res.status}: ${text.slice(0, 200)}`);
  return data;
}

async function get(path) {
  const res = await fetch(`${BASE}${path}`);
  const text = await res.text();
  if (!res.ok) throw new Error(`${path} HTTP ${res.status}: ${text.slice(0, 200)}`);
  return JSON.parse(text);
}

async function main() {
  console.log(`[helix:verify] backend ${BASE}`);
  await new Promise((r) => setTimeout(r, 3000));

  const activate = await post('/api/helix/activate', {
    source: process.platform === 'win32' ? 'powershell' : 'bash',
    arm_routes: true,
  });
  console.log('[activate]', activate.message || activate.genesisHash || 'ok');

  const routes = await get('/api/helix/routes');
  console.log(
    `[routes] ${routes.live_count}/${routes.route_count} live, ${routes.armed_count} armed`,
  );
  for (const r of routes.routes || []) {
    console.log(`  ${r.duadilateral}  ${r.status}  (${r.lane})`);
  }

  const status = await get('/api/helix/status');
  const dr = status.duadilateralRoutes;
  if (dr) {
    console.log(`[status] duadilaterals armed=${dr.armed} routes=${dr.route_count}`);
  }
  console.log('[helix:verify] done');
}

main().catch((err) => {
  console.error('[helix:verify] FAIL:', err.message);
  console.error('Start backend first: npm run prod:backend');
  process.exit(1);
});
