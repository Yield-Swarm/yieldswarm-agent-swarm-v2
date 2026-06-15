import assert from "node:assert/strict";
import test from "node:test";

import {
  mergeTelemetry,
  normalizeAkashTelemetry,
  normalizeOdysseusTelemetry
} from "../shared/telemetry.js";

test("normalizes Akash worker telemetry from leases and deployments", () => {
  const telemetry = normalizeAkashTelemetry({
    updatedAt: "2026-06-15T05:00:00.000Z",
    leases: [
      {
        dseq: "lease-1",
        provider: "akash-a",
        state: "running",
        gpus: 2,
        cpu: 16,
        memoryGb: 64,
        spendUsd: 120
      }
    ],
    deployments: [
      {
        id: "deployment-2",
        name: "miner-b",
        status: "pending",
        gpuCount: 1,
        cpuCores: 8,
        ramGb: 32,
        monthlyCostUsd: 80
      }
    ]
  });

  assert.equal(telemetry.source, "akash");
  assert.equal(telemetry.totals.workerCount, 2);
  assert.equal(telemetry.totals.activeWorkerCount, 1);
  assert.equal(telemetry.totals.gpuCount, 3);
  assert.equal(telemetry.totals.cpuCores, 24);
  assert.equal(telemetry.totals.memoryGb, 96);
  assert.equal(telemetry.totals.monthlyCostUsd, 200);
});

test("normalizes Odysseus agent and memory telemetry", () => {
  const telemetry = normalizeOdysseusTelemetry({
    agents: [
      {
        id: "research-1",
        role: "deep-research",
        health: "healthy",
        activeResearchRuns: 3,
        memoryWrites: 42
      },
      {
        id: "memory-1",
        status: "syncing",
        researchRuns: 1
      }
    ],
    memory: {
      items: 1200,
      vectors: 5600
    },
    queueDepth: 7,
    completedResearchRuns: 88
  });

  assert.equal(telemetry.source, "odysseus");
  assert.equal(telemetry.totals.agentCount, 2);
  assert.equal(telemetry.totals.activeAgentCount, 1);
  assert.equal(telemetry.totals.activeResearchRuns, 4);
  assert.equal(telemetry.totals.memoryWrites, 42);
  assert.equal(telemetry.totals.memoryItems, 1200);
  assert.equal(telemetry.totals.vectorCount, 5600);
  assert.equal(telemetry.totals.queueDepth, 7);
  assert.equal(telemetry.totals.completedResearchRuns, 88);
});

test("merges Akash and Odysseus telemetry into Arena totals", () => {
  const akash = normalizeAkashTelemetry({
    workers: [{ id: "akash-1", status: "running", gpuCount: 4, cpuCores: 32 }]
  });
  const odysseus = normalizeOdysseusTelemetry({
    agents: [{ id: "agent-1", status: "healthy", activeResearchRuns: 2 }],
    memorySystem: { documents: 50, embeddings: 200 }
  });

  const merged = mergeTelemetry(akash, odysseus);

  assert.equal(merged.health, "healthy");
  assert.equal(merged.totals.activeSystems, 2);
  assert.equal(merged.totals.akashWorkers, 1);
  assert.equal(merged.totals.odysseusAgents, 1);
  assert.equal(merged.totals.gpuCount, 4);
  assert.equal(merged.totals.activeResearchRuns, 2);
  assert.equal(merged.totals.memoryItems, 50);
  assert.equal(merged.totals.vectorCount, 200);
});
