/**
 * In-memory ZKML Arena leaderboard + battle receipts.
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const STORE_PATH = path.join(repoRoot, 'dashboard', 'zkml-arena-leaderboard.json');

/** @type {{ agents: Map<string, object>, battles: object[] }} */
const memory = {
  agents: new Map(),
  battles: [],
};

async function loadStore() {
  try {
    const raw = await fs.readFile(STORE_PATH, 'utf8');
    const data = JSON.parse(raw);
    memory.agents = new Map(Object.entries(data.agents || {}));
    memory.battles = data.battles || [];
  } catch {
    memory.agents = new Map();
    memory.battles = [];
  }
}

async function persistStore() {
  await fs.mkdir(path.dirname(STORE_PATH), { recursive: true });
  const payload = {
    updatedAt: new Date().toISOString(),
    agents: Object.fromEntries(memory.agents),
    battles: memory.battles.slice(-500),
  };
  await fs.writeFile(STORE_PATH, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
  return payload;
}

/**
 * @param {object} result — computeAndProve output + battleId
 */
export async function recordBattleSubmission(result) {
  await loadStore();

  const entry = {
    agentDid: result.agentDid,
    battleId: result.battleId,
    score: result.score,
    proofHash: result.proofHash,
    proofValid: result.proofValid,
    sbtUpdated: result.sbtUpdated,
    mockProof: result.mockProof ?? false,
    timestamp: result.timestamp,
  };

  memory.battles.push(entry);

  const prior = memory.agents.get(result.agentDid) || { agentDid: result.agentDid, battles: 0 };
  const next = {
    ...prior,
    agentDid: result.agentDid,
    score: result.score,
    proofHash: result.proofHash,
    lastUpdate: result.timestamp,
    battles: (prior.battles || 0) + 1,
    sbtBound: result.sbtUpdated || prior.sbtBound || false,
  };
  memory.agents.set(result.agentDid, next);

  await persistStore();
  return { entry, leaderboard: getLeaderboardSync() };
}

export function getLeaderboardSync(limit = 50) {
  const rows = [...memory.agents.values()].sort((a, b) => b.score - a.score);
  return {
    generatedAt: new Date().toISOString(),
    count: rows.length,
    agents: rows.slice(0, limit),
  };
}

export async function getLeaderboard(limit = 50) {
  await loadStore();
  return getLeaderboardSync(limit);
}

export async function getAgentReputation(agentDid) {
  await loadStore();
  return memory.agents.get(agentDid) || null;
}
