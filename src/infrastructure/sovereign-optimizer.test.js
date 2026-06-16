/**
 * @vitest-environment node
 */
import { describe, it, expect } from 'vitest';
import { scoreCandidate, wormholeRoute, optimizeTick } from '../infrastructure/sovereign-optimizer.js';

const baseWorker = {
  tokensPerSec: 80,
  costPerHourUsd: 0.8,
  uptimePct: 99,
  utilizationPct: 72,
  wattsPerToken: 1.2,
  thermalC: 70,
  vramUsedPct: 60,
  packetLossPct: 0.5,
  url: 'https://worker-a.akash',
};

describe('sovereign-optimizer v6', () => {
  it('scores candidates with NFT tier boost', () => {
    const low = scoreCandidate(baseWorker, { mutationTier: 0 });
    const high = scoreCandidate(baseWorker, { mutationTier: 4, mutationBoostBps: 1000 });
    expect(high.compositeScore).toBeGreaterThan(low.compositeScore);
  });

  it('applies thermal fallback penalty', () => {
    const hot = scoreCandidate({ ...baseWorker, thermalC: 90 });
    const cool = scoreCandidate({ ...baseWorker, thermalC: 70 });
    expect(hot.compositeScore).toBeLessThan(cool.compositeScore);
  });

  it('returns wormhole routing signal', () => {
    const workers = [
      baseWorker,
      { ...baseWorker, url: 'https://worker-b.akash', tokensPerSec: 100 },
    ];
    const signal = wormholeRoute(workers, { mutationTier: 2 });
    expect(signal.wormholeTarget).toBeTruthy();
    expect(signal.wormholeReason).toMatch(/alpha_zeta|greedy/);
  });

  it('runs full optimize tick', () => {
    const result = optimizeTick({
      workers: [baseWorker],
      nft: { tier: 3, mutationBoostBps: 500 },
    });
    expect(result.version).toBe('v6');
    expect(result.signal).toBeTruthy();
  });
});
