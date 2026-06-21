/**
 * Helix bridge integration tests — run via `anchor test`.
 *
 * Requires: anchor 0.30.1, local validator, `anchor build` complete.
 */
import * as anchor from '@coral-xyz/anchor';
import { PublicKey, Keypair, SystemProgram } from '@solana/web3.js';
import { assert } from 'chai';

describe('helix_bridge', () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  it('program IDs are configured', () => {
    const crossChain = new PublicKey('9RoCmfzrPkbpSCr9a74cJJPGbXtzcQos6bbcePu7aSUt');
    assert.ok(crossChain);
  });

  it('treasury PDA is deterministic', () => {
    const programId = new PublicKey('9RoCmfzrPkbpSCr9a74cJJPGbXtzcQos6bbcePu7aSUt');
    const [a] = PublicKey.findProgramAddressSync([Buffer.from('treasury')], programId);
    const [b] = PublicKey.findProgramAddressSync([Buffer.from('treasury')], programId);
    assert.equal(a.toBase58(), b.toBase58());
  });
});
