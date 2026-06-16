import { describe, expect, it } from "vitest";
import {
  computeCommitment,
  computeQualityFromWindow,
  buildCircuitInput,
  flattenTelemetry,
} from "./entropy-circuit-inputs.js";
import { clampToBounds, normalizeTelemetry } from "./entropy-bounds.js";
import { EntropyCore } from "./zk-entropy-core.js";
import { WINDOW_SIZE } from "./entropy-bounds.js";

function fillWindow() {
  const core = new EntropyCore();
  let result = null;
  for (let i = 0; i < WINDOW_SIZE; i++) {
    result = core.ingest({
      temp: 70,
      power_draw: 400,
      tokens_per_sec: 1500,
      error_rate: 0.0005,
      timestamp: 1_700_000_000_000 + i,
    });
  }
  return result;
}

describe("entropy-circuit-inputs", () => {
  it("flattens telemetry into 5-field rows", () => {
    const point = clampToBounds(
      normalizeTelemetry({ temp: 70, power_draw: 400, tokens_per_sec: 1500 })
    );
    expect(flattenTelemetry([point])).toEqual([[point.t, point.p, point.s, point.e, point.ts]]);
  });

  it("computes deterministic Poseidon commitment", async () => {
    const result = fillWindow();
    const window = result.zkInputs.private.telemetryWindow;
    const c1 = await computeCommitment(window);
    const c2 = await computeCommitment(window);
    expect(c1).toBe(c2);
    expect(c1).toMatch(/^0x[0-9a-f]{64}$/);
  });

  it("aligns quality with entropy-core output", async () => {
    const result = fillWindow();
    const window = result.zkInputs.private.telemetryWindow;
    const commitment = await computeCommitment(window);
    const quality = computeQualityFromWindow(window);

    expect(quality).toBe(result.quality);

    const input = buildCircuitInput(
      { telemetryWindow: window },
      { commitment, quality }
    );
    expect(input.telemetry).toHaveLength(WINDOW_SIZE);
    expect(input.quality).toBe(quality);
    expect(input.outQuality).toBe(quality);
  });
});
