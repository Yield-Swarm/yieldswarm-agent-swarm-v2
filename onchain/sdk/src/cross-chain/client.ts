import {
  Connection,
  PublicKey,
  Transaction,
  TransactionInstruction,
} from '@solana/web3.js';
import { PROGRAM_IDS } from '../index';
import { bridgeStatePda, parseBridgeState } from '../accounts/parsers';
import {
  CHAIN_IOTEX,
  YIELD_DEST_BTC_IOPAY,
  YIELD_DEST_IOTEX,
  YIELD_DEST_NEXUS,
  YieldDestination,
  treasuryRoutingPda,
} from './iotex';
import { getIotexRoutingConfig } from '../treasury/manifest';

export const HELIX_CHAIN_ID = 0x484c58; // "HLX"

export { CHAIN_IOTEX, YIELD_DEST_NEXUS, YIELD_DEST_IOTEX, YIELD_DEST_BTC_IOPAY };
export type { YieldDestination };
export { resolveIotexRoutingFromManifest, treasuryRoutingPda } from './iotex';

export interface HarvestEvent {
  authority: PublicKey;
  originChainId: number;
  targetTreasury: PublicKey;
  timestamp: number;
}

export interface YieldReceivedEvent {
  amount: bigint;
  sourceChainId: number;
  treasury: PublicKey;
  agent: PublicKey;
  timestamp: number;
}

/**
 * Client for cross-chain bridge instructions (Helix Chain ↔ Solana).
 */
export class CrossChainClient {
  constructor(
    readonly connection: Connection,
    readonly programId: PublicKey = PROGRAM_IDS.crossChain,
  ) {}

  async fetchBridgeState(): Promise<ReturnType<typeof parseBridgeState> | null> {
    const [pda] = bridgeStatePda();
    const info = await this.connection.getAccountInfo(pda);
    if (!info?.data) return null;
    return parseBridgeState(info.data);
  }

  buildTriggerRemoteHarvestIx(
    authority: PublicKey,
    originChainId: number,
  ): TransactionInstruction {
    const [bridgeState] = bridgeStatePda();
    const data = Buffer.alloc(8);
    data.writeUInt32LE(originChainId, 0);
    return new TransactionInstruction({
      programId: this.programId,
      keys: [
        { pubkey: authority, isSigner: true, isWritable: false },
        { pubkey: bridgeState, isSigner: false, isWritable: true },
      ],
      data: Buffer.concat([
        Buffer.from([0x9a, 0x2f, 0x1c, 0x8b, 0x4d, 0x6e, 0x3a, 0x7f]), // placeholder discriminator
        data.subarray(0, 4),
      ]),
    });
  }

  buildReceiveYieldIx(
    relayer: PublicKey,
    treasury: PublicKey,
    amount: bigint,
    sourceChainId: number,
  ): TransactionInstruction {
    const [bridgeState] = bridgeStatePda();
    const payload = Buffer.alloc(12);
    payload.writeBigUInt64LE(amount, 0);
    payload.writeUInt32LE(sourceChainId, 8);
    return new TransactionInstruction({
      programId: this.programId,
      keys: [
        { pubkey: relayer, isSigner: true, isWritable: false },
        { pubkey: bridgeState, isSigner: false, isWritable: true },
        { pubkey: treasury, isSigner: false, isWritable: true },
      ],
      data: Buffer.concat([
        Buffer.from([0x3c, 0x5e, 0x7a, 0x1d, 0x9b, 0x4f, 0x2e, 0x6c]),
        payload,
      ]),
    });
  }

  async triggerRemoteHarvest(
    authority: PublicKey,
    originChainId: number = HELIX_CHAIN_ID,
  ): Promise<string> {
    const ix = this.buildTriggerRemoteHarvestIx(authority, originChainId);
    const tx = new Transaction().add(ix);
    tx.feePayer = authority;
    tx.recentBlockhash = (await this.connection.getLatestBlockhash()).blockhash;
    return tx.serialize({ requireAllSignatures: false }).toString('base64');
  }

  buildRouteYieldIx(
    relayer: PublicKey,
    treasury: PublicKey,
    amount: bigint,
    sourceChainId: number,
    destination: YieldDestination,
  ): TransactionInstruction {
    const [bridgeState] = bridgeStatePda();
    const [routingConfig] = treasuryRoutingPda();
    const payload = Buffer.alloc(13);
    payload.writeBigUInt64LE(amount, 0);
    payload.writeUInt32LE(sourceChainId, 8);
    payload.writeUInt8(destination, 12);
    return new TransactionInstruction({
      programId: this.programId,
      keys: [
        { pubkey: relayer, isSigner: true, isWritable: false },
        { pubkey: bridgeState, isSigner: false, isWritable: true },
        { pubkey: routingConfig, isSigner: false, isWritable: true },
        { pubkey: treasury, isSigner: false, isWritable: true },
      ],
      data: Buffer.concat([
        Buffer.from([0x7b, 0x2a, 0x9e, 0x4c, 0x1f, 0x8d, 0x6b, 0x3a]),
        payload,
      ]),
    });
  }

  /** Route yield to IoTeX treasury per TREASURY_MANIFEST.json. */
  buildRouteToIotexIx(
    relayer: PublicKey,
    treasury: PublicKey,
    amount: bigint,
    sourceChainId: number = CHAIN_IOTEX,
  ): TransactionInstruction {
    return this.buildRouteYieldIx(
      relayer,
      treasury,
      amount,
      sourceChainId,
      YIELD_DEST_IOTEX,
    );
  }

  /** Route yield to BTC address via IOPAY bridge. */
  buildRouteToBtcIopayIx(
    relayer: PublicKey,
    treasury: PublicKey,
    amount: bigint,
    sourceChainId: number = CHAIN_IOTEX,
  ): TransactionInstruction {
    return this.buildRouteYieldIx(
      relayer,
      treasury,
      amount,
      sourceChainId,
      YIELD_DEST_BTC_IOPAY,
    );
  }

  getManifestRouting() {
    return getIotexRoutingConfig();
  }
}

export async function fetchBridgeStateOrThrow(
  connection: Connection,
): Promise<NonNullable<Awaited<ReturnType<CrossChainClient['fetchBridgeState']>>>> {
  const client = new CrossChainClient(connection);
  const state = await client.fetchBridgeState();
  if (!state) {
    throw new Error('BridgeState PDA not initialized');
  }
  return state;
}
