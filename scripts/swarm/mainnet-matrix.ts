#!/usr/bin/env npx tsx
/**
 * YieldSwarm mainnet multidimensional mesh matrix — Termux + Azure + RunPod.
 * Run: npm run swarm:mainnet
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { MultidimensionalMeshEngine } from "./lib/meshDriver.ts";
import { RunPodSupercharger } from "./lib/runpodBridge.ts";
import { SwarmSyncNetwork } from "./lib/syncNetwork.ts";
import type { SyncMeta } from "./lib/syncNetwork.ts";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "../..");
const REPORTS_DIR = path.join(REPO_ROOT, "reports");

const STRESS = process.argv.includes("--stress");
const TIMEOUT_MS = Number(
  process.argv.find((a) => a.startsWith("--timeout="))?.split("=")[1] || "5000",
);

function nodeId(): number {
  const raw = process.env.SWARM_NODE_ID || "1";
  const n = Number(raw);
  return Number.isFinite(n) && n >= 1 ? n : 1;
}

function activeNodeList(): string[] {
  const total = Number(process.env.SWARM_TOTAL_NODES || "16");
  return Array.from({ length: total }, (_, i) =>
    `node-${String(i + 1).padStart(2, "0")}`,
  );
}

async function runSwarmMainnetMatrix(): Promise<string> {
  const RUN_ID = Date.now().toString();
  const nid = nodeId();

  console.log("==========================================================");
  console.log(`STARTING SUPERCHARGED TOPOLOGY [ID: ${RUN_ID}] node=${nid}`);
  if (STRESS) console.log(`STRESS MODE timeout=${TIMEOUT_MS}ms`);
  console.log("==========================================================");

  fs.mkdirSync(REPORTS_DIR, { recursive: true });

  const mesh = new MultidimensionalMeshEngine(activeNodeList());
  const supercharger = new RunPodSupercharger();
  const network = new SwarmSyncNetwork();

  network.initializeNetworkGateway(8080);
  network.on("sync_complete", (meta: SyncMeta) => {
    console.log(
      `[PROPAGATION] ${meta.file} → peers [${meta.nodesReached.join(", ")}] ${meta.latencyMs}ms`,
    );
  });

  console.log("Ingesting 35+ dimensional API mesh streams...");
  const rawData = mesh.ingestDimensionalStreams();

  console.log("Triangular + Pentagonal validation rings...");
  const layers = mesh.processGeometricLayers(rawData);
  layers.forEach((l) => console.log(`  [${l.layer}] ${l.status}`));

  console.log("INITIALIZING RUNPOD ACCELERATION...");
  const cloudResult = await Promise.race([
    supercharger.offloadToCloudPods(rawData),
    new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error("RunPod offload timeout")), TIMEOUT_MS),
    ),
  ]);
  console.log(
    `Cloud complete worker=${cloudResult.gpuWorkerId} hash=${cloudResult.acceleratedHash} (${cloudResult.executionTimeMs}ms)`,
  );

  console.log("Alpha-to-Zeta solenoid sequence...");
  mesh.executeSolenoidSequence().forEach((s) => console.log(`  ${s}`));

  const shadowPath = mesh.commitToShadowChain(RUN_ID, REPORTS_DIR);
  console.log(`Shadow chain committed: ${shadowPath}`);

  const reportPath = path.join(REPORTS_DIR, `consensus_run_${RUN_ID}.md`);
  const reportContent = `# Swarm Consensus Report — ${RUN_ID}
* Timestamp: ${new Date().toISOString()}
* Node: termux-node-${nid}
* Pipeline Status: SUCCESS
* RunPod Hash: ${cloudResult.acceleratedHash}
* Framework: Sitemap v1.0 / Helix mainnet matrix
`;
  fs.writeFileSync(reportPath, reportContent);

  await network.broadcastReport(reportPath);

  console.log("==========================================================");
  console.log("STATE MATRICES SYNCHRONIZED ACROSS HYBRID CLUSTER");
  console.log("==========================================================");

  return reportPath;
}

runSwarmMainnetMatrix().catch((err) => {
  console.error("[mainnet-matrix] FAILED:", err instanceof Error ? err.message : err);
  process.exit(1);
});
