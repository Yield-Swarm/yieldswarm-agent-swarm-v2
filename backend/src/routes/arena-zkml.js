/**
 * ZKML Arena API — reputation proof submission, leaderboard, bounty intake.
 */

import { createRequire } from 'node:module';
import { Router } from 'express';
import {
  getLeaderboard,
  getAgentReputation,
  recordBattleSubmission,
} from '../adapters/zkmlArena.js';

const require = createRequire(import.meta.url);
const { ZKMLReputationEngine } = require('../../../src/zkml-arena/reputation-engine.js');
const { sanitizeBattleLog } = require('../../../src/zkml-arena/quarantine-judge.js');

const router = Router();
const engine = new ZKMLReputationEngine();

function asyncRoute(handler) {
  return (req, res, next) => {
    Promise.resolve(handler(req, res, next)).catch(next);
  };
}

router.get('/leaderboard', asyncRoute(async (req, res) => {
  const limit = Math.min(100, Number(req.query.limit) || 50);
  const board = await getLeaderboard(limit);
  res.json({ service: 'zkml-arena', ...board });
}));

router.get('/agent/:did', asyncRoute(async (req, res) => {
  const agent = await getAgentReputation(decodeURIComponent(req.params.did));
  if (!agent) {
    return res.status(404).json({ error: 'agent_not_found' });
  }
  res.json({ service: 'zkml-arena', agent });
}));

/**
 * POST /api/arena/zkml/submit-battle
 * Body: { agentDid, battleId, winRate, consistency, stakeWeight, battleLog?, rounds? }
 */
router.post('/submit-battle', asyncRoute(async (req, res) => {
  const body = req.body || {};
  const agentDid = body.agentDid;
  const battleId = body.battleId;

  if (!agentDid || !battleId) {
    return res.status(400).json({ error: 'agentDid and battleId are required' });
  }
  if (!/^did:ys:[a-zA-Z0-9._-]+$/.test(agentDid)) {
    return res.status(400).json({ error: 'invalid_agent_did', hint: 'did:ys:<wallet-id>' });
  }

  const winRate = Number(body.winRate ?? 0);
  const consistency = Number(body.consistency ?? 0);
  const stakeWeight = Number(body.stakeWeight ?? 0);

  if ([winRate, consistency, stakeWeight].some((n) => !Number.isFinite(n))) {
    return res.status(400).json({ error: 'winRate, consistency, stakeWeight must be numbers' });
  }

  try {
    if (body.battleLog != null) {
      sanitizeBattleLog(body.battleLog);
    }
  } catch (err) {
    return res.status(422).json({ error: err.message });
  }

  const result = await engine.computeAndProve(
    {
      winRate,
      consistency,
      stakeWeight,
      battleLog: body.battleLog,
      rounds: body.rounds,
    },
    agentDid,
    { battleId },
  );

  const recorded = await recordBattleSubmission({ ...result, battleId });

  res.json({
    ok: true,
    score: result.score,
    scoreDisplay: (result.score / 100).toFixed(2),
    proofValid: result.proofValid,
    sbtUpdated: result.sbtUpdated,
    mockProof: result.mockProof,
    proofHash: result.proofHash,
    agentDid,
    battleId,
    leaderboardRank:
      recorded.leaderboard.agents.findIndex((a) => a.agentDid === agentDid) + 1 || null,
    timestamp: result.timestamp,
  });
}));

export default router;
