export interface SyncProof {
  deltaTSeconds: number;
  lastUpdateOnChain: number;
  deltaClamped: boolean;
  earnedNano: string;
  earnedIgj: string;
  capped: boolean;
  engine: {
    nanoPerSecond: string;
    activityMultiplier: number;
    rawNano: string;
  };
  settlementHash: string;
  syncedAt: number;
}

export interface GameSyncState {
  sessionId: string;
  accumulatedNanoThisSession: string;
  accumulatedIgjThisSession: string;
  proof?: SyncProof;
  walletConnected: boolean;
  walletAddress?: string;
}

export function formatRelativeSync(syncedAt: number, nowSec = Math.floor(Date.now() / 1000)): string {
  const diff = Math.max(0, nowSec - syncedAt);
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  return `${Math.floor(diff / 3600)}h ago`;
}
