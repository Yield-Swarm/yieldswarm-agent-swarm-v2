/**
 * Weekly mutation automation — Chainlink Automation + entropy loop.
 * @module src/automation/mutation-scheduler
 */

import { buildFunctionsRequest } from '../infrastructure/oracle-bridge.js';

/**
 * @param {object[]} agents [{ tokenId, telemetry, currentGenome }]
 */
export function planWeeklyMutations(agents) {
  return agents
    .filter((a) => a.eligible !== false)
    .map((a) => buildFunctionsRequest(a));
}

/**
 * Cron-friendly tick — returns payloads ready for Chainlink Functions batch.
 */
export function mutationCronTick(state) {
  const now = Date.now();
  const weekMs = 7 * 24 * 60 * 60 * 1000;
  const due = (state.agents ?? []).filter((a) => {
    const last = a.lastMutationAt ?? 0;
    return now - last >= weekMs;
  });

  return {
    dueCount: due.length,
    requests: planWeeklyMutations(due),
    nextRunAt: due.length ? now : now + weekMs,
  };
}

export default { planWeeklyMutations, mutationCronTick };
