import { resolveConfig } from "./config.js";

const LOCAL_SESSION_KEY = "yieldswarm.session";

function safeJsonParse(value) {
  if (!value) {
    return undefined;
  }

  try {
    return JSON.parse(value);
  } catch (_error) {
    return undefined;
  }
}

function readLocalSession(globalRef = typeof window === "undefined" ? undefined : window) {
  const storage = globalRef?.localStorage;
  if (!storage || typeof storage.getItem !== "function") {
    return undefined;
  }

  return safeJsonParse(storage.getItem(LOCAL_SESSION_KEY));
}

export function createAuthHeaders(session = {}) {
  const token = session.accessToken ?? session.token ?? session.jwt;
  const headers = {};

  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  if (session.tenantId) {
    headers["X-YieldSwarm-Tenant"] = session.tenantId;
  }

  if (session.userId) {
    headers["X-YieldSwarm-User"] = session.userId;
  }

  return headers;
}

export async function getCurrentSession(options = {}) {
  const {
    config: configOverrides = {},
    fetchFn = typeof fetch === "undefined" ? undefined : fetch,
    globalRef = typeof window === "undefined" ? undefined : window
  } = options;
  const config = resolveConfig(configOverrides, globalRef);

  if (typeof fetchFn === "function") {
    try {
      const response = await fetchFn(config.authSessionUrl, {
        credentials: "include",
        headers: {
          Accept: "application/json"
        }
      });

      if (response.ok) {
        return response.json();
      }
    } catch (_error) {
      // Fall through to local storage for static deployments and local previews.
    }
  }

  return readLocalSession(globalRef);
}

export function buildOdysseusUrl(workspaceUrl, handoff = {}) {
  const url = new URL(workspaceUrl, "https://yieldswarm.local");

  if (handoff.targetPath) {
    url.searchParams.set("target", handoff.targetPath);
  }

  if (handoff.handoffToken) {
    url.searchParams.set("handoff_token", handoff.handoffToken);
  }

  if (handoff.sessionId) {
    url.searchParams.set("session_id", handoff.sessionId);
  }

  const serialized = url.toString();
  return workspaceUrl.startsWith("/") ? serialized.replace("https://yieldswarm.local", "") : serialized;
}

export async function createOdysseusHandoff(options = {}) {
  const {
    targetPath = "/",
    session,
    config: configOverrides = {},
    fetchFn = typeof fetch === "undefined" ? undefined : fetch,
    globalRef = typeof window === "undefined" ? undefined : window
  } = options;
  const config = resolveConfig(configOverrides, globalRef);

  if (typeof fetchFn !== "function") {
    throw new Error("A fetch implementation is required to create an Odysseus handoff.");
  }

  const response = await fetchFn(config.authHandoffUrl, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...createAuthHeaders(session)
    },
    body: JSON.stringify({
      audience: "odysseus",
      targetPath
    })
  });

  if (!response.ok) {
    throw new Error(`Odysseus SSO handoff failed with status ${response.status}.`);
  }

  const handoff = await response.json();
  if (handoff.redirectUrl) {
    return handoff.redirectUrl;
  }

  return buildOdysseusUrl(config.odysseusWorkspaceUrl, {
    targetPath,
    handoffToken: handoff.handoffToken,
    sessionId: handoff.sessionId
  });
}
