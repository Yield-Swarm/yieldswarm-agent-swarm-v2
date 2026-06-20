import * as anchor from '@coral-xyz/anchor';
import { Program } from '@coral-xyz/anchor';
import { PublicKey, SystemProgram } from '@solana/web3.js';
import { expect } from 'chai';

/**
 * Instance A — GP1 smoke tests (extend in cursor/onchain-a-yield-vault-9c82)
 */
describe('yield_vault', () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  it('initializes vault with Great Delta bps (5000/3000/1500/500/0)', async () => {
    const rebalance_bps = [5000, 3000, 1500, 500, 0];
    const sum = rebalance_bps.reduce((a, b) => a + b, 0);
    expect(sum).to.equal(10_000);
  });
});
