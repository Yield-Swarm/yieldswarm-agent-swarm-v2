/**
 * Bridges helical state files + systemState into dashboard-consumable telemetry.
 */
import { createHash } from "node:crypto";
import { readFileSync, existsSync, appendFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { QUANTUM_EQUATION } from "./trident-state.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const CORE_ROOT = join(__dirname, "../..");
const REPO_ROOT = process.env.YIELDSWARM_REPO_ROOT || join(CORE_ROOT, "..");

function readJson(path) {
  if (!existsSync(path)) return null;
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return null;
  }
}

export function loadExternalTelemetry() {
  return {
    miningPools: readJson(join(REPO_ROOT, ".data/mining-pools/latest.json")),
    termuxFleet: readJson(join(REPO_ROOT, ".data/termux-fleet/latest.json")),
    termuxXmrig: readJson(join(REPO_ROOT, ".data/termux-xmrig/latest.json")),
    physicalCore: readJson(join(REPO_ROOT, ".data/physical-core/latest.json")),
  };
}

export function genesisHash(systemState) {
  const seed =
    process.env.GENESIS_HASH ||
    `${QUANTUM_EQUATION}|${systemState?.mining?.yieldswarmNative || "PRL"}|${systemState?.temporal?.iso || ""}`;
  return createHash("sha256").update(seed).digest("hex").slice(0, 16);
}

export function temporalBeacon(temporal) {
  const now = new Date();
  const startOfYear = Date.UTC(now.getUTCFullYear(), 0, 1);
  const dayOfYear = Math.floor((now - startOfYear) / 86400000) + 1;
  const dayProgress = `${Math.min(100, Math.round((dayOfYear / 365) * 100))}%`;
  return {
    week: temporal?.week ?? 0,
    season: temporal?.season ?? "—",
    label: temporal?.label ?? temporal?.contextFlag ?? "—",
    dayProgress,
    dayOfYear,
  };
}

export function mapLocalHardware(systemState, external) {
  const onPrem = systemState?.onPrem || {};
  const asic = onPrem.asic || {};
  const edge = onPrem.edge || {};
  const phoneWall = edge.attVistaWTATTRW2?.count ?? 700;
  const termux = edge.termuxInstances?.count ?? 8;
  const termuxAlive =
    external.termuxFleet?.instances?.filter((i) => i.alive).length ?? 0;

  let status = "standby";
  if (termuxAlive > 0) status = `active:${termuxAlive}/${termux}`;
  if (external.termuxXmrig?.instancesAlive > 0) {
    status = `xmr-mining:${external.termuxXmrig.instancesAlive}/${external.termuxXmrig.instances ?? 8}`;
  }
  if (external.physicalCore?.asics?.aggregateHashrateGh > 0) status = "ranch-asic-live";

  return {
    phoneWallNodes: phoneWall,
    termuxInstances: termux,
    termuxAlive,
    s19Count: asic.antminerS19?.count ?? 0,
    l7Count: asic.antminerL7?.count ?? 0,
    z15Count: asic.z15Fleet?.count ?? 0,
    status,
    physicalCoreHashrateGh: external.physicalCore?.asics?.aggregateHashrateGh ?? 0,
    xmrigHashrateKhps: external.termuxXmrig?.hashrateTotalKhps ?? 0,
    xmrigInstancesAlive: external.termuxXmrig?.instancesAlive ?? 0,
  };
}

export function mapCloudPrices(cloud) {
  const p = cloud?.normalizedUsdPerGpuHour || {};
  return {
    runpod: Number(p.runpod ?? 0).toFixed(2),
    akash: Number(p.akash ?? 0).toFixed(2),
    vast: Number(p.vast ?? 0).toFixed(2),
    vultr: Number(p.vultr ?? 0).toFixed(2),
    fleetCreditUsd: cloud?.fleetCreditRemainingUsd ?? 0,
  };
}

export function aggregateMiningPools(systemState, external) {
  const pools = external.miningPools?.pools || [];
  const switcher = external.miningPools?.switcher || systemState?.mining?.profitability;
  const active = pools.filter((p) => p.status === "active");
  const totalWorkers = pools.reduce((n, p) => n + (p.workersOnline || 0), 0);
  const top = [...pools].sort((a, b) => (b.hashrate || 0) - (a.hashrate || 0)).slice(0, 6);

  return {
    ecosystem: external.miningPools?.ecosystem || "PoWUoI",
    yieldswarmCoin: external.miningPools?.yieldswarmCoin || systemState?.mining?.yieldswarmNative || "PRL",
    activeNetwork: external.miningPools?.switcher?.activeNetwork || systemState?.mining?.activeCoin || "—",
    activeQuoteUsdDay: external.miningPools?.switcher?.activeQuoteUsdDay ?? switcher?.best?.usdDay ?? 0,
    poolsTotal: pools.length,
    poolsActive: active.length,
    workersOnline: totalWorkers,
    topPools: top.map((p) => ({
      coin: p.coin,
      status: p.status,
      algorithm: p.algorithm,
      workers: p.workersOnline,
    })),
    attribution: external.miningPools?.attribution || null,
  };
}

export function aggregateTermuxXmrig(external) {
  const x = external.termuxXmrig;
  if (!x) {
    return { mining: false, instancesAlive: 0, hashrateTotalKhps: 0, hashrateTotalHps: 0 };
  }
  return {
    mining: (x.instancesAlive ?? 0) > 0,
    instances: x.instances ?? 8,
    instancesAlive: x.instancesAlive ?? 0,
    hashrateTotalHps: x.hashrateTotalHps ?? 0,
    hashrateTotalKhps: x.hashrateTotalKhps ?? 0,
    workers: (x.workers || []).filter((w) => w.alive).map((w) => ({
      instance: w.instance,
      worker: w.worker,
      hashrateHps: w.hashrateHps,
    })),
    capturedAt: x.capturedAt,
  };
}

export function buildTelemetryView(systemState, external = loadExternalTelemetry()) {
  return {
    genesisHash: genesisHash(systemState),
    quantumEquation: QUANTUM_EQUATION,
    temporalBeacon: temporalBeacon(systemState?.temporal),
    cloudPrices: mapCloudPrices(systemState?.cloud),
    localHardware: mapLocalHardware(systemState, external),
    miningPools: aggregateMiningPools(systemState, external),
    termuxXmrig: aggregateTermuxXmrig(external),
    remoteFleet: {
      creditUsd: systemState?.remoteFleet?.creditUsd ?? 0,
      h100: systemState?.remoteFleet?.gpus?.h100?.count ?? 0,
      h200: systemState?.remoteFleet?.gpus?.h200?.count ?? 0,
    },
  };
}

let _lastHardwareSig = "";

export function logHardwareDelta(view, logPath) {
  const hw = view.localHardware;
  const sig = JSON.stringify(hw);
  if (sig === _lastHardwareSig) return;
  _lastHardwareSig = sig;
  const dir = dirname(logPath);
  mkdirSync(dir, { recursive: true });
  const line = `${new Date().toISOString()} HARDWARE_UPDATE ${sig}\n`;
  appendFileSync(logPath, line, "utf8");
}
