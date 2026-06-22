import { describe, it, expect } from "vitest";
import {
  calculatePoEEmission,
  computeServerDeltaTime,
  POE_MAX_DELTA_SECONDS,
  POE_MAX_EMISSION,
} from "@/lib/game/engine";

const baseAction = {
  baseFactor: 50,
  metrics: [2, 10],
  weights: [0.5, 1.0],
  actionType: "combat" as const,
};

describe("calculatePoEEmission", () => {
  it("returns positive emission for valid server-side deltaTime", () => {
    const emission = calculatePoEEmission({ ...baseAction, deltaTime: 120 });
    expect(emission).toBeGreaterThan(0n);
  });

  it("returns zero when deltaTime is zero", () => {
    expect(calculatePoEEmission({ ...baseAction, deltaTime: 0 })).toBe(0n);
  });

  it("caps deltaTime to prevent client-scale time exploits", () => {
    const capped = calculatePoEEmission({
      ...baseAction,
      deltaTime: POE_MAX_DELTA_SECONDS + 99_999,
    });
    const atMax = calculatePoEEmission({
      ...baseAction,
      deltaTime: POE_MAX_DELTA_SECONDS,
    });
    expect(capped).toBe(atMax);
    expect(capped).toBeLessThanOrEqual(POE_MAX_EMISSION);
  });

  it("rejects mismatched metrics/weights", () => {
    expect(() =>
      calculatePoEEmission({
        ...baseAction,
        metrics: [1],
        weights: [1, 2],
        deltaTime: 60,
      }),
    ).toThrow(/mismatch/);
  });
});

describe("computeServerDeltaTime", () => {
  it("uses baseline when no on-chain save exists", () => {
    expect(computeServerDeltaTime(0, 1_700_000_000)).toBe(60);
  });

  it("computes bounded delta from on-chain timestamp", () => {
    const now = 1_700_000_600;
    expect(computeServerDeltaTime(1_700_000_000, now)).toBe(600);
  });
});
