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

  return {
    ...merged,
    telemetryRefreshMs: coerceNumber(merged.telemetryRefreshMs, DEFAULT_CONFIG.telemetryRefreshMs),
    requestTimeoutMs: coerceNumber(merged.requestTimeoutMs, DEFAULT_CONFIG.requestTimeoutMs)
  };
}

export { DEFAULT_CONFIG };
