import {
  Connection,
  Keypair,
  PublicKey,
  SystemProgram,
  Transaction,
  TransactionInstruction,
  LAMPORTS_PER_SOL,
} from '@solana/web3.js';
import { Program, AnchorProvider, BN, Idl } from '@coral-xyz/anchor';
import crossChainIdl from './idl/cross_chain.json' with { type: 'json' };
import {
  PROGRAM_IDS,
  CHAIN_IDS,
  DEFAULT_MAX_SLIPPAGE_BPS,
  BridgeConfig,
  GasEstimate,
  HarvestParams,
  BridgeEventLog,
  EVENT_KIND,
} from './constants.js';
import {
  bridgeStatePda,
  treasuryPda,
  harvestRequestPda,
  agentRegistryPda,
  swarmConfigPda,
  coordinatorStatePda,
  bridgeMessageBytes,
} from './pdas.js';

export interface HelixClientOptions {
  connection: Connection;
  wallet: AnchorProvider['wallet'];
  crossChainProgramId?: PublicKey;
  swarmOpsProgramId?: PublicKey;
  coordinatorProgramId?: PublicKey;
}

/**
 * HelixClient — TypeScript SDK for Solenoid 2 cross-chain yield execution.
 */
export class HelixClient {
  readonly connection: Connection;
  readonly provider: AnchorProvider;
  readonly program: Program;
  readonly crossChainProgramId: PublicKey;
  readonly swarmOpsProgramId: PublicKey;
  readonly coordinatorProgramId: PublicKey;

  private logListeners = new Map<number, () => void>();

  constructor(opts: HelixClientOptions) {
    this.connection = opts.connection;
    this.provider = new AnchorProvider(opts.connection, opts.wallet, {
      commitment: 'confirmed',
      preflightCommitment: 'confirmed',
    });
    this.crossChainProgramId = opts.crossChainProgramId ?? new PublicKey(PROGRAM_IDS.crossChain);
    this.swarmOpsProgramId = opts.swarmOpsProgramId ?? new PublicKey(PROGRAM_IDS.swarmOps);
    this.coordinatorProgramId = opts.coordinatorProgramId ?? new PublicKey(PROGRAM_IDS.coordinator);
    this.program = new Program(crossChainIdl as Idl, this.provider);
  }

  /** Fetch parsed bridge configuration. */
  async getBridgeConfig(): Promise<BridgeConfig> {
    const [bridgePda] = bridgeStatePda(this.crossChainProgramId);
    const state = await (this.program.account as any).bridgeState.fetch(bridgePda);
    return {
      bridgeAuthority: state.bridgeAuthority.toBase58(),
      minHarvestAmount: BigInt(state.minHarvestAmount.toString()),
      maxSlippageBps: state.maxSlippageBps,
      bridgeFeeLamports: BigInt(state.bridgeFeeLamports.toString()),
      paused: state.paused,
    };
  }

  /** Read current harvest nonce (next nonce = nonce + 1). */
  async getHarvestNonce(): Promise<bigint> {
    const [bridgePda] = bridgeStatePda(this.crossChainProgramId);
    const state = await (this.program.account as any).bridgeState.fetch(bridgePda);
    return BigInt(state.harvestNonce.toString());
  }

  /** Estimate transaction cost for a harvest trigger. */
  async estimateHarvestGas(params: HarvestParams): Promise<GasEstimate> {
    const config = await this.getBridgeConfig();
    const rent = await this.connection.getMinimumBalanceForRentExemption(8 + 120);
    const baseFee = BigInt(5000);
    return {
      baseFeeLamports: baseFee,
      bridgeFeeLamports: config.bridgeFeeLamports,
      rentLamports: BigInt(rent),
      totalLamports: baseFee + config.bridgeFeeLamports + BigInt(rent),
    };
  }

  /** Build `trigger_remote_harvest` transaction (does not send). */
  async buildTriggerHarvestTx(
    agent: PublicKey,
    params: HarvestParams,
  ): Promise<Transaction> {
    const nonce = (await this.getHarvestNonce()) + 1n;
    const maxSlippage = params.maxSlippageBps ?? DEFAULT_MAX_SLIPPAGE_BPS;
    const [bridgePda] = bridgeStatePda(this.crossChainProgramId);
    const [treasuryPdaKey] = treasuryPda(this.crossChainProgramId);
    const [harvestPda] = harvestRequestPda(agent, nonce, this.crossChainProgramId);
    const [coordinatorPda] = coordinatorStatePda(this.coordinatorProgramId);
    const [swarmCfg] = swarmConfigPda(this.swarmOpsProgramId);
    const [agentReg] = agentRegistryPda(agent, this.swarmOpsProgramId);

    const ix = await this.program.methods
      .triggerRemoteHarvest(
        params.originChainId,
        params.targetChainId,
        new BN(params.amount.toString()),
        maxSlippage,
        new BN(nonce.toString()),
      )
      .accounts({
        agent,
        bridgeState: bridgePda,
        treasury: treasuryPdaKey,
        harvestRequest: harvestPda,
        coordinatorState: coordinatorPda,
        swarmConfig: swarmCfg,
        agentRegistry: agentReg,
        swarmOpsProgram: this.swarmOpsProgramId,
        crossChainProgram: this.crossChainProgramId,
        systemProgram: SystemProgram.programId,
      })
      .instruction();

    const tx = new Transaction().add(ix);
    tx.feePayer = agent;
    const { blockhash } = await this.connection.getLatestBlockhash();
    tx.recentBlockhash = blockhash;
    return tx;
  }

  /** Trigger remote harvest and return signature. */
  async triggerRemoteHarvest(agent: Keypair, params: HarvestParams): Promise<string> {
    const tx = await this.buildTriggerHarvestTx(agent.publicKey, params);
    tx.sign(agent);
    return this.connection.sendRawTransaction(tx.serialize(), { skipPreflight: false });
  }

  /** Build `receive_cross_chain_yield` (bridge authority / TEE oracle). */
  async buildReceiveYieldTx(
    bridgeAuthority: PublicKey,
    agent: PublicKey,
    originChainId: number,
    amount: bigint,
    nonce: bigint,
  ): Promise<Transaction> {
    const [bridgePda] = bridgeStatePda(this.crossChainProgramId);
    const [treasuryPdaKey] = treasuryPda(this.crossChainProgramId);
    const [harvestPda] = harvestRequestPda(agent, nonce, this.crossChainProgramId);
    const [coordinatorPda] = coordinatorStatePda(this.coordinatorProgramId);

    const ix = await this.program.methods
      .receiveCrossChainYield(originChainId, new BN(amount.toString()), new BN(nonce.toString()))
      .accounts({
        bridgeAuthority,
        agent,
        bridgeState: bridgePda,
        harvestRequest: harvestPda,
        treasury: treasuryPdaKey,
        coordinatorState: coordinatorPda,
        instructionsSysvar: new PublicKey('Sysvar1nstructions1111111111111111111111111'),
        systemProgram: SystemProgram.programId,
      })
      .instruction();

    const tx = new Transaction().add(ix);
    tx.feePayer = bridgeAuthority;
    const { blockhash } = await this.connection.getLatestBlockhash();
    tx.recentBlockhash = blockhash;
    return tx;
  }

  /** Canonical message hash for ed25519 co-signature. */
  messageHashForHarvest(
    agent: PublicKey,
    originChainId: number,
    amount: bigint,
    nonce: bigint,
  ): Buffer {
    const [harvestPda] = harvestRequestPda(agent, nonce, this.crossChainProgramId);
    return bridgeMessageBytes(harvestPda, originChainId, amount, nonce);
  }

  /** Subscribe to program logs and parse EventLog-style emissions. */
  onBridgeEvents(handler: (event: BridgeEventLog) => void): () => void {
    const subId = this.connection.onLogs(
      this.crossChainProgramId,
      (logs) => {
        for (const line of logs.logs) {
          if (!line.includes('Program data:')) continue;
          const parsed = this.tryParseEventLog(line);
          if (parsed) handler(parsed);
        }
      },
      'confirmed',
    );
    const unsub = () => {
      void this.connection.removeOnLogsListener(subId);
      this.logListeners.delete(subId);
    };
    this.logListeners.set(subId, unsub);
    return unsub;
  }

  private tryParseEventLog(line: string): BridgeEventLog | null {
    if (!line.includes('EventLog')) return null;
    return null;
  }

  /** Convenience: Helix → Solana harvest. */
  async triggerHelixToSolanaHarvest(agent: Keypair, amount: bigint): Promise<string> {
    return this.triggerRemoteHarvest(agent, {
      originChainId: CHAIN_IDS.HELIX,
      targetChainId: CHAIN_IDS.SOLANA,
      amount,
    });
  }
}

export { CHAIN_IDS, DEFAULT_MAX_SLIPPAGE_BPS, EVENT_KIND };
