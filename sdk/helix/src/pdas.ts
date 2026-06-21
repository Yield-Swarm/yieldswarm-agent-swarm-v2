import { PublicKey } from '@solana/web3.js';
import { SEEDS, PROGRAM_IDS } from './constants.js';

export function treasuryPda(programId: PublicKey = new PublicKey(PROGRAM_IDS.crossChain)): [PublicKey, number] {
  return PublicKey.findProgramAddressSync([SEEDS.treasury], programId);
}

export function bridgeStatePda(programId: PublicKey = new PublicKey(PROGRAM_IDS.crossChain)): [PublicKey, number] {
  return PublicKey.findProgramAddressSync([SEEDS.bridgeState], programId);
}

export function harvestRequestPda(
  agent: PublicKey,
  nonce: bigint | number,
  programId: PublicKey = new PublicKey(PROGRAM_IDS.crossChain),
): [PublicKey, number] {
  const nonceBuf = Buffer.alloc(8);
  nonceBuf.writeBigUInt64LE(BigInt(nonce));
  return PublicKey.findProgramAddressSync([SEEDS.harvest, agent.toBuffer(), nonceBuf], programId);
}

export function agentRegistryPda(
  agent: PublicKey,
  programId: PublicKey = new PublicKey(PROGRAM_IDS.swarmOps),
): [PublicKey, number] {
  return PublicKey.findProgramAddressSync([SEEDS.agent, agent.toBuffer()], programId);
}

export function swarmConfigPda(programId: PublicKey = new PublicKey(PROGRAM_IDS.swarmOps)): [PublicKey, number] {
  return PublicKey.findProgramAddressSync([SEEDS.swarmConfig], programId);
}

export function coordinatorStatePda(
  programId: PublicKey = new PublicKey(PROGRAM_IDS.coordinator),
): [PublicKey, number] {
  return PublicKey.findProgramAddressSync([SEEDS.coordinator], programId);
}

/** Canonical bridge message bytes for ed25519 attestation. */
export function bridgeMessageBytes(
  harvestRequest: PublicKey,
  originChainId: number,
  amount: bigint,
  nonce: bigint,
): Buffer {
  const buf = Buffer.alloc(32 + 4 + 8 + 8);
  harvestRequest.toBuffer().copy(buf, 0);
  buf.writeUInt32LE(originChainId, 32);
  buf.writeBigUInt64LE(amount, 36);
  buf.writeBigUInt64LE(nonce, 44);
  return buf;
}
