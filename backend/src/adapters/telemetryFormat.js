/**
 * Shape backend adapter snapshots into the JSON contracts consumed by
 * frontend/shared/telemetry.js (static Arena + Portal dashboards).
 */

export function toAkashTelemetryPayload(snapshot) {
  const workers = (snapshot.workers || []).map((w) => ({
    id: w.id,
    name: w.id,
    provider: w.provider || w.region || 'akash',
    status: w.state || 'unknown',
    state: w.state || 'unknown',
    gpuCount: w.gpu ? 1 : 0,
    gpus: w.gpu ? 1 : 0,
    cpuCores: w.cpuUtil != null ? Math.max(1, Math.round(w.cpuUtil * 32)) : 8,
    memoryGb: w.memUtil != null ? Math.max(8, Math.round(w.memUtil * 64)) : 32,
    monthlyCostUsd: w.kind === 'gpu-miner' ? 120 : 45,
    throughput: w.hashrateMhs || 0,
    updatedAt: new Date().toISOString(),
  }));

  return {
    updatedAt: new Date().toISOString(),
    status: snapshot.live ? 'active' : 'degraded',
    workers,
    deployments: [],
    alerts: snapshot.live
      ? []
      : [`Akash upstream: ${snapshot.source} (${snapshot.reason || 'degraded'})`],
  };
}

export function toOdysseusTelemetryPayload(snapshot) {
  const p = snapshot.payload || {};
  return {
    updatedAt: new Date().toISOString(),
    status: snapshot.live ? 'active' : 'degraded',
    agents: p.agents || [],
    memory: p.memory || p.memorySystem || {},
    queueDepth: p.queueDepth ?? 0,
    completedResearchRuns: p.completedResearchRuns ?? 0,
    alerts: snapshot.live
      ? []
      : [`Odysseus upstream: ${snapshot.source} (${snapshot.reason || 'degraded'})`],
  };
}
