/**
 * @vitest-environment node
 */
import { describe, it, expect, beforeEach } from 'vitest';
import {
  getAgentContext,
  appendMessage,
  routeRequest,
  resetContext,
} from '../infrastructure/odysseus-router.js';

describe('odysseus-router — per-agent isolation', () => {
  beforeEach(() => {
    resetContext('42');
    resetContext('99');
  });

  it('isolates contexts by tokenId', () => {
    appendMessage('42', { role: 'user', content: 'agent-A-only' });
    appendMessage('99', { role: 'user', content: 'agent-B-only' });
    expect(getAgentContext('42').messages).toHaveLength(1);
    expect(getAgentContext('99').messages[0].content).toBe('agent-B-only');
  });

  it('prunes when exceeding token cap', () => {
    const long = 'x'.repeat(40_000);
    appendMessage('42', { role: 'user', content: long });
    expect(getAgentContext('42').tokenCount).toBeLessThanOrEqual(8192);
  });

  it('routes with tier-aware model selection', () => {
    const route = routeRequest({ tokenId: '42', task: 'inference', tier: 4 });
    expect(route.isolated).toBe(true);
    expect(route.model).toContain('5090');
    expect(route.layers.greek).toBe('context_isolated');
  });
});
