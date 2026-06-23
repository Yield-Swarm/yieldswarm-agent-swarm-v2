/**
 * Poseidon Delta Trident v3.05911111100 — mainnet deployment orchestrator.
 *
 * Usage:
 *   npx tsx scripts/mainnet-deploy.ts
 *   npx tsx scripts/mainnet-deploy.ts --dry-run
 */
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');
const DRY_RUN = process.argv.includes('--dry-run');
const RUN_DIR = resolve(ROOT, '.run');
const LOG_PATH = resolve(RUN_DIR, 'trident-mainnet-deploy.log');

type StepResult = {
  phase: string;
  step: string;
  status: 'ok' | 'skipped' | 'error';
  detail: string;
};

const results: StepResult[] = [];

function log(msg: string) {
  const line = `[${new Date().toISOString()}] ${msg}`;
  console.error(line);
  mkdirSync(RUN_DIR, { recursive: true });
  writeFileSync(LOG_PATH, line + '\n', { flag: 'a' });
}

function runStep(phase: string, step: string, cmd: string, args: string[]): void {
  log(`${phase} :: ${step} → ${cmd} ${args.join(' ')}`);
  if (DRY_RUN) {
    results.push({ phase, step, status: 'ok', detail: 'dry-run' });
    return;
  }
  const res = spawnSync(cmd, args, { cwd: ROOT, encoding: 'utf8', env: process.env });
  const detail = (res.stdout || res.stderr || '').trim().slice(0, 500);
  if (res.status === 0) {
    results.push({ phase, step, status: 'ok', detail: detail || 'completed' });
  } else {
    results.push({ phase, step, status: 'error', detail: detail || `exit ${res.status}` });
  }
}

function loadEnv(): void {
  const envFile = resolve(ROOT, 'deploy/env/trident-mainnet.env');
  const example = resolve(ROOT, 'deploy/env/trident-mainnet.env.example');
  const dotenv = resolve(ROOT, '.env');
  for (const f of [dotenv, envFile, example]) {
    if (!existsSync(f)) continue;
    for (const line of readFileSync(f, 'utf8').split('\n')) {
      const t = line.trim();
      if (!t || t.startsWith('#')) continue;
      const eq = t.indexOf('=');
      if (eq < 1) continue;
      const k = t.slice(0, eq);
      const v = t.slice(eq + 1);
      if (!process.env[k]) process.env[k] = v;
    }
  }
  process.env.NODE_ENV = process.env.NODE_ENV ?? 'mainnet';
  process.env.TRIDENT_VERSION =
    process.env.TRIDENT_VERSION ?? '3.05911111100';
}

async function phase1Domains(): Promise<void> {
  runStep('PHASE1', 'wire-domains', 'npx', ['tsx', 'scripts/wire-domains.ts']);
  runStep('PHASE1', 'wire-production-domains', 'bash', [
    'scripts/wire-production-domains.sh',
  ]);
}

async function phase2Loops(): Promise<void> {
  runStep('PHASE2', 'activate-helix', 'bash', ['scripts/activate-helix.sh']);
  runStep('PHASE2', 'sovereign-loops', 'bash', [
    'deploy/scripts/start-sovereign-loops.sh',
    'start',
  ]);
  runStep('PHASE2', 'pentagramal-manager', 'bash', [
    'scripts/start-trident-loops.sh',
  ]);
}

async function phase3Contracts(): Promise<void> {
  const forge = spawnSync('which', ['forge'], { encoding: 'utf8' });
  if (forge.status === 0 && existsSync(resolve(ROOT, 'foundry.toml'))) {
    runStep('PHASE3', 'forge-build', 'forge', [
      'build',
      '--contracts',
      'contracts/KairosYieldEngine.sol',
    ]);
  } else {
    results.push({
      phase: 'PHASE3',
      step: 'forge-build',
      status: 'skipped',
      detail: 'forge CLI not installed — KairosYieldEngine.sol ready for foundry deploy',
    });
  }
}

async function phase4Mining(): Promise<void> {
  runStep('PHASE4', 'run-all-onchain', 'bash', ['scripts/run-all-onchain.sh']);
  runStep('PHASE4', 'mining-fleet', 'bash', ['scripts/mining/start-all.sh']);
}

async function main(): Promise<void> {
  loadEnv();
  log(
    `Poseidon Delta Trident v${process.env.TRIDENT_VERSION} mainnet deploy (dry_run=${DRY_RUN})`,
  );

  await phase1Domains();
  await phase3Contracts();
  await phase2Loops();
  await phase4Mining();

  const summary = {
    trident_version: process.env.TRIDENT_VERSION,
    node_env: process.env.NODE_ENV,
    dry_run: DRY_RUN,
    ok: results.filter((r) => r.status === 'ok').length,
    skipped: results.filter((r) => r.status === 'skipped').length,
    errors: results.filter((r) => r.status === 'error').length,
    results,
    log: LOG_PATH,
  };

  writeFileSync(
    resolve(RUN_DIR, 'trident-mainnet-deploy.json'),
    JSON.stringify(summary, null, 2),
  );
  console.log(JSON.stringify(summary, null, 2));
  process.exit(summary.errors > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
