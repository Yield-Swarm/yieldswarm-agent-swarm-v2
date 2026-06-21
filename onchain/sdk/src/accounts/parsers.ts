import { PublicKey } from '@solana/web3.js';
import { PROGRAM_IDS, PDA_SEEDS } from '../index';

/** BridgeState account layout (matches on-chain). */
export interface BridgeStateAccount {
  authority: PublicKey;
  treasury: PublicKey;
  totalReceived: bigint;
  lastHarvestTs: bigint;
  bump: number;
}

export function bridgeStatePda(): [PublicKey, number] {
  return PublicKey.findProgramAddressSync(
    [Buffer.from('bridge_state')],
    PROGRAM_IDS.crossChain,
  );
}

export function parseBridgeState(data: Buffer): BridgeStateAccount {
  let offset = 8; // anchor discriminator
  const authority = new PublicKey(data.subarray(offset, offset + 32));
  offset += 32;
  const treasury = new PublicKey(data.subarray(offset, offset + 32));
  offset += 32;
  const totalReceived = data.readBigUInt64LE(offset);
  offset += 8;
  const lastHarvestTs = data.readBigInt64LE(offset);
  offset += 8;
  const bump = data.readUInt8(offset);
  return { authority, treasury, totalReceived, lastHarvestTs, bump };
}

/** ShardVault account layout. */
export interface ShardVaultAccount {
  shardId: bigint;
  authority: PublicKey;
  totalAssets: bigint;
  targetWeightBps: number;
  bump: number;
}

export function shardVaultPda(shardId: bigint | number): [PublicKey, number] {
  const id = typeof shardId === 'bigint' ? shardId : BigInt(shardId);
  const buf = Buffer.alloc(8);
  buf.writeBigUInt64LE(id);
  return PublicKey.findProgramAddressSync(
    [Buffer.from(PDA_SEEDS.shardVault), buf],
    PROGRAM_IDS.coordinator,
  );
}

export function parseShardVault(data: Buffer): ShardVaultAccount {
  let offset = 8;
  const shardId = data.readBigUInt64LE(offset);
  offset += 8;
  const authority = new PublicKey(data.subarray(offset, offset + 32));
  offset += 32;
  const totalAssets = data.readBigUInt64LE(offset);
  offset += 8;
  const targetWeightBps = data.readUInt16LE(offset);
  offset += 2;
  const bump = data.readUInt8(offset);
  return { shardId, authority, totalAssets, targetWeightBps, bump };
}

export function vaultCoordinatorPda(): [PublicKey, number] {
  return PublicKey.findProgramAddressSync(
    [Buffer.from('vault_coordinator')],
    PROGRAM_IDS.coordinator,
  );
}
