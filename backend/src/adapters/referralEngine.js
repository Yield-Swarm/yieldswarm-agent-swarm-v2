/**
 * Referral engine — tamper-resistant progress tracking with solenoid state anchors.
 * Wires the "New to Crypto" funnel: link completions → 40% unlock → TAO/SOL staking eligibility.
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const stackPath = path.join(repoRoot, 'config', 'referral', 'stack.json');

/** @type {Map<string, object>} */
const sessions = new Map();

function int(value, fallback) {
  const n = Number.parseInt(value ?? '', 10);
  return Number.isFinite(n) ? n : fallback;
}

function loadStack() {
  try {
    return JSON.parse(fs.readFileSync(stackPath, 'utf8'));
  } catch {
    return { version: 1, unlockThresholdPct: 40, categories: [] };
  }
}

function flattenLinks(stack) {
  const links = [];
  for (const cat of stack.categories || []) {
    for (const link of cat.links || []) {
      links.push({ ...link, categoryId: cat.id, categoryLabel: cat.label });
    }
  }
  return links;
}

export function getRewardSplit() {
  const userBps = int(process.env.REFERRAL_REWARD_USER_BPS, 6000);
  const treasuryBps = int(process.env.REFERRAL_REWARD_TREASURY_BPS, 4000);
  const total = userBps + treasuryBps;
  return {
    userStakePct: total > 0 ? (userBps / total) * 100 : 60,
    nodeOpsTreasuryPct: total > 0 ? (treasuryBps / total) * 100 : 40,
    userBps,
    treasuryBps,
  };
}

/**
 * Cryptographic state anchor for auditable referral events (solenoid-compatible).
 */
export function generateStateAnchor(wallet, eventType, payload = {}) {
  const normalized = String(wallet || '').toLowerCase();
  const canonical = JSON.stringify({
    wallet: normalized,
    eventType,
    payload,
    ts: Date.now(),
  });
  return crypto.createHash('sha256').update(canonical).digest('hex');
}

function chainHash(prevHash, anchor) {
  return crypto.createHash('sha256').update(`${prevHash}:${anchor}`).digest('hex');
}

function normalizeWallet(wallet) {
  return String(wallet || '').trim();
}

function sessionKey(wallet, chain = 'evm') {
  return `${chain}:${normalizeWallet(wallet).toLowerCase()}`;
}

function getOrCreateSession(wallet, chain = 'evm') {
  const key = sessionKey(wallet, chain);
  if (!sessions.has(key)) {
    const genesis = crypto.createHash('sha256').update('YIELDSWARM_REFERRAL_GENESIS').digest('hex');
    sessions.set(key, {
      wallet: normalizeWallet(wallet),
      chain,
      completedLinks: new Set(),
      anchors: [],
      stateChainHash: genesis,
      mutantAgentId: null,
      cloudCreditUsd: 1850,
      stakingUnlocked: false,
      claimedAt: null,
      createdAt: new Date().toISOString(),
    });
  }
  return sessions.get(key);
}

function recordEvent(session, eventType, payload) {
  const anchor = generateStateAnchor(session.wallet, eventType, payload);
  session.stateChainHash = chainHash(session.stateChainHash, anchor);
  session.anchors.push({
    anchor,
    eventType,
    payload,
    at: new Date().toISOString(),
  });
  return anchor;
}

export function getReferralStack() {
  const stack = loadStack();
  const links = flattenLinks(stack);
  const thresholdPct = Number(process.env.REFERRAL_STACK_UNLOCK_PCT || stack.unlockThresholdPct || 40);
  return {
    ...stack,
    unlockThresholdPct: thresholdPct,
    totalLinks: links.length,
    requiredLinks: Math.ceil((links.length * thresholdPct) / 100),
    rewardSplit: getRewardSplit(),
    cloudCreditUsd: Number(process.env.REFERRAL_CLOUD_CREDIT_USD || 1850),
    disclaimers: {
      affiliate: 'Links may be affiliate or referral partnerships. Rewards are not guaranteed.',
      staking: 'TAO/SOL staking rewards are variable and subject to network conditions.',
    },
  };
}

export function getProgress(wallet, chain = 'evm') {
  const stack = getReferralStack();
  const session = sessions.get(sessionKey(wallet, chain));
  const completed = session ? [...session.completedLinks] : [];
  const pct = stack.totalLinks > 0 ? (completed.length / stack.totalLinks) * 100 : 0;
  const unlocked = completed.length >= stack.requiredLinks;

  return {
    wallet: normalizeWallet(wallet),
    chain,
    completedLinks: completed,
    completedCount: completed.length,
    totalLinks: stack.totalLinks,
    progressPct: Math.round(pct * 10) / 10,
    unlockThresholdPct: stack.unlockThresholdPct,
    requiredLinks: stack.requiredLinks,
    stakingUnlocked: session?.stakingUnlocked || unlocked,
    mutantAgentId: session?.mutantAgentId || null,
    stateChainHash: session?.stateChainHash || null,
    anchors: session?.anchors?.length || 0,
    cloudCreditUsd: stack.cloudCreditUsd,
    rewardSplit: stack.rewardSplit,
    claimed: Boolean(session?.claimedAt),
  };
}

export function trackLinkClick(wallet, linkId, chain = 'evm', meta = {}) {
  const stack = loadStack();
  const links = flattenLinks(stack);
  const link = links.find((l) => l.id === linkId);
  if (!link) {
    throw new Error(`unknown link: ${linkId}`);
  }

  const session = getOrCreateSession(wallet, chain);
  session.completedLinks.add(linkId);

  const anchor = recordEvent(session, 'link_click', {
    linkId,
    linkName: link.name,
    categoryId: link.categoryId,
    ...meta,
  });

  const progress = getProgress(wallet, chain);
  if (progress.completedCount >= getReferralStack().requiredLinks && !session.stakingUnlocked) {
    session.stakingUnlocked = true;
    recordEvent(session, 'staking_unlock', { completedCount: progress.completedCount });
  }

  return { anchor, link, progress: getProgress(wallet, chain) };
}

export function claimReferralBundle(body = {}) {
  const wallet = normalizeWallet(body.wallet);
  const chain = body.chain || 'evm';
  if (!wallet) throw new Error('wallet required');

  const session = getOrCreateSession(wallet, chain);
  if (!session.claimedAt) {
    session.claimedAt = new Date().toISOString();
    session.mutantAgentId = `mutant-tester-${crypto.createHash('sha256').update(wallet).digest('hex').slice(0, 12)}`;
    recordEvent(session, 'claim_bundle', {
      cloudCreditUsd: session.cloudCreditUsd,
      mutantAgentId: session.mutantAgentId,
    });
  }

  return {
    ok: true,
    wallet: session.wallet,
    chain: session.chain,
    mutantAgentId: session.mutantAgentId,
    cloudCreditUsd: session.cloudCreditUsd,
    stateAnchor: session.anchors[session.anchors.length - 1]?.anchor,
    stateChainHash: session.stateChainHash,
    progress: getProgress(wallet, chain),
    rewardSplit: getRewardSplit(),
  };
}

/** Reset in-memory store (tests only). */
export function _resetReferralSessions() {
  sessions.clear();
}
