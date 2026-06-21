/**
 * Helix on-chain bridge helpers (Solenoid 2).
 * Program IDs and PDAs — sync with Anchor.toml / HELIX.md.
 */

import { PublicKey } from '@solana/web3.js';
import config from '../config.js';

export const HELIX_PROGRAM_IDS = {
  crossChain: new PublicKey('9RoCmfzrPkbpSCr9a74cJJPGbXtzcQos6bbcePu7aSUt'),
  swarmOps: new PublicKey('6BbH4rvmxERTbcAbEat9SzT3N3P9fEFWvoAD3EsJ3BAz'),
  coordinator: new PublicKey('DXGVx4HsitGdFawg5KL68SAq9URhTaNL9tZAWWGGbo7p'),
};

export const CHAIN_IDS = {
  HELIX: 1,
  SOLANA: 2,
  ETHEREUM: 3,
};

export function bridgeStatePda() {
  return PublicKey.findProgramAddressSync(
    [Buffer.from('bridge_state')],
    HELIX_PROGRAM_IDS.crossChain,
  );
}

export function treasuryPda() {
  return PublicKey.findProgramAddressSync(
    [Buffer.from('treasury')],
    HELIX_PROGRAM_IDS.crossChain,
  );
}

export function harvestRequestPda(agentPubkey, nonce) {
  const nonceBuf = Buffer.alloc(8);
  nonceBuf.writeBigUInt64LE(BigInt(nonce));
  return PublicKey.findProgramAddressSync(
    [Buffer.from('harvest'), agentPubkey.toBuffer(), nonceBuf],
    HELIX_PROGRAM_IDS.crossChain,
  );
}

/**
 * Dry-run settlement quote for agent harvest planning.
 * Does not sign or submit transactions.
 */
export async function quoteHelixSettlement({
  agentPubkey,
  originChainId = CHAIN_IDS.HELIX,
  targetChainId = CHAIN_IDS.SOLANA,
  amount = 0,
}) {
  const lockdown = String(process.env.NETWORK_LOCKDOWN_MODE || '').toLowerCase() === 'true';
  const dryRun = process.env.CROSS_CHAIN_DRY_RUN !== '0';

  const [bridgePda] = bridgeStatePda();
  const [treasury] = treasuryPda();

  let bridgePaused = false;
  let harvestNonce = 0;

  // Best-effort chain read when RPC is configured
  const rpc = process.env.SOLANA_RPC_URL || process.env.QUICKNODE_SOLANA_RPC_URL;
  if (rpc && agentPubkey) {
    try {
      const { Connection } = await import('@solana/web3.js');
      const conn = new Connection(rpc, 'confirmed');
      const info = await conn.getAccountInfo(bridgePda);
      bridgePaused = !info;
      harvestNonce = 0;
    } catch {
      bridgePaused = lockdown;
    }
  } else {
    bridgePaused = lockdown;
  }

  const nextNonce = harvestNonce + 1;
  const agent = agentPubkey ? new PublicKey(agentPubkey) : null;
  const [harvestPda] = agent
    ? harvestRequestPda(agent, nextNonce)
    : [PublicKey.default];

  const blocked = lockdown || bridgePaused;
  const maxSlippageBps = Number(process.env.SLIPPAGE_TOLERANCE || 0.005) * 10_000 || 50;

  return {
    dryRun,
    blocked,
    lockdown,
    bridgePaused,
    bridgePda: bridgePda.toBase58(),
    treasury: treasury.toBase58(),
    harvestPda: harvestPda.toBase58(),
    nonce: nextNonce,
    originChainId,
    targetChainId,
    amount,
    maxSlippageBps: Math.min(maxSlippageBps, 50),
    bridgeConfigured: Boolean(config.helix?.bridgeKey),
    programs: {
      crossChain: HELIX_PROGRAM_IDS.crossChain.toBase58(),
      swarmOps: HELIX_PROGRAM_IDS.swarmOps.toBase58(),
      coordinator: HELIX_PROGRAM_IDS.coordinator.toBase58(),
    },
  };
}
