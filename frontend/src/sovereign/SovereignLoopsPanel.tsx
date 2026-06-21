import { memo, useCallback, useEffect, useMemo, useRef } from "react";
import {
  startSovereignLoopsPolling,
  useSovereignLoops,
} from "./SovereignLoopManager";
import "./sovereign-loops.css";

type StateTheme = { color: string; label: string };

function getStateStyle(state: string): StateTheme {
  switch (state) {
    case "Rebalancing Funds":
      return { color: "#FFB300", label: "ECONOMIC LOOP ACTIVE" };
    case "Deploying Replica":
      return { color: "#9C27B0", label: "REPLICATION LOOP ACTIVE" };
    case "Executing Self-Heal Patch":
      return { color: "#F44336", label: "CRITICAL PATCH ENGAGED" };
    case "Active Loop Running":
    default:
      return { color: "#00E676", label: "ALL SOVEREIGN LOOPS SYSTEM NOMINAL" };
  }
}

const TerminalLog = memo(function TerminalLog({
  logs,
}: {
  logs: Array<{ type: string; message: string; timestamp: string }>;
}) {
  const consoleRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = consoleRef.current;
    if (el) el.scrollTop = 0;
  }, [logs]);

  return (
    <div className="slp-terminal-console" ref={consoleRef}>
      {logs.map((log, idx) => {
        let logColor = "#00E5FF";
        if (log.type === "Warning") logColor = "#FFB300";
        if (log.type === "Critical") logColor = "#F44336";

        return (
          <div
            key={`${log.timestamp}-${idx}`}
            className="slp-terminal-line"
            style={{ color: logColor }}
          >
            [{log.timestamp}] &gt; {log.message}
          </div>
        );
      })}
    </div>
  );
});

export const SovereignLoopsPanel = memo(function SovereignLoopsPanel() {
  const {
    currentState,
    logs,
    treasuries,
    totalTreasury,
    penningTrapIntegrity,
    replicationSurplus,
    focused,
    setFocused,
    manualActions,
    error,
    loading,
  } = useSovereignLoops();

  const pulseRef = useRef<HTMLSpanElement>(null);
  const activeTheme = useMemo(() => getStateStyle(currentState), [currentState]);

  useEffect(() => {
    startSovereignLoopsPolling();
  }, []);

  useEffect(() => {
    const el = pulseRef.current;
    if (!el) return;
    el.style.setProperty("--slp-pulse-color", activeTheme.color);
    el.classList.add("slp-pulse-active");
    return () => el.classList.remove("slp-pulse-active");
  }, [activeTheme.color]);

  const panelClass = useMemo(
    () => ["slp-panel", focused && "slp-panel--focused"].filter(Boolean).join(" "),
    [focused],
  );

  const onFocus = useCallback(() => setFocused(true), [setFocused]);
  const onBlur = useCallback(() => setFocused(false), [setFocused]);

  const penningColor = penningTrapIntegrity < 99.99 ? "#F44336" : "#00E676";

  return (
    <section
      className={panelClass}
      tabIndex={0}
      onFocus={onFocus}
      onBlur={onBlur}
      aria-label="Sovereign Loops Telemetry"
    >
      <header className="slp-header">
        <div className="slp-status-row">
          <span className="slp-pulse-circle" ref={pulseRef} />
          <span className="slp-status-text" style={{ color: activeTheme.color }}>
            {activeTheme.label}
          </span>
        </div>
        <div className="slp-state-subtitle">
          CURRENT STATE: {currentState.toUpperCase()}
          {loading && " · SYNCING"}
          {error && ` · ${error}`}
        </div>
      </header>

      <div className="slp-matrix-grid">
        <div className="slp-matrix-card">
          <div className="slp-card-label">TOTAL TREASURY (CONSOLIDATED)</div>
          <div className="slp-card-value slp-mono">${totalTreasury.toLocaleString()}</div>
          <div className="slp-card-subtext slp-mono">
            NX: ${(treasuries.nexus ?? 0).toLocaleString()} | HX: $
            {(treasuries.helix ?? 0).toLocaleString()}
          </div>
        </div>

        <div className="slp-matrix-card">
          <div className="slp-card-label">REPLICATION SURPLUS METRIC</div>
          <div className="slp-card-value slp-mono">{replicationSurplus.toFixed(1)}%</div>
          <div className="slp-progress-bg">
            <div
              className="slp-progress-fill"
              style={{ width: `${Math.min(replicationSurplus, 100)}%` }}
            />
          </div>
        </div>

        <div className="slp-matrix-card">
          <div className="slp-card-label">PENNING TRAP MAGNETIC STRENGTH</div>
          <div className="slp-card-value slp-mono" style={{ color: penningColor }}>
            {penningTrapIntegrity.toFixed(4)}%
          </div>
          <div className="slp-card-subtext slp-mono">HELIX DELTA V5 FLUX CORE</div>
        </div>
      </div>

      <div className="slp-terminal-container">
        <div className="slp-terminal-title">SOVEREIGN DAEMON REAL-TIME LOGS</div>
        <TerminalLog logs={logs} />
      </div>

      <div className="slp-actions">
        <button
          type="button"
          className="slp-action-btn"
          onClick={() => void manualActions.forceRebalance()}
        >
          FORCE ECONOMIC BALANCING
        </button>
        <button
          type="button"
          className="slp-action-btn"
          onClick={() => void manualActions.forceReplicate()}
        >
          PROVISION WORKER SWARM
        </button>
        <button
          type="button"
          className="slp-action-btn slp-action-btn--danger"
          onClick={() => void manualActions.triggerPatch()}
        >
          MANUAL SELF-HEAL CYCLE
        </button>
      </div>
    </section>
  );
});

export default SovereignLoopsPanel;
