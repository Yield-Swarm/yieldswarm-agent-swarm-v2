import { useState } from "react";
import type { GameSyncState } from "../types";
import { formatRelativeSync } from "../types";
import { AdvancedProofPanel } from "./AdvancedProofPanel";
import { CharacterStateRow } from "./CharacterStateRow";

export interface GameDashboardProps {
  state: GameSyncState;
  onSync?: () => void;
  syncing?: boolean;
}

export function GameDashboard({ state, onSync, syncing }: GameDashboardProps) {
  const [proofOpen, setProofOpen] = useState(false);
  const sessionNano = state.accumulatedNanoThisSession;
  const sessionIgj = state.accumulatedIgjThisSession;

  return (
    <div className="ton-mmorpg-dashboard" style={{ fontFamily: "system-ui", maxWidth: 480 }}>
      <header style={{ marginBottom: 16 }}>
        <h1 style={{ margin: 0, fontSize: 20 }}>TON MMORPG</h1>
        <p style={{ margin: "4px 0 0", opacity: 0.7, fontSize: 13 }}>
          Server-authoritative · PlayerSBT + IGJ
        </p>
      </header>

      {sessionNano !== "0" && (
        <div
          style={{
            display: "inline-block",
            padding: "4px 10px",
            borderRadius: 999,
            background: "#1a3a2a",
            color: "#6ee7a0",
            fontSize: 12,
            marginBottom: 12,
          }}
        >
          +{sessionNano} nano accumulated this session
        </div>
      )}

      <CharacterStateRow
        wallet={state.walletAddress}
        connected={state.walletConnected}
        settlementHash={state.proof?.settlementHash}
        lastSyncedLabel={
          state.proof ? formatRelativeSync(state.proof.syncedAt) : "Never synced"
        }
      />

      <AdvancedProofPanel
        open={proofOpen}
        onToggle={() => setProofOpen((o) => !o)}
        proof={state.proof}
        sessionIgj={sessionIgj}
      />

      <button
        type="button"
        onClick={onSync}
        disabled={!state.walletConnected || syncing}
        style={{
          marginTop: 16,
          width: "100%",
          padding: "12px 16px",
          borderRadius: 8,
          border: "none",
          background: state.walletConnected ? "#3b82f6" : "#444",
          color: "#fff",
          fontWeight: 600,
          cursor: state.walletConnected ? "pointer" : "not-allowed",
        }}
      >
        {syncing ? "Syncing…" : "Sync with chain"}
      </button>
    </div>
  );
}
