/**
 * Dual inference router — RTX 5090 (light/BERT) vs H100 (heavy reasoning).
 *
 * Routes embedding, telemetry, and classification to the 5090 endpoint;
 * complex reasoning tasks to the H100 endpoint.
 */

import config from '../config.js';
import { requestJson } from '../lib/httpClient.js';

const LIGHT_TASKS = new Set([
  'embedding',
  'telemetry',
  'masked_prediction',
  'simple_classification',
]);

function ollamaGenerate(baseUrl, model, prompt, stream = false) {
  return requestJson({
    method: 'POST',
    url: `${baseUrl.replace(/\/$/, '')}/api/generate`,
    data: { model, prompt, stream },
    headers: { 'Content-Type': 'application/json' },
  });
}

/**
 * @param {string} prompt
 * @param {string} [taskType] - e.g. embedding | telemetry | chat | reasoning
 * @returns {Promise<{ backend: string, model: string, response: string, raw: object }>}
 */
export async function routeRequest(prompt, taskType = 'chat') {
  const task = String(taskType || 'chat').toLowerCase();

  try {
    if (LIGHT_TASKS.has(task)) {
      const raw = await ollamaGenerate(
        config.inference.rtx5090Endpoint,
        config.inference.rtx5090Model,
        prompt,
      );
      return {
        backend: 'rtx5090',
        model: config.inference.rtx5090Model,
        response: raw.response ?? '',
        raw,
      };
    }

    const raw = await ollamaGenerate(
      config.inference.h100Endpoint,
      config.inference.h100Model,
      prompt,
    );
    return {
      backend: 'h100',
      model: config.inference.h100Model,
      response: raw.response ?? '',
      raw,
    };
  } catch (err) {
    const message = err?.message || 'Inference routing failed';
    throw new Error(`Inference routing failed: ${message}`);
  }
}

export default { routeRequest };
