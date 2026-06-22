import { describe, it, expect } from "vitest";
import {
  canonicalSettlementBytes,
  signSettlementPayload,
  verifySettlementSignature,
  getOrGenerateDevKeyPair,
} from "@/lib/game/signing";

const samplePayload = {
  wallet: "EQD4g3Y-N26G_vK3hXq9rB0123456789abcdefghijklmnop",
  level: 12,
  equipmentHash: "1db0a198a554734c975210bbad5991a14efd26776c4cffdbdf420491601a37f2",
  emissionNano: "1800",
  chainTimestamp: 1719010000,
  serverTimestamp: 1719020000,
  deltaTime: 120,
  actionType: "combat",
};

describe("settlement signing", () => {
  it("produces deterministic canonical digest", () => {
    const a = canonicalSettlementBytes(samplePayload);
    const b = canonicalSettlementBytes(samplePayload);
    expect(a.equals(b)).toBe(true);
    expect(a.length).toBe(32);
  });

  it("signs and verifies in dev mode", () => {
    const { publicKeyHex, privateKeyHex } = getOrGenerateDevKeyPair();
    process.env.GAME_SETTLEMENT_PRIVATE_KEY_HEX = privateKeyHex;
    const sig = signSettlementPayload(samplePayload);
    expect(sig).toHaveLength(128);
    expect(verifySettlementSignature(samplePayload, sig, publicKeyHex)).toBe(true);
    delete process.env.GAME_SETTLEMENT_PRIVATE_KEY_HEX;
  });
});
