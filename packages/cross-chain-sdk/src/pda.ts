import { PublicKey } from '@solana/web3.js';
import { CROSS_CHAIN_PROGRAM_ID, SHARD_COORDINATOR_PROGRAM_ID, SWARM_OPS_PROGRAM_ID } from './constants';

function u16le(value: number): Uint8Array {
  const buf = new Uint8Array(2);
  new DataView(buf.buffer).setUint16(0, value, true);
  return buf;
}

function u64le(value: bigint): Uint8Array {
  const buf = new Uint8Array(8);
  new DataView(buf.buffer).setBigUint64(0, value, true);
  return buf;
}

export function crossChainConfigPda(
  programId: PublicKey = CROSS_CHAIN_PROGRAM_ID
): [PublicKey, number] {
  return PublicKey.findProgramAddressSync([new TextEncoder().encode('cross_chain_config')], programId);
}

export function treasuryVaultPda(
  config: PublicKey,
  programId: PublicKey = CROSS_CHAIN_PROGRAM_ID
): [PublicKey, number] {
  return PublicKey.findProgramAddressSync(
    [new TextEncoder().encode('treasury_vault'), config.toBytes()],
    programId
  );
}

export function treasuryTokenPda(
  config: PublicKey,
  programId: PublicKey = CROSS_CHAIN_PROGRAM_ID
): [PublicKey, number] {
  return PublicKey.findProgramAddressSync(
    [new TextEncoder().encode('treasury_token'), config.toBytes()],
    programId
  );
}

export function shardVaultPda(
  shardId: number,
  programId: PublicKey = SHARD_COORDINATOR_PROGRAM_ID
): [PublicKey, number] {
  return PublicKey.findProgramAddressSync(
    [new TextEncoder().encode('shard_vault'), u16le(shardId)],
    programId
  );
}

export function coordinatorPda(
  programId: PublicKey = SHARD_COORDINATOR_PROGRAM_ID
): [PublicKey, number] {
  return PublicKey.findProgramAddressSync([new TextEncoder().encode('coordinator')], programId);
}

export function treasuryRegistryPda(
  programId: PublicKey = CROSS_CHAIN_PROGRAM_ID
): [PublicKey, number] {
  return PublicKey.findProgramAddressSync([new TextEncoder().encode('treasury_registry')], programId);
}

export function miningRootPda(
  rootKind: number,
  programId: PublicKey = CROSS_CHAIN_PROGRAM_ID
): [PublicKey, number] {
  return PublicKey.findProgramAddressSync(
    [new TextEncoder().encode('mining_root'), Uint8Array.of(rootKind)],
    programId
  );
}

export function proposalPda(
  proposalId: bigint,
  programId: PublicKey = SWARM_OPS_PROGRAM_ID
): [PublicKey, number] {
  return PublicKey.findProgramAddressSync(
    [new TextEncoder().encode('proposal'), u64le(proposalId)],
    programId
  );
}

export function approvalPda(
  proposal: PublicKey,
  approver: PublicKey,
  programId: PublicKey = SWARM_OPS_PROGRAM_ID
): [PublicKey, number] {
  return PublicKey.findProgramAddressSync(
    [new TextEncoder().encode('approval'), proposal.toBytes(), approver.toBytes()],
    programId
  );
}
