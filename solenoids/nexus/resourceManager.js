/**
 * Multi-cloud resource manager — Azure, Akash, Vast.ai allocation plane.
 */

import { CLOUD_PROVIDERS } from './constants.js';

const DEFAULT_CAPACITY = {
  [CLOUD_PROVIDERS.AZURE]: { gpu: 8, cpu: 32, memoryGb: 128 },
  [CLOUD_PROVIDERS.AKASH]: { gpu: 16, cpu: 64, memoryGb: 256 },
  [CLOUD_PROVIDERS.VASTAI]: { gpu: 24, cpu: 96, memoryGb: 384 },
};

export class MultiCloudResourceManager {
  constructor() {
    /** @type {Map<string, object>} */
    this.allocations = new Map();
    this.capacity = { ...DEFAULT_CAPACITY };
  }

  setCapacity(provider, caps) {
    if (!this.capacity[provider]) {
      throw new Error(`unknown provider ${provider}`);
    }
    this.capacity[provider] = { ...this.capacity[provider], ...caps };
    return this.capacity[provider];
  }

  _used(provider) {
    let gpu = 0;
    let cpu = 0;
    let memoryGb = 0;
    for (const alloc of this.allocations.values()) {
      if (alloc.provider !== provider || alloc.status !== 'active') continue;
      gpu += alloc.gpu || 0;
      cpu += alloc.cpu || 0;
      memoryGb += alloc.memoryGb || 0;
    }
    return { gpu, cpu, memoryGb };
  }

  availability() {
    return Object.fromEntries(
      Object.entries(this.capacity).map(([provider, cap]) => {
        const used = this._used(provider);
        return [provider, {
          total: cap,
          used,
          available: {
            gpu: Math.max(0, cap.gpu - used.gpu),
            cpu: Math.max(0, cap.cpu - used.cpu),
            memoryGb: Math.max(0, cap.memoryGb - used.memoryGb),
          },
        }];
      }),
    );
  }

  allocate({ workloadId, provider, gpu = 1, cpu = 4, memoryGb = 16, solenoidId = 'nexus' }) {
    if (!this.capacity[provider]) {
      throw new Error(`unknown provider ${provider}`);
    }
    const avail = this.availability()[provider].available;
    if (gpu > avail.gpu || cpu > avail.cpu || memoryGb > avail.memoryGb) {
      throw new Error(`insufficient ${provider} capacity`);
    }
    if (this.allocations.has(workloadId)) {
      throw new Error(`workload ${workloadId} already allocated`);
    }

    const entry = {
      workloadId,
      provider,
      solenoidId,
      gpu,
      cpu,
      memoryGb,
      status: 'active',
      createdAt: new Date().toISOString(),
      vaultInjectTemplate: `vault/inject/templates/${provider}.env.ctmpl`,
    };
    this.allocations.set(workloadId, entry);
    return entry;
  }

  release(workloadId) {
    const alloc = this.allocations.get(workloadId);
    if (!alloc) throw new Error(`workload ${workloadId} not found`);
    alloc.status = 'released';
    alloc.releasedAt = new Date().toISOString();
    return alloc;
  }

  list({ provider = null, solenoidId = null } = {}) {
    return [...this.allocations.values()].filter((a) => {
      if (provider && a.provider !== provider) return false;
      if (solenoidId && a.solenoidId !== solenoidId) return false;
      return true;
    });
  }
}
