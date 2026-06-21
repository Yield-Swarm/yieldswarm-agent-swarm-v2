import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const { AntimatterEngineV5 } = require(
  path.join(__dirname, "..", "..", "src", "infrastructure", "AntimatterEngineV5.js"),
);

describe("Helix Delta v5 client physics", () => {
  it("ticks antimatter engine with relativistic exhaust", () => {
    const engine = new AntimatterEngineV5();
    engine.updateEngineState(0.5, 0.75);
    const state = engine.getState();
    assert.ok(state.thrustNewtons > 0);
    assert.ok(state.exhaustVelocityBeta >= 0.3);
  });
});
