import test from "node:test";
import assert from "node:assert/strict";
import { buildSystemState, profitabilitySnapshot, temporalContext } from "../src/lib/trident-state.js";

test("buildSystemState includes quantum equation and hardware matrix", () => {
  const state = buildSystemState();
  assert.equal(state.quantum.equation, "∇⨂Ψ = ∮∂Ω(t,c)");
  assert.equal(state.onPrem.asic.antminerS19.count, 3);
  assert.equal(state.onPrem.edge.attVistaWTATTRW2.count, 700);
  assert.equal(state.remoteFleet.creditUsd, 36000);
  assert.equal(state.websocket.port, 8095);
});

test("profitabilitySnapshot ranks coins", () => {
  const snap = profitabilitySnapshot();
  assert.ok(snap.ranked.length === 3);
  assert.ok(snap.best.usdDay >= snap.ranked[1].usdDay);
});

test("temporalContext includes week number", () => {
  const t = temporalContext(new Date("2026-06-15T12:00:00Z"));
  assert.equal(t.year, 2026);
  assert.equal(t.season, "Summer");
  assert.ok(t.week >= 1);
});
