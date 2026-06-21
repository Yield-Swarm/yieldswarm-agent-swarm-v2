/**
 * Helix Solenoid 2 — IoTeX / IOPAY routing SDK
 */

export type IotexYieldDestination = 'iotex_treasury' | 'btc_via_iopay';

export type IotexYieldInflowEvent = {
  type: 'IotexYieldInflow';
  chain: 'iotex';
  destination: IotexYieldDestination;
  address: string;
  amount: string;
  asset: string;
  sourceChain: string;
  sourceTx: string | null;
  agentId: string | null;
  timestamp: string;
};

export type TreasuryManifest = {
  version: string;
  updated_at: string;
  nexus_treasury: { solana: string; description: string };
  mining_roots: Record<string, string>;
  iotex_hub: {
    primary: string;
    btc_bridge: string;
    description: string;
  };
};

export type ReceiveCrossChainYieldParams = {
  amount: string;
  asset?: string;
  sourceChain: string;
  destination?: IotexYieldDestination;
  sourceTx?: string;
  agentId?: string;
};

export type ReceiveCrossChainYieldResult = {
  ok: boolean;
  chain: 'iotex';
  destination: IotexYieldDestination;
  address: string;
  amount: string;
  asset: string;
  sourceChain: string;
  sourceTx: string | null;
  agentId: string | null;
  event: IotexYieldInflowEvent;
};

export class HelixIotexClient {
  constructor(private readonly baseUrl: string) {}

  async getTreasuryManifest(): Promise<TreasuryManifest> {
    const res = await fetch(`${this.baseUrl}/api/helix/treasury/manifest`);
    if (!res.ok) throw new Error(`manifest fetch failed: ${res.status}`);
    return res.json() as Promise<TreasuryManifest>;
  }

  async getIotexHubStatus(): Promise<{
    ready: boolean;
    treasury: string;
    btcBridge: string;
    inflowCount: number;
  }> {
    const res = await fetch(`${this.baseUrl}/api/helix/iotex/status`);
    if (!res.ok) throw new Error(`iotex status failed: ${res.status}`);
    return res.json();
  }

  /**
   * Route cross-chain yield to IoTeX Treasury or BTC via IOPAY.
   */
  async receiveCrossChainYield(
    params: ReceiveCrossChainYieldParams
  ): Promise<ReceiveCrossChainYieldResult> {
    const res = await fetch(`${this.baseUrl}/api/helix/yield/receive`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(params),
    });
    if (!res.ok) {
      const err = (await res.json().catch(() => ({}))) as { error?: string };
      throw new Error(err.error || `yield receive failed: ${res.status}`);
    }
    return res.json() as Promise<ReceiveCrossChainYieldResult>;
  }

  /** Convenience: route directly to IoTeX Treasury */
  async routeToIotexTreasury(
    amount: string,
    sourceChain: string,
    opts: { asset?: string; sourceTx?: string; agentId?: string } = {}
  ) {
    return this.receiveCrossChainYield({
      amount,
      sourceChain,
      destination: 'iotex_treasury',
      ...opts,
    });
  }

  /** Convenience: route to BTC via IOPAY bridge */
  async routeToBtcViaIopay(
    amount: string,
    sourceChain: string,
    opts: { asset?: string; sourceTx?: string; agentId?: string } = {}
  ) {
    return this.receiveCrossChainYield({
      amount,
      sourceChain,
      destination: 'btc_via_iopay',
      ...opts,
    });
  }
}
