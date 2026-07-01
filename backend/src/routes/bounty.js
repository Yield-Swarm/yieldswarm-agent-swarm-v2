/**
 * Bug bounty intake — ZKML Arena critical findings.
 */

import { Router } from 'express';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const BOUNTY_LOG = path.join(repoRoot, 'dashboard', 'zkml-bounty-reports.jsonl');

const router = Router();
const BOUNTY_SOL = 100;

function asyncRoute(handler) {
  return (req, res, next) => {
    Promise.resolve(handler(req, res, next)).catch(next);
  };
}

const VALID_CATEGORIES = new Set([
  'circuit_soundness',
  'score_inflation',
  'privacy_leak',
  'sandbox_escape',
  'other',
]);

router.post('/', asyncRoute(async (req, res) => {
  const body = req.body || {};
  const category = body.category || 'other';
  const reporter = body.reporter || 'anonymous';
  const summary = String(body.summary || '').slice(0, 2000);
  const poc = String(body.poc || '').slice(0, 8000);

  if (!summary) {
    return res.status(400).json({ error: 'summary is required' });
  }
  if (!VALID_CATEGORIES.has(category)) {
    return res.status(400).json({ error: 'invalid_category', valid: [...VALID_CATEGORIES] });
  }

  const report = {
    id: `bounty-${Date.now()}`,
    category,
    reporter,
    summary,
    pocHash: poc ? `sha256:${Buffer.from(poc).toString('hex').slice(0, 16)}` : null,
    rewardSol: BOUNTY_SOL,
    status: 'received',
    receivedAt: new Date().toISOString(),
  };

  await fs.mkdir(path.dirname(BOUNTY_LOG), { recursive: true });
  await fs.appendFile(BOUNTY_LOG, `${JSON.stringify(report)}\n`, 'utf8');

  res.status(202).json({
    ok: true,
    reportId: report.id,
    status: 'received',
    rewardSol: BOUNTY_SOL,
    message: 'Report logged for ethical auditor review. Do not disclose publicly until triaged.',
  });
}));

export default router;
