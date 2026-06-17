/**
 * Referral funnel API — state anchors, 40% stack unlock, mutant agent claim.
 */

import { Router } from 'express';
import * as referral from '../adapters/referralEngine.js';

const router = Router();

/** Simple per-IP sliding window rate limiter */
const buckets = new Map();
const RATE_WINDOW_MS = 60_000;
const RATE_MAX = 60;

function rateLimit(req, res, next) {
  const ip = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.socket.remoteAddress || 'unknown';
  const now = Date.now();
  const bucket = buckets.get(ip) || { count: 0, resetAt: now + RATE_WINDOW_MS };
  if (now > bucket.resetAt) {
    bucket.count = 0;
    bucket.resetAt = now + RATE_WINDOW_MS;
  }
  bucket.count += 1;
  buckets.set(ip, bucket);
  if (bucket.count > RATE_MAX) {
    return res.status(429).json({ error: 'rate limit exceeded', retryAfterMs: bucket.resetAt - now });
  }
  return next();
}

router.use(rateLimit);

router.get('/stack', (_req, res) => {
  res.json(referral.getReferralStack());
});

router.get('/config', (_req, res) => {
  const stack = referral.getReferralStack();
  res.json({
    unlockThresholdPct: stack.unlockThresholdPct,
    cloudCreditUsd: stack.cloudCreditUsd,
    rewardSplit: stack.rewardSplit,
    disclaimers: stack.disclaimers,
  });
});

router.get('/progress/:wallet', (req, res) => {
  const chain = req.query.chain || 'evm';
  res.json(referral.getProgress(req.params.wallet, String(chain)));
});

router.post('/track', (req, res) => {
  try {
    const { wallet, linkId, chain, utm } = req.body || {};
    if (!wallet || !linkId) {
      return res.status(400).json({ error: 'wallet and linkId required' });
    }
    const result = referral.trackLinkClick(wallet, linkId, chain || 'evm', { utm });
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message || 'track failed' });
  }
});

router.post('/claim', (req, res) => {
  try {
    const result = referral.claimReferralBundle(req.body || {});
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message || 'claim failed' });
  }
});

export default router;
