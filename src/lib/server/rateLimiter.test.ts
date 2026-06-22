import { describe, it, expect, beforeEach } from "vitest";
import {
  checkEmissionRateLimit,
  _resetRateLimitBucketsForTests,
} from "@/lib/server/rateLimiter";

const WALLET = "EQD4g3Y-N26G_vK3hXq9rB0123456789abcdefghijklmnop";

describe("checkEmissionRateLimit", () => {
  beforeEach(() => {
    _resetRateLimitBucketsForTests();
    delete process.env.REDIS_URL;
    delete process.env.REDIS_TOKEN;
  });

  it("allows burst up to bucket max", async () => {
    for (let i = 0; i < 10; i++) {
      const result = await checkEmissionRateLimit(WALLET);
      expect(result.allowed).toBe(true);
    }
    const blocked = await checkEmissionRateLimit(WALLET);
    expect(blocked.allowed).toBe(false);
    expect(blocked.remainingTokens).toBe(0);
  });

  it("isolates buckets per wallet (anti-Sybil per address)", async () => {
    const other = "UQD4g3Y-N26G_vK3hXq9rB0123456789abcdefghijklmnop";
    for (let i = 0; i < 10; i++) {
      await checkEmissionRateLimit(WALLET);
    }
    const otherWallet = await checkEmissionRateLimit(other);
    expect(otherWallet.allowed).toBe(true);
  });
});
