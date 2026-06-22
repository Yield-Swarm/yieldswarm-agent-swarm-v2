import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { computePoe, activityMultiplier } from "./engine.js";
import { computeDeltaT } from "../sync/timestamp-reader.js";

describe("PoE engine", () => {
  it("activity multiplier ranges 0.5–1.5", () => {
    assert.equal(activityMultiplier(0), 0.5);
    assert.equal(activityMultiplier(100), 1.5);
    assert.equal(activityMultiplier(50), 1.0);
  });

  it("accrues nano from deltaT and caps", () => {
    const result = computePoe(
      { deltaTSeconds: 100, activityScore: 100, sessionAccumulatedNano: 0n },
      {
        nanoPerSecond: 1_000_000n,
        nanoCapPerSync: 50_000_000n,
        igjCapPerSync: 1_000_000_000_000n,
        igjPerNanoScale: 1_000n,
      },
    );
    assert.equal(result.capped, true);
    assert.equal(result.earnedNano, 50_000_000n);
  });
});

describe("Δt clamp", () => {
  it("clamps excessive delta", () => {
    const now = 1_700_000_000;
    const last = now - 10_000;
    const d = computeDeltaT(last, now, 3600);
    assert.equal(d.deltaTSeconds, 3600);
    assert.equal(d.clamped, true);
  });

  it("never returns negative delta", () => {
    const d = computeDeltaT(9999999999, 1000, 3600);
    assert.equal(d.deltaTSeconds, 0);
  });
});
