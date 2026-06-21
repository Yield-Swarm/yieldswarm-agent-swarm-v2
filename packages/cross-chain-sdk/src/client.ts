import {
  Connection,
  Keypair,
  PublicKey,
  Transaction,
  TransactionInstruction,
} from '@solana/web3.js';
import {
  BASE_TX_FEE_LAMPORTS,
  BRIDGE_GAS_ESTIMATE_LAMPORTS,
  CROSS_CHAIN_PROGRAM_ID,
  DEFAULT_PRIORITY_FEE_MICROLAMPORTS,
  HELIX_CHAIN_ID,
} from './constants';
import { crossChainConfigPda } from './pda';
import type { BridgeTxStatus, CrossChainConfigAccount, GasEstimate } from './types';

function readU64(data: Uint8Array, offset: number): bigint {
  return new DataView(data.buffer, data.byteOffset, data.byteLength).getBigUint64(offset, true);
}

export function parseCrossChainConfig(data: Uint8Array): CrossChainConfigAccount {
  let o = 8;
  const authority = new PublicKey(data.slice(o, o + 32));
  o += 32;
  const bridgeAuthority = new PublicKey(data.slice(o, o + 32));
  o += 32;
  const treasury = new PublicKey(data.slice(o, o + 32));
  o += 32;
  const helixChainId = readU64(data, o);
  o += 8;
  const totalHarvested = readU64(data, o);
  o += 8;
  const totalReceived = readU64(data, o);
  o += 8;
  const lastNonce = readU64(data, o);

  return {
    authority: authority.toBase58(),
    bridgeAuthority: bridgeAuthority.toBase58(),
    treasury: treasury.toBase58(),
    helixChainId,
    totalHarvested,
    totalReceived,
    lastNonce,
  };
}

export function estimateBridgeGas(computeUnits = 200_000): GasEstimate {
  const priorityFeeLamports = Math.ceil(
    (DEFAULT_PRIORITY_FEE_MICROLAMPORTS * computeUnits) / 1_000_000
  );
  const totalLamports =
    BASE_TX_FEE_LAMPORTS + priorityFeeLamports + BRIDGE_GAS_ESTIMATE_LAMPORTS;

  return {
    baseFeeLamports: BASE_TX_FEE_LAMPORTS,
    priorityFeeLamports,
    bridgeGasLamports: BRIDGE_GAS_ESTIMATE_LAMPORTS,
    totalLamports,
  };
}

export class CrossChainClient {
  constructor(
    public readonly connection: Connection,
    public readonly programId: PublicKey = CROSS_CHAIN_PROGRAM_ID
  ) {}

  async fetchConfig(): Promise<CrossChainConfigAccount | null> {
    const [pda] = crossChainConfigPda(this.programId);
    const info = await this.connection.getAccountInfo(pda);
    if (!info?.data) return null;
    return parseCrossChainConfig(info.data);
  }

  buildTriggerRemoteHarvestIx(
    agent: PublicKey,
    originChainId: bigint,
    targetVault: PublicKey,
    harvestAmount: bigint,
    agentSignature: Uint8Array
  ): TransactionInstruction {
    const [config] = crossChainConfigPda(this.programId);

    const data = new Uint8Array(8 + 8 + 32 + 8 + 64);
    let o = 0;
    const disc = new Uint8Array([0x9a, 0x3b, 0x1c, 0x7e, 0x4f, 0x2a, 0x8d, 0x5b]);
    data.set(disc, o);
    o += 8;
    new DataView(data.buffer).setBigUint64(o, originChainId, true);
    o += 8;
    data.set(targetVault.toBytes(), o);
    o += 32;
    new DataView(data.buffer).setBigUint64(o, harvestAmount, true);
    o += 8;
    data.set(agentSignature, o);

    return new TransactionInstruction({
      programId: this.programId,
      keys: [
        { pubkey: agent, isSigner: true, isWritable: false },
        { pubkey: config, isSigner: false, isWritable: true },
      ],
      data: data as unknown as Buffer,
    });
  }

  async triggerRemoteHarvest(
    payer: Keypair,
    targetVault: PublicKey,
    harvestAmount: bigint,
    agentSignature: Uint8Array,
    originChainId: bigint = HELIX_CHAIN_ID
  ): Promise<BridgeTxStatus> {
    const ix = this.buildTriggerRemoteHarvestIx(
      payer.publicKey,
      originChainId,
      targetVault,
      harvestAmount,
      agentSignature
    );

    const tx = new Transaction().add(ix);
    tx.feePayer = payer.publicKey;
    tx.recentBlockhash = (await this.connection.getLatestBlockhash()).blockhash;
    tx.sign(payer);

    const signature = await this.connection.sendRawTransaction(tx.serialize());
    const confirmation = await this.connection.confirmTransaction(signature, 'confirmed');

    return {
      signature,
      confirmed: !confirmation.value.err,
      slot: confirmation.context.slot,
      err: confirmation.value.err ? JSON.stringify(confirmation.value.err) : null,
    };
  }

  listenBridgeExecutions(
    onEvent: (logs: { signature: string; logs: string[] }) => void
  ): number {
    return this.connection.onLogs(this.programId, (logInfo) => {
      if (logInfo.err) return;
      onEvent({ signature: logInfo.signature, logs: logInfo.logs });
    });
  }

  removeBridgeListener(id: number): Promise<void> {
    return this.connection.removeOnLogsListener(id);
  }
}

export async function waitForBridgeConfirmation(
  connection: Connection,
  signature: string,
  commitment: 'processed' | 'confirmed' | 'finalized' = 'confirmed'
): Promise<BridgeTxStatus> {
  const result = await connection.confirmTransaction(signature, commitment);
  return {
    signature,
    confirmed: !result.value.err,
    slot: result.context.slot,
    err: result.value.err ? JSON.stringify(result.value.err) : null,
  };
}
