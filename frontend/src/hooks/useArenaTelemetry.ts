import { useCallback, useEffect, useState } from "react";

export type SplitRow = {
  bucket?: string;
  label?: string;
  destination?: string;
  pct?: number;
  bps?: number;
  perEpoch?: number;
  sol?: number;
  amount?: number;
};

export type ArenaOverview = {
  generatedAt: string;
  connectionsHealthy: number;
  connectionsTotal: number;
  connections: Record<string, { connected: boolean; source: string }>;
  akash?: { activeWorkers?: number; totalWorkers?: number; live?: boolean; workers?: unknown[] };
  emissionRouter?: {
    live?: boolean;
    totalEmittedApn?: number;
    emissionPerEpoch?: number;
    routes?: SplitRow[];
  };
  treasury?: { live?: boolean; balanceUsd?: number; totalSol?: number; splits?: SplitRow[] };
  greatDelta?: { policy?: string; buckets?: SplitRow[] };
  leaderboard?: {
    live?: boolean;
    rows?: Array<{ rank: number; agentId: string; rewardsApn: number }>;
  };
  helix?: {
    activated?: boolean;
    phase?: string;
    readinessScore?: string;
    genesisHash?: string | null;
  };
  zkMayhem?: {
    enabled?: boolean;
    circuitBuilt?: boolean;
    minEntropyQuality?: number;
    lastCycle?: {
      at?: string | null;
      commitment?: string | null;
      quality?: number | null;
      skipped?: boolean;
    } | null;
  };
};

const OVERVIEW_URL =
  import.meta.env.VITE_ARENA_OVERVIEW_URL || "/api/arena/overview";

export function useArenaTelemetry(refreshMs = 30_000) {
  const [data, setData] = useState<ArenaOverview | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(OVERVIEW_URL, { headers: { Accept: "application/json" } });
      if (!res.ok) throw new Error(`Telemetry ${res.status}`);
      setData((await res.json()) as ArenaOverview);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Telemetry failed");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
    const id = setInterval(() => void refresh(), refreshMs);
    return () => clearInterval(id);
  }, [refresh, refreshMs]);

  return { data, error, loading, refresh };
}
