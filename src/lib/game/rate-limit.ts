/**
 * Token-bucket rate limiter — Redis (Upstash) with in-memory fallback.
 * Step 1 of settlement pipeline: prevent automated claim spam.
 */
import { Redis } from "@upstash/redis";
import { gameEnv } from "@/lib/game/config";

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  retryAfterSec?: number;
}

type Bucket = { count: number; resetAt: number };

const memoryBuckets = new Map<string, Bucket>();

function memoryRateLimit(key: string, max: number, windowSec: number): RateLimitResult {
  const now = Math.floor(Date.now() / 1000);
  const bucket = memoryBuckets.get(key);
  if (!bucket || now >= bucket.resetAt) {
    memoryBuckets.set(key, { count: 1, resetAt: now + windowSec });
    return { allowed: true, remaining: max - 1 };
  }
  if (bucket.count >= max) {
    return { allowed: false, remaining: 0, retryAfterSec: bucket.resetAt - now };
  }
  bucket.count += 1;
  return { allowed: true, remaining: max - bucket.count };
}

let redisClient: Redis | null = null;

function getRedis(): Redis | null {
  const url = gameEnv.redisUrl();
  const token = gameEnv.redisToken();
  if (!url || !token) return null;
  if (!redisClient) redisClient = new Redis({ url, token });
  return redisClient;
}

export async function checkClaimRateLimit(wallet: string): Promise<RateLimitResult> {
  const max = gameEnv.rateLimitMax();
  const windowSec = gameEnv.rateLimitWindowSec();
  const key = `game:claim:${wallet}`;

  const redis = getRedis();
  if (!redis) {
    return memoryRateLimit(key, max, windowSec);
  }

  const now = Math.floor(Date.now() / 1000);
  const count = await redis.incr(key);
  if (count === 1) {
    await redis.expire(key, windowSec);
  }
  if (count > max) {
    const ttl = await redis.ttl(key);
    return {
      allowed: false,
      remaining: 0,
      retryAfterSec: ttl > 0 ? ttl : windowSec,
    };
  }
  return { allowed: true, remaining: max - count };
}
