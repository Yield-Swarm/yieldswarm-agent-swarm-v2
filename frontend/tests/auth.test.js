import assert from "node:assert/strict";
import test from "node:test";

import { buildOdysseusUrl, createAuthHeaders, createOdysseusHandoff } from "../shared/auth.js";

test("creates auth headers from YieldSwarm session fields", () => {
  const headers = createAuthHeaders({
    accessToken: "token-123",
    tenantId: "tenant-a",
    userId: "user-b"
  });

  assert.deepEqual(headers, {
    Authorization: "Bearer token-123",
    "X-YieldSwarm-Tenant": "tenant-a",
    "X-YieldSwarm-User": "user-b"
  });
});

test("builds Odysseus workspace URL with handoff token", () => {
  const url = buildOdysseusUrl("https://odysseus.example/workspace", {
    targetPath: "/research",
    handoffToken: "handoff-1"
  });

  assert.equal(
    url,
    "https://odysseus.example/workspace?target=%2Fresearch&handoff_token=handoff-1"
  );
});

test("creates handoff URL from auth exchange response", async () => {
  const calls = [];
  const url = await createOdysseusHandoff({
    targetPath: "/memory",
    session: { token: "jwt-1" },
    config: {
      authHandoffUrl: "/handoff",
      odysseusWorkspaceUrl: "/odysseus"
    },
    fetchFn: async (requestUrl, options) => {
      calls.push({ requestUrl, options });
      return {
        ok: true,
        async json() {
          return {
            handoffToken: "short-lived",
            sessionId: "session-1"
          };
        }
      };
    }
  });

  assert.equal(url, "/odysseus?target=%2Fmemory&handoff_token=short-lived&session_id=session-1");
  assert.equal(calls[0].requestUrl, "/handoff");
  assert.equal(calls[0].options.method, "POST");
  assert.equal(calls[0].options.credentials, "include");
  assert.equal(calls[0].options.headers.Authorization, "Bearer jwt-1");
  assert.equal(
    calls[0].options.body,
    JSON.stringify({ audience: "odysseus", targetPath: "/memory" })
  );
});
