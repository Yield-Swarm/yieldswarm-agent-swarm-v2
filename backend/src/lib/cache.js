/**
 * Tiny in-memory TTL cache with single-flight de-duplication.
 *
 * Telemetry endpoints are polled frequently by the dashboard; this avoids
 * hammering upstreams (Akash REST, Solana RPC) and smooths over transient
 * upstream blips by serving the last good value within the TTL window.
 */

export class TtlCache {
  constructor(defaultTtlMs = 15_000) {
    this.defaultTtlMs = defaultTtlMs;
    this.store = new Map();
    this.inflight = new Map();
  }

  /**
   * Returns the cached value for `key` if fresh, otherwise runs `producer()`,
   * caches the result, and returns it. Concurrent callers share one producer
   * invocation (single-flight).
   */
  async get(key, producer, ttlMs = this.defaultTtlMs) {
    const now = Date.now();
    const hit = this.store.get(key);
    if (hit && hit.expiresAt > now) {
      return hit.value;
    }
    if (this.inflight.has(key)) {
      return this.inflight.get(key);
    }
    const promise = (async () => {
      try {
        const value = await producer();
        this.store.set(key, { value, expiresAt: Date.now() + ttlMs });
        return value;
      } finally {
        this.inflight.delete(key);
      }
    })();
    this.inflight.set(key, promise);
    return promise;
  }

  invalidate(key) {
    this.store.delete(key);
  }
}

export default TtlCache;
