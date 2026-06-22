"use client";

import { useEffect, useMemo, useRef, useState } from "react";

type WorkerLease = {
  leaseId: string;
  workerUrl: string;
};

type WorkerTelemetry = {
  leaseId: string;
  workerUrl: string;
  online: boolean;
  vramUsedBytes: number | null;
  vramTotalBytes: number | null;
  temperatureC: number | null;
  agentCount: number | null;
  loadedModels: string[];
  lastSeenAt: number | null;
  error: string | null;
};

type TreasuryTelemetry = {
  velocityUsdPerHour: number | null;
  source: string;
  error: string | null;
};

type DashboardStatus = "connecting" | "live" | "reconnecting" | "error";

type DashboardState = {
  status: DashboardStatus;
  leases: WorkerLease[];
  workers: WorkerTelemetry[];
  treasury: TreasuryTelemetry | null;
  lastUpdatedAt: number | null;
  reconnectAttempt: number;
  nextRetryAt: number | null;
  globalError: string | null;
};

const LEASES_ENDPOINT = process.env.NEXT_PUBLIC_AKASH_LEASES_URL ?? "";
const TREASURY_ENDPOINT = process.env.NEXT_PUBLIC_TREASURY_VELOCITY_URL ?? "";

const TARGET_MODELS = ["llama3.1:8b", "qwen2.5:7b"];
const POLL_INTERVAL_MS = 10_000;
const REQUEST_TIMEOUT_MS = 5_500;
const RECONNECT_BASE_MS = 2_000;
const RECONNECT_MAX_MS = 30_000;

const initialState: DashboardState = {
  status: "connecting",
  leases: [],
  workers: [],
  treasury: null,
  lastUpdatedAt: null,
  reconnectAttempt: 0,
  nextRetryAt: null,
  globalError: null,
};

const numberFormatter = new Intl.NumberFormat("en-US", { maximumFractionDigits: 1 });
const compactNumberFormatter = new Intl.NumberFormat("en-US", {
  notation: "compact",
  maximumFractionDigits: 1,
});
const currencyFormatter = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  maximumFractionDigits: 2,
});

function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function normalizeWorkerBase(raw: string): string | null {
  if (!raw) return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;

  const withProtocol = /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;

  try {
    const parsed = new URL(withProtocol);
    if (!parsed.hostname) return null;
    return `${parsed.protocol}//${parsed.host}${parsed.pathname.replace(/\/$/, "")}`;
  } catch {
    return null;
  }
}

function joinUrl(base: string, suffix: string): string {
  const safeBase = base.endsWith("/") ? base : `${base}/`;
  return new URL(suffix, safeBase).toString();
}

function toNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

function shorten(value: string, max = 30): string {
  if (value.length <= max) return value;
  return `${value.slice(0, Math.floor(max / 2) - 1)}…${value.slice(-(Math.floor(max / 2) - 1))}`;
}

async function fetchWithTimeout(input: string): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    return await fetch(input, { cache: "no-store", signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}

async function fetchJson<T = unknown>(input: string): Promise<T> {
  const response = await fetchWithTimeout(input);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} from ${input}`);
  }
  return (await response.json()) as T;
}

async function fetchText(input: string): Promise<string> {
  const response = await fetchWithTimeout(input);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} from ${input}`);
  }
  return response.text();
}

function parsePrometheusSeries(metricsText: string, metricName: string): number[] {
  const pattern = new RegExp(
    `^${escapeRegex(metricName)}(?:\\{[^\\n]*\\})?\\s+(-?\\d+(?:\\.\\d+)?)\\s*$`,
    "gm",
  );

  const values: number[] = [];
  let match: RegExpExecArray | null = pattern.exec(metricsText);
  while (match) {
    const numeric = Number(match[1]);
    if (Number.isFinite(numeric)) values.push(numeric);
    match = pattern.exec(metricsText);
  }
  return values;
}

function firstNonEmptySeries(metricsText: string, names: string[]): number[] {
  for (const name of names) {
    const values = parsePrometheusSeries(metricsText, name);
    if (values.length > 0) return values;
  }
  return [];
}

function getVramBytes(metricsText: string): { usedBytes: number | null; totalBytes: number | null } {
  const usedBytesSeries = firstNonEmptySeries(metricsText, [
    "nvidia_smi_fb_memory_used_bytes",
    "gpu_memory_used_bytes",
  ]);
  const totalBytesSeries = firstNonEmptySeries(metricsText, [
    "nvidia_smi_fb_memory_total_bytes",
    "gpu_memory_total_bytes",
  ]);

  if (usedBytesSeries.length > 0 || totalBytesSeries.length > 0) {
    return {
      usedBytes: usedBytesSeries.length > 0 ? usedBytesSeries.reduce((a, b) => a + b, 0) : null,
      totalBytes: totalBytesSeries.length > 0 ? totalBytesSeries.reduce((a, b) => a + b, 0) : null,
    };
  }

  // DCGM often emits FB memory in MiB.
  const dcgmUsed = firstNonEmptySeries(metricsText, ["DCGM_FI_DEV_FB_USED"]);
  const dcgmTotal = firstNonEmptySeries(metricsText, ["DCGM_FI_DEV_FB_TOTAL"]);
  return {
    usedBytes: dcgmUsed.length > 0 ? dcgmUsed.reduce((a, b) => a + b, 0) * 1024 * 1024 : null,
    totalBytes: dcgmTotal.length > 0 ? dcgmTotal.reduce((a, b) => a + b, 0) * 1024 * 1024 : null,
  };
}

function getTemperatureC(metricsText: string): number | null {
  const values = firstNonEmptySeries(metricsText, [
    "DCGM_FI_DEV_GPU_TEMP",
    "nvidia_smi_temperature_gpu",
    "gpu_temperature_celsius",
  ]);
  if (values.length === 0) return null;
  return Math.max(...values);
}

function getAgentCountFromMetrics(metricsText: string): number | null {
  const values = firstNonEmptySeries(metricsText, [
    "openclaw_agents_active",
    "agent_count",
    "agents_active",
  ]);
  if (values.length === 0) return null;
  return Math.round(values.reduce((a, b) => a + b, 0));
}

function readPath(object: unknown, keys: string[]): unknown {
  let cursor: unknown = object;
  for (const key of keys) {
    if (!cursor || typeof cursor !== "object" || !(key in cursor)) {
      return undefined;
    }
    cursor = (cursor as Record<string, unknown>)[key];
  }
  return cursor;
}

function extractAgentCount(payload: unknown): number | null {
  if (!payload || typeof payload !== "object") return null;
  const object = payload as Record<string, unknown>;

  const direct = [
    object.agentCount,
    object.activeAgentCount,
    object.active_agents,
    object.count,
    readPath(object, ["data", "count"]),
    readPath(object, ["stats", "agents", "active"]),
  ];
  for (const candidate of direct) {
    const numeric = toNumber(candidate);
    if (numeric !== null) return Math.round(numeric);
  }

  if (Array.isArray(object.agents)) return object.agents.length;
  if (Array.isArray(object.data)) return object.data.length;

  return null;
}

function extractModelNames(payload: unknown): string[] {
  if (!payload || typeof payload !== "object") return [];
  const object = payload as Record<string, unknown>;

  const modelEntries = Array.isArray(object.models)
    ? object.models
    : Array.isArray(object.data)
      ? object.data
      : [];

  const names: string[] = [];
  for (const entry of modelEntries) {
    if (!entry || typeof entry !== "object") continue;
    const model = entry as Record<string, unknown>;
    const candidate = model.name ?? model.model ?? model.id;
    if (typeof candidate === "string" && candidate.trim()) {
      names.push(candidate.trim().toLowerCase());
    }
  }
  return names;
}

function modelLoaded(modelName: string, activeModels: string[]): boolean {
  const normalized = modelName.toLowerCase();
  return activeModels.some((active) => active === normalized || active.startsWith(`${normalized}:`) || active.includes(normalized));
}

function computeBackoffDelayMs(attempt: number): number {
  const exponential = RECONNECT_BASE_MS * 2 ** Math.max(0, attempt - 1);
  return Math.min(RECONNECT_MAX_MS, exponential);
}

function asLeaseArray(payload: unknown): unknown[] {
  if (Array.isArray(payload)) return payload;
  if (!payload || typeof payload !== "object") return [];

  const object = payload as Record<string, unknown>;
  if (Array.isArray(object.leases)) return object.leases;
  if (Array.isArray(object.data)) return object.data;
  if (Array.isArray(readPath(object, ["data", "leases"]))) return readPath(object, ["data", "leases"]) as unknown[];
  if (Array.isArray(readPath(object, ["result", "leases"]))) return readPath(object, ["result", "leases"]) as unknown[];
  return [];
}

function extractLeaseId(entry: Record<string, unknown>, index: number): string {
  const candidates = [
    entry.leaseId,
    entry.id,
    readPath(entry, ["lease", "id"]),
    readPath(entry, ["lease_id"]),
    readPath(entry, ["lease_id", "dseq"]),
    readPath(entry, ["dseq"]),
  ];

  for (const candidate of candidates) {
    if (candidate === undefined || candidate === null) continue;
    if (typeof candidate === "string" && candidate.trim()) return candidate.trim();
    if (typeof candidate === "number" && Number.isFinite(candidate)) return String(candidate);
  }
  return `lease-${index + 1}`;
}

function extractWorkerUrlsFromLease(entry: Record<string, unknown>): string[] {
  const urls = new Set<string>();
  const hints = ["worker", "url", "uri", "endpoint", "service", "host"];

  const walk = (value: unknown, keyHint = ""): void => {
    if (value === null || value === undefined) return;

    if (typeof value === "string") {
      const looksLikeUrl = /^https?:\/\//i.test(value) || /^[a-z0-9.-]+(:\d+)?(\/.*)?$/i.test(value);
      const hasHint = hints.some((hint) => keyHint.toLowerCase().includes(hint));
      if (looksLikeUrl && hasHint) {
        const normalized = normalizeWorkerBase(value);
        if (normalized) urls.add(normalized);
      }
      return;
    }

    if (Array.isArray(value)) {
      for (const nested of value) walk(nested, keyHint);
      return;
    }

    if (typeof value !== "object") return;
    const object = value as Record<string, unknown>;

    const host = object.host ?? object.hostname ?? object.ip;
    const port = object.port;
    if (typeof host === "string" && (typeof port === "number" || typeof port === "string")) {
      const normalized = normalizeWorkerBase(`${host}:${port}`);
      if (normalized) urls.add(normalized);
    }

    for (const [key, nested] of Object.entries(object)) {
      walk(nested, key);
    }
  };

  walk(entry);
  return Array.from(urls);
}

async function fetchWorkerLeases(endpoint: string): Promise<WorkerLease[]> {
  if (!endpoint) {
    throw new Error("Missing NEXT_PUBLIC_AKASH_LEASES_URL.");
  }

  const payload = await fetchJson<unknown>(endpoint);
  const leases = asLeaseArray(payload);

  const workers: WorkerLease[] = [];
  leases.forEach((leaseEntry, index) => {
    if (!leaseEntry || typeof leaseEntry !== "object") return;
    const entry = leaseEntry as Record<string, unknown>;
    const leaseId = extractLeaseId(entry, index);
    const urls = extractWorkerUrlsFromLease(entry);
    urls.forEach((workerUrl) => workers.push({ leaseId, workerUrl }));
  });

  const deduped = new Map<string, WorkerLease>();
  workers.forEach((worker) => {
    const key = `${worker.leaseId}::${worker.workerUrl}`;
    if (!deduped.has(key)) deduped.set(key, worker);
  });

  const uniqueWorkers = Array.from(deduped.values());
  if (uniqueWorkers.length === 0) {
    throw new Error("No worker URLs found in lease payload.");
  }
  return uniqueWorkers;
}

async function fetchAgentCountFromApi(workerUrl: string): Promise<number | null> {
  const endpoints = ["api/agents", "agents", "api/v1/agents"];
  for (const suffix of endpoints) {
    try {
      const payload = await fetchJson<unknown>(joinUrl(workerUrl, suffix));
      const count = extractAgentCount(payload);
      if (count !== null) return count;
    } catch {
      // Try next endpoint; many workers expose only one of these paths.
    }
  }
  return null;
}

async function pollWorker(worker: WorkerLease): Promise<WorkerTelemetry> {
  const [metricsResult, modelsResult, agentsResult] = await Promise.allSettled([
    fetchText(joinUrl(worker.workerUrl, "metrics")),
    fetchJson<unknown>(joinUrl(worker.workerUrl, "api/ps")),
    fetchAgentCountFromApi(worker.workerUrl),
  ]);

  if (metricsResult.status === "rejected" && modelsResult.status === "rejected" && agentsResult.status === "rejected") {
    return {
      leaseId: worker.leaseId,
      workerUrl: worker.workerUrl,
      online: false,
      vramUsedBytes: null,
      vramTotalBytes: null,
      temperatureC: null,
      agentCount: null,
      loadedModels: [],
      lastSeenAt: null,
      error: "Worker endpoints unreachable",
    };
  }

  const metricsText = metricsResult.status === "fulfilled" ? metricsResult.value : "";
  const modelPayload = modelsResult.status === "fulfilled" ? modelsResult.value : null;
  const apiAgentCount = agentsResult.status === "fulfilled" ? agentsResult.value : null;

  const vram = metricsText ? getVramBytes(metricsText) : { usedBytes: null, totalBytes: null };
  const metricAgentCount = metricsText ? getAgentCountFromMetrics(metricsText) : null;

  return {
    leaseId: worker.leaseId,
    workerUrl: worker.workerUrl,
    online: true,
    vramUsedBytes: vram.usedBytes,
    vramTotalBytes: vram.totalBytes,
    temperatureC: metricsText ? getTemperatureC(metricsText) : null,
    agentCount: metricAgentCount ?? apiAgentCount ?? null,
    loadedModels: modelPayload ? extractModelNames(modelPayload) : [],
    lastSeenAt: Date.now(),
    error: null,
  };
}

function extractTreasuryVelocity(payload: unknown): number | null {
  if (!payload || typeof payload !== "object") return null;
  const object = payload as Record<string, unknown>;

  const directPaths = [
    ["velocityUsdPerHour"],
    ["treasuryVelocityUsdPerHour"],
    ["velocity_per_hour_usd"],
    ["velocity"],
    ["data", "velocityUsdPerHour"],
    ["data", "treasuryVelocityUsdPerHour"],
    ["stats", "velocityUsdPerHour"],
  ];

  for (const path of directPaths) {
    const numeric = toNumber(readPath(object, path));
    if (numeric !== null) return numeric;
  }

  const current = toNumber(object.currentBalanceUsd ?? readPath(object, ["data", "currentBalanceUsd"]));
  const previous24h = toNumber(object.balanceUsd24hAgo ?? readPath(object, ["data", "balanceUsd24hAgo"]));
  if (current !== null && previous24h !== null) {
    return (current - previous24h) / 24;
  }

  const pointsRaw = readPath(object, ["points"]) ?? readPath(object, ["data", "points"]);
  if (Array.isArray(pointsRaw) && pointsRaw.length >= 2) {
    const first = pointsRaw[0];
    const last = pointsRaw[pointsRaw.length - 1];
    if (first && last && typeof first === "object" && typeof last === "object") {
      const firstObj = first as Record<string, unknown>;
      const lastObj = last as Record<string, unknown>;
      const firstBalance = toNumber(firstObj.balanceUsd ?? firstObj.balance ?? firstObj.value);
      const lastBalance = toNumber(lastObj.balanceUsd ?? lastObj.balance ?? lastObj.value);
      const firstTimestamp = toNumber(firstObj.timestamp ?? firstObj.ts ?? firstObj.time);
      const lastTimestamp = toNumber(lastObj.timestamp ?? lastObj.ts ?? lastObj.time);

      if (
        firstBalance !== null &&
        lastBalance !== null &&
        firstTimestamp !== null &&
        lastTimestamp !== null &&
        lastTimestamp > firstTimestamp
      ) {
        const deltaHours = (lastTimestamp - firstTimestamp) / 3_600_000;
        if (deltaHours > 0) return (lastBalance - firstBalance) / deltaHours;
      }
    }
  }

  return null;
}

async function fetchTreasuryVelocity(endpoint: string): Promise<TreasuryTelemetry> {
  if (!endpoint) {
    return {
      velocityUsdPerHour: null,
      source: "NEXT_PUBLIC_TREASURY_VELOCITY_URL",
      error: "Treasury endpoint not configured",
    };
  }

  try {
    const payload = await fetchJson<unknown>(endpoint);
    return {
      velocityUsdPerHour: extractTreasuryVelocity(payload),
      source: endpoint,
      error: null,
    };
  } catch (error) {
    return {
      velocityUsdPerHour: null,
      source: endpoint,
      error: error instanceof Error ? error.message : "Failed to fetch treasury velocity",
    };
  }
}

function formatBytesToGiB(value: number | null): string {
  if (value === null) return "—";
  const gib = value / (1024 ** 3);
  return `${numberFormatter.format(gib)} GiB`;
}

function formatTemperature(value: number | null): string {
  if (value === null) return "—";
  return `${numberFormatter.format(value)}°C`;
}

function formatPercent(value: number | null): string {
  if (value === null) return "—";
  return `${numberFormatter.format(value)}%`;
}

function statusTone(status: DashboardStatus): string {
  switch (status) {
    case "live":
      return "bg-emerald-500/15 text-emerald-200 border-emerald-400/40";
    case "reconnecting":
      return "bg-amber-500/15 text-amber-200 border-amber-400/40";
    case "error":
      return "bg-rose-500/15 text-rose-200 border-rose-400/40";
    default:
      return "bg-sky-500/15 text-sky-200 border-sky-400/40";
  }
}

export default function ArenaPage(): JSX.Element {
  const [state, setState] = useState<DashboardState>(initialState);
  const [clock, setClock] = useState<number>(Date.now());
  const timerRef = useRef<number | null>(null);

  useEffect(() => {
    const id = window.setInterval(() => setClock(Date.now()), 1_000);
    return () => window.clearInterval(id);
  }, []);

  useEffect(() => {
    let active = true;

    const clearExistingTimer = (): void => {
      if (timerRef.current !== null) {
        window.clearTimeout(timerRef.current);
        timerRef.current = null;
      }
    };

    const scheduleNext = (delayMs: number): void => {
      clearExistingTimer();
      timerRef.current = window.setTimeout(() => {
        void runPoll();
      }, delayMs);
    };

    const runPoll = async (): Promise<void> => {
      if (!active) return;

      setState((previous) => ({
        ...previous,
        status: previous.lastUpdatedAt ? "reconnecting" : "connecting",
        globalError: null,
      }));

      try {
        const leases = await fetchWorkerLeases(LEASES_ENDPOINT);
        const workers = await Promise.all(leases.map((lease) => pollWorker(lease)));
        const treasury = await fetchTreasuryVelocity(TREASURY_ENDPOINT);

        if (!active) return;

        const anyOnline = workers.some((worker) => worker.online);
        const hasTreasuryError = Boolean(treasury.error);

        setState({
          status: anyOnline ? "live" : "error",
          leases,
          workers,
          treasury,
          lastUpdatedAt: Date.now(),
          reconnectAttempt: 0,
          nextRetryAt: null,
          globalError: anyOnline
            ? hasTreasuryError
              ? `Treasury telemetry degraded: ${treasury.error}`
              : null
            : "All workers are offline or unreachable.",
        });

        scheduleNext(POLL_INTERVAL_MS);
      } catch (error) {
        if (!active) return;
        const message = error instanceof Error ? error.message : "Polling failed";

        setState((previous) => {
          const attempt = previous.reconnectAttempt + 1;
          const delay = computeBackoffDelayMs(attempt);
          scheduleNext(delay);

          return {
            ...previous,
            status: attempt >= 3 ? "error" : "reconnecting",
            reconnectAttempt: attempt,
            nextRetryAt: Date.now() + delay,
            globalError: message,
          };
        });
      }
    };

    void runPoll();

    return () => {
      active = false;
      clearExistingTimer();
    };
  }, []);

  const onlineWorkers = useMemo(
    () => state.workers.filter((worker) => worker.online).length,
    [state.workers],
  );

  const aggregate = useMemo(() => {
    const validVramWorkers = state.workers.filter(
      (worker) => worker.vramUsedBytes !== null && worker.vramTotalBytes !== null && (worker.vramTotalBytes ?? 0) > 0,
    );
    const vramUsed = validVramWorkers.reduce((sum, worker) => sum + (worker.vramUsedBytes ?? 0), 0);
    const vramTotal = validVramWorkers.reduce((sum, worker) => sum + (worker.vramTotalBytes ?? 0), 0);
    const vramPercent = vramTotal > 0 ? (vramUsed / vramTotal) * 100 : null;

    const tempValues = state.workers
      .map((worker) => worker.temperatureC)
      .filter((value): value is number => value !== null);
    const avgTemp = tempValues.length > 0 ? tempValues.reduce((a, b) => a + b, 0) / tempValues.length : null;

    const activeAgents = state.workers
      .map((worker) => worker.agentCount ?? 0)
      .reduce((sum, value) => sum + value, 0);

    return { vramUsed, vramTotal, vramPercent, avgTemp, activeAgents };
  }, [state.workers]);

  const nextRetrySeconds = useMemo(() => {
    if (!state.nextRetryAt) return null;
    return Math.max(0, Math.ceil((state.nextRetryAt - clock) / 1_000));
  }, [clock, state.nextRetryAt]);

  return (
    <main className="min-h-screen bg-[#04070f] text-slate-100">
      <div className="mx-auto w-full max-w-7xl px-6 py-10">
        <header className="mb-8 rounded-2xl border border-cyan-400/30 bg-gradient-to-br from-[#0a1322] via-[#0b172b] to-[#0b1f1e] p-6 shadow-[0_0_40px_rgba(56,189,248,0.12)]">
          <div className="mb-3 text-xs uppercase tracking-[0.28em] text-cyan-300/80">80ms Guardrail</div>
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div>
              <h1 className="text-3xl font-semibold tracking-tight">Akash Arena Telemetry Mesh</h1>
              <p className="mt-2 text-sm text-slate-300">
                Lease-derived worker polling with live VRAM, thermal load, model residency, agent footprint, and treasury
                velocity.
              </p>
            </div>
            <div className={`rounded-full border px-4 py-2 text-xs font-medium uppercase tracking-[0.2em] ${statusTone(state.status)}`}>
              {state.status}
            </div>
          </div>
          <div className="mt-4 text-xs text-slate-400">
            Polling source:{" "}
            <span className="font-mono text-slate-300">
              {LEASES_ENDPOINT || "NEXT_PUBLIC_AKASH_LEASES_URL (unset)"}
            </span>
          </div>
        </header>

        {state.globalError ? (
          <section className="mb-6 rounded-xl border border-rose-400/40 bg-rose-500/10 p-4 text-sm text-rose-100">
            <div className="font-medium">Telemetry issue detected</div>
            <div className="mt-1">{state.globalError}</div>
            {nextRetrySeconds !== null && state.status !== "live" ? (
              <div className="mt-2 text-xs text-rose-200/90">Auto-reconnect in {nextRetrySeconds}s.</div>
            ) : null}
          </section>
        ) : null}

        <section className="mb-6 grid gap-4 md:grid-cols-2 xl:grid-cols-5">
          <StatCard
            label="Workers Online"
            value={`${onlineWorkers}/${state.leases.length || state.workers.length || 0}`}
            subtitle="Lease-mapped workers"
          />
          <StatCard
            label="Fleet VRAM"
            value={`${formatBytesToGiB(aggregate.vramUsed)} / ${formatBytesToGiB(aggregate.vramTotal)}`}
            subtitle={`Utilization ${formatPercent(aggregate.vramPercent)}`}
          />
          <StatCard label="Avg GPU Temp" value={formatTemperature(aggregate.avgTemp)} subtitle="Across reachable workers" />
          <StatCard
            label="Active Agents"
            value={compactNumberFormatter.format(aggregate.activeAgents)}
            subtitle="Summed worker count"
          />
          <StatCard
            label="Treasury Velocity"
            value={
              state.treasury?.velocityUsdPerHour !== null
                ? `${state.treasury.velocityUsdPerHour >= 0 ? "+" : ""}${currencyFormatter.format(state.treasury.velocityUsdPerHour)}/hr`
                : "—"
            }
            subtitle={state.treasury?.error ? `Error: ${state.treasury.error}` : "Current treasury flow"}
          />
        </section>

        <section className="space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-medium text-slate-100">Worker Grid</h2>
            <div className="text-xs text-slate-400">
              Last update:{" "}
              {state.lastUpdatedAt
                ? new Date(state.lastUpdatedAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" })
                : "—"}
            </div>
          </div>

          {state.workers.length === 0 ? (
            <div className="rounded-xl border border-slate-700/70 bg-slate-900/50 p-6 text-sm text-slate-300">
              Waiting for lease data and worker discovery.
            </div>
          ) : (
            <div className="grid gap-4 lg:grid-cols-2">
              {state.workers.map((worker) => {
                const utilization =
                  worker.vramUsedBytes !== null &&
                  worker.vramTotalBytes !== null &&
                  worker.vramTotalBytes > 0
                    ? (worker.vramUsedBytes / worker.vramTotalBytes) * 100
                    : null;

                return (
                  <article
                    key={`${worker.leaseId}-${worker.workerUrl}`}
                    className={`rounded-xl border p-4 shadow-[0_0_24px_rgba(15,23,42,0.38)] ${
                      worker.online ? "border-cyan-400/30 bg-slate-900/65" : "border-rose-400/30 bg-rose-950/15"
                    }`}
                  >
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <div className="text-sm font-medium text-slate-100">{shorten(worker.leaseId, 32)}</div>
                      <span
                        className={`rounded-full border px-2 py-0.5 text-[10px] uppercase tracking-[0.2em] ${
                          worker.online
                            ? "border-emerald-400/40 bg-emerald-500/10 text-emerald-200"
                            : "border-rose-400/40 bg-rose-500/10 text-rose-200"
                        }`}
                      >
                        {worker.online ? "online" : "offline"}
                      </span>
                    </div>

                    <div className="mt-2 font-mono text-xs text-cyan-200/90">{shorten(worker.workerUrl, 60)}</div>

                    <div className="mt-4 grid grid-cols-2 gap-3 text-sm">
                      <Metric label="VRAM Used" value={formatBytesToGiB(worker.vramUsedBytes)} />
                      <Metric label="VRAM Utilization" value={formatPercent(utilization)} />
                      <Metric label="Temperature" value={formatTemperature(worker.temperatureC)} />
                      <Metric
                        label="Agent Count"
                        value={worker.agentCount !== null ? compactNumberFormatter.format(worker.agentCount) : "—"}
                      />
                    </div>

                    <div className="mt-4">
                      <div className="mb-2 text-[11px] uppercase tracking-[0.16em] text-slate-400">Loaded Models</div>
                      <div className="flex flex-wrap gap-2">
                        {TARGET_MODELS.map((target) => {
                          const loaded = modelLoaded(target, worker.loadedModels);
                          return (
                            <span
                              key={`${worker.workerUrl}-${target}`}
                              className={`rounded-md border px-2 py-1 text-xs ${
                                loaded
                                  ? "border-emerald-400/40 bg-emerald-500/10 text-emerald-100"
                                  : "border-slate-500/50 bg-slate-800/80 text-slate-300"
                              }`}
                            >
                              {target}
                            </span>
                          );
                        })}
                      </div>
                    </div>

                    {worker.error ? <div className="mt-3 text-xs text-rose-200">{worker.error}</div> : null}
                    <div className="mt-3 text-[11px] text-slate-500">
                      Last seen:{" "}
                      {worker.lastSeenAt
                        ? new Date(worker.lastSeenAt).toLocaleTimeString([], {
                            hour: "2-digit",
                            minute: "2-digit",
                            second: "2-digit",
                          })
                        : "—"}
                    </div>
                  </article>
                );
              })}
            </div>
          )}
        </section>
      </div>
    </main>
  );
}

function StatCard({ label, value, subtitle }: { label: string; value: string; subtitle: string }): JSX.Element {
  return (
    <article className="rounded-xl border border-cyan-400/20 bg-slate-900/65 p-4">
      <div className="text-[11px] uppercase tracking-[0.16em] text-slate-400">{label}</div>
      <div className="mt-2 text-xl font-semibold text-slate-100">{value}</div>
      <div className="mt-1 text-xs text-slate-500">{subtitle}</div>
    </article>
  );
}

function Metric({ label, value }: { label: string; value: string }): JSX.Element {
  return (
    <div className="rounded-lg border border-slate-700/70 bg-slate-950/60 p-2">
      <div className="text-[10px] uppercase tracking-[0.16em] text-slate-500">{label}</div>
      <div className="mt-1 text-sm font-medium text-slate-100">{value}</div>
    </div>
  );
}
