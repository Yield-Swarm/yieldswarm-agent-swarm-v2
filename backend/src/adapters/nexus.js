/**
 * Solenoid 1 — Nexus Chain API adapter.
 */

import { getNexusOrchestrator } from '../../../solenoids/nexus/index.js';

let booted = false;

async function ensureInit() {
  const nexus = getNexusOrchestrator();
  if (!booted) {
    await nexus.init();
    booted = true;
  }
  return nexus;
}

export async function getNexusStatus() {
  const nexus = await ensureInit();
  const status = nexus.status();
  const vaultDetail = await nexus.vaultStatus().catch(() => ({ configured: false }));
  return { ...status, vault: vaultDetail };
}

export async function registerNexusAgent(body) {
  const nexus = await ensureInit();
  return nexus.registerAgent({
    id: body.id || body.agentId,
    pubkey: body.pubkey || body.agentPubkey,
    solenoidId: body.solenoidId || 'helix',
    permissions: body.permissions ?? 0,
    dailyLimit: body.dailyLimit ?? body.daily_harvest_limit ?? 0,
  });
}

export async function allocateNexusResource(body) {
  const nexus = await ensureInit();
  return nexus.allocateResource({
    workloadId: body.workloadId || body.id,
    provider: body.provider,
    gpu: body.gpu,
    cpu: body.cpu,
    memoryGb: body.memoryGb || body.memory_gb,
    solenoidId: body.solenoidId || 'nexus',
  });
}

export async function releaseNexusResource(workloadId) {
  const nexus = await ensureInit();
  return nexus.resources.release(workloadId);
}

export async function setNexusGlobalPause(paused) {
  const nexus = await ensureInit();
  return nexus.setGlobalPause(Boolean(paused));
}

export async function publishNexusMessage(body) {
  const nexus = await ensureInit();
  return nexus.bus.publish(
    body.topic,
    body.payload || {},
    { sourceSolenoid: body.sourceSolenoid, targetSolenoid: body.targetSolenoid },
  );
}

export async function getNexusBusRecent(topic, limit = 20) {
  const nexus = await ensureInit();
  return nexus.bus.recent(topic || null, limit);
}
