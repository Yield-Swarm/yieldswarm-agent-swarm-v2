/**
 * GPU Credit Yield Dashboard — pillar 13_treasury_yield.
 *
 * Aggregates Akash GPU lease burn (e.g. BERT P40 @ $0.17/hr) and estimates
 * treasury yield contribution vs inference revenue potential.
 */

import { splitAmount } from '../lib/great-delta-split.js';

function parseWorkersEnv() {
  const raw = process.env.YIELDSWARM_AKASH_WORKERS;
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function bertWorkerEntry() {
  const hourly = Number(process.env.AKASH_BERT_HOURLY_COST_USD || 0.17);
  const ingress = process.env.AKASH_BERT_INGRESS_URL || '';
  if (!ingress && hourly <= 0) return null;
  return {
    worker_id: 'akash-bert-p40',
    pillar: '04_akash_gpu_workers',
    gpu_model: 'nvidia-p40',
    provider_uri: ingress,
    hourly_cost_usd: hourly,
    dseq: process.env.AKASH_BERT_DSEQ || '1781638160905',
    service: 'bert-flask-inference',
    live: Boolean(ingress),
  };
}

function estimateRevenueUsd(worker, hours = 24) {
  const tps = Number(worker.tokens_per_second || worker.estimated_tps || 2);
  const pricePerM = Number(process.env.GPU_CREDIT_PRICE_PER_M_TOKENS || 0.15);
  const util = Number(worker.utilization || 0.65);
  const tokens = tps * util * 3600 * hours;
  return (tokens * pricePerM) / 1_000_000;
}

function workerEconomics(worker) {
  const hourly = Number(worker.hourly_cost_usd || 0);
  const dailyBurn = hourly * 24;
  const monthlyBurn = dailyBurn * 30;
  const dailyRevenue = estimateRevenueUsd(worker, 24);
  const dailyNet = dailyRevenue - dailyBurn;
  const monthlyNet = dailyNet * 30;
  const breakEvenHours = dailyRevenue > 0 ? dailyBurn / (dailyRevenue / 24) : null;

  const treasuryRoute = splitAmount(Math.max(0, dailyNet));

  return {
    worker_id: worker.worker_id,
    pillar: worker.pillar || '04_akash_gpu_workers',
    gpu_model: worker.gpu_model,
    hourly_cost_usd: hourly,
    daily_burn_usd: Number(dailyBurn.toFixed(4)),
    monthly_burn_usd: Number(monthlyBurn.toFixed(2)),
    estimated_daily_revenue_usd: Number(dailyRevenue.toFixed(4)),
    estimated_daily_net_usd: Number(dailyNet.toFixed(4)),
    estimated_monthly_net_usd: Number(monthlyNet.toFixed(2)),
    break_even_hours: breakEvenHours ? Number(breakEvenHours.toFixed(1)) : null,
    treasury_yield_pillar: '13_treasury_yield',
    great_delta_split_daily: treasuryRoute,
    live: worker.live !== false,
  };
}

export function getGpuCreditYieldDashboard() {
  const workers = [];
  const bert = bertWorkerEntry();
  if (bert) workers.push(bert);

  for (const w of parseWorkersEnv()) {
    workers.push({
      worker_id: w.worker_id,
      pillar: '04_akash_gpu_workers',
      gpu_model: w.gpu_model,
      hourly_cost_usd: Number(w.hourly_cost_usd || 0.42),
      provider_uri: w.provider_uri,
      tokens_per_second: w.tokens_per_second,
      utilization: w.health_score ?? 0.7,
      live: true,
    });
  }

  const economics = workers.map(workerEconomics);
  const totalDailyBurn = economics.reduce((s, e) => s + e.daily_burn_usd, 0);
  const totalDailyNet = economics.reduce((s, e) => s + e.estimated_daily_net_usd, 0);
  const totalMonthlyNet = economics.reduce((s, e) => s + e.estimated_monthly_net_usd, 0);

  return {
    source: workers.length ? 'gpu-credit-yield' : 'empty',
    live: workers.some((w) => w.live),
    pillar: '13_treasury_yield',
    credit_pool_usd: Number(process.env.SOVEREIGN_CREDIT_POOL_USD || 5408),
    totals: {
      workers: workers.length,
      daily_burn_usd: Number(totalDailyBurn.toFixed(4)),
      estimated_daily_net_usd: Number(totalDailyNet.toFixed(4)),
      estimated_monthly_net_usd: Number(totalMonthlyNet.toFixed(2)),
      split_policy: '50/30/15/5',
      treasury_routing: splitAmount(Math.max(0, totalDailyNet)),
    },
    workers: economics,
    generatedAt: new Date().toISOString(),
  };
}

export default { getGpuCreditYieldDashboard };
