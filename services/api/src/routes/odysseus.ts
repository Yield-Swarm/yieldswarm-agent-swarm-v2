import { Router } from 'express';
import {
  getProviderConfig,
  routeToProvider,
  getAgentStats,
  queryMemory,
  getAgentsByShard,
} from '../services/odysseus.js';

export const odysseusRouter = Router();

odysseusRouter.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'odysseus', ...getAgentStats() });
});

odysseusRouter.get('/agents/stats', (_req, res) => {
  res.json(getAgentStats());
});

odysseusRouter.get('/agents/shard/:shardId', (req, res) => {
  const shardId = parseInt(req.params.shardId);
  res.json(getAgentsByShard(shardId));
});

odysseusRouter.get('/providers', (_req, res) => {
  res.json(getProviderConfig());
});

odysseusRouter.post('/invoke', async (req, res) => {
  const { agentId, prompt } = req.body as { agentId?: string; prompt: string };
  if (!prompt) {
    res.status(400).json({ error: 'prompt required' });
    return;
  }

  try {
    const result = await routeToProvider(agentId || 'agent-00000', prompt);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: String(err) });
  }
});

odysseusRouter.get('/memory/health', async (_req, res) => {
  const chromaUrl = process.env.CHROMA_URL || 'http://chromadb:8000';
  try {
    const r = await fetch(`${chromaUrl}/api/v1/heartbeat`);
    res.json({ status: 'ok', chroma: r.ok ? 'connected' : 'degraded' });
  } catch {
    res.json({ status: 'degraded', chroma: 'unavailable', fallback: 'in-memory' });
  }
});

odysseusRouter.get('/memory/:collection', (req, res) => {
  const limit = parseInt(req.query.limit as string) || 20;
  res.json(queryMemory(req.params.collection, limit));
});
