/**
 * Background mutation loop — polls oracle sync + triggers batch mutation engine.
 *
 * Usage: node src/automation/mutation-loop.js
 * Env: MUTATION_LOOP_INTERVAL_MS, YIELDSWARM_API_URL, MUTATION_ENGINE_DRY_RUN
 */

const API_BASE = (process.env.YIELDSWARM_API_URL || process.env.ARENA_API_BASE || 'http://127.0.0.1:8080').replace(/\/$/, '');
const INTERVAL_MS = Number(process.env.MUTATION_LOOP_INTERVAL_MS || 3_600_000); // 1h default

async function fetchOracleStatus() {
  const res = await fetch(`${API_BASE}/api/oracle/sync`);
  if (!res.ok) throw new Error(`oracle sync ${res.status}`);
  return res.json();
}

async function runMutationEngine() {
  const { spawn } = await import('node:child_process');
  return new Promise((resolve, reject) => {
    const child = spawn('python3', ['services/nft_mutation_engine.py'], {
      cwd: process.cwd().endsWith('backend') ? '..' : process.cwd(),
      stdio: 'inherit',
      env: process.env,
    });
    child.on('exit', (code) => (code === 0 ? resolve() : reject(new Error(`engine exit ${code}`))));
  });
}

async function tick() {
  const status = await fetchOracleStatus();
  console.log(`[mutation-loop] oracle live=${status.live} configured=${status.configured}`);

  if (process.env.MUTATION_LOOP_AUTO_RUN === '1') {
    await runMutationEngine();
  }
}

async function main() {
  console.log(`[mutation-loop] starting interval=${INTERVAL_MS}ms api=${API_BASE}`);
  await tick();
  setInterval(() => {
    tick().catch((err) => console.error('[mutation-loop] tick failed:', err.message));
  }, INTERVAL_MS);
}

main().catch((err) => {
  console.error('[mutation-loop] fatal:', err);
  process.exit(1);
});
