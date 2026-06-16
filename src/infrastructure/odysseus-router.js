/**
 * Eastern layer ($E^1$) — Odysseus context router with zero-trust tenant isolation.
 *
 * Routes inference requests through SHA-256 tenant-scoped memory maps.
 * All input vectors are sanitized before entering any tenant context.
 */

import crypto from "node:crypto";

/** @typedef {{ tenantHash: string, createdAt: string, messages: Array<{ role: string, content: string, at: string }>, metadata: Record<string, unknown> }} TenantContext */

const MAX_CONTENT_LENGTH = 32_768;
const MAX_MESSAGES = 256;
const ALLOWED_ROLES = new Set(["system", "user", "assistant", "tool"]);

/**
 * @param {string} tenantId
 * @returns {string} hex SHA-256 tenant hash (isolation key)
 */
export function hashTenant(tenantId) {
  if (typeof tenantId !== "string" || tenantId.trim().length < 8) {
    throw new TypeError("tenantId must be a non-empty string (min 8 chars)");
  }
  return crypto.createHash("sha256").update(tenantId.trim(), "utf8").digest("hex");
}

/**
 * Sanitize a single message content string.
 * @param {unknown} raw
 * @returns {string}
 */
export function sanitizeContent(raw) {
  if (raw === null || raw === undefined) return "";
  let text = String(raw)
    .replace(/\0/g, "")
    .replace(/[\u0001-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "")
    .trim();
  if (text.length > MAX_CONTENT_LENGTH) {
    text = text.slice(0, MAX_CONTENT_LENGTH);
  }
  return text;
}

/**
 * Validate and sanitize an inbound message array.
 * @param {unknown} messages
 * @returns {Array<{ role: string, content: string }>}
 */
export function sanitizeMessages(messages) {
  if (!Array.isArray(messages)) {
    throw new TypeError("messages must be an array");
  }
  if (messages.length > MAX_MESSAGES) {
    throw new RangeError(`messages exceed max ${MAX_MESSAGES}`);
  }

  return messages.map((msg, idx) => {
    if (!msg || typeof msg !== "object") {
      throw new TypeError(`message[${idx}] must be an object`);
    }
    const role = String(/** @type {{ role?: unknown }} */ (msg).role || "").toLowerCase();
    if (!ALLOWED_ROLES.has(role)) {
      throw new TypeError(`message[${idx}] has invalid role: ${role}`);
    }
    const content = sanitizeContent(/** @type {{ content?: unknown }} */ (msg).content);
    if (!content && role !== "system") {
      throw new TypeError(`message[${idx}] content cannot be empty`);
    }
    return { role, content };
  });
}

/**
 * Zero-trust tenant validation — rejects cross-tenant token reuse.
 * @param {object} opts
 * @param {string} opts.tenantId
 * @param {string} [opts.authTenantHash] hash presented by caller
 * @param {string} [opts.apiKey] optional API key bound to tenant
 * @returns {{ tenantHash: string, validated: true }}
 */
export function validateTenant({ tenantId, authTenantHash, apiKey }) {
  const tenantHash = hashTenant(tenantId);

  if (authTenantHash && authTenantHash !== tenantHash) {
    throw new Error("tenant hash mismatch — zero-trust rejection");
  }

  const expectedKey = process.env[`TENANT_KEY_${tenantHash.slice(0, 16).toUpperCase()}`];
  if (expectedKey && apiKey !== expectedKey) {
    throw new Error("invalid tenant API key");
  }

  return { tenantHash, validated: true };
}

/**
 * In-memory tenant context store (swap for Redis/Postgres in production).
 */
export class OdysseusRouter {
  constructor() {
    /** @type {Map<string, TenantContext>} */
    this.contexts = new Map();
  }

  /**
   * @param {string} tenantId
   * @returns {TenantContext}
   */
  getOrCreateContext(tenantId) {
    const { tenantHash } = validateTenant({ tenantId });
    let ctx = this.contexts.get(tenantHash);
    if (!ctx) {
      ctx = {
        tenantHash,
        createdAt: new Date().toISOString(),
        messages: [],
        metadata: {},
      };
      this.contexts.set(tenantHash, ctx);
    }
    return ctx;
  }

  /**
   * Route a request into an isolated tenant context.
   * @param {object} input
   * @param {string} input.tenantId
   * @param {unknown} input.messages
   * @param {string} [input.authTenantHash]
   * @param {string} [input.apiKey]
   * @returns {{ tenantHash: string, messages: Array<{ role: string, content: string, at: string }>, routedAt: string }}
   */
  route(input) {
    const { tenantId, authTenantHash, apiKey } = input;
    const { tenantHash } = validateTenant({ tenantId, authTenantHash, apiKey });
    const sanitized = sanitizeMessages(input.messages);
    const ctx = this.getOrCreateContext(tenantId);

    const stamped = sanitized.map((m) => ({
      ...m,
      at: new Date().toISOString(),
    }));

    ctx.messages.push(...stamped);
    if (ctx.messages.length > MAX_MESSAGES) {
      ctx.messages = ctx.messages.slice(-MAX_MESSAGES);
    }

    return {
      tenantHash,
      messages: ctx.messages,
      routedAt: new Date().toISOString(),
    };
  }

  /**
   * Prune tenant context (invoked on hardware threshold breach).
   * @param {string} tenantId
   * @param {number} [keepLast=32]
   */
  pruneContext(tenantId, keepLast = 32) {
    const { tenantHash } = validateTenant({ tenantId });
    const ctx = this.contexts.get(tenantHash);
    if (!ctx) return { pruned: 0, tenantHash };
    const before = ctx.messages.length;
    ctx.messages = ctx.messages.slice(-keepLast);
    return { pruned: before - ctx.messages.length, tenantHash };
  }
}

/** Singleton router for serverless / Next.js imports. */
export const odysseusRouter = new OdysseusRouter();

export default odysseusRouter;
