import type { SyncProof } from "../types";

export interface AdvancedProofPanelProps {
  open: boolean;
  onToggle: () => void;
  proof?: SyncProof;
  sessionIgj: string;
}

export function AdvancedProofPanel({ open, onToggle, proof, sessionIgj }: AdvancedProofPanelProps) {
  return (
    <section style={{ marginTop: 12 }}>
      <button
        type="button"
        onClick={onToggle}
        style={{
          width: "100%",
          textAlign: "left",
          padding: "10px 12px",
          borderRadius: 8,
          border: "1px solid #333",
          background: "#1a1a1a",
          color: "#ccc",
          cursor: "pointer",
        }}
      >
        {open ? "▼" : "▶"} Advanced proof (engine nano / IGJ)
      </button>
      {open && (
        <div
          style={{
            marginTop: 8,
            padding: 12,
            borderRadius: 8,
            border: "1px solid #333",
            background: "#0d0d0d",
            fontFamily: "monospace",
            fontSize: 12,
            color: "#aaa",
          }}
        >
          {!proof ? (
            <p style={{ margin: 0 }}>No sync proof yet — run Sync with chain.</p>
          ) : (
            <ul style={{ margin: 0, paddingLeft: 18, lineHeight: 1.6 }}>
              <li>Δt (server): {proof.deltaTSeconds}s</li>
              <li>last_update (chain): {proof.lastUpdateOnChain}</li>
              <li>Δt clamped: {proof.deltaClamped ? "yes" : "no"}</li>
              <li>earned nano: {proof.earnedNano}</li>
              <li>earned IGJ: {proof.earnedIgj}</li>
              <li>session IGJ total: {sessionIgj}</li>
              <li>cap hit: {proof.capped ? "yes" : "no"}</li>
              <li>engine nano/s: {proof.engine.nanoPerSecond}</li>
              <li>activity mult: {proof.engine.activityMultiplier.toFixed(2)}</li>
              <li>raw nano: {proof.engine.rawNano}</li>
            </ul>
          )}
        </div>
      )}
    </section>
  );
}
