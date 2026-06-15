import { useEffect, useState } from "react";

import { useBalance, useChain, useWallet } from "@/wallet";
import { ConnectGate } from "../components/ConnectGate";

const API_BASE = import.meta.env.VITE_API_BASE || "http://localhost:8787/api";

type SplitRow = {
  bucket?: string;
  label?: string;
  destination?: string;
  pct?: number;
  bps?: number;
  perEpoch?: number;
  sol?: number;
  amount?: number;
};

type ArenaOverview = {
  generatedAt?: string;
  connectionsHealthy?: number;
  connectionsTotal?: number;
  akash?: { live?: boolean; workers?: unknown[] };
  emissionRouter?: { live?: boolean; emissionPerEpoch?: number; routes?: SplitRow[] };
  treasury?: { live?: boolean; totalSol?: number; splits?: SplitRow[] };
  greatDelta?: { policy?: string; buckets?: SplitRow[] };
  leaderboard?: { entries?: unknown[] };
};

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

function SplitTable({ title, rows, valueKey }: { title: string; rows: SplitRow[]; valueKey: "perEpoch" | "sol" }) {
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
  const [overview, setOverview] = useState<ArenaOverview | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const load = async () => {
      try {
        const res = await fetch(`${API_BASE}/arena/overview`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        setOverview(await res.json());
        setError(null);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Failed to load");
      }
    };
    load();
    const id = setInterval(load, 15000);
    return () => clearInterval(id);
  }, []);

  const workers = (overview?.akash as { workers?: unknown[] })?.workers ?? [];
  const emissionRoutes = overview?.emissionRouter?.routes ?? [];
  const treasurySplits = overview?.treasury?.splits ?? [];

  return (
    <section className="page">
      <div className="page__head">
        <h1>Arena</h1>
        <p className="ysw-muted">
          Live data from backend integration server. Updated {overview?.generatedAt?.slice(11, 19) ?? "—"} UTC
        </p>
      </div>

      {error && <div className="ysw-error">{error}</div>}

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
            {overview?.emissionRouter?.emissionPerEpoch?.toLocaleString(undefined, { maximumFractionDigits: 2 }) ?? "—"}
          </div>
          <div className="ysw-muted">{overview?.emissionRouter?.live ? "on-chain" : "simulated"}</div>
        </div>
        <div className="card">
          <div className="card__label">Treasury SOL</div>
          <div className="card__value">
            {overview?.treasury?.totalSol?.toLocaleString(undefined, { maximumFractionDigits: 2 }) ?? "—"}
          </div>
          <div className="ysw-muted">{overview?.treasury?.live ? "live balance" : "fallback"}</div>
        </div>
      </div>

      <div className="panel">
        <h3>Great Delta Emission Router</h3>
        <p className="ysw-muted">
          Treasury split {overview?.greatDelta?.policy ?? "50/30/15/5"} —{" "}
          {overview?.emissionRouter?.live ? "connected" : "simulated"}
        </p>
      </div>

      <SplitTable title="Emission routes (per epoch)" rows={emissionRoutes} valueKey="perEpoch" />
      <SplitTable title="Treasury allocation (SOL)" rows={treasurySplits} valueKey="sol" />

      <div className="panel" style={{ marginTop: 12 }}>
        <h3>Chain / Wallet</h3>
        <p className="ysw-muted">{chain?.name ?? "—"}</p>
        <p className="ysw-mono ysw-muted">{balance ? `${balance.formatted} ${balance.symbol}` : "—"}</p>
        <p className="ysw-mono ysw-muted">{wallet.address ?? "—"}</p>
      </div>
    </section>
  );
}
