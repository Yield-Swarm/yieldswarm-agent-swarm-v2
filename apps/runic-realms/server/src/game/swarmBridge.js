/**
 * Bridge gameplay compute to YieldSwarm solenoids (Apollo Nexus, Helix, Shadow, Odysseus).
 */

const INTEGRATION_BASE = process.env.YIELDSWARM_API_BASE || 'http://127.0.0.1:8080';

export async function submitComputeJob(job, playerId) {
  const payload = {
    playerId,
    jobId: job.id,
    sanscript: job.sanscript,
    proof: job.proof,
    chains: job.chains,
    midasGoldEquivalent: job.midasGoldEquivalent,
    source: 'runic-realms',
  };

  const results = { nexus: null, helix: null, shadow: null, odysseus: null, simulated: true };

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
        metrics: { compute_jobs: 1, rune_midas: job.midasGoldEquivalent },
      }),
    });
    results.helix = { ok: true };
  } catch {
    results.helix = { ok: false };
  }

  try {
    await fetch(`${INTEGRATION_BASE}/api/shadow/arena/status`).then((r) => r.json());
    results.shadow = { ok: true };
  } catch {
    results.shadow = { ok: false };
  }

  return { payload, results };
}
