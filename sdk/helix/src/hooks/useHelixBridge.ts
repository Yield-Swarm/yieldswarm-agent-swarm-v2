import { useCallback, useEffect, useMemo, useState } from 'react';
import { Connection, Keypair, PublicKey } from '@solana/web3.js';
import { HelixClient } from '../client.js';
import type { BridgeConfig, HarvestParams } from '../constants.js';

export interface UseHelixBridgeOptions {
  connection: Connection;
  wallet: { publicKey: PublicKey | null; signTransaction?: (tx: unknown) => Promise<unknown> };
  programId?: PublicKey;
}

export interface UseHelixBridgeResult {
  client: HelixClient | null;
  config: BridgeConfig | null;
  loading: boolean;
  error: string | null;
  paused: boolean;
  refresh: () => Promise<void>;
  triggerHarvest: (agent: Keypair, params: HarvestParams) => Promise<string>;
}

/** React hook for Helix bridge state and harvest triggers. */
export function useHelixBridge(opts: UseHelixBridgeOptions): UseHelixBridgeResult {
  const [config, setConfig] = useState<BridgeConfig | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const client = useMemo(() => {
    if (!opts.wallet.publicKey) return null;
    return new HelixClient({
      connection: opts.connection,
      wallet: opts.wallet as HelixClient['provider']['wallet'],
      crossChainProgramId: opts.programId,
    });
  }, [opts.connection, opts.wallet, opts.programId]);

  const refresh = useCallback(async () => {
    if (!client) {
      setConfig(null);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const cfg = await client.getBridgeConfig();
      setConfig(cfg);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [client]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const triggerHarvest = useCallback(
    async (agent: Keypair, params: HarvestParams) => {
      if (!client) throw new Error('Helix client not ready');
      return client.triggerRemoteHarvest(agent, params);
    },
    [client],
  );

  return {
    client,
    config,
    loading,
    error,
    paused: config?.paused ?? false,
    refresh,
    triggerHarvest,
  };
}
