/**
 * Swarm 4 — 35-layer mesh + headless game backend worker pool.
 * Scales async agent ticks (10k+ terminal agents simulation).
 */

import { mintPowId, mintPowUiId } from '../../lib/encrypted-swarm-id.mjs';

const LAYERS = 35;
const DEFAULT_AGENTS = Number(process.env.MESH_AGENT_COUNT || 128);

export class AgentMeshPool {
  constructor(options = {}) {
    this.layers = options.layers ?? LAYERS;
    this.maxAgents = options.maxAgents ?? DEFAULT_AGENTS;
    this.agents = new Map();
  }

  spawn(agentIndex, meta = {}) {
    const raw = `mesh-agent-${agentIndex}`;
    const record = {
      index: agentIndex,
      encrypted_pow_id: mintPowId(raw, { layer: 'mesh', ...meta }),
      encrypted_powui_id: mintPowUiId(raw, { surface: 'arena' }),
      skill_xp: {},
      geo_multiplier: 1.0,
      status: 'idle',
    };
    this.agents.set(agentIndex, record);
    return record;
  }

  async tickBatch(size = 32) {
    const results = [];
    for (let i = 0; i < size; i += 1) {
      const idx = (Date.now() + i) % this.maxAgents;
      if (!this.agents.has(idx)) this.spawn(idx);
      const agent = this.agents.get(idx);
      agent.status = 'active';
      agent.skill_xp.Compute_Harvesting = (agent.skill_xp.Compute_Harvesting || 0) + 1;
      results.push({ idx, pow_id: agent.encrypted_pow_id.slice(0, 20) + '…' });
    }
    return { layers: this.layers, ticked: results.length, agents: results };
  }
}

export function createMeshPool(options) {
  return new AgentMeshPool(options);
}

export default { AgentMeshPool, createMeshPool, LAYERS };
