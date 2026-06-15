import { Router } from 'express';
import { getStats as getMandelbrotStats } from '../services/mandelbrot-pipeline.js';
import { getAgentStats } from '../services/odysseus.js';
import { getPaymentStats } from '../services/payments.js';

export const telemetryRouter = Router();

telemetryRouter.get('/dashboard', (_req, res) => {
  const mandelbrot = getMandelbrotStats();
  const odysseus = getAgentStats();
  const payments = getPaymentStats();

  res.json({
    timestamp: new Date().toISOString(),
    targetRevenue: 5_000_000,
    currentMetrics: {
      mandelbrot,
      odysseus,
      payments,
      depinNodes: mandelbrot.activeShards,
      totalAgents: odysseus.totalAgents,
      revenueCents: payments.totalRevenueCents,
    },
    progressPercent: Math.min(
      100,
      (payments.totalRevenueCents / 5_000_000_00) * 100
    ),
  });
});
