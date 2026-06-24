/**
 * In-process token-bucket rate limiter.
 * For multi-instance production, point REDIS_URL at ElastiCache and extend
 * with ioredis + Lua script (see docs/IOTEX_W3BSTREAM_INTEGRATION.md).
 */

const buckets = new Map();

/**
 * @param {string} key
 * @param {{ capacity?: number, refillPerSecond?: number, cost?: number }} opts
 * @returns {boolean} true if allowed
 */
export function consumeToken(key, opts = {}) {
  const capacity = opts.capacity ?? 5;
  const refillPerSecond = opts.refillPerSecond ?? 1 / 60;
  const cost = opts.cost ?? 1;
  const now = Date.now() / 1000;

  let bucket = buckets.get(key);
  if (!bucket) {
    bucket = { tokens: capacity, lastUpdate: now };
    buckets.set(key, bucket);
  }

  const elapsed = Math.max(0, now - bucket.lastUpdate);
  bucket.tokens = Math.min(capacity, bucket.tokens + elapsed * refillPerSecond);
  bucket.lastUpdate = now;

  if (bucket.tokens < cost) return false;
  bucket.tokens -= cost;
  return true;
}

/** @param {string} [prefix] */
export function resetBuckets(prefix) {
  if (!prefix) {
    buckets.clear();
    return;
  }
  for (const key of buckets.keys()) {
    if (key.startsWith(prefix)) buckets.delete(key);
  }
}
