/**
 * Command dashboard adapter tests.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { getCommandOverview } from './commandDashboard.js';
import { getConfiguredDomains } from './unstoppableDomains.js';

describe('command dashboard', () => {
  it('returns fused overview with three solenoids', async () => {
    const data = await getCommandOverview();
    assert.ok(data.solenoids.nexus);
    assert.ok(data.solenoids.helix);
    assert.ok(data.solenoids.shadow);
    assert.equal(data.agents.cap, 521);
  });

  it('includes 14 spiritual elevators', async () => {
    const data = await getCommandOverview();
    assert.equal(data.spiritual_elevators.length, 14);
    assert.equal(data.spiritual_elevators[0].title, 'Emerald Tablets of Thoth');
    assert.equal(data.spiritual_elevators[13].title, 'Tao Te Ching');
  });

  it('includes IoTeX mining root', async () => {
    const data = await getCommandOverview();
    assert.ok(data.treasury.mining_roots.iotex);
    assert.ok(data.treasury.mining_roots.iotex.startsWith('0x'));
  });

  it('reports system health', async () => {
    const data = await getCommandOverview();
    assert.ok(['healthy', 'degraded', 'critical'].includes(data.system.overall));
  });
});

describe('unstoppable domains', () => {
  it('has default domain list', () => {
    const domains = getConfiguredDomains();
    assert.ok(domains.includes('yieldswarm.crypto'));
  });
});
