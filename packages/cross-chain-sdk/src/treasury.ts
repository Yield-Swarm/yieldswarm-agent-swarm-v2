import { Connection, PublicKey } from '@solana/web3.js';
import { CROSS_CHAIN_PROGRAM_ID, MINING_ROOT_LIST } from './constants';
import { miningRootPda, treasuryRegistryPda } from './pda';
import type { MiningRootAccount, TreasuryRegistryAccount } from './types';

function readU64(data: Uint8Array, offset: number): bigint {
  return new DataView(data.buffer, data.byteOffset, data.byteLength).getBigUint64(offset, true);
}

function readPubkey(data: Uint8Array, offset: number): string {
  return new PublicKey(data.slice(offset, offset + 32)).toBase58();
}

function readBytesAsUtf8(data: Uint8Array, offset: number, len: number): string {
  return new TextDecoder().decode(data.slice(offset, offset + len));
}

export function parseTreasuryRegistry(data: Uint8Array): TreasuryRegistryAccount {
  let o = 8;
  const authority = readPubkey(data, o);
  o += 32;
  const nexusAuthority = readPubkey(data, o);
  o += 32;
  const nexusTreasury = readPubkey(data, o);
  o += 32;
  const pausedSweeps = data[o] === 1;
  o += 1;
  const pausedInflows = data[o] === 1;
  o += 1;
  const totalToNexus = readU64(data, o);
  o += 8;
  const totalToMining = readU64(data, o);
  o += 8;
  const miningRootCount = data[o];

  return {
    authority,
    nexusAuthority,
    nexusTreasury,
    pausedSweeps,
    pausedInflows,
    totalToNexus,
    totalToMining,
    miningRootCount,
  };
}

export function parseMiningRoot(data: Uint8Array): MiningRootAccount {
  let o = 8;
  const registry = readPubkey(data, o);
  o += 32;
  const rootKind = data[o];
  o += 1;
  const chainFamily = data[o];
  o += 1;
  const addressBytes = data.slice(o, o + 64);
  o += 64;
  const addressLen = data[o];
  o += 1;
  const solanaRecipient = readPubkey(data, o);
  o += 32;
  const totalRouted = readU64(data, o);
  o += 8;
  const active = data[o] === 1;

  const address = readBytesAsUtf8(addressBytes, 0, addressLen);

  return {
    registry,
    rootKind,
    chainFamily,
    address,
    solanaRecipient,
    totalRouted,
    active,
  };
}

export async function fetchTreasuryRegistry(
  connection: Connection,
  programId: PublicKey = CROSS_CHAIN_PROGRAM_ID
): Promise<TreasuryRegistryAccount | null> {
  const [pda] = treasuryRegistryPda(programId);
  const info = await connection.getAccountInfo(pda);
  if (!info?.data) return null;
  return parseTreasuryRegistry(info.data);
}

export async function fetchAllMiningRoots(
  connection: Connection,
  programId: PublicKey = CROSS_CHAIN_PROGRAM_ID
): Promise<MiningRootAccount[]> {
  const roots: MiningRootAccount[] = [];
  for (const meta of MINING_ROOT_LIST) {
    const [pda] = miningRootPda(meta.kind, programId);
    const info = await connection.getAccountInfo(pda);
    if (info?.data) {
      roots.push(parseMiningRoot(info.data));
    } else {
      roots.push({
        registry: '',
        rootKind: meta.kind,
        chainFamily: meta.chainFamily,
        address: meta.address,
        solanaRecipient: 'solana' in meta ? meta.solana.toBase58() : '',
        totalRouted: 0n,
        active: true,
      });
    }
  }
  return roots;
}

export function selectMiningRootForOrigin(originChainId: bigint): number {
  // Helix / Solana internal yield → Nexus Treasury (caller uses DEST_NEXUS_TREASURY).
  // Map common origin chain ids to mining roots for external DePIN rewards.
  const id = Number(originChainId);
  if (id === 8453 || id === 84532) return 0; // Base → ETC root default
  if (id === 1337) return 2; // PRL test id
  return 0;
}
