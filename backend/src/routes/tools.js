/**
 * YieldSwarm tool adapter routes — backends for Odysseus tool handlers.
 *
 * Handlers in agents/yieldswarm_tools/handlers.py call these endpoints when
 * YIELDSWARM_*_API_URL points at the integration backend.
 */

import { Router } from 'express';
import * as akash from '../adapters/akash.js';
import * as emission from '../adapters/emissionRouter.js';
import * as treasury from '../adapters/treasury.js';
import * as odysseus from '../adapters/odysseus.js';
import * as dex from '../adapters/dex.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(502).json({ error: err.message || 'tool adapter failure' });
    });
  };
}

router.post('/akash/leases', asyncRoute(async (req, res) => {
  const { action, dry_run: dryRun } = req.body || {};
  const workers = await akash.getWorkers();

  if (dryRun !== false) {
    return res.json({
      status: 'dry_run',
      message: 'Akash lease operation prepared.',
      data: { action, workers: workers.workers?.length || 0 },
    });
  }

  res.json({
    status: 'submitted',
    message: 'Akash lease action recorded — use scripts/akash-deploy.sh for live mutations.',
    data: { action, workers },
  });
}));

router.post('/emission-router/query', asyncRoute(async (req, res) => {
  const emissions = await emission.getEmissions();
  res.json({
    status: 'queried',
    message: 'Emission router telemetry returned.',
    data: { query: req.body, emissions },
  });
}));

router.post('/wallet/operation', asyncRoute(async (req, res) => {
  res.status(501).json({
    status: 'adapter_missing',
    message: 'Wire YIELDSWARM_UNIFIED_WALLET_SDK_MODULE for live wallet operations.',
    data: req.body,
  });
}));

router.post('/workers/telemetry', asyncRoute(async (req, res) => {
  const [workers, odysseusTelemetry] = await Promise.all([
    akash.getWorkers(),
    odysseus.getTelemetry(),
  ]);
  res.json({
    status: 'queried',
    message: 'Worker telemetry aggregated.',
    data: {
      filters: req.body?.filters,
      akash: workers,
      odysseus: odysseusTelemetry,
      treasury: await treasury.getTreasurySplits(),
    },
  });
}));

router.get('/dex/health', asyncRoute(async (_req, res) => {
  const data = await dex.getDexHealth();
  res.json({ status: 'ok', data });
}));

router.post('/dex/quote', asyncRoute(async (req, res) => {
  const { chain, ...params } = req.body || {};
  if (chain === 'ethereum' || chain === 'evm') {
    return res.json(await dex.quoteUniswapV4(params));
  }
  const quote = await dex.quoteJupiter({
    inputMint: params.input_mint || params.inputMint,
    outputMint: params.output_mint || params.outputMint,
    amount: params.amount,
    slippageBps: params.slippage_bps || params.slippageBps,
  });
  res.json(quote);
}));

router.post('/dex/swap', asyncRoute(async (req, res) => {
  const data = await dex.executeDexSwap(req.body || {});
  res.json(data);
}));

export default router;
