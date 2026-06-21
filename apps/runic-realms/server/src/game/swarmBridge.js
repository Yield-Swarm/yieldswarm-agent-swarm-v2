/**
 * Bridge gameplay compute to YieldSwarm solenoids + Alchemy multi-chain RPC router.
 */

import { routeComputeJob, probeAllChains, listChains } from '../chain/alchemyRouter.js';
import { registerPlotraDeity, loadPlotraAgent, plotraAvatarUrl } from '../agents/plotraAgents.js';

const INTEGRATION_BASE = process.env.YIELDSWARM_API_BASE || 'http://127.0.0.1:8080';

export { listChains, probeAllChains, registerPlotraDeity, loadPlotraAgent, plotraAvatarUrl };

export async function submitComputeJob(job, playerId, context = {}) {
  const alchemy = await routeComputeJob(job);

  const payload = {
    playerId,
    jobId: job.id,
    sanscript: job.sanscript,
    proof: job.proof,
    chains: job.chains,
    midasGoldEquivalent: job.midasGoldEquivalent,
    alchemy,
    source: 'runic-realms',
  };

  const results = {
    nexus: null,
    helix: null,
    shadow: null,
    odysseus: null,
    codex: null,
    rosetta: null,
    alchemy,
    simulated: alchemy.simulated !== false,
  };

  try {
    const nexus = await fetch(`${INTEGRATION_BASE}/api/nexus/status`).then((r) => r.json());
    results.nexus = { ok: true, agents: nexus?.registry?.agentCount };
    results.simulated = false;
  } catch {
    results.nexus = { ok: false, error: 'nexus_unreachable' };
  }

  try {
    await fetch(`${INTEGRATION_BASE}/api/solenoid/pulse`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        pillarId: 13,
        name: 'runic_realms_compute',
        metrics: {
          compute_jobs: 1,
          rune_midas: job.midasGoldEquivalent,
          alchemy_chain: alchemy.chain,
          block: alchemy.blockNumber,
        },
      }),
    });
    results.helix = { ok: true, chain: alchemy.chain };
  } catch {
    results.helix = { ok: false };
  }

  try {
    await fetch(`${INTEGRATION_BASE}/api/shadow/arena/status`).then((r) => r.json());
    results.shadow = { ok: true };
  } catch {
    results.shadow = { ok: false };
  }

  try {
    await fetch(`${INTEGRATION_BASE}/api/helix/treasury`).then((r) => r.json());
    results.codex = { ok: true, layer: 'helix_treasury' };
  } catch {
    results.codex = { ok: false };
  }

  if (context.telegramId) {
    const plotra = await loadPlotraAgent(context.telegramId);
    if (plotra) {
      results.plotra = { ok: true, view_url: plotra.view_url, agent_id: plotra.agent_id };
    }
  }

  results.rosetta = {
    ok: true,
    sanscript: job.sanscript,
    anchor: alchemy.jobAnchor,
  };

  return { payload, results };
}
