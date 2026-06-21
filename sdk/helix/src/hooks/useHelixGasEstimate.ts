import { useCallback, useEffect, useMemo, useState } from 'react';
import { Connection, PublicKey } from '@solana/web3.js';
import { HelixClient } from '../client.js';
import type { GasEstimate, HarvestParams } from '../constants.js';

export interface UseHelixGasEstimateOptions {
  connection: Connection;
  wallet: { publicKey: PublicKey | null };
  harvestParams: HarvestParams | null;
}

export interface UseHelixGasEstimateResult {
  estimate: GasEstimate | null;
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
}

/** Estimate lamport cost for a harvest transaction. */
export function useHelixGasEstimate(opts: UseHelixGasEstimateOptions): UseHelixGasEstimateResult {
  const [estimate, setEstimate] = useState<GasEstimate | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const client = useMemo(() => {
    if (!opts.wallet.publicKey) return null;
    return new HelixClient({
      connection: opts.connection,
      wallet: opts.wallet as HelixClient['provider']['wallet'],
    });
  }, [opts.connection, opts.wallet]);

  const refresh = useCallback(async () => {
    if (!client || !opts.harvestParams) {
      setEstimate(null);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const est = await client.estimateHarvestGas(opts.harvestParams);
      setEstimate(est);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [client, opts.harvestParams]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  return { estimate, loading, error, refresh };
}
