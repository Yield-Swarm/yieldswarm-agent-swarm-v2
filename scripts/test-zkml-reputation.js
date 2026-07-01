#!/usr/bin/env node
/**
 * Smoke test for ZKML Arena reputation submission.
 * Usage: node scripts/test-zkml-reputation.js [baseUrl]
 */

const base = process.argv[2] || 'http://127.0.0.1:8080';

async function main() {
  const payload = {
    agentDid: 'did:ys:smoke-test-agent',
    battleId: `battle-${Date.now()}`,
    winRate: 8200,
    consistency: 7800,
    stakeWeight: 6500,
    battleLog: 'deterministic smoke test battle log',
    rounds: 3,
  };

  const res = await fetch(`${base}/api/arena/zkml/submit-battle`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });

  const body = await res.json();
  if (!res.ok) {
    console.error('[zkml-smoke] FAIL', res.status, body);
    process.exit(1);
  }

  console.log('[zkml-smoke] OK', {
    score: body.score,
    scoreDisplay: body.scoreDisplay,
    proofValid: body.proofValid,
    sbtUpdated: body.sbtUpdated,
    mockProof: body.mockProof,
  });

  const board = await fetch(`${base}/api/arena/zkml/leaderboard`);
  const leaderboard = await board.json();
  console.log('[zkml-smoke] leaderboard agents:', leaderboard.count);
}

main().catch((err) => {
  console.error('[zkml-smoke] error', err.message);
  process.exit(1);
});
