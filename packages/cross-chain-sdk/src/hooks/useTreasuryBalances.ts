import { useCallback, useEffect, useMemo, useState } from 'react';
import { Connection, PublicKey } from '@solana/web3.js';
import { CROSS_CHAIN_PROGRAM_ID, NEXUS_TREASURY_SOLANA } from '../constants';
import { fetchAllMiningRoots, fetchTreasuryRegistry } from '../treasury';
import type { TreasuryBalancesState } from '../types';

export interface UseTreasuryBalancesOptions {
  rpcUrl?: string;
  programId?: PublicKey;
  pollMs?: number;
}

export function useTreasuryBalances(
  options: UseTreasuryBalancesOptions = {}
): TreasuryBalancesState & { refresh: () => Promise<void> } {
  const rpcUrl = options.rpcUrl ?? 'https://api.devnet.solana.com';
  const programId = options.programId ?? CROSS_CHAIN_PROGRAM_ID;
  const pollMs = options.pollMs ?? 15_000;

  const connection = useMemo(() => new Connection(rpcUrl, 'confirmed'), [rpcUrl]);

  const [state, setState] = useState<TreasuryBalancesState>({
    nexusTreasury: NEXUS_TREASURY_SOLANA.toBase58(),
    totalToNexus: 0n,
    totalToMining: 0n,
    pausedSweeps: false,
    pausedInflows: false,
    miningRoots: [],
    loading: true,
    error: null,
  });

  const refresh = useCallback(async () => {
    setState((s) => ({ ...s, loading: true, error: null }));
    try {
      const [registry, miningRoots] = await Promise.all([
        fetchTreasuryRegistry(connection, programId),
        fetchAllMiningRoots(connection, programId),
      ]);

      setState({
        nexusTreasury: registry?.nexusTreasury ?? NEXUS_TREASURY_SOLANA.toBase58(),
        totalToNexus: registry?.totalToNexus ?? 0n,
        totalToMining: registry?.totalToMining ?? 0n,
        pausedSweeps: registry?.pausedSweeps ?? false,
        pausedInflows: registry?.pausedInflows ?? false,
        miningRoots,
        loading: false,
        error: null,
      });
    } catch (e) {
      setState((s) => ({
        ...s,
        loading: false,
        error: e instanceof Error ? e.message : 'Failed to load treasury balances',
      }));
    }
  }, [connection, programId]);

  useEffect(() => {
    refresh();
    const id = window.setInterval(refresh, pollMs);
    return () => window.clearInterval(id);
  }, [refresh, pollMs]);

  return { ...state, refresh };
}
