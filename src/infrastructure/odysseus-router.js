/**
 * Odysseus Router — strict per-agent cognitive isolation (Greek layer D¹).
 *
 * Every agent NFT tokenId gets an isolated context namespace with hard caps
 * and automatic pruning. Eastern layer (E¹) allows emergence only within
 * bounded session windows. Paradigm Shift (PDs¹) links mutation tier to
 * routing quality budgets.
 *
 * @module src/infrastructure/odysseus-router
 */

const DEFAULT_MAX_CONTEXT_TOKENS = 8192;
const DEFAULT_MAX_SESSIONS = 4;
const PRUNE_AGE_MS = 30 * 60 * 1000; // 30 minutes idle

/** @type {Map<string, import('./odysseus-router.types').AgentContext>} */
const contexts = new Map();

/**
 * @param {string|number} tokenId NFT tokenId — isolation boundary key
 * @param {object} [opts]
 * @returns {import('./odysseus-router.types').AgentContext}
 */
export function getAgentContext(tokenId, opts = {}) {
  const key = String(tokenId);
  if (!contexts.has(key)) {
    contexts.set(key, {
      tokenId: key,
      tier: opts.tier ?? 0,
      messages: [],
      tokenCount: 0,
      maxTokens: opts.maxTokens ?? DEFAULT_MAX_CONTEXT_TOKENS,
      maxSessions: opts.maxSessions ?? DEFAULT_MAX_SESSIONS,
      sessions: [],
      createdAt: Date.now(),
      lastActiveAt: Date.now(),
      mutationEpoch: opts.mutationEpoch ?? 0,
    });
  }
  const ctx = contexts.get(key);
  ctx.lastActiveAt = Date.now();
  return ctx;
}

/**
 * Append a message with hard cap enforcement and LRU pruning.
 * @param {string|number} tokenId
 * @param {{ role: string, content: string, tokens?: number }} message
 */
export function appendMessage(tokenId, message) {
  const ctx = getAgentContext(tokenId);
  let content = message.content;
  let tokens = message.tokens ?? estimateTokens(content);

  if (tokens > ctx.maxTokens) {
    const maxChars = ctx.maxTokens * 4;
    content = content.slice(0, maxChars);
    tokens = estimateTokens(content);
  }

  while (ctx.tokenCount + tokens > ctx.maxTokens && ctx.messages.length > 0) {
    const removed = ctx.messages.shift();
    ctx.tokenCount -= removed.tokens ?? 0;
  }

  ctx.messages.push({ ...message, content, tokens, at: Date.now() });
  ctx.tokenCount += tokens;
  pruneIdleSessions(ctx);
  return ctx;
}

/**
 * Route inference request to model/worker based on tier + task.
 * @param {object} req
 * @param {string|number} req.tokenId
 * @param {string} req.task
 * @param {object} [req.telemetry]
 * @param {import('./sovereign-optimizer.js').OptimizerSignal} [req.optimizer]
 */
export function routeRequest(req) {
  const ctx = getAgentContext(req.tokenId, { tier: req.tier });
  const tier = ctx.tier ?? 0;

  const modelProfile = selectModelForTier(tier, req.task);
  const workerUrl = selectWorker(req.optimizer, modelProfile);

  return {
    tokenId: ctx.tokenId,
    isolated: true,
    model: modelProfile.modelId,
    workerUrl,
    contextTokens: ctx.tokenCount,
    maxTokens: ctx.maxTokens,
    tier,
    layers: {
      greek: 'context_isolated',
      eastern: 'adaptive_routing',
      paradigm: `tier_${tier}_co_evolution`,
    },
  };
}

function selectModelForTier(tier, task) {
  const catalog = {
    0: { modelId: 'llama3.2-3b', vramGb: 4 },
    1: { modelId: 'llama3.1-8b', vramGb: 8 },
    2: { modelId: 'llama3.1-70b-q4', vramGb: 20 },
    3: { modelId: 'qwen2.5-72b-awq', vramGb: 28 },
    4: { modelId: 'deepseek-r1-5090', vramGb: 48 },
  };
  const base = catalog[Math.min(tier, 4)] ?? catalog[0];
  return { ...base, task };
}

function selectWorker(optimizer, profile) {
  if (optimizer?.wormholeTarget) return optimizer.wormholeTarget;
  const workers = (process.env.YIELDSWARM_AKASH_WORKERS ?? '')
    .split(',')
    .map((w) => w.trim())
    .filter(Boolean);
  if (workers.length === 0) return null;
  const idx = profile.vramGb >= 40 ? 0 : workers.length - 1;
  return workers[idx] ?? workers[0];
}

function pruneIdleSessions(ctx) {
  const now = Date.now();
  ctx.sessions = ctx.sessions.filter((s) => now - s.lastActiveAt < PRUNE_AGE_MS);
  while (ctx.sessions.length > ctx.maxSessions) {
    ctx.sessions.shift();
  }
}

function estimateTokens(text) {
  return Math.ceil(String(text).length / 4);
}

/** Clear context for tokenId — hard isolation reset. */
export function resetContext(tokenId) {
  contexts.delete(String(tokenId));
}

/** Stats for monitoring / Arena telemetry. */
export function routerStats() {
  return {
    activeContexts: contexts.size,
    contexts: [...contexts.values()].map((c) => ({
      tokenId: c.tokenId,
      tier: c.tier,
      tokenCount: c.tokenCount,
      messages: c.messages.length,
    })),
  };
}

export default { getAgentContext, appendMessage, routeRequest, resetContext, routerStats };
