import { describe, it, expect } from "vitest";
import {
  calculatePoEEmission,
  MAX_EMISSION_PER_ACTION,
  POE_SCALE,
} from "@/lib/game/engine";
import type { ProofOfEngagementAction } from "@/types/game";

const baseAction: ProofOfEngagementAction = {
  baseFactor: 1.5,
  enemyLevel: 8,
  precision: 1.0,
  deltaTime: 120,
  actionType: "combat",
};

describe("calculatePoEEmission", () => {
  it("returns deterministic bigint for combat action", () => {
    const emission = calculatePoEEmission(baseAction);
    expect(typeof emission).toBe("bigint");
    expect(emission).toBe(1800n);
  });

  it("clamps deltaTime to max 3600 seconds", () => {
    const huge = calculatePoEEmission({ ...baseAction, deltaTime: 999_999 });
    const capped = calculatePoEEmission({ ...baseAction, deltaTime: 3600 });
    expect(huge).toBe(capped);
  });

  it("clamps deltaTime to min 1 second", () => {
    const zero = calculatePoEEmission({ ...baseAction, deltaTime: 0 });
    const one = calculatePoEEmission({ ...baseAction, deltaTime: 1 });
    expect(zero).toBe(one);
  });

  it("returns 0 when precision scales to 0", () => {
    const emission = calculatePoEEmission({ ...baseAction, precision: 0.0001 });
    expect(emission).toBe(0n);
  });

  it("caps emission at MAX_EMISSION_PER_ACTION", () => {
    const emission = calculatePoEEmission({
      baseFactor: 9999,
      enemyLevel: 100,
      precision: 0.001,
      deltaTime: 3600,
      actionType: "combat",
    });
    expect(emission).toBe(MAX_EMISSION_PER_ACTION);
  });

  it("applies exploration modifier below combat", () => {
    const combat = calculatePoEEmission(baseAction);
    const exploration = calculatePoEEmission({
      ...baseAction,
      actionType: "exploration",
    });
    expect(exploration).toBeLessThan(combat);
  });

  it("uses fixed-point scale constant", () => {
    expect(POE_SCALE).toBe(1_000_000_000n);
  });
});
