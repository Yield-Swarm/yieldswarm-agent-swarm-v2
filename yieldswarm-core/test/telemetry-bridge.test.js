import test from "node:test";
import assert from "node:assert/strict";
import {
  buildTelemetryView,
  temporalBeacon,
  mapLocalHardware,
  aggregateMiningPools,
} from "../src/lib/telemetry-bridge.js";
import { buildSystemState } from "../src/lib/trident-state.js";

test("buildTelemetryView maps dashboard fields", () => {
  const state = buildSystemState();
  const view = buildTelemetryView(state, {
    miningPools: {
      ecosystem: "PoWUoI",
      yieldswarmCoin: "PRL",
      pools: [
        { coin: "PRL", status: "active", algorithm: "ProgPowZ", workersOnline: 2, hashrate: 12 },
        { coin: "ZANO", status: "standby", algorithm: "ProgPowZ", workersOnline: 0, hashrate: 0 },
      ],
      switcher: { activeNetwork: "PRL", activeQuoteUsdDay: 12.5 },
      attribution: { estimatedUsd24h: 50, treasurySplit: "50,30,15,5" },
    },
    termuxFleet: { instances: [{ alive: true }, { alive: false }] },
    physicalCore: { asics: { aggregateHashrateGh: 120 } },
  });

  assert.ok(view.genesisHash);
  assert.equal(view.temporalBeacon.week > 0, true);
  assert.equal(view.localHardware.s19Count, 3);
  assert.equal(view.localHardware.phoneWallNodes, 700);
  assert.equal(view.miningPools.poolsActive, 1);
  assert.equal(view.cloudPrices.runpod, "1.89");
});

test("temporalBeacon includes dayProgress", () => {
  const b = temporalBeacon({ week: 26, season: "Summer", label: "June 2026" });
  assert.match(b.dayProgress, /%$/);
});

test("mapLocalHardware detects ranch live", () => {
  const hw = mapLocalHardware(buildSystemState(), {
    physicalCore: { asics: { aggregateHashrateGh: 5 } },
    termuxFleet: null,
  });
  assert.equal(hw.status, "ranch-asic-live");
});
