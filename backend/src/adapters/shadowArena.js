/**
 * Solenoid 3 — Shadow Chain Arena adapter (Kyle's chain).
 * Competition, reputation, and reward distribution with ZK-Swarm Mutation batches.
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { getNexusOrchestrator } from '../../../solenoids/nexus/index.js';
import { MESSAGE_TOPICS } from '../../../solenoids/nexus/constants.js';
import { submitZkSwarmBatch } from './helixTreasury.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const STATE_PATH = path.join(REPO_ROOT, '.run', 'shadow-arena.json');

const DEFAULT_STATE = {
  season: 1,
  owner: 'kyle',
  competitors: {},
  leaderboard: [],
  rewardPoolLamports: 0,
  lastBatchId: null,
};

async function loadState() {
  try {
    const raw = await fs.readFile(STATE_PATH, 'utf8');
    return { ...DEFAULT_STATE, ...JSON.parse(raw) };
  } catch {
    return { ...DEFAULT_STATE };
  }
}

async function saveState(state) {
  await fs.mkdir(path.dirname(STATE_PATH), { recursive: true });
  await fs.writeFile(STATE_PATH, `${JSON.stringify(state, null, 2)}\n`, 'utf8');
}

function computeReputation(score, wins, losses) {
  const base = Math.log10(Math.max(score, 1) + 1) * 100;
  const winRate = wins + losses > 0 ? wins / (wins + losses) : 0.5;
  return Math.round(base * (0.5 + winRate));
}

export async function getArenaStatus() {
  const state = await loadState();
  return {
    solenoid: 'shadow',
    chain: 'shadow',
    owner: state.owner,
    season: state.season,
    competitorCount: Object.keys(state.competitors).length,
    rewardPoolLamports: state.rewardPoolLamports,
    lastBatchId: state.lastBatchId,
    topAgents: state.leaderboard.slice(0, 10),
    swarmOpsProgram: '6BbH4rvmxERTbcAbEat9SzT3N3P9fEFWvoAD3EsJ3BAz',
    timestamp: new Date().toISOString(),
  };
}

export async function registerCompetitor({ agentId, pubkey, swarmRegistered = false }) {
  if (!agentId || !pubkey) {
    throw new Error('agentId and pubkey required');
  }
  if (!swarmRegistered) {
    throw new Error('agent must be registered in swarm_ops first');
  }

  const state = await loadState();
  if (state.competitors[agentId]) {
    throw new Error(`competitor ${agentId} already registered`);
  }

  state.competitors[agentId] = {
    agentId,
    pubkey,
    reputation: 0,
    score: 0,
    wins: 0,
    losses: 0,
    registeredAt: new Date().toISOString(),
  };
  await saveState(state);

  const nexus = getNexusOrchestrator();
  await nexus.init();
  await nexus.bus.publish(MESSAGE_TOPICS.AGENT_REGISTERED, {
    arena: true,
    agentId,
    pubkey,
  }, { sourceSolenoid: 'shadow' });

  return state.competitors[agentId];
}

export async function submitArenaScore({ agentId, score, won = null }) {
  const state = await loadState();
  const competitor = state.competitors[agentId];
  if (!competitor) throw new Error(`competitor ${agentId} not found`);

  competitor.score += Number(score) || 0;
  if (won === true) competitor.wins += 1;
  if (won === false) competitor.losses += 1;
  competitor.reputation = computeReputation(competitor.score, competitor.wins, competitor.losses);
  competitor.lastScoreAt = new Date().toISOString();

  state.leaderboard = Object.values(state.competitors)
    .sort((a, b) => b.reputation - a.reputation || b.score - a.score);

  await saveState(state);

  const nexus = getNexusOrchestrator();
  await nexus.bus.publish(MESSAGE_TOPICS.ARENA_SCORE, {
    agentId,
    score: competitor.score,
    reputation: competitor.reputation,
  }, { sourceSolenoid: 'shadow' });

  return competitor;
}

export async function submitArenaZkBatch({ proofs, mutationRoot }) {
  const batch = await submitZkSwarmBatch({ proofs, mutationRoot });
  const state = await loadState();
  state.lastBatchId = batch.batchId;
  await saveState(state);
  return { ...batch, arenaSeason: state.season };
}

export async function distributeArenaRewards({ amounts = {} }) {
  const state = await loadState();
  const distributions = [];

  for (const [agentId, lamports] of Object.entries(amounts)) {
    const competitor = state.competitors[agentId];
    if (!competitor) continue;
    const amount = Number(lamports) || 0;
    competitor.rewardsLamports = (competitor.rewardsLamports || 0) + amount;
    state.rewardPoolLamports = Math.max(0, state.rewardPoolLamports - amount);
    distributions.push({ agentId, lamports: amount });
  }

  await saveState(state);
  return {
    distributions,
    remainingPool: state.rewardPoolLamports,
    receiptId: crypto.randomUUID(),
    timestamp: new Date().toISOString(),
  };
}

export async function fundArenaPool(lamports) {
  const state = await loadState();
  state.rewardPoolLamports += Number(lamports) || 0;
  await saveState(state);
  return { rewardPoolLamports: state.rewardPoolLamports };
}
