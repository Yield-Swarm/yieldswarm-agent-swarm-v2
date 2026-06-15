import { resolveConfig } from "./config.js";
import { createAuthHeaders } from "./auth.js";

function asArray(value) {
  if (!value) {
    return [];
  }

  return Array.isArray(value) ? value : [value];
}

function numberValue(value, fallback = 0) {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : fallback;
}

function firstDefined(...values) {
  return values.find((value) => value !== undefined && value !== null);
}

function normalizeStatus(status) {
  const normalized = String(status ?? "unknown").toLowerCase();
  if (["running", "active", "healthy", "online", "ready", "synced"].includes(normalized)) {
    return "healthy";
  }
  if (["warning", "degraded", "pending", "syncing", "queued"].includes(normalized)) {
    return "degraded";
  }
  if (["failed", "error", "offline", "halted", "critical"].includes(normalized)) {
    return "critical";
  }
  return normalized;
}

function collectAkashWorkers(payload = {}) {
  if (Array.isArray(payload)) {
    return payload;
  }

  return [
    ...asArray(payload.workers),
    ...asArray(payload.leases),
    ...asArray(payload.deployments),
    ...asArray(payload.nodes)
  ];
}

export function normalizeAkashTelemetry(payload = {}) {
  const workers = collectAkashWorkers(payload).map((worker, index) => ({
    id: String(firstDefined(worker.id, worker.dseq, worker.name, `akash-${index + 1}`)),
    name: String(firstDefined(worker.name, worker.provider, worker.id, `Akash worker ${index + 1}`)),
    status: normalizeStatus(firstDefined(worker.status, worker.state, worker.health)),
    gpuCount: numberValue(firstDefined(worker.gpuCount, worker.gpus, worker.gpu), 0),
    cpuCores: numberValue(firstDefined(worker.cpuCores, worker.cpu, worker.vcpu), 0),
    memoryGb: numberValue(firstDefined(worker.memoryGb, worker.memory, worker.ramGb), 0),
    monthlyCostUsd: numberValue(firstDefined(worker.monthlyCostUsd, worker.costUsd, worker.spendUsd), 0),
    throughput: numberValue(firstDefined(worker.throughput, worker.hashrate, worker.jobsPerMinute), 0),
    updatedAt: firstDefined(worker.updatedAt, worker.lastSeenAt, payload.updatedAt)
  }));

  const totals = workers.reduce(
    (accumulator, worker) => {
      accumulator.workerCount += 1;
      accumulator.activeWorkerCount += worker.status === "healthy" ? 1 : 0;
      accumulator.gpuCount += worker.gpuCount;
      accumulator.cpuCores += worker.cpuCores;
      accumulator.memoryGb += worker.memoryGb;
      accumulator.monthlyCostUsd += worker.monthlyCostUsd;
      accumulator.throughput += worker.throughput;
      return accumulator;
    },
    {
      workerCount: 0,
      activeWorkerCount: 0,
      gpuCount: 0,
      cpuCores: 0,
      memoryGb: 0,
      monthlyCostUsd: 0,
      throughput: 0
    }
  );

  return {
    source: "akash",
    status: normalizeStatus(firstDefined(payload.status, payload.health, totals.workerCount ? "active" : "unknown")),
    updatedAt: firstDefined(payload.updatedAt, payload.timestamp, new Date().toISOString()),
    workers,
    totals,
    alerts: asArray(payload.alerts)
  };
}

function collectOdysseusAgents(payload = {}) {
  if (Array.isArray(payload)) {
    return payload;
  }

  return [
    ...asArray(payload.agents),
    ...asArray(payload.researchAgents),
    ...asArray(payload.workers)
  ];
}

export function normalizeOdysseusTelemetry(payload = {}) {
  const memory = payload.memory ?? payload.memorySystem ?? {};
  const agents = collectOdysseusAgents(payload).map((agent, index) => ({
    id: String(firstDefined(agent.id, agent.name, `odysseus-${index + 1}`)),
    name: String(firstDefined(agent.name, agent.role, agent.id, `Odysseus agent ${index + 1}`)),
    status: normalizeStatus(firstDefined(agent.status, agent.state, agent.health)),
    activeResearchRuns: numberValue(firstDefined(agent.activeResearchRuns, agent.researchRuns, agent.tasks), 0),
    memoryWrites: numberValue(firstDefined(agent.memoryWrites, agent.memoriesWritten), 0),
    updatedAt: firstDefined(agent.updatedAt, agent.lastSeenAt, payload.updatedAt)
  }));

  const explicitMemories = asArray(payload.memories).length;
  const memoryItems = numberValue(
    firstDefined(memory.items, memory.memories, memory.documents, payload.memoryItems, explicitMemories),
    explicitMemories
  );
  const vectorCount = numberValue(firstDefined(memory.vectors, memory.embeddings, payload.vectorCount), 0);
  const queueDepth = numberValue(firstDefined(payload.queueDepth, payload.pendingTasks, memory.queueDepth), 0);
  const completedResearchRuns = numberValue(firstDefined(payload.completedResearchRuns, payload.researchRuns), 0);

  const totals = agents.reduce(
    (accumulator, agent) => {
      accumulator.agentCount += 1;
      accumulator.activeAgentCount += agent.status === "healthy" ? 1 : 0;
      accumulator.activeResearchRuns += agent.activeResearchRuns;
      accumulator.memoryWrites += agent.memoryWrites;
      return accumulator;
    },
    {
      agentCount: 0,
      activeAgentCount: 0,
      activeResearchRuns: 0,
      memoryWrites: 0,
      memoryItems,
      vectorCount,
      queueDepth,
      completedResearchRuns
    }
  );

  return {
    source: "odysseus",
    status: normalizeStatus(firstDefined(payload.status, payload.health, totals.agentCount ? "active" : "unknown")),
    updatedAt: firstDefined(payload.updatedAt, payload.timestamp, new Date().toISOString()),
    agents,
    memory,
    totals,
    alerts: asArray(payload.alerts)
  };
}

export function mergeTelemetry(akash, odysseus) {
  const alerts = [
    ...asArray(akash?.alerts).map((alert) => ({ source: "Akash", message: String(alert) })),
    ...asArray(odysseus?.alerts).map((alert) => ({ source: "Odysseus", message: String(alert) }))
  ];
  const criticalSources = [akash, odysseus].filter((source) => source?.status === "critical").length;
  const degradedSources = [akash, odysseus].filter((source) => source?.status === "degraded").length;
  const health = criticalSources ? "critical" : degradedSources ? "degraded" : "healthy";

  return {
    updatedAt: new Date().toISOString(),
    health,
    sources: {
      akash,
      odysseus
    },
    totals: {
      activeSystems: numberValue(akash?.totals?.activeWorkerCount) + numberValue(odysseus?.totals?.activeAgentCount),
      akashWorkers: numberValue(akash?.totals?.workerCount),
      odysseusAgents: numberValue(odysseus?.totals?.agentCount),
      gpuCount: numberValue(akash?.totals?.gpuCount),
      cpuCores: numberValue(akash?.totals?.cpuCores),
      monthlyCostUsd: numberValue(akash?.totals?.monthlyCostUsd),
      activeResearchRuns: numberValue(odysseus?.totals?.activeResearchRuns),
      completedResearchRuns: numberValue(odysseus?.totals?.completedResearchRuns),
      memoryItems: numberValue(odysseus?.totals?.memoryItems),
      vectorCount: numberValue(odysseus?.totals?.vectorCount),
      queueDepth: numberValue(odysseus?.totals?.queueDepth)
    },
    lanes: [
      {
        name: "Akash compute",
        status: akash?.status ?? "unknown",
        primaryMetric: `${numberValue(akash?.totals?.activeWorkerCount)} / ${numberValue(akash?.totals?.workerCount)} active`,
        secondaryMetric: `${numberValue(akash?.totals?.gpuCount)} GPUs, ${numberValue(akash?.totals?.cpuCores)} CPU cores`
      },
      {
        name: "Odysseus agents",
        status: odysseus?.status ?? "unknown",
        primaryMetric: `${numberValue(odysseus?.totals?.activeAgentCount)} / ${numberValue(odysseus?.totals?.agentCount)} active`,
        secondaryMetric: `${numberValue(odysseus?.totals?.activeResearchRuns)} active research runs`
      },
      {
        name: "Odysseus memory",
        status: numberValue(odysseus?.totals?.queueDepth) > 0 ? "degraded" : odysseus?.status ?? "unknown",
        primaryMetric: `${numberValue(odysseus?.totals?.memoryItems)} memories`,
        secondaryMetric: `${numberValue(odysseus?.totals?.vectorCount)} vectors, ${numberValue(odysseus?.totals?.queueDepth)} queued`
      }
    ],
    alerts
  };
}

async function fetchJson(url, options = {}) {
  const {
    fetchFn = typeof fetch === "undefined" ? undefined : fetch,
    timeoutMs = 10000,
    session
  } = options;

  if (typeof fetchFn !== "function") {
    throw new Error("A fetch implementation is required to load telemetry.");
  }

  const controller = typeof AbortController === "undefined" ? undefined : new AbortController();
  const timeout = controller ? setTimeout(() => controller.abort(), timeoutMs) : undefined;

  try {
    const response = await fetchFn(url, {
      credentials: "include",
      signal: controller?.signal,
      headers: {
        Accept: "application/json",
        ...createAuthHeaders(session)
      }
    });

    if (!response.ok) {
      throw new Error(`Telemetry request failed with status ${response.status}.`);
    }

    return response.json();
  } finally {
    if (timeout) {
      clearTimeout(timeout);
    }
  }
}

export async function loadUnifiedTelemetry(options = {}) {
  const {
    config: configOverrides = {},
    fetchFn = typeof fetch === "undefined" ? undefined : fetch,
    session,
    globalRef = typeof window === "undefined" ? undefined : window
  } = options;
  const config = resolveConfig(configOverrides, globalRef);
  const common = { fetchFn, timeoutMs: config.requestTimeoutMs, session };

  const [akashResult, odysseusResult] = await Promise.allSettled([
    fetchJson(config.akashTelemetryUrl, common),
    fetchJson(config.odysseusTelemetryUrl, common)
  ]);

  const akash =
    akashResult.status === "fulfilled"
      ? normalizeAkashTelemetry(akashResult.value)
      : normalizeAkashTelemetry({
          status: "critical",
          alerts: [`Akash telemetry unavailable: ${akashResult.reason.message}`]
        });
  const odysseus =
    odysseusResult.status === "fulfilled"
      ? normalizeOdysseusTelemetry(odysseusResult.value)
      : normalizeOdysseusTelemetry({
          status: "critical",
          alerts: [`Odysseus telemetry unavailable: ${odysseusResult.reason.message}`]
        });

  return mergeTelemetry(akash, odysseus);
}
