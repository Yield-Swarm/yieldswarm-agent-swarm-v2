/**
 * Solenoid 1 — Nexus Chain central orchestrator.
 * Coordinates registry, messaging bus, multi-cloud resources, and Vault.
 */

import { SolenoidRegistry } from './registry.js';
import { CrossSolenoidBus } from './messageBus.js';
import { MultiCloudResourceManager } from './resourceManager.js';
import { VaultSecretClient } from './vaultSecrets.js';
import { MESSAGE_TOPICS, SOLENOID_IDS } from './constants.js';

let singleton = null;

export class NexusOrchestrator {
  constructor() {
    this.registry = new SolenoidRegistry();
    this.bus = new CrossSolenoidBus();
    this.resources = new MultiCloudResourceManager();
    this.vault = new VaultSecretClient();
    this.initialized = false;
    this.globalPaused = false;

    this.bus.subscribe(MESSAGE_TOPICS.GLOBAL_PAUSE, (env) => {
      this.globalPaused = Boolean(env.payload?.paused);
    });
  }

  async init() {
    if (this.initialized) return this.status();
    await this.registry.load();
    this.registry.heartbeat(SOLENOID_IDS.NEXUS);
    this.initialized = true;
    await this.bus.publish(MESSAGE_TOPICS.AGENT_REGISTERED, {
      event: 'nexus_online',
      agentCap: 521,
    }, { sourceSolenoid: SOLENOID_IDS.NEXUS });
    return this.status();
  }

  async registerAgent(input) {
    if (this.globalPaused) throw new Error('nexus global pause active');
    const agent = this.registry.registerAgent(input);
    await this.registry.persist();
    await this.bus.publish(MESSAGE_TOPICS.AGENT_REGISTERED, agent, {
      sourceSolenoid: SOLENOID_IDS.NEXUS,
      targetSolenoid: input.solenoidId,
    });
    return agent;
  }

  async allocateResource(input) {
    if (this.globalPaused) throw new Error('nexus global pause active');
    const alloc = this.resources.allocate(input);
    await this.bus.publish(MESSAGE_TOPICS.RESOURCE_ALLOCATED, alloc, {
      sourceSolenoid: SOLENOID_IDS.NEXUS,
    });
    return alloc;
  }

  async setGlobalPause(paused) {
    this.globalPaused = paused;
    await this.bus.publish(MESSAGE_TOPICS.GLOBAL_PAUSE, { paused }, {
      sourceSolenoid: SOLENOID_IDS.NEXUS,
    });
    return { paused, timestamp: new Date().toISOString() };
  }

  async vaultStatus() {
    const nexusSol = this.registry.solenoids.get(SOLENOID_IDS.NEXUS);
    const secrets = nexusSol
      ? await this.vault.secretsForSolenoid(nexusSol).catch(() => ({}))
      : {};
    return {
      configured: this.vault.configured(),
      pathsLoaded: Object.keys(secrets).filter((k) => secrets[k] != null),
      pathCount: Object.keys(secrets).length,
    };
  }

  status() {
    return {
      solenoid: SOLENOID_IDS.NEXUS,
      initialized: this.initialized,
      globalPaused: this.globalPaused,
      registry: this.registry.snapshot(),
      resources: this.resources.availability(),
      bus: {
        topics: this.bus.topics(),
        recent: this.bus.recent(null, 10),
      },
      vault: { configured: this.vault.configured() },
      timestamp: new Date().toISOString(),
    };
  }
}

export function getNexusOrchestrator() {
  if (!singleton) singleton = new NexusOrchestrator();
  return singleton;
}

export { SolenoidRegistry, CrossSolenoidBus, MultiCloudResourceManager, VaultSecretClient };
