/**
 * Gamified Quest & Lottery State Engine (God Prompt 3)
 * TypeScript logic mirror of PostgreSQL functions — usable without DB in tests.
 */

export type QuestCriteria = {
  min_uptime_sec?: number;
  min_referrals?: number;
};

export type QuestDefinition = {
  id: string;
  title: string;
  xpReward: number;
  ticketReward: number;
  criteria: QuestCriteria;
};

export type UserState = {
  id: string;
  accountId: string;
  xp: number;
  level: number;
};

export type NodeState = {
  nodeKey: string;
  status: 'active' | 'idle' | 'offline';
  connectionStreakDays: number;
  totalUptimeSec: number;
};

export type LotteryTicket = {
  ticketHash: string;
  userId: string;
  windowDate: string;
  source: string;
};

export const DEFAULT_QUESTS: QuestDefinition[] = [
  {
    id: 'maintain_24h_node',
    title: 'Maintain 24H Node Connection',
    xpReward: 120,
    ticketReward: 1,
    criteria: { min_uptime_sec: 86_400 },
  },
  {
    id: 'invite_verified_peer',
    title: 'Invite Verified Peer',
    xpReward: 80,
    ticketReward: 1,
    criteria: { min_referrals: 1 },
  },
];

/** Level curve: floor(sqrt(xp / 100)) + 1 */
export function levelForXp(xp: number): number {
  return Math.max(1, Math.floor(Math.sqrt(Math.max(0, xp) / 100)) + 1);
}

export function evaluateQuest(
  quest: QuestDefinition,
  ctx: { node?: NodeState; referralsVerified?: number },
): boolean {
  if (quest.criteria.min_uptime_sec != null) {
    const uptime = ctx.node?.totalUptimeSec ?? 0;
    const active = ctx.node?.status === 'active';
    if (!active || uptime < quest.criteria.min_uptime_sec) return false;
  }
  if (quest.criteria.min_referrals != null) {
    if ((ctx.referralsVerified ?? 0) < quest.criteria.min_referrals) return false;
  }
  return true;
}

export type CompletionResult = {
  user: UserState;
  tickets: LotteryTicket[];
  questId: string;
};

/** In-memory atomic completion (production: call yieldswarm_complete_quest via SQL). */
export function completeQuestAtomic(
  user: UserState,
  quest: QuestDefinition,
  windowDate: string,
  completedKeys: Set<string>,
  rng: () => number = Math.random,
): CompletionResult | null {
  const key = `${user.id}:${quest.id}:${windowDate}`;
  if (completedKeys.has(key)) return null;
  completedKeys.add(key);

  const newXp = user.xp + quest.xpReward;
  const updated: UserState = {
    ...user,
    xp: newXp,
    level: levelForXp(newXp),
  };

  const tickets: LotteryTicket[] = [];
  for (let i = 0; i < quest.ticketReward; i += 1) {
    const ticketHash = hashStub(`${user.id}:${windowDate}:${quest.id}:${i}:${rng()}`);
    tickets.push({ ticketHash, userId: user.id, windowDate, source: quest.id });
  }

  return { user: updated, tickets, questId: quest.id };
}

function hashStub(input: string): string {
  let h = 0;
  for (let i = 0; i < input.length; i += 1) {
    h = (Math.imul(31, h) + input.charCodeAt(i)) | 0;
  }
  return `ys-ticket-${(h >>> 0).toString(16).padStart(8, '0')}`;
}

/**
 * Deterministic daily winner index from VRF seed (transparent, verifiable).
 * Production: replace stub with Chainlink VRF or drand beacon.
 */
export function pickLotteryWinner(
  tickets: LotteryTicket[],
  vrfSeed: string,
): LotteryTicket | null {
  if (tickets.length === 0) return null;
  const idx = deterministicIndex(vrfSeed, tickets.length);
  return tickets[idx] ?? null;
}

export function deterministicIndex(seed: string, modulo: number): number {
  let acc = 0;
  for (let i = 0; i < seed.length; i += 1) {
    acc = (acc + seed.charCodeAt(i) * (i + 1)) % 1_000_000_007;
  }
  return acc % modulo;
}

/** Smart contract / on-chain VRF stub interface */
export type VrfDrawRequest = {
  drawingId: string;
  windowDate: string;
  ticketRootHash: string;
  callbackUrl: string;
};

export function buildVrfStubRequest(
  drawingId: string,
  windowDate: string,
  tickets: LotteryTicket[],
): VrfDrawRequest {
  const root = hashStub(tickets.map((t) => t.ticketHash).sort().join('|'));
  return {
    drawingId,
    windowDate,
    ticketRootHash: root,
    callbackUrl: 'https://gateway.yieldswarm.crypto/api/quests/vrf-callback',
  };
}
