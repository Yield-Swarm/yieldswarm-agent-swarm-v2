import { Connection, PublicKey } from '@solana/web3.js';
import { CrossChainClient, HarvestEvent, YieldReceivedEvent } from './client';

export type BridgeEvent = HarvestEvent | YieldReceivedEvent;

export interface BridgeListenerOptions {
  pollIntervalMs?: number;
  onHarvest?: (event: HarvestEvent) => void;
  onYieldReceived?: (event: YieldReceivedEvent) => void;
  onError?: (err: Error) => void;
}

/**
 * Polls bridge_state and program logs for cross-chain yield events.
 * Production: replace with Geyser gRPC per indexer/INDEXER_SPEC.md.
 */
export class BridgeListener {
  private timer: ReturnType<typeof setInterval> | null = null;
  private lastTotalReceived: bigint = 0n;

  constructor(
    readonly connection: Connection,
    readonly client: CrossChainClient = new CrossChainClient(connection),
    readonly options: BridgeListenerOptions = {},
  ) {}

  start(): void {
    const interval = this.options.pollIntervalMs ?? 15_000;
    void this.poll();
    this.timer = setInterval(() => void this.poll(), interval);
  }

  stop(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  private async poll(): Promise<void> {
    try {
      const state = await this.client.fetchBridgeState();
      if (!state) return;
      if (state.totalReceived > this.lastTotalReceived) {
        const delta = state.totalReceived - this.lastTotalReceived;
        this.lastTotalReceived = state.totalReceived;
        this.options.onYieldReceived?.({
          amount: delta,
          sourceChainId: 0,
          treasury: state.treasury,
          agent: state.authority,
          timestamp: Number(state.lastHarvestTs),
        });
      }
    } catch (err) {
      this.options.onError?.(err instanceof Error ? err : new Error(String(err)));
    }
  }
}

export function subscribeBridgeLogs(
  connection: Connection,
  programId: PublicKey,
  onEvent: (logs: string[]) => void,
): number {
  return connection.onLogs(programId, (resp) => {
    if (resp.err) return;
    onEvent(resp.logs);
  });
}
