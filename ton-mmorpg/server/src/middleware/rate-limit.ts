/**
 * In-memory sliding-window rate limiter with optional Upstash hook.
 */

export interface RateLimitConfig {
  windowMs: number;
  maxRequests: number;
}

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: number;
}

interface Bucket {
  count: number;
  windowStart: number;
}

const buckets = new Map<string, Bucket>();

export function loadRateLimitConfig(): RateLimitConfig {
  return {
    windowMs: Number(process.env.RATE_LIMIT_WINDOW_MS || "60000"),
    maxRequests: Number(process.env.RATE_LIMIT_MAX_REQUESTS || "30"),
  };
}

export function checkRateLimit(
  key: string,
  config: RateLimitConfig = loadRateLimitConfig(),
): RateLimitResult {
  const now = Date.now();
  let bucket = buckets.get(key);

  if (!bucket || now - bucket.windowStart >= config.windowMs) {
    bucket = { count: 0, windowStart: now };
    buckets.set(key, bucket);
  }

  bucket.count += 1;
  const allowed = bucket.count <= config.maxRequests;
  const remaining = Math.max(0, config.maxRequests - bucket.count);
  const resetAt = bucket.windowStart + config.windowMs;

  return { allowed, remaining, resetAt };
}

/** Optional Upstash Redis REST rate limit (production). */
export async function checkRateLimitRedis(
  key: string,
  config: RateLimitConfig = loadRateLimitConfig(),
): Promise<RateLimitResult | null> {
  const url = process.env.UPSTASH_REDIS_REST_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN;
  if (!url || !token) return null;

  const redisKey = `ton-mmorpg:rl:${key}`;
  const res = await fetch(`${url}/incr/${encodeURIComponent(redisKey)}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) return null;

  const count = Number(await res.text());
  if (count === 1) {
    await fetch(`${url}/pexpire/${encodeURIComponent(redisKey)}/${config.windowMs}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
  }

  return {
    allowed: count <= config.maxRequests,
    remaining: Math.max(0, config.maxRequests - count),
    resetAt: Date.now() + config.windowMs,
  };
}

export async function enforceRateLimit(wallet: string): Promise<RateLimitResult> {
  const config = loadRateLimitConfig();
  const redis = await checkRateLimitRedis(wallet, config);
  if (redis) return redis;
  return checkRateLimit(wallet, config);
}
