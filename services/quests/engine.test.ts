import { describe, expect, it } from 'vitest';
import {
  levelForXp,
  evaluateQuest,
  completeQuestAtomic,
  pickLotteryWinner,
  DEFAULT_QUESTS,
  deterministicIndex,
} from './engine';

describe('quest engine', () => {
  it('computes level from xp curve', () => {
    expect(levelForXp(0)).toBe(1);
    expect(levelForXp(100)).toBe(2);
    expect(levelForXp(10_000)).toBeGreaterThan(10);
  });

  it('evaluates 24h node quest', () => {
    const quest = DEFAULT_QUESTS[0];
    expect(
      evaluateQuest(quest, { node: { nodeKey: 'n1', status: 'active', connectionStreakDays: 1, totalUptimeSec: 90_000 } }),
    ).toBe(true);
    expect(
      evaluateQuest(quest, { node: { nodeKey: 'n1', status: 'idle', connectionStreakDays: 0, totalUptimeSec: 0 } }),
    ).toBe(false);
  });

  it('completes quest atomically once', () => {
    const user = { id: 'u1', accountId: 'acct', xp: 0, level: 1 };
    const completed = new Set<string>();
    const quest = DEFAULT_QUESTS[1];
    const r1 = completeQuestAtomic(user, quest, '2026-06-15', completed, () => 0.5);
    const r2 = completeQuestAtomic(user, quest, '2026-06-15', completed, () => 0.5);
    expect(r1?.user.xp).toBe(80);
    expect(r1?.tickets).toHaveLength(1);
    expect(r2).toBeNull();
  });

  it('picks deterministic lottery winner', () => {
    const tickets = [
      { ticketHash: 'a', userId: 'u1', windowDate: '2026-06-15', source: 'q' },
      { ticketHash: 'b', userId: 'u2', windowDate: '2026-06-15', source: 'q' },
      { ticketHash: 'c', userId: 'u3', windowDate: '2026-06-15', source: 'q' },
    ];
    const w1 = pickLotteryWinner(tickets, 'seed-alpha');
    const w2 = pickLotteryWinner(tickets, 'seed-alpha');
    expect(w1).toEqual(w2);
    expect(deterministicIndex('seed-alpha', 3)).toBeGreaterThanOrEqual(0);
  });
});
