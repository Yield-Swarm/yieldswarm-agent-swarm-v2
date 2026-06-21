/**
 * React hook — sovereign loop engine state for TV dashboard + Arena.
 */

import { useCallback, useEffect, useState } from 'react';

export type SovereignLogEntry = {
  ts: string;
  phase: string;
  message: string;
  [key: string]: unknown;
};

export type SovereignLoopsState = {
  version: string;
  state: string;
  tickCount: number;
  credentialsOk: boolean;
  chainBalances: Record<string, number>;
  logs: SovereignLogEntry[];
  chains: string[];
  thresholds: {
    treasury_usd: number;
    replication_usd: number;
    penning_trap_min: number;
  };
  timestamp: string;
};

const API_BASE = (import.meta.env.VITE_API_BASE as string) || '/api';

export function useSovereignLoops(pollMs = 10_000) {
  const [data, setData] = useState<SovereignLoopsState | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      const res = await fetch(`${API_BASE}/sovereign/loops`, { cache: 'no-store' });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = (await res.json()) as SovereignLoopsState;
      setData(json);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'sovereign loops unreachable');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
    const id = setInterval(refresh, pollMs);
    return () => clearInterval(id);
  }, [refresh, pollMs]);

  return {
    /** e.g. "Active Loop Running", "Rebalancing Funds" */
    loopState: data?.state ?? '—',
    logs: data?.logs ?? [],
    chainBalances: data?.chainBalances ?? {},
    tickCount: data?.tickCount ?? 0,
    credentialsOk: data?.credentialsOk ?? false,
    thresholds: data?.thresholds,
    loading,
    error,
    refresh,
    data,
  };
}
