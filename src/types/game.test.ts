import { describe, it, expect } from "vitest";
import { createHash } from "crypto";
import { hashEquipment, PlayerProfileSchema } from "@/types/game";

describe("hashEquipment", () => {
  it("hashes raw comma-separated loadout to SHA-256 hex", () => {
    const raw = "ironclad-blade,dragon-mail,oak-shield";
    const hash = hashEquipment(raw);
    expect(hash).toMatch(/^[a-f0-9]{64}$/);
    expect(hash).toBe(
      createHash("sha256").update(raw.trim()).digest("hex"),
    );
  });

  it("passes through existing 64-char hex hashes", () => {
    const existing = "a".repeat(64);
    expect(hashEquipment(existing)).toBe(existing);
  });
});

describe("PlayerProfileSchema", () => {
  it("transforms raw equipmentHash on parse", () => {
    const parsed = PlayerProfileSchema.parse({
      walletAddress: "EQD4g3Y-N26G_vK3hXq9rB0123456789abcdefghijklmnop",
      level: 12,
      experience: 48230,
      equipmentHash: "ironclad-blade,dragon-mail,oak-shield",
      lastSaveTimestamp: 1719020000,
    });
    expect(parsed.equipmentHash).toHaveLength(64);
    expect(parsed.equipmentHash).not.toContain("ironclad");
  });
});
