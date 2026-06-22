import { useCallback, useState } from "react";
import type { GameSyncState, SyncProof } from "../types";

const DEFAULT_API = "http://localhost:3100/api";

export interface UseGameSyncOptions {
  apiBase?: string;
  walletAddress?: string;
  walletConnected: boolean;
}

export function useGameSync({
  apiBase = DEFAULT_API,
  walletAddress,
  walletConnected,
}: UseGameSyncOptions) {
  const [state, setState] = useState<GameSyncState>({
    sessionId: "",
    accumulatedNanoThisSession: "0",
    accumulatedIgjThisSession: "0",
    walletConnected,
    walletAddress,
  });
  const [syncing, setSyncing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const sync = useCallback(async () => {
    if (!walletAddress || !walletConnected) return;
    setSyncing(true);
    setError(null);
    try {
      const res = await fetch(`${apiBase}/sync`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          wallet: walletAddress,
          activityScore: 50,
          sessionId: state.sessionId || undefined,
        }),
      });
      const data = await res.json();
      if (!res.ok || !data.ok) {
        throw new Error(data.error || "sync failed");
      }
      setState({
        sessionId: data.session.sessionId,
        accumulatedNanoThisSession: data.session.accumulatedNanoThisSession,
        accumulatedIgjThisSession: data.session.accumulatedIgjThisSession,
        proof: data.proof as SyncProof,
        walletConnected,
        walletAddress,
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : "sync failed");
    } finally {
      setSyncing(false);
    }
  }, [apiBase, walletAddress, walletConnected, state.sessionId]);

  return { state, sync, syncing, error };
}
