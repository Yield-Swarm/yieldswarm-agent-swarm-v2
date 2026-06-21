/**
 * Solenoid Registry — tracks Nexus, Helix, Shadow Chain and up to 521 agents.
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { MAX_AGENTS, SOLENOID_IDS } from './constants.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const CONFIG_PATH = path.join(REPO_ROOT, 'config', 'solenoids.json');
const STATE_PATH = process.env.NEXUS_REGISTRY_STATE ||
  path.join(REPO_ROOT, '.run', 'nexus-registry.json');

export class SolenoidRegistry {
  constructor() {
    /** @type {Map<string, object>} */
    this.solenoids = new Map();
    /** @type {Map<string, object>} */
    this.agents = new Map();
    this.config = null;
    this.loadedAt = null;
  }

  async load() {
    const raw = await fs.readFile(CONFIG_PATH, 'utf8');
    this.config = JSON.parse(raw);

    for (const sol of this.config.solenoids) {
      this.solenoids.set(sol.id, {
        ...sol,
        status: 'active',
        lastHeartbeat: null,
        agentCount: 0,
      });
    }

    try {
      const stateRaw = await fs.readFile(STATE_PATH, 'utf8');
      const state = JSON.parse(stateRaw);
      for (const agent of state.agents || []) {
        this.agents.set(agent.id, agent);
      }
      for (const [id, meta] of Object.entries(state.solenoidMeta || {})) {
        const sol = this.solenoids.get(id);
        if (sol) Object.assign(sol, meta);
      }
    } catch {
      // cold start
    }

    this._recomputeAgentCounts();
    this.loadedAt = new Date().toISOString();
    return this.snapshot();
  }

  _recomputeAgentCounts() {
    for (const sol of this.solenoids.values()) {
      sol.agentCount = 0;
    }
    for (const agent of this.agents.values()) {
      const sol = this.solenoids.get(agent.solenoidId || SOLENOID_IDS.HELIX);
      if (sol) sol.agentCount += 1;
    }
  }

  async persist() {
    await fs.mkdir(path.dirname(STATE_PATH), { recursive: true });
    const payload = {
      updatedAt: new Date().toISOString(),
      agents: [...this.agents.values()],
      solenoidMeta: Object.fromEntries(
        [...this.solenoids.entries()].map(([id, s]) => [id, {
          status: s.status,
          lastHeartbeat: s.lastHeartbeat,
        }]),
      ),
    };
    await fs.writeFile(STATE_PATH, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
  }

  registerAgent({ id, pubkey, solenoidId = SOLENOID_IDS.HELIX, permissions = 0, dailyLimit = 0 }) {
    if (this.agents.size >= MAX_AGENTS) {
      throw new Error(`agent cap ${MAX_AGENTS} reached`);
    }
    if (this.agents.has(id)) {
      throw new Error(`agent ${id} already registered`);
    }
    const entry = {
      id,
      pubkey,
      solenoidId,
      permissions,
      dailyLimit,
      registeredAt: new Date().toISOString(),
      harvestCount: 0,
      reputation: 0,
    };
    this.agents.set(id, entry);
    this._recomputeAgentCounts();
    return entry;
  }

  heartbeat(solenoidId) {
    const sol = this.solenoids.get(solenoidId);
    if (!sol) throw new Error(`unknown solenoid ${solenoidId}`);
    sol.lastHeartbeat = new Date().toISOString();
    sol.status = 'active';
    return sol;
  }

  snapshot() {
    return {
      maxAgents: MAX_AGENTS,
      agentCount: this.agents.size,
      slotsRemaining: MAX_AGENTS - this.agents.size,
      loadedAt: this.loadedAt,
      solenoids: [...this.solenoids.values()],
      agents: [...this.agents.values()].slice(0, 50),
      agentsTruncated: this.agents.size > 50,
    };
  }
}
