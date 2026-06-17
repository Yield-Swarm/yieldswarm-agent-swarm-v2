import test from 'node:test';
import assert from 'node:assert/strict';
import {
  generateStateAnchor,
  getReferralStack,
  trackLinkClick,
  claimReferralBundle,
  getProgress,
  getRewardSplit,
  _resetReferralSessions,
} from './referralEngine.js';

test.beforeEach(() => {
  _resetReferralSessions();
});

test('generateStateAnchor returns 64-char hex', () => {
  const anchor = generateStateAnchor('0xabc', 'test', { foo: 1 });
  assert.match(anchor, /^[0-9a-f]{64}$/);
});

test('reward split defaults to 60/40 user/treasury', () => {
  const split = getRewardSplit();
  assert.equal(split.userStakePct, 60);
  assert.equal(split.nodeOpsTreasuryPct, 40);
});

test('referral stack loads categories and computes 40% threshold', () => {
  const stack = getReferralStack();
  assert.ok(stack.totalLinks > 0);
  assert.equal(stack.unlockThresholdPct, 40);
  assert.ok(stack.requiredLinks >= 1);
  assert.ok(stack.requiredLinks <= stack.totalLinks);
});

test('track + claim flow unlocks staking at threshold', () => {
  const wallet = '0xTestWallet123';
  claimReferralBundle({ wallet, chain: 'evm' });

  const stack = getReferralStack();
  const links = stack.categories.flatMap((c) => c.links.map((l) => l.id));

  for (let i = 0; i < stack.requiredLinks; i += 1) {
    trackLinkClick(wallet, links[i], 'evm');
  }

  const progress = getProgress(wallet, 'evm');
  assert.equal(progress.completedCount, stack.requiredLinks);
  assert.equal(progress.stakingUnlocked, true);
  assert.ok(progress.mutantAgentId);
  assert.ok(progress.stateChainHash);
});
