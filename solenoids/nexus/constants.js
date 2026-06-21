/** Solenoid 1 — Nexus Chain orchestration constants. */

export const MAX_AGENTS = 521;

export const SOLENOID_IDS = Object.freeze({
  NEXUS: 'nexus',
  HELIX: 'helix',
  SHADOW: 'shadow',
});

export const MESSAGE_TOPICS = Object.freeze({
  AGENT_REGISTERED: 'agent.registered',
  HARVEST_TRIGGERED: 'harvest.triggered',
  YIELD_ROUTED: 'yield.routed',
  ARENA_SCORE: 'arena.score',
  ZK_BATCH_VERIFIED: 'zk.batch.verified',
  RESOURCE_ALLOCATED: 'resource.allocated',
  VAULT_ROTATED: 'vault.rotated',
  GLOBAL_PAUSE: 'nexus.global_pause',
});

export const CLOUD_PROVIDERS = Object.freeze({
  AZURE: 'azure',
  AKASH: 'akash',
  VASTAI: 'vastai',
});
