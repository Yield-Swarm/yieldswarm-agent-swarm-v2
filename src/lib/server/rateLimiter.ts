import { Redis } from "@upstash/redis";

export type RateLimitResponse = {
  allowed: boolean;
  remainingTokens: number;
};

type BucketState = {
  tokens: number;
  lastRefill: number;
};

const BUCKET_MAX = Number(process.env.POE_RATE_LIMIT_BURST || "10");
const REFILL_RATE_SEC = Number(process.env.POE_RATE_LIMIT_REFILL || "0.2");

/** In-memory fallback when Upstash Redis is not configured (dev / Termux). */
const memoryBuckets = new Map<string, BucketState>();

function redisConfigured(): boolean {
  return Boolean(process.env.REDIS_URL && process.env.REDIS_TOKEN);
}

let _redis: Redis | null = null;

function getRedis(): Redis {
  if (!_redis) {
    _redis = new Redis({
      url: process.env.REDIS_URL!,
      token: process.env.REDIS_TOKEN!,
    });
  }
  return _redis;
}

function refillTokens(state: BucketState, now: number): BucketState {
  const elapsed = Math.max(0, now - state.lastRefill);
  const tokens = Math.min(BUCKET_MAX, state.tokens + elapsed * REFILL_RATE_SEC);
  return { tokens, lastRefill: now };
}

async function checkMemoryBucket(key: string, now: number): Promise<RateLimitResponse> {
  const existing = memoryBuckets.get(key);
  const state = refillTokens(
    existing ?? { tokens: BUCKET_MAX, lastRefill: now },
    now,
  );

  if (state.tokens >= 1) {
    state.tokens -= 1;
    memoryBuckets.set(key, state);
    return { allowed: true, remainingTokens: Math.floor(state.tokens) };
  }

  memoryBuckets.set(key, state);
  return { allowed: false, remainingTokens: 0 };
}

async function checkRedisBucket(key: string, now: number): Promise<RateLimitResponse> {
  const redis = getRedis();
  const data = await redis.hgetall<{ tokens: string; lastRefill: string }>(key);

  let state: BucketState = { tokens: BUCKET_MAX, lastRefill: now };
  if (data?.tokens !== undefined && data?.lastRefill !== undefined) {
    state = refillTokens(
      {
        tokens: Number(data.tokens),
        lastRefill: Number(data.lastRefill),
      },
      now,
    );
  }

  if (state.tokens >= 1) {
    state.tokens -= 1;
    await redis.hset(key, {
      tokens: String(state.tokens),
      lastRefill: String(state.lastRefill),
    });
    await redis.expire(key, 86_400);
    return { allowed: true, remainingTokens: Math.floor(state.tokens) };
  }

  await redis.hset(key, {
    tokens: String(state.tokens),
    lastRefill: String(state.lastRefill),
  });
  await redis.expire(key, 86_400);
  return { allowed: false, remainingTokens: 0 };
}

/**
 * Server-side token bucket per wallet — anti-Sybil / bot spam firewall.
 */
export async function checkEmissionRateLimit(
  walletAddress: string,
): Promise<RateLimitResponse> {
  const key = `ratelimit:emission:${walletAddress}`;
  const now = Date.now() / 1000;

  if (redisConfigured()) {
    return checkRedisBucket(key, now);
  }
  return checkMemoryBucket(key, now);
}

/** Test helper — reset in-memory buckets. */
export function _resetRateLimitBucketsForTests(): void {
  memoryBuckets.clear();
}
