import { describe, expect, it } from "vitest";
import { EntropyCore } from "./entropy-core.js";
import { WINDOW_SIZE } from "./entropy-bounds.js";

function sampleTelemetry(i) {
  return {
    temp: 65 + (i % 10),
    power_draw: 320 + (i % 50),
    tokens_per_sec: 1200 + i,
    error_rate: 0.001,
    timestamp: 1_700_000_000_000 + i * 1_000,
  };
}

describe("EntropyCore", () => {
  it("returns null until the rolling window is full", () => {
    const core = new EntropyCore();
    for (let i = 0; i < WINDOW_SIZE - 1; i++) {
      expect(core.ingest(sampleTelemetry(i))).toBeNull();
    }
  });

  it("emits seed, quality, and zkInputs when the window fills", () => {
    const core = new EntropyCore();
    let result = null;
    for (let i = 0; i < WINDOW_SIZE; i++) {
      result = core.ingest(sampleTelemetry(i));
    }

    expect(result).not.toBeNull();
    expect(result.seed).toMatch(/^0x[0-9a-f]{32}$/);
    expect(result.quality).toBeGreaterThanOrEqual(85);
    expect(result.quality).toBeLessThanOrEqual(100);
    expect(result.zkInputs.private.telemetryWindow).toHaveLength(WINDOW_SIZE);
    expect(result.zkInputs.public.commitment).toBeNull();
  });

  it("resets the window after generating a seed", () => {
    const core = new EntropyCore();
    for (let i = 0; i < WINDOW_SIZE; i++) {
      core.ingest(sampleTelemetry(i));
    }
    expect(core.ingest(sampleTelemetry(999))).toBeNull();
  });
});
