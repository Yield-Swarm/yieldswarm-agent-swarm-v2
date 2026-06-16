const DEFAULT_CONFIG = {
  akashTelemetryUrl: "/api/telemetry/akash",
  odysseusTelemetryUrl: "/api/telemetry/odysseus",
  odysseusWorkspaceUrl: "/odysseus",
  authSessionUrl: "/api/auth/session",
  authHandoffUrl: "/api/auth/odysseus/handoff",
  telemetryRefreshMs: 30000,
  requestTimeoutMs: 10000
};

const META_KEYS = {
  akashTelemetryUrl: "yieldswarm-akash-telemetry-url",
  odysseusTelemetryUrl: "yieldswarm-odysseus-telemetry-url",
  odysseusWorkspaceUrl: "yieldswarm-odysseus-workspace-url",
  authSessionUrl: "yieldswarm-auth-session-url",
  authHandoffUrl: "yieldswarm-auth-handoff-url",
  telemetryRefreshMs: "yieldswarm-telemetry-refresh-ms",
  requestTimeoutMs: "yieldswarm-request-timeout-ms"
};

function browserGlobal() {
  return typeof window === "undefined" ? undefined : window;
}

function metaContent(documentRef, name) {
  if (!documentRef || typeof documentRef.querySelector !== "function") {
    return undefined;
  }

  const element = documentRef.querySelector(`meta[name="${name}"]`);
  const value = element?.getAttribute("content")?.trim();
  return value || undefined;
}

function coerceNumber(value, fallback) {
  if (value === undefined || value === null || value === "") {
    return fallback;
  }

  const numeric = Number(value);
  return Number.isFinite(numeric) && numeric > 0 ? numeric : fallback;
}

function workerUrlsFromLocation() {
  if (typeof window === "undefined") {
    return [];
  }

  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get("workers");
  if (fromQuery) {
    return fromQuery
      .split(/[\n,\s]+/g)
      .map((entry) => entry.trim())
      .filter(Boolean)
      .map((entry) => entry.replace(/\/+$/, ""));
  }

  const runtime = window.YIELDSWARM_CONFIG?.akashWorkerUrls;
  if (typeof runtime === "string" && runtime.trim()) {
    return runtime
      .split(/[\n,\s]+/g)
      .map((entry) => entry.trim())
      .filter(Boolean);
  }

  return [];
}

export function resolveConfig(overrides = {}, globalRef = browserGlobal()) {
  const runtimeConfig = globalRef?.YIELDSWARM_CONFIG ?? {};
  const documentRef = globalRef?.document;
  const fromMeta = Object.fromEntries(
    Object.entries(META_KEYS).map(([key, metaName]) => [key, metaContent(documentRef, metaName)])
  );

  const merged = {
    ...DEFAULT_CONFIG,
    ...runtimeConfig,
    ...fromMeta,
    ...overrides
  };

  const workerUrls = workerUrlsFromLocation();
  if (workerUrls.length > 0) {
    merged.akashWorkerUrls = workerUrls.join(",");
    merged.akashTelemetryUrl = `${workerUrls[0].replace(/\/+$/, "")}/api/telemetry/akash`;
  }

  return {
    ...merged,
    telemetryRefreshMs: coerceNumber(merged.telemetryRefreshMs, DEFAULT_CONFIG.telemetryRefreshMs),
    requestTimeoutMs: coerceNumber(merged.requestTimeoutMs, DEFAULT_CONFIG.requestTimeoutMs)
  };
}

export { DEFAULT_CONFIG };
