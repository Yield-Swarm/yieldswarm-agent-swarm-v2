import { useCallback, useEffect, useMemo, useState } from 'react';
import { Connection, PublicKey } from '@solana/web3.js';
import { CrossChainClient, estimateBridgeGas } from '../client';
import { CROSS_CHAIN_PROGRAM_ID } from '../constants';
import type { BridgeTxStatus, CrossChainConfigAccount, GasEstimate } from '../types';

export interface UseCrossChainBridgeOptions {
  rpcUrl?: string;
  programId?: PublicKey;
}

export interface UseCrossChainBridgeResult {
  client: CrossChainClient;
  config: CrossChainConfigAccount | null;
  gasEstimate: GasEstimate;
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
  listenExecutions: (
    handler: (payload: { signature: string; logs: string[] }) => void
  ) => () => void;
  lastTx: BridgeTxStatus | null;
  setLastTx: (tx: BridgeTxStatus | null) => void;
}

export function useCrossChainBridge(
  options: UseCrossChainBridgeOptions = {}
): UseCrossChainBridgeResult {
  const rpcUrl = options.rpcUrl ?? 'https://api.devnet.solana.com';
  const programId = options.programId ?? CROSS_CHAIN_PROGRAM_ID;

  const connection = useMemo(() => new Connection(rpcUrl, 'confirmed'), [rpcUrl]);
  const client = useMemo(
    () => new CrossChainClient(connection, programId),
    [connection, programId]
  );

  const [config, setConfig] = useState<CrossChainConfigAccount | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastTx, setLastTx] = useState<BridgeTxStatus | null>(null);

  const gasEstimate = useMemo(() => estimateBridgeGas(), []);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const cfg = await client.fetchConfig();
      setConfig(cfg);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to fetch cross-chain config');
    } finally {
      setLoading(false);
    }
  }, [client]);

  useEffect(() => {
    refresh();
    const id = window.setInterval(refresh, 15_000);
    return () => window.clearInterval(id);
  }, [refresh]);

  const listenExecutions = useCallback(
    (handler: (payload: { signature: string; logs: string[] }) => void) => {
      const listenerId = client.listenBridgeExecutions(handler);
      return () => {
        void client.removeBridgeListener(listenerId);
      };
    },
    [client]
  );

  return {
    client,
    config,
    gasEstimate,
    loading,
    error,
    refresh,
    listenExecutions,
    lastTx,
    setLastTx,
  };
}
