import { describe, expect, it } from 'vitest';
import {
  mintPowId,
  mintPosId,
  mintPowUiId,
  resolveEncryptedId,
  isEncryptedSwarmId,
  redactForLogs,
} from '../../lib/encrypted-swarm-id.mjs';

describe('encrypted-swarm-id', () => {
  it('mints and resolves PoW id', () => {
    const token = mintPowId('asic-z15-unit-07', { rack: 'nm-solar' });
    expect(isEncryptedSwarmId(token)).toBe(true);
    expect(token.startsWith('ys_pow_')).toBe(true);
    const { plaintext } = resolveEncryptedId(token);
    expect(plaintext.id).toBe('asic-z15-unit-07');
  });

  it('mints PoS and PoWUI types', () => {
    const pos = mintPosId('validator-mainnet-1');
    const ui = mintPowUiId('arena-session-abc');
    expect(resolveEncryptedId(pos).type).toBe('pos');
    expect(resolveEncryptedId(ui).type).toBe('powui');
  });

  it('redacts for logs', () => {
    const token = mintPowId('secret-worker');
    expect(redactForLogs(token)).toMatch(/^ys_pow_/);
    expect(redactForLogs('0x1234567890abcdef')).toMatch(/…/);
  });
});
