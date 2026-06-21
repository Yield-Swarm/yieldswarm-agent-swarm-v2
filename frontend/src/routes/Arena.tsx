import { useState } from "react";

import { useBalance, useChain, useWallet } from "@/wallet";
import { ConnectGate } from "../components/ConnectGate";
import { useArenaTelemetry, type SplitRow } from "../hooks/useArenaTelemetry";
import { HelixDeltaVariantPanel } from "../helix/delta-v5/HelixDeltaVariantPanel";
import { SovereignLoopsPanel } from "../sovereign/SovereignLoopsPanel";

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

function SplitTable({
  title,
  rows,
  valueKey,
}: {
  title: string;
  rows: SplitRow[];
  valueKey: "perEpoch" | "sol";
}) {
  if (!rows.length) return null;
  return (
    <div className="panel" style={{ marginTop: 12 }}>
      <h3>{title}</h3>
      <table className="ysw-table" style={{ width: "100%", fontSize: 13 }}>
        <thead>
          <tr>
            <th style={{ textAlign: "left" }}>Bucket</th>
            <th style={{ textAlign: "right" }}>Share</th>
            <th style={{ textAlign: "right" }}>{valueKey === "sol" ? "SOL" : "APN / epoch"}</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.bucket || row.destination}>
              <td>{row.label || row.bucket || row.destination}</td>
              <td style={{ textAlign: "right" }}>{row.pct ?? (row.bps ? row.bps / 100 : "—")}%</td>
              <td style={{ textAlign: "right" }} className="ysw-mono">
                {(row[valueKey] ?? row.amount ?? 0).toLocaleString(undefined, { maximumFractionDigits: 4 })}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
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
  const treasuryData = overview?.treasury as
    | { live?: boolean; balanceUsd?: number; totalSol?: number; splits?: SplitRow[] }
    | undefined;
  const emissionData = overview?.emissionRouter as
    | { live?: boolean; emissionPerEpoch?: number; routes?: SplitRow[] }
    | undefined;
  const board = overview?.leaderboard as
    | { rows?: Array<{ agentId: string; rewardsApn: number }> }
    | undefined;

  const emissionRoutes = emissionData?.routes ?? [];
  const treasurySplits = treasuryData?.splits ?? [];

  const handleAuth = async () => {
    setAuthing(true);
    setAuthError(null);
    try {
      const nonce = Math.random().toString(36).slice(2);
      const sig = await wallet.signMessage(`Sign in to YieldSwarm Arena\nNonce: ${nonce}`);
      setAuthToken(`${sig.slice(0, 24)}…`);
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
            {overview?.connectionsHealthy ?? 0}/{overview?.connectionsTotal ?? 5}
          </div>
        </div>
        <div className="card">
          <div className="card__label">Akash workers</div>
          <div className="card__value" style={{ color: overview?.akash?.live ? "#3ddc97" : "#ff5470" }}>
            {workers.length} {overview?.akash?.live ? "live" : "fallback"}
          </div>
        </div>
        <div className="card">
          <div className="card__label">Emission / epoch</div>
          <div className="card__value">
            {emissionData?.emissionPerEpoch?.toLocaleString(undefined, { maximumFractionDigits: 2 }) ?? "—"}
          </div>
          <div className="ysw-muted">{emissionData?.live ? "on-chain" : "simulated"}</div>
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
          <div className="ysw-muted">{treasuryData?.live ? "live balance" : "projected"}</div>
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
          <div className="card__label">Helix Chain</div>
          <div
            className="card__value"
            style={{ color: overview?.helix?.activated ? "#3ddc97" : "#ff5470" }}
          >
            {overview?.helix?.phase ?? "—"}
          </div>
          <div className="ysw-muted">
            {overview?.helix?.readinessScore ? `ready ${overview.helix.readinessScore}` : "genesis"}
          </div>
        </div>
        <div className="card">
          <div className="card__label">ZK Mayhem</div>
          <div
            className="card__value"
            style={{
              color: overview?.zkMayhem?.enabled && overview?.zkMayhem?.circuitBuilt ? "#c77dff" : "#ff5470",
            }}
          >
            {overview?.zkMayhem?.circuitBuilt ? "armed" : "dev"}
          </div>
          <div className="ysw-muted">
            {overview?.zkMayhem?.lastCycle?.quality != null
              ? `q=${overview.zkMayhem.lastCycle.quality.toFixed(2)}`
              : `min q ${overview?.zkMayhem?.minEntropyQuality ?? 0.5}`}
          </div>
        </div>
        <div className="card">
          <div className="card__label">Session</div>
          {authToken ? (
            <div className="card__value" style={{ color: "#3ddc97" }}>
              Authenticated
            </div>
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
        <h3>Great Delta Emission Router</h3>
        <p className="ysw-muted">
          Treasury split {overview?.greatDelta?.policy ?? "50/30/15/5"} —{" "}
          {emissionData?.live ? "connected" : "simulated"}
        </p>
        <div className="ticket">
          <button className="ysw-btn" disabled={!authToken}>
            Buy $APN
          </button>
          <button className="ysw-btn ysw-btn--ghost" disabled={!authToken}>
            Sell $APN
          </button>
        </div>
      </div>

      <SplitTable title="Emission routes (per epoch)" rows={emissionRoutes} valueKey="perEpoch" />
      <SplitTable title="Treasury allocation (SOL)" rows={treasurySplits} valueKey="sol" />

      <div className="panel" style={{ marginTop: 12, padding: 0, background: "transparent", border: "none" }}>
        <SovereignLoopsPanel />
      </div>

      <div className="panel" style={{ marginTop: 12, padding: 0, background: "transparent", border: "none" }}>
        <HelixDeltaVariantPanel />
      </div>

      <div className="panel" style={{ marginTop: 12 }}>
        <h3>Chain / Wallet</h3>
        <p className="ysw-muted">{chain?.name ?? "—"}</p>
        <p className="ysw-mono ysw-muted">{balance ? `${balance.formatted} ${balance.symbol}` : "—"}</p>
        <p className="ysw-mono ysw-muted">{wallet.address ?? "—"}</p>
      </div>
    </section>
  );
}
