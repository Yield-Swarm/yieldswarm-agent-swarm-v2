/**
 * Intelligent dual-backend inference router.
 * RTX 5090 (vLLM OpenAI API or Ollama) vs H100 (heavy reasoning).
 * Multi-objective scoring, circuit-breaker fallback, load-aware routing.
 */

import config from '../config.js';
import { requestJson } from '../lib/httpClient.js';

const LIGHT_TASKS = new Set([
  'embedding',
  'telemetry',
  'masked_prediction',
  'simple_classification',
  'light_classification',
  'light_reasoning',
]);

const nodeHealth = {
  rtx5090: { failures: 0, lastOk: 0 },
  h100: { failures: 0, lastOk: 0 },
};

const CIRCUIT_THRESHOLD = 3;

function backendUrl(backend) {
  if (backend === 'rtx5090') {
    return config.inference.rtx5090VllmBaseUrl || config.inference.rtx5090Endpoint;
  }
  return config.inference.h100VllmBaseUrl || config.inference.h100Endpoint;
}

function usesVllm(url) {
  const mode = config.inference.rtx5090ApiMode;
  if (mode === 'vllm') return true;
  if (mode === 'ollama') return false;
  return String(url).includes(':8000') || String(url).includes('/v1');
}

async function callVllm(baseUrl, model, prompt) {
  const root = baseUrl.replace(/\/$/, '').replace(/\/v1$/, '');
  const data = await requestJson({
    method: 'POST',
    url: `${root}/v1/chat/completions`,
    data: {
      model,
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 1024,
      temperature: 0.7,
    },
    headers: { 'Content-Type': 'application/json' },
    timeout: config.inference.timeoutMs,
  });
  const text = data.choices?.[0]?.message?.content ?? '';
  return { response: text, raw: data };
}

async function callOllama(baseUrl, model, prompt) {
  const data = await requestJson({
    method: 'POST',
    url: `${baseUrl.replace(/\/$/, '')}/api/generate`,
    data: { model, prompt, stream: false },
    headers: { 'Content-Type': 'application/json' },
    timeout: config.inference.timeoutMs,
  });
  return { response: data.response ?? '', raw: data };
}

async function callBackend(backend, prompt) {
  const url = backendUrl(backend);
  const model =
    backend === 'rtx5090' ? config.inference.rtx5090Model : config.inference.h100Model;
  if (usesVllm(url)) {
    return callVllm(url, model, prompt);
  }
  return callOllama(url, model, prompt);
}

function calculateScore(telemetry, taskType, priority) {
  const tps = telemetry?.tokensPerSecond ?? telemetry?.tokens_per_second ?? 50;
  const vram = telemetry?.vram_used ?? telemetry?.vramUsed ?? 16;
  const util = telemetry?.utilization ?? 0.5;
  let score = tps * 0.4 + (1 / Math.max(util, 0.1)) * 20;
  if (LIGHT_TASKS.has(taskType) && vram < 24) score += 30;
  if (priority === 'high' || priority === 'critical') score += 20;
  if (nodeHealth[telemetry?.backend]?.failures >= CIRCUIT_THRESHOLD) score -= 100;
  return score;
}

function pickBackend(taskType, priority, telemetry5090, telemetryH100) {
  const task = String(taskType || 'chat').toLowerCase();
  const forceLight = LIGHT_TASKS.has(task);

  const s5090 = calculateScore(
    { ...telemetry5090, backend: 'rtx5090' },
    task,
    priority,
  );
  const sH100 = calculateScore(
    { ...telemetryH100, backend: 'h100' },
    task,
    priority,
  );

  if (forceLight && s5090 >= sH100) return 'rtx5090';
  if (!config.inference.h100Endpoint && !config.inference.h100VllmBaseUrl) return 'rtx5090';
  return sH100 > s5090 ? 'h100' : 'rtx5090';
}

function recordSuccess(backend) {
  nodeHealth[backend].failures = 0;
  nodeHealth[backend].lastOk = Date.now();
}

function recordFailure(backend) {
  nodeHealth[backend].failures += 1;
}

/**
 * @param {string} prompt
 * @param {string} [taskType]
 * @param {string} [priority]
 * @param {object} [telemetry] - { rtx5090, h100 } from /api/telemetry/5090
 */
export async function routeRequest(prompt, taskType = 'chat', priority = 'normal', telemetry = {}) {
  const primary = pickBackend(
    taskType,
    priority,
    telemetry.rtx5090 ?? {},
    telemetry.h100 ?? {},
  );
  const fallback = primary === 'rtx5090' ? 'h100' : 'rtx5090';

  const tryBackend = async (backend) => {
    const { response, raw } = await callBackend(backend, prompt);
    recordSuccess(backend);
    return {
      backend,
      model: backend === 'rtx5090' ? config.inference.rtx5090Model : config.inference.h100Model,
      response,
      raw,
    };
  };

  try {
    return await tryBackend(primary);
  } catch (err) {
    recordFailure(primary);
    const hasFallback =
      fallback === 'h100'
        ? config.inference.h100Endpoint || config.inference.h100VllmBaseUrl
        : true;
    if (!hasFallback || nodeHealth[fallback].failures >= CIRCUIT_THRESHOLD) {
      throw new Error(`Inference routing failed: ${err.message}`);
    }
    try {
      const result = await tryBackend(fallback);
      return { ...result, fallbackFrom: primary };
    } catch (fallbackErr) {
      recordFailure(fallback);
      throw new Error(`Inference routing failed: ${fallbackErr.message}`);
    }
  }
}

export default { routeRequest, calculateScore, pickBackend };
