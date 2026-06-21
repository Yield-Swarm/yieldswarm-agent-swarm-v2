/**
 * React hook — sovereign loop engine state for TV dashboard + Arena.
 */

import { useCallback, useEffect, useMemo, useState } from 'react';

export type SovereignLogEntry = {
  ts: string;
  phase: string;
  message: string;
  type?: string;
  [key: string]: unknown;
};

export type SovereignLoopMetrics = {
  consolidated_treasury_usd: number;
  replication_surplus_usd: number;
  replication_progress_pct: number;
  penning_trap_integrity: number;
};

export type SovereignLoopsState = {
  version: string;
  state: string;
  tickCount: number;
  credentialsOk: boolean;
  running?: boolean;
  chainBalances: Record<string, number>;
  logs: SovereignLogEntry[];
  chains: string[];
  metrics?: SovereignLoopMetrics;
  thresholds: {
    treasury_usd: number;
    replication_usd: number;
    penning_trap_min: number;
  };
  timestamp: string;
};

const API_BASE = (import.meta.env.VITE_API_BASE as string) || '/api';

async function postAction(path: string): Promise<SovereignLoopsState> {
  const res = await fetch(`${API_BASE}${path}`, { method: 'POST', cache: 'no-store' });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json() as Promise<SovereignLoopsState>;
}

export function useSovereignLoops(pollMs = 10_000) {
  const [data, setData] = useState<SovereignLoopsState | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionPending, setActionPending] = useState<string | null>(null);

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

  const runAction = useCallback(async (label: string, path: string) => {
    setActionPending(label);
    try {
      const json = await postAction(path);
      setData(json);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : `${label} failed`);
    } finally {
      setActionPending(null);
    }
  }, []);

  const forceRebalance = useCallback(
    () => runAction('rebalance', '/sovereign/loops/force-rebalance'),
    [runAction],
  );
  const forceReplicate = useCallback(
    () => runAction('replicate', '/sovereign/loops/force-replicate'),
    [runAction],
  );
  const triggerPatch = useCallback(
    () => runAction('patch', '/sovereign/loops/trigger-patch'),
    [runAction],
  );
  const pauseReset = useCallback(
    () => runAction('pause', '/sovereign/loops/pause-reset'),
    [runAction],
  );

  useEffect(() => {
    refresh();
    const id = setInterval(refresh, pollMs);
    return () => clearInterval(id);
  }, [refresh, pollMs]);

  const metrics = useMemo(() => {
    const balances = data?.chainBalances ?? {};
    const consolidated = Object.values(balances).reduce((a, b) => a + b, 0);
    const replicationUsd = data?.thresholds?.replication_usd ?? 500_000;
    return {
      consolidated_treasury_usd: data?.metrics?.consolidated_treasury_usd ?? consolidated,
      replication_surplus_usd: data?.metrics?.replication_surplus_usd
        ?? Math.max(0, consolidated - replicationUsd),
      replication_progress_pct: data?.metrics?.replication_progress_pct
        ?? Math.min(100, Math.round((consolidated / Math.max(replicationUsd, 1)) * 100)),
      penning_trap_integrity: data?.metrics?.penning_trap_integrity ?? 0.88,
    };
  }, [data]);

  return {
    /** e.g. "Active Loop Running", "Rebalancing Funds" */
    loopState: data?.state ?? '—',
    logs: data?.logs ?? [],
    chainBalances: data?.chainBalances ?? {},
    tickCount: data?.tickCount ?? 0,
    credentialsOk: data?.credentialsOk ?? false,
    running: data?.running ?? false,
    thresholds: data?.thresholds,
    metrics,
    loading,
    error,
    actionPending,
    refresh,
    forceRebalance,
    forceReplicate,
    triggerPatch,
    pauseReset,
    data,
  };
}
