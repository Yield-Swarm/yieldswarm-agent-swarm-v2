import { useState } from "react";

import { useBalance, useChain, useWallet } from "@/wallet";
import { ConnectGate } from "../components/ConnectGate";
import { useArenaTelemetry } from "../hooks/useArenaTelemetry";

/**
 * Arena — live telemetry from Akash, emission router, treasury, leaderboard.
 */
export function Arena() {
  return (
    <ConnectGate
      title="Enter the Arena"
      subtitle="Live YieldSwarm telemetry — Akash workers, emissions, treasury."
    >
      <ArenaInner />
    </ConnectGate>
  );
}

function ArenaInner() {
  const wallet = useWallet();
  const { chain } = useChain();
  const { data: balance } = useBalance();
  const { data: overview, error, loading, refresh } = useArenaTelemetry(15_000);
  const [authToken, setAuthToken] = useState<string | null>(null);
  const [authError, setAuthError] = useState<string | null>(null);
  const [authing, setAuthing] = useState(false);

  const workers = (overview?.akash as { workers?: unknown[] } | undefined)?.workers ?? [];
  const treasuryData = overview?.treasury as { live?: boolean; balanceUsd?: number; totalSol?: number } | undefined;
  const emissionData = overview?.emissionRouter as { live?: boolean } | undefined;
  const board = overview?.leaderboard as { rows?: Array<{ agentId: string; rewardsApn: number }> } | undefined;

  const handleAuth = async () => {
    setAuthing(true);
    setAuthError(null);
    try {
      const nonce = Math.random().toString(36).slice(2);
      const sig = await wallet.signMessage(`Sign in to YieldSwarm Arena\nNonce: ${nonce}`);
      setAuthToken(sig.slice(0, 24) + "…");
    } catch (err) {
      setAuthError(err instanceof Error ? err.message : "Signature failed");
    } finally {
      setAuthing(false);
    }
  };

  return (
    <section className="page">
      <div className="page__head">
        <h1>Arena</h1>
        <p className="ysw-muted">
          Live data from integration API · updated{" "}
          {overview?.generatedAt ? new Date(overview.generatedAt).toLocaleTimeString() : "—"}
        </p>
      </div>

      <div className="panel" style={{ marginBottom: 16 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 12 }}>
          <h3 style={{ margin: 0 }}>Swarm telemetry</h3>
          <button className="ysw-btn ysw-btn--ghost" type="button" onClick={() => void refresh()}>
            Refresh
          </button>
        </div>
        {loading && <p className="ysw-muted">Loading Akash, emission router, treasury…</p>}
        {error && <p className="ysw-error">{error}</p>}
      </div>

      <div className="cards">
        <div className="card">
          <div className="card__label">Connections</div>
          <div className="card__value">
            {overview?.connectionsHealthy ?? 0}/{overview?.connectionsTotal ?? 4}
          </div>
        </div>
        <div className="card">
          <div className="card__label">Akash workers</div>
          <div className="card__value" style={{ color: overview?.akash?.live ? "#3ddc97" : "#ff5470" }}>
            {workers.length} {overview?.akash?.live ? "live" : "fallback"}
          </div>
        </div>
        <div className="card">
          <div className="card__label">Treasury</div>
          <div className="card__value">
            {treasuryData?.balanceUsd != null
              ? `$${Math.round(treasuryData.balanceUsd).toLocaleString()}`
              : treasuryData?.totalSol != null
                ? `${treasuryData.totalSol} SOL`
                : "—"}
          </div>
          <div className="ysw-muted">{treasuryData?.live ? "on-chain" : "projected"}</div>
        </div>
        <div className="card">
          <div className="card__label">Top agent</div>
          <div className="card__value">{board?.rows?.[0]?.agentId ?? "—"}</div>
          <div className="ysw-muted">
            {board?.rows?.[0]?.rewardsApn != null
              ? `${board.rows[0].rewardsApn.toLocaleString()} $APN`
              : "leaderboard"}
          </div>
        </div>
        <div className="card">
          <div className="card__label">Chain / Balance</div>
          <div className="card__value">{chain?.name ?? "—"}</div>
          <div className="ysw-muted">{balance ? `${balance.formatted} ${balance.symbol}` : "—"}</div>
        </div>
        <div className="card">
          <div className="card__label">Session</div>
          {authToken ? (
            <div className="card__value" style={{ color: "#3ddc97" }}>Authenticated</div>
          ) : (
            <button className="ysw-btn" onClick={handleAuth} disabled={authing}>
              {authing ? "Signing…" : "Sign in to trade"}
            </button>
          )}
          {authToken && <div className="ysw-mono ysw-muted">{authToken}</div>}
          {authError && <div className="ysw-error" style={{ margin: "8px 0 0" }}>{authError}</div>}
        </div>
      </div>

      <div className="panel">
        <h3>Emission router</h3>
        <p className="ysw-muted">
          Treasury split 50/30/15/5 — {emissionData?.live ? "connected" : "simulated"}
        </p>
        <div className="ticket">
          <button className="ysw-btn" disabled={!authToken}>Buy $APN</button>
          <button className="ysw-btn ysw-btn--ghost" disabled={!authToken}>Sell $APN</button>
        </div>
      </div>
    </section>
  );
}
