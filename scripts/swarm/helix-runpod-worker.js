#!/usr/bin/env node
/**
 * Helix RunPod swarm worker — telemetry + LiteLLM/RunPod health loop.
 * One instance per Termux node (SWARM_NODE_ID=1..16).
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "../..");
const MATRIX_PATH =
  process.env.SWARM_MATRIX ||
  path.join(REPO_ROOT, "config/swarm/16-node-matrix.json");

const NODE_ID = Number(process.env.SWARM_NODE_ID || "1");
const TELEMETRY_URL =
  process.env.SWARM_TELEMETRY_URL ||
  process.env.TELEMETRY_URL ||
  "http://127.0.0.1:8080/api/great-delta/telemetry";
const LITELLM_BASE =
  process.env.LITELLM_BASE_URL || "http://127.0.0.1:4000/v1";
const HEARTBEAT_SEC = Number(process.env.SWARM_HEARTBEAT_SEC || "15");
const RUN_DIR = path.join(REPO_ROOT, ".run", "swarm-nodes");

function log(msg) {
  const line = `[swarm-node-${NODE_ID}] ${new Date().toISOString()} ${msg}`;
  console.log(line);
  try {
    fs.mkdirSync(RUN_DIR, { recursive: true });
    fs.appendFileSync(path.join(RUN_DIR, `node-${NODE_ID}.log`), `${line}\n`);
  } catch {
    /* ignore write errors on mobile */
  }
}

function loadNodeConfig() {
  const matrix = JSON.parse(fs.readFileSync(MATRIX_PATH, "utf8"));
  const node = matrix.nodes.find((n) => n.id === NODE_ID);
  if (!node) throw new Error(`No matrix entry for SWARM_NODE_ID=${NODE_ID}`);
  return { matrix, node };
}

async function pingJson(url, options = {}) {
  const started = Date.now();
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), options.timeoutMs ?? 12_000);
  try {
    const res = await fetch(url, {
      ...options,
      signal: ctrl.signal,
      headers: {
        Accept: "application/json",
        ...(options.headers || {}),
      },
    });
    const latencyMs = Date.now() - started;
    return { ok: res.ok, status: res.status, latencyMs };
  } catch (err) {
    return {
      ok: false,
      status: 0,
      latencyMs: Date.now() - started,
      error: err instanceof Error ? err.message : String(err),
    };
  } finally {
    clearTimeout(timer);
  }
}

async function postTelemetry(payload) {
  const started = Date.now();
  try {
    const res = await fetch(TELEMETRY_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(15_000),
    });
    const latencyMs = Date.now() - started;
    if (!res.ok) {
      log(`telemetry HTTP ${res.status} (${latencyMs}ms)`);
      return false;
    }
    log(`telemetry OK (${latencyMs}ms)`);
    return true;
  } catch (err) {
    log(
      `telemetry FAIL: ${err instanceof Error ? err.message : err} — retry after stagger`,
    );
    return false;
  }
}

async function probeRunpodStack(node) {
  const tier = String(node.tier).toUpperCase();
  const vllmVar = `RUNPOD_${tier}_VLLM_URL`;
  const vllmUrl = process.env[vllmVar];
  const results = {};

  if (vllmUrl) {
    const base = vllmUrl.replace(/\/v1\/?$/, "");
    results.vllm = await pingJson(`${base}/health`);
  }

  const routerKey = process.env.YIELDSWARM_ROUTER_API_KEY || "open-metal-local";
  results.litellm = await pingJson(`${LITELLM_BASE}/models`, {
    headers: { Authorization: `Bearer ${routerKey}` },
  });

  if (node.tier === "ollama") {
    const ollama = process.env.LOCAL_OLLAMA_BASE_URL || "http://127.0.0.1:11434";
    results.ollama = await pingJson(`${ollama}/api/tags`);
  }

  return results;
}

async function tick(node) {
  const agentId = `termux-node-${NODE_ID}`;
  const probes = await probeRunpodStack(node);

  const statePath = path.join(RUN_DIR, `node-${NODE_ID}-state.json`);
  const state = {
    nodeId: NODE_ID,
    agentId,
    tier: node.tier,
    model: node.model,
    runpodHost: node.runpod_host,
    role: node.role,
    updatedAt: new Date().toISOString(),
    probes,
    litellmBase: LITELLM_BASE,
  };
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2));

  await postTelemetry({
    event: "swarm-heartbeat",
    source: "termux-runpod",
    agentId,
    sentAt: new Date().toISOString(),
    nodeId: NODE_ID,
    tier: node.tier,
    model: node.model,
    runpodHost: node.runpod_host,
    probes,
  });
}

async function main() {
  const { node } = loadNodeConfig();
  log(
    `online — tier=${node.tier} model=${node.model} host=${node.runpod_host} telemetry=${TELEMETRY_URL}`,
  );

  await tick(node);
  setInterval(() => {
    tick(node).catch((err) => log(`tick error: ${err}`));
  }, HEARTBEAT_SEC * 1000);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
