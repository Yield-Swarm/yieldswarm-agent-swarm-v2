#!/usr/bin/env node
/**
 * SAA V2 / Trident telemetry console — consumes ws://127.0.0.1:8095 TELEMETRY_UPDATE frames.
 */
import { WebSocket } from "ws";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildTelemetryView, logHardwareDelta } from "./lib/telemetry-bridge.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const WS_URL = process.env.TRIDENT_WS_URL || "ws://127.0.0.1:8095";
const LOG_PATH = process.env.TRIDENT_HARDWARE_LOG || join(__dirname, "../.run/trident/hardware-events.log");

console.log("📡 Initializing SAA V2 Telemetry Console Listener...");
console.log(`   endpoint: ${WS_URL}`);

const ws = new WebSocket(WS_URL);

function pickView(payload) {
  if (payload?.telemetryView) return payload.telemetryView;
  const base = payload?.systemState || payload;
  return buildTelemetryView(base, payload?.externalTelemetry);
}

function renderFrame(message) {
  const view = pickView(message.payload);
  const { genesisHash, temporalBeacon, cloudPrices, localHardware, miningPools, termuxXmrig, remoteFleet } = view;

  logHardwareDelta(view, LOG_PATH);

  console.clear();
  console.log("=====================================================");
  console.log(" TRIDENT ECOSYSTEM REAL-TIME HEALTH MONITOR         ");
  console.log("=====================================================");
  console.log(`[GENESIS TARGET] : ${genesisHash}`);
  console.log(`[TEMPORAL BEACON]: Week ${temporalBeacon.week} | Progress: ${temporalBeacon.dayProgress}`);
  console.log(`                   ${temporalBeacon.label}`);
  console.log("-----------------------------------------------------");
  console.log("📡 LOCAL HARDWARE ARRAYS:");
  console.log(`  • Phone Wall Nodes: ${localHardware.phoneWallNodes} units [${localHardware.status}]`);
  console.log(`  • Termux Fleet     : ${localHardware.termuxAlive}/${localHardware.termuxInstances} alive`);
  console.log(`  • ASIC Clusters    : ${localHardware.s19Count}x S19, ${localHardware.l7Count}x L7, ${localHardware.z15Count}x Z15`);
  if (localHardware.physicalCoreHashrateGh > 0) {
    console.log(`  • Ranch Hashrate   : ${localHardware.physicalCoreHashrateGh} GH/s`);
  }
  if (termuxXmrig?.mining) {
    console.log(
      `  • XMRig (Termux)   : ${termuxXmrig.hashrateTotalKhps} kH/s | ${termuxXmrig.instancesAlive}/${termuxXmrig.instances} instances`
    );
  }
  console.log("-----------------------------------------------------");
  console.log("📊 CLOUD COMPUTE INDEX (USD/hr per GPU):");
  console.log(
    `  • RunPod: $${cloudPrices.runpod}  |  Akash: $${cloudPrices.akash}  |  Vast: $${cloudPrices.vast}`
  );
  console.log(`  • Fleet Credit: $${cloudPrices.fleetCreditUsd}  |  H100×${remoteFleet.h100} H200×${remoteFleet.h200}`);
  console.log("-----------------------------------------------------");
  console.log("⛏️  MINING POOL AGGREGATE (PoWUoI):");
  console.log(`  • Active Network : ${miningPools.activeNetwork} ($${miningPools.activeQuoteUsdDay}/day est)`);
  console.log(`  • Pools          : ${miningPools.poolsActive}/${miningPools.poolsTotal} active | ${miningPools.workersOnline} workers`);
  for (const p of miningPools.topPools) {
    console.log(`    - ${p.coin.padEnd(5)} ${p.algorithm.padEnd(12)} [${p.status}] workers=${p.workers}`);
  }
  if (miningPools.attribution?.estimatedUsd24h != null) {
    console.log(`  • Treasury Est   : $${miningPools.attribution.estimatedUsd24h} / 24h (50/30/15/5)`);
  }
  console.log("=====================================================");
  console.log(`[frame] ${message.timestamp || new Date().toISOString()}`);
}

ws.on("open", () => {
  console.log("✅ Connected to Trident Protocol Orchestrator Daemon.");
});

ws.on("message", (raw) => {
  try {
    const message = JSON.parse(String(raw));
    if (message.type === "TELEMETRY_UPDATE") {
      renderFrame(message);
    }
  } catch (err) {
    console.error("⚠️  Bad frame:", err.message);
  }
});

ws.on("close", () => {
  console.log("❌ Disconnected from Orchestrator Daemon.");
  process.exit(1);
});

ws.on("error", (err) => {
  console.error("❌ WebSocket error:", err.message);
  console.error("   Start orchestrator: cd yieldswarm-core && npm start");
  process.exit(1);
});
