"use client";

import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";

const POLL_INTERVAL_MS = 5_000;
const REQUEST_TIMEOUT_MS = 4_500;
const GUARDRAIL_MS = 80;
const ENDPOINT_CANDIDATES = ["/telemetry", "/status", "/metrics", "/health", "/healthz"];

type FlatEntry = {
  key: string;
  value: unknown;
};

type ParsedTelemetry = {
  vramUsedGb: number | null;
  vramTotalGb: number | null;
  temperatureC: number | null;
  loadedModels: string[];
  agentCount: number | null;
  treasuryVelocityUsdHr: number | null;
};

type WorkerTelemetry = ParsedTelemetry & {
  workerUrl: string;
  sourceEndpoint: string | null;
  latencyMs: number;
  ok: boolean;
  updatedAt: string;
  error: string | null;
};

function sanitizeWorkerUrls(raw: string | undefined): string[] {
  if (!raw) {
    return [];
  }

  return raw
    .split(/[\n,\s]+/g)
    .map((entry) => entry.trim())
    .filter(Boolean)
    .map((entry) => entry.replace(/\/+$/, ""));
}

function parseNumberish(input: unknown): number | null {
  if (typeof input === "number" && Number.isFinite(input)) {
    return input;
  }

  if (typeof input === "string") {
    const cleaned = input.trim().replace(/[,%$]/g, "");
    if (!cleaned) {
      return null;
    }
    const parsed = Number(cleaned);
    return Number.isFinite(parsed) ? parsed : null;
  }

  return null;
}

function flatten(input: unknown, prefix = ""): FlatEntry[] {
  if (input === null || input === undefined) {
    return [{ key: prefix, value: input }];
  }

  if (Array.isArray(input)) {
    return input.flatMap((item, idx) => flatten(item, `${prefix}[${idx}]`));
  }

  if (typeof input !== "object") {
    return [{ key: prefix, value: input }];
  }

  return Object.entries(input as Record<string, unknown>).flatMap(([key, value]) => {
    const nextPrefix = prefix ? `${prefix}.${key}` : key;
    return flatten(value, nextPrefix);
  });
}

function findFirstNumeric(entries: FlatEntry[], keyHints: string[][]): { value: number; key: string } | null {
  for (const hints of keyHints) {
    const match = entries.find((entry) => {
      const key = entry.key.toLowerCase();
      return hints.every((hint) => key.includes(hint));
    });
    if (!match) {
      continue;
    }
    const parsed = parseNumberish(match.value);
    if (parsed !== null) {
      return { value: parsed, key: match.key.toLowerCase() };
    }
  }
  return null;
}

function asGb(value: number, key: string): number {
  if (key.includes("bytes")) {
    return value / (1024 ** 3);
  }
  if (key.includes("mb")) {
    return value / 1024;
  }
  if (key.includes("kb")) {
    return value / (1024 ** 2);
  }
  return value;
}

function extractModels(entries: FlatEntry[]): string[] {
  const set = new Set<string>();

  for (const entry of entries) {
    const key = entry.key.toLowerCase();
    if (!key.includes("model")) {
      continue;
    }

    if (Array.isArray(entry.value)) {
      entry.value.forEach((item) => {
        if (typeof item === "string" && item.trim()) {
          set.add(item.trim());
        }
      });
      continue;
    }

    if (typeof entry.value === "string") {
      const raw = entry.value.trim();
      if (!raw) {
        continue;
      }

      raw
        .split(/[,\n|]/g)
        .map((item) => item.trim())
        .filter(Boolean)
        .forEach((item) => set.add(item));
    }
  }

  return Array.from(set);
}

function parsePrometheus(payload: string): ParsedTelemetry {
  const lines = payload.split("\n");
  let vramUsedGb: number | null = null;
  let vramTotalGb: number | null = null;
  let temperatureC: number | null = null;
  let agentCount: number | null = null;
  let treasuryVelocityUsdHr: number | null = null;
  const models = new Set<string>();

  const metricLineRegex = /^([a-zA-Z_:][a-zA-Z0-9_:]*)(\{([^}]*)\})?\s+(-?\d+(?:\.\d+)?(?:e[+-]?\d+)?)$/;

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }

    const match = metricLineRegex.exec(trimmed);
    if (!match) {
      continue;
    }

    const metricName = match[1].toLowerCase();
    const labels = match[3] ?? "";
    const value = Number(match[4]);
    if (!Number.isFinite(value)) {
      continue;
    }

    if (vramUsedGb === null && /vram.*used|gpu.*memory.*used/.test(metricName)) {
      if (metricName.includes("bytes")) {
        vramUsedGb = value / (1024 ** 3);
      } else if (metricName.includes("mb")) {
        vramUsedGb = value / 1024;
      } else {
        vramUsedGb = value;
      }
    }

    if (vramTotalGb === null && /vram.*total|gpu.*memory.*total/.test(metricName)) {
      if (metricName.includes("bytes")) {
        vramTotalGb = value / (1024 ** 3);
      } else if (metricName.includes("mb")) {
        vramTotalGb = value / 1024;
      } else {
        vramTotalGb = value;
      }
    }

    if (temperatureC === null && /temp|temperature/.test(metricName)) {
      temperatureC = value;
    }

    if (agentCount === null && /agent.*count|active.*agents/.test(metricName)) {
      agentCount = Math.round(value);
    }

    if (treasuryVelocityUsdHr === null && /treasury.*velocity|velocity.*treasury/.test(metricName)) {
      treasuryVelocityUsdHr = value;
    }

    if (/loaded.*model|model.*loaded|active.*model/.test(metricName) && labels) {
      const modelMatch = /model="([^"]+)"/.exec(labels);
      if (modelMatch?.[1]) {
        models.add(modelMatch[1]);
      }
    }
  }

  return {
    vramUsedGb,
    vramTotalGb,
    temperatureC,
    loadedModels: Array.from(models),
    agentCount,
    treasuryVelocityUsdHr,
  };
}

function parseJsonTelemetry(payload: unknown): ParsedTelemetry {
  const entries = flatten(payload).map((entry) => ({
    key: entry.key.toLowerCase(),
    value: entry.value,
  }));

  const vramUsed = findFirstNumeric(entries, [
    ["vram", "used", "gb"],
    ["gpu", "memory", "used", "gb"],
    ["vram", "used", "mb"],
    ["gpu", "memory", "used", "mb"],
    ["vram", "used"],
    ["gpu", "memory", "used"],
  ]);

  const vramTotal = findFirstNumeric(entries, [
    ["vram", "total", "gb"],
    ["gpu", "memory", "total", "gb"],
    ["vram", "total", "mb"],
    ["gpu", "memory", "total", "mb"],
    ["vram", "total"],
    ["gpu", "memory", "total"],
  ]);

  const temperature = findFirstNumeric(entries, [
    ["temperature", "c"],
    ["gpu", "temp"],
    ["temperature"],
    ["temp"],
  ]);

  const agents = findFirstNumeric(entries, [
    ["agent", "count"],
    ["active", "agents"],
    ["agents"],
  ]);

  const treasuryVelocity = findFirstNumeric(entries, [
    ["treasury", "velocity", "usd", "hour"],
    ["treasury", "velocity"],
    ["velocity", "treasury"],
  ]);

  return {
    vramUsedGb: vramUsed ? asGb(vramUsed.value, vramUsed.key) : null,
    vramTotalGb: vramTotal ? asGb(vramTotal.value, vramTotal.key) : null,
    temperatureC: temperature ? temperature.value : null,
    loadedModels: extractModels(entries),
    agentCount: agents ? Math.round(agents.value) : null,
    treasuryVelocityUsdHr: treasuryVelocity ? treasuryVelocity.value : null,
  };
}

async function fetchWithTimeout(url: string, timeoutMs: number): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { signal: controller.signal, cache: "no-store" });
  } finally {
    clearTimeout(timeout);
  }
}

async function pollWorker(workerUrl: string): Promise<WorkerTelemetry> {
  const started = performance.now();
  let lastError = "No telemetry endpoint responded with valid payload.";

  for (const endpoint of ENDPOINT_CANDIDATES) {
    const target = new URL(endpoint, `${workerUrl}/`).toString();
    try {
      const response = await fetchWithTimeout(target, REQUEST_TIMEOUT_MS);
      if (!response.ok) {
        lastError = `${response.status} ${response.statusText} from ${endpoint}`;
        continue;
      }

      const contentType = response.headers.get("content-type")?.toLowerCase() ?? "";
      const body = await response.text();

      const parsed = contentType.includes("application/json")
        ? parseJsonTelemetry(JSON.parse(body))
        : parsePrometheus(body);

      return {
        ...parsed,
        workerUrl,
        sourceEndpoint: endpoint,
        latencyMs: Math.round(performance.now() - started),
        updatedAt: new Date().toISOString(),
        ok: true,
        error: null,
      };
    } catch (error) {
      lastError = error instanceof Error ? `${endpoint}: ${error.message}` : `${endpoint}: Unknown failure`;
    }
  }

  return {
    workerUrl,
    sourceEndpoint: null,
    latencyMs: Math.round(performance.now() - started),
    updatedAt: new Date().toISOString(),
    ok: false,
    vramUsedGb: null,
    vramTotalGb: null,
    temperatureC: null,
    loadedModels: [],
    agentCount: null,
    treasuryVelocityUsdHr: null,
    error: lastError,
  };
}

function formatNumber(value: number | null, fractionDigits = 1, suffix = ""): string {
  if (value === null || Number.isNaN(value)) {
    return "—";
  }
  return `${value.toLocaleString(undefined, { maximumFractionDigits: fractionDigits })}${suffix}`;
}

export default function ArenaTelemetryPage(): JSX.Element {
  return (
    <Suspense
      fallback={
        <main className="arena">
          <section className="shell">
            <p className="tag">ARENA / AKASH LIVE TELEMETRY</p>
            <p>Loading worker telemetry…</p>
          </section>
        </main>
      }
    >
      <ArenaTelemetryContent />
    </Suspense>
  );
}

function ArenaTelemetryContent(): JSX.Element {
  const searchParams = useSearchParams();
  const [leaseUrls, setLeaseUrls] = useState<string[]>([]);

  const workerUrls = useMemo(() => {
    const fromQuery = sanitizeWorkerUrls(searchParams?.get("workers") ?? undefined);
    if (fromQuery.length > 0) {
      return fromQuery;
    }
    const fromEnv = sanitizeWorkerUrls(process.env.NEXT_PUBLIC_AKASH_WORKER_URLS);
    if (fromEnv.length > 0) {
      return fromEnv;
    }
    return leaseUrls;
  }, [leaseUrls, searchParams]);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const response = await fetch("/api/akash/lease", { cache: "no-store" });
        if (!response.ok) {
          return;
        }
        const payload = (await response.json()) as { workerUrls?: string[] };
        if (!cancelled && Array.isArray(payload.workerUrls) && payload.workerUrls.length > 0) {
          setLeaseUrls(sanitizeWorkerUrls(payload.workerUrls.join(",")));
        }
      } catch {
        // Local dev without a deployed lease — query param or env still works.
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);
  const [workers, setWorkers] = useState<WorkerTelemetry[]>([]);
  const [lastUpdated, setLastUpdated] = useState<string | null>(null);
  const [polling, setPolling] = useState(false);

  const refresh = useCallback(async () => {
    if (workerUrls.length === 0) {
      return;
    }

    setPolling(true);
    const results = await Promise.all(workerUrls.map((url) => pollWorker(url)));
    setWorkers(results);
    setLastUpdated(new Date().toISOString());
    setPolling(false);
  }, [workerUrls]);

  useEffect(() => {
    void refresh();
    if (workerUrls.length === 0) {
      return;
    }

    const timer = setInterval(() => {
      void refresh();
    }, POLL_INTERVAL_MS);

    return () => clearInterval(timer);
  }, [refresh, workerUrls.length]);

  const aggregate = useMemo(() => {
    const online = workers.filter((worker) => worker.ok);
    const vramUsedGb = online.reduce((sum, worker) => sum + (worker.vramUsedGb ?? 0), 0);
    const vramTotalGb = online.reduce((sum, worker) => sum + (worker.vramTotalGb ?? 0), 0);
    const temperatures = online
      .map((worker) => worker.temperatureC)
      .filter((value): value is number => value !== null);
    const avgTemp = temperatures.length
      ? temperatures.reduce((sum, value) => sum + value, 0) / temperatures.length
      : null;
    const agentCount = online.reduce((sum, worker) => sum + (worker.agentCount ?? 0), 0);
    const treasuryVelocity = online.reduce(
      (sum, worker) => sum + (worker.treasuryVelocityUsdHr ?? 0),
      0
    );
    const loadedModels = Array.from(
      new Set(online.flatMap((worker) => worker.loadedModels.map((model) => model.trim())))
    ).filter(Boolean);
    const guardrailBreaches = online.filter((worker) => worker.latencyMs > GUARDRAIL_MS).length;

    return {
      onlineWorkers: online.length,
      totalWorkers: workers.length,
      vramUsedGb,
      vramTotalGb,
      avgTemp,
      agentCount,
      treasuryVelocity,
      loadedModels,
      guardrailBreaches,
    };
  }, [workers]);

  return (
    <main className="arena">
      <section className="shell">
        <header className="header">
          <div>
            <p className="tag">ARENA / AKASH LIVE TELEMETRY</p>
            <h1>Worker Control Plane</h1>
          </div>
          <div className="guardrail">80ms Guardrail</div>
        </header>

        {workerUrls.length === 0 && (
          <div className="notice">
            Connect a live Akash worker via{" "}
            <code>?workers=https://&lt;lease-uri&gt;:8080</code>, set{" "}
            <code>NEXT_PUBLIC_AKASH_WORKER_URLS</code>, or deploy with{" "}
            <code>./scripts/deploy-to-akash.sh</code> (Arena reads <code>.run/akash-lease.env</code>{" "}
            via <code>/api/akash/lease</code>).
          </div>
        )}

        <div className="stats">
          <article>
            <span>VRAM Utilization</span>
            <strong>
              {formatNumber(aggregate.vramUsedGb, 1, " GB")} /{" "}
              {formatNumber(aggregate.vramTotalGb, 1, " GB")}
            </strong>
          </article>
          <article>
            <span>GPU Temperature</span>
            <strong>{formatNumber(aggregate.avgTemp, 1, "°C")}</strong>
          </article>
          <article>
            <span>Loaded Models</span>
            <strong>{aggregate.loadedModels.length || "—"}</strong>
          </article>
          <article>
            <span>Agent Count</span>
            <strong>{aggregate.agentCount.toLocaleString() || "—"}</strong>
          </article>
          <article>
            <span>Treasury Velocity</span>
            <strong>{formatNumber(aggregate.treasuryVelocity, 2, " USD/hr")}</strong>
          </article>
          <article>
            <span>Guardrail Breaches</span>
            <strong>{aggregate.guardrailBreaches}</strong>
          </article>
        </div>

        <div className="meta">
          <span>
            {aggregate.onlineWorkers}/{aggregate.totalWorkers} workers healthy
          </span>
          <span>{polling ? "Polling..." : "Idle"}</span>
          <span>Last update: {lastUpdated ? new Date(lastUpdated).toLocaleTimeString() : "—"}</span>
        </div>

        <div className="tableWrap">
          <table>
            <thead>
              <tr>
                <th>Worker</th>
                <th>Latency</th>
                <th>VRAM</th>
                <th>Temp</th>
                <th>Agents</th>
                <th>Treasury Velocity</th>
                <th>Models</th>
                <th>Endpoint</th>
              </tr>
            </thead>
            <tbody>
              {workers.map((worker) => {
                const latencyClass =
                  worker.latencyMs <= GUARDRAIL_MS ? "ok" : worker.latencyMs <= 2 * GUARDRAIL_MS ? "warn" : "bad";

                return (
                  <tr key={worker.workerUrl}>
                    <td>
                      <div className="worker">
                        <span className={`dot ${worker.ok ? "ok" : "bad"}`} />
                        <span>{worker.workerUrl}</span>
                      </div>
                      {!worker.ok && worker.error && <p className="error">{worker.error}</p>}
                    </td>
                    <td>
                      <span className={`latency ${latencyClass}`}>{worker.latencyMs}ms</span>
                    </td>
                    <td>
                      {formatNumber(worker.vramUsedGb, 1, " GB")}
                      {worker.vramTotalGb !== null ? ` / ${formatNumber(worker.vramTotalGb, 1, " GB")}` : ""}
                    </td>
                    <td>{formatNumber(worker.temperatureC, 1, "°C")}</td>
                    <td>{worker.agentCount?.toLocaleString() ?? "—"}</td>
                    <td>{formatNumber(worker.treasuryVelocityUsdHr, 2, " USD/hr")}</td>
                    <td>{worker.loadedModels.length ? worker.loadedModels.join(", ") : "—"}</td>
                    <td>{worker.sourceEndpoint ?? "—"}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      <style jsx>{`
        .arena {
          min-height: 100vh;
          background: radial-gradient(circle at 20% 0%, #14142c 0%, #090a14 50%, #05060d 100%);
          color: #dcdef2;
          padding: 24px;
          font-family: "IBM Plex Mono", "SFMono-Regular", Menlo, Consolas, monospace;
        }
        .shell {
          margin: 0 auto;
          max-width: 1400px;
          border: 1px solid rgba(114, 129, 255, 0.4);
          background: linear-gradient(
            180deg,
            rgba(10, 13, 33, 0.95) 0%,
            rgba(8, 10, 24, 0.95) 100%
          );
          box-shadow: 0 0 0 1px rgba(0, 246, 255, 0.2), 0 0 40px rgba(88, 105, 255, 0.2);
          border-radius: 14px;
          padding: 24px;
        }
        .header {
          display: flex;
          justify-content: space-between;
          align-items: flex-start;
          gap: 16px;
          margin-bottom: 20px;
        }
        .tag {
          color: #8d95d8;
          letter-spacing: 0.15em;
          font-size: 12px;
          margin: 0 0 6px 0;
        }
        h1 {
          font-size: 30px;
          margin: 0;
          color: #f6f7ff;
        }
        .guardrail {
          border: 1px solid rgba(0, 246, 255, 0.65);
          color: #8cfbff;
          padding: 8px 12px;
          border-radius: 999px;
          font-size: 12px;
          text-transform: uppercase;
          letter-spacing: 0.08em;
          align-self: center;
          box-shadow: inset 0 0 16px rgba(0, 246, 255, 0.12);
        }
        .notice {
          border: 1px solid rgba(255, 221, 122, 0.45);
          background: rgba(255, 221, 122, 0.08);
          color: #ffe194;
          border-radius: 10px;
          padding: 12px;
          margin-bottom: 20px;
        }
        .stats {
          display: grid;
          grid-template-columns: repeat(6, minmax(150px, 1fr));
          gap: 12px;
          margin-bottom: 16px;
        }
        .stats article {
          border: 1px solid rgba(126, 143, 255, 0.35);
          background: rgba(17, 21, 47, 0.75);
          border-radius: 10px;
          padding: 12px;
          min-height: 78px;
          display: flex;
          flex-direction: column;
          justify-content: center;
          gap: 6px;
        }
        .stats span {
          font-size: 12px;
          color: #99a4f3;
        }
        .stats strong {
          font-size: 16px;
          color: #f2f4ff;
        }
        .meta {
          display: flex;
          justify-content: space-between;
          color: #8891ce;
          margin-bottom: 14px;
          font-size: 12px;
        }
        .tableWrap {
          overflow-x: auto;
          border: 1px solid rgba(116, 133, 255, 0.25);
          border-radius: 10px;
        }
        table {
          border-collapse: collapse;
          width: 100%;
          min-width: 1100px;
          background: rgba(10, 13, 30, 0.78);
        }
        thead {
          background: rgba(41, 51, 109, 0.44);
        }
        th,
        td {
          text-align: left;
          padding: 10px 12px;
          border-bottom: 1px solid rgba(95, 112, 220, 0.2);
          vertical-align: top;
          font-size: 12px;
        }
        th {
          color: #adb6f8;
          text-transform: uppercase;
          font-size: 11px;
          letter-spacing: 0.08em;
        }
        .worker {
          display: flex;
          align-items: center;
          gap: 8px;
          max-width: 260px;
          overflow: hidden;
          text-overflow: ellipsis;
        }
        .dot {
          width: 8px;
          height: 8px;
          border-radius: 999px;
          flex: 0 0 auto;
        }
        .dot.ok {
          background: #53ffaf;
          box-shadow: 0 0 12px rgba(83, 255, 175, 0.6);
        }
        .dot.bad {
          background: #ff667d;
          box-shadow: 0 0 12px rgba(255, 102, 125, 0.5);
        }
        .latency {
          display: inline-flex;
          border-radius: 999px;
          border: 1px solid transparent;
          padding: 3px 8px;
          font-size: 11px;
          min-width: 58px;
          justify-content: center;
        }
        .latency.ok {
          color: #86ffca;
          border-color: rgba(83, 255, 175, 0.4);
          background: rgba(83, 255, 175, 0.09);
        }
        .latency.warn {
          color: #ffe6a0;
          border-color: rgba(255, 219, 116, 0.45);
          background: rgba(255, 219, 116, 0.1);
        }
        .latency.bad {
          color: #ffb0bc;
          border-color: rgba(255, 102, 125, 0.45);
          background: rgba(255, 102, 125, 0.1);
        }
        .error {
          margin: 6px 0 0;
          color: #ff93a5;
          font-size: 11px;
        }
        @media (max-width: 1200px) {
          .stats {
            grid-template-columns: repeat(2, minmax(150px, 1fr));
          }
        }
      `}</style>
    </main>
  );
}
