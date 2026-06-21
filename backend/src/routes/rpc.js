/**
 * Alchemy RPC routes — Christopher's First App endpoint catalog.
 */

import { Router } from 'express';
import {
  alchemyRpcUrl,
  getAlchemyApiKey,
  listAlchemyEndpoints,
  resolveAlchemyDefaults,
} from '../lib/alchemy.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(err.status || 502).json({ error: err.message || 'rpc failure' });
    });
  };
}

router.get('/alchemy/health', asyncRoute(async (_req, res) => {
  const key = getAlchemyApiKey();
  res.json({
    live: Boolean(key),
    app: "Christopher's First App",
    api_key_configured: Boolean(key),
  });
}));

router.get('/alchemy/endpoints', asyncRoute(async (req, res) => {
  const reveal = req.query.reveal === '1' && process.env.ALCHEMY_REVEAL_URLS === '1';
  res.json(listAlchemyEndpoints(getAlchemyApiKey(), { revealUrls: reveal }));
}));

router.get('/alchemy/defaults', asyncRoute(async (_req, res) => {
  res.json({
    app: "Christopher's First App",
    api_key_configured: Boolean(getAlchemyApiKey()),
    defaults: resolveAlchemyDefaults(),
  });
}));

router.get('/alchemy/url/:networkId', asyncRoute(async (req, res) => {
  const key = getAlchemyApiKey();
  if (!key) {
    return res.status(503).json({ error: 'ALCHEMY_API_KEY not configured' });
  }
  const url = alchemyRpcUrl(req.params.networkId, key);
  if (!url) {
    return res.status(404).json({ error: 'unknown network id' });
  }
  const reveal = req.query.reveal === '1' && process.env.ALCHEMY_REVEAL_URLS === '1';
  res.json({
    network_id: req.params.networkId,
    https_url: reveal ? url : url.replace(key, '***REDACTED***'),
  });
}));

export default router;
