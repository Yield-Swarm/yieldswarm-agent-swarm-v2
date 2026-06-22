import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { PublicKey } from '@solana/web3.js';
import {
  treasuryPda,
  bridgeStatePda,
  harvestRequestPda,
  bridgeMessageBytes,
} from '../src/pdas.js';
import { PROGRAM_IDS, CHAIN_IDS, SEEDS } from '../src/constants.js';

describe('helix pdas', () => {
  const programId = new PublicKey(PROGRAM_IDS.crossChain);
  const agent = new PublicKey('11111111111111111111111111111111');

  it('derives deterministic treasury PDA', () => {
    const [a, bumpA] = treasuryPda(programId);
    const [b, bumpB] = treasuryPda(programId);
    assert.equal(a.equals(b), true);
    assert.equal(bumpA, bumpB);
  });

  it('derives bridge_state PDA', () => {
    const [pda] = bridgeStatePda(programId);
    assert.ok(pda.toBase58().length > 30);
  });

  it('nonce changes harvest request PDA', () => {
    const [a] = harvestRequestPda(agent, 1n, programId);
    const [b] = harvestRequestPda(agent, 2n, programId);
    assert.equal(a.equals(b), false);
  });

  it('builds canonical bridge message bytes', () => {
    const [harvest] = harvestRequestPda(agent, 42n, programId);
    const msg = bridgeMessageBytes(harvest, CHAIN_IDS.HELIX, 1_000_000n, 42n);
    assert.equal(msg.length, 52);
  });

  it('exports expected seeds', () => {
    assert.ok(SEEDS.treasury.toString().includes('treasury'));
  });
});
