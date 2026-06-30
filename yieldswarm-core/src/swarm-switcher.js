#!/usr/bin/env node
/**
 * Trident Protocol — autonomous swarm profitability switcher.
 * Guards $36k remote H100/H200 fleet; pivots PRL / ETC / ERG mining scripts.
 */
import { exec } from "node:child_process";
import { promisify } from "node:util";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { profitabilitySnapshot, REMOTE_FLEET } from "./lib/trident-state.js";

const execAsync = promisify(exec);
const __dirname = dirname(fileURLToPath(import.meta.url));
const SRC = __dirname;
const POLL_MS = Number(process.env.SWARM_SWITCHER_POLL_MS || 60000);
const DRY_RUN = ["1", "true", "yes"].includes(String(process.env.SWARM_SWITCHER_DRY_RUN || "0").toLowerCase());

const SCRIPT_MAP = {
  PRL: join(SRC, "mine_prl.sh"),
  ETC: join(SRC, "mine_etc.sh"),
  ERG: join(SRC, "mine_erg.sh"),
};

let activeCoin = process.env.SWARM_ACTIVE_COIN || "PRL";

function ts() {
  return new Date().toISOString();
}

function log(msg, data) {
  const line = data ? `${msg} ${JSON.stringify(data)}` : msg;
  console.log(`[${ts()}] [swarm-switcher] ${line}`);
}

async function killStaleMiners() {
  if (DRY_RUN) {
    log("DRY_RUN skip pkill SRBMiner-MULTI");
    return;
  }
  try {
    await execAsync("pkill -f SRBMiner-MULTI || true");
    log("terminated stale SRBMiner-MULTI processes");
  } catch (err) {
    log("pkill note", { message: err.message });
  }
}

async function launchScript(coin) {
  const script = SCRIPT_MAP[coin];
  if (!script) {
    log("ERROR unknown coin", { coin });
    return false;
  }
  log("launching mining script", { coin, script, fleet: REMOTE_FLEET });
  if (DRY_RUN) {
    log("DRY_RUN would exec", { script });
    return true;
  }
  try {
    const { stdout, stderr } = await execAsync(`bash "${script}"`, {
      cwd: SRC,
      env: { ...process.env, MINING_DRY_RUN: "0" },
      timeout: 120000,
    });
    if (stdout) log("script stdout", { tail: stdout.slice(-400) });
    if (stderr) log("script stderr", { tail: stderr.slice(-400) });
    return true;
  } catch (err) {
    log("script failed", { coin, message: err.message });
    return false;
  }
}

async function evaluateAndSwitch() {
  const snap = profitabilitySnapshot();
  const best = snap.best.coin;
  log("profitability poll", {
    ranked: snap.ranked,
    activeCoin,
    fleetCreditUsd: REMOTE_FLEET.creditUsd,
  });

  if (best === activeCoin) {
    log("no pivot required", { activeCoin, bestUsdDay: snap.best.usdDay });
    return;
  }

  log("PIVOT detected", { from: activeCoin, to: best, algorithm: snap.best.algorithm });
  await killStaleMiners();
  const ok = await launchScript(best);
  if (ok) {
    activeCoin = best;
    process.env.SWARM_ACTIVE_COIN = best;
    log("pivot complete", { activeCoin });
  }
}

log("daemon starting", { pollMs: POLL_MS, dryRun: DRY_RUN, initialCoin: activeCoin });
await evaluateAndSwitch();
setInterval(() => {
  evaluateAndSwitch().catch((err) => log("evaluate error", { message: err.message }));
}, POLL_MS);
