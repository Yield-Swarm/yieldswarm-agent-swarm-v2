/**
 * Quest & lottery API — in-memory store for alpha; swap for PostgreSQL in production.
 * Schema: services/quests/schema.sql
 */

import { Router } from 'express';

const router = Router();

const store = {
  users: new Map(),
  completed: new Set(),
  tickets: [],
};

function levelForXp(xp) {
  return Math.max(1, Math.floor(Math.sqrt(Math.max(0, xp) / 100)) + 1);
}

function ticketHash(userId, window, questId, i) {
  let h = 0;
  const s = `${userId}:${window}:${questId}:${i}`;
  for (let j = 0; j < s.length; j += 1) h = (Math.imul(31, h) + s.charCodeAt(j)) | 0;
  return `ys-ticket-${(h >>> 0).toString(16).padStart(8, '0')}`;
}

router.get('/definitions', (_req, res) => {
  res.json({
    quests: [
      { id: 'maintain_24h_node', title: 'Maintain 24H Node Connection', xpReward: 120, ticketReward: 1 },
      { id: 'invite_verified_peer', title: 'Invite Verified Peer', xpReward: 80, ticketReward: 1 },
    ],
  });
});

router.post('/complete', (req, res) => {
  const { accountId, questId, windowDate } = req.body || {};
  if (!accountId || !questId) {
    return res.status(400).json({ error: 'accountId and questId required' });
  }
  const window = windowDate || new Date().toISOString().slice(0, 10);
  const key = `${accountId}:${questId}:${window}`;
  if (store.completed.has(key)) {
    return res.json({ ok: true, duplicate: true });
  }
  store.completed.add(key);

  let user = store.users.get(accountId);
  if (!user) {
    user = { accountId, xp: 0, level: 1 };
  }
  const xpGain = questId === 'maintain_24h_node' ? 120 : 80;
  user.xp += xpGain;
  user.level = levelForXp(user.xp);
  store.users.set(accountId, user);

  const tickets = [{ ticketHash: ticketHash(accountId, window, questId, 0), accountId, window, source: questId }];
  store.tickets.push(...tickets);

  res.json({ ok: true, user, tickets });
});

router.get('/leaderboard', (_req, res) => {
  const rows = [...store.users.values()].sort((a, b) => b.xp - a.xp).slice(0, 50);
  res.json({ leaderboard: rows });
});

router.post('/lottery/draw', (req, res) => {
  const { vrfSeed, windowDate } = req.body || {};
  const window = windowDate || new Date().toISOString().slice(0, 10);
  const pool = store.tickets.filter((t) => t.window === window);
  if (!pool.length) return res.json({ ok: true, winner: null });
  const seed = vrfSeed || `stub-${window}`;
  let acc = 0;
  for (let i = 0; i < seed.length; i += 1) acc = (acc + seed.charCodeAt(i) * (i + 1)) % 1_000_000_007;
  const winner = pool[acc % pool.length];
  res.json({ ok: true, winner, vrfSeed: seed, ticketCount: pool.length });
});

export default router;
