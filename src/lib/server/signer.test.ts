import { describe, it, expect } from "vitest";
import { signClaimPayload, verifyClaimPayload } from "@/lib/server/signer";

describe("signClaimPayload", () => {
  it("produces verifiable HMAC signatures", () => {
    const payload = {
      recipient: "EQD4g3Y-N26G_vK3hXq9rB0123456789abcdefghijklmnop",
      amount: "12345",
      actionHash: "a".repeat(64),
      nonce: 100021,
      timestamp: 1_700_000_000,
    };
    const sig = signClaimPayload(payload);
    expect(sig).toHaveLength(64);
    expect(verifyClaimPayload(payload, sig)).toBe(true);
    expect(verifyClaimPayload({ ...payload, nonce: 1 }, sig)).toBe(false);
  });
});
