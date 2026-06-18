/**
 * PoW / OpenClaw yield tracker — pillar 13_treasury_yield
 * Reads deploy/openclaw-test/state/instances.jsonl + env estimates.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { splitAmount } from '../lib/great-delta-split.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const statePath = path.join(repoRoot, 'deploy', 'openclaw-test', 'state', 'instances.jsonl');

const REVENUE_BY_MODE = {
  openclaw: { cpu: 0.05, gpu: 0.1, label: 'inference + telemetry' },
  'dual-yield': { cpu: 0.12, gpu: 0.45, label: 'grass CPU + bittensor GPU' },
  'pow-dual': { cpu: 0.35, gpu: 0.55, label: 'operator PoW (estimated)' },
};

function num(value, fallback) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function loadInstances() {
  if (!fs.existsSync(statePath)) return [];
  const lines = fs.readFileSync(statePath, 'utf8').split('\n').filter(Boolean);
  const instances = [];
  for (const line of lines) {
    try {
      instances.push(JSON.parse(line));
    } catch {
      /* skip malformed */
    }
  }
  return instances;
}

function monthlyToDaily(monthlyUsd) {
  return monthlyUsd / 30;
}

export function getPowYieldSnapshot() {
  const instances = loadInstances();
  const costMonthly = num(process.env.OPENCLAW_COST_PER_INSTANCE_USD, 10);
  const costDailyPer = monthlyToDaily(costMonthly);
  const budgetUsd = num(process.env.OPENCLAW_TEST_BUDGET_USD, 50);
  const workloadMode =
    process.env.WORKLOAD_MODE ||
    instances[0]?.workload_mode ||
    'dual-yield';
  const rev = REVENUE_BY_MODE[workloadMode] || REVENUE_BY_MODE['dual-yield'];

  const count = instances.length || num(process.env.NUM_INSTANCES, 5);
  const rows = (instances.length ? instances : Array.from({ length: count }, (_, i) => ({
    instance: i + 1,
    provider: process.env.CLOUD_PROVIDER || 'vast',
    status: 'planned',
    workload_mode: workloadMode,
  }))).map((inst) => {
    const dailyBurn = costDailyPer;
    const estCpu = rev.cpu;
    const estGpu = rev.gpu;
    const estGross = estCpu + estGpu;
    const estNet = estGross - dailyBurn;
    return {
      instance_id: inst.instance ?? inst.instance_id ?? '?',
      provider: inst.provider || 'unknown',
      workload_mode: inst.workload_mode || workloadMode,
      status: inst.status || 'unknown',
      dseq: inst.dseq || null,
      daily_burn_usd: round(dailyBurn),
      est_cpu_revenue_usd: round(estCpu),
      est_gpu_revenue_usd: round(estGpu),
      est_gross_usd: round(estGross),
      est_net_usd: round(estNet),
      break_even_hours: estGross > 0 ? round((dailyBurn / estGross) * 24) : null,
    };
  });

  const dailyBurn = rows.reduce((s, r) => s + r.daily_burn_usd, 0);
  const dailyGross = rows.reduce((s, r) => s + r.est_gross_usd, 0);
  const dailyNet = dailyGross - dailyBurn;

  const greatDelta = splitAmount(Math.max(dailyNet, 0));

  return {
    pillar: '13_treasury_yield',
    workload_mode: workloadMode,
    revenue_model: rev.label,
    budget_usd: budgetUsd,
    instance_count: rows.length,
    state_file: fs.existsSync(statePath) ? statePath : null,
    totals: {
      daily_burn_usd: round(dailyBurn),
      estimated_daily_gross_usd: round(dailyGross),
      estimated_daily_net_usd: round(dailyNet),
      estimated_monthly_net_usd: round(dailyNet * 30),
      budget_utilization_pct: budgetUsd > 0 ? round((count * costMonthly / budgetUsd) * 100) : 0,
    },
    great_delta_split: greatDelta,
    instances: rows,
    generated_at: new Date().toISOString(),
    disclaimer:
      'Revenue figures are conservative estimates for planning — not guaranteed yields.',
  };
}

function round(n) {
  return Math.round(n * 100) / 100;
}

export default { getPowYieldSnapshot };
