import { useEffect, useState } from "react";

import { useBalance, useChain, useWallet } from "@/wallet";
import { ConnectGate } from "../components/ConnectGate";

const API_BASE = import.meta.env.VITE_API_BASE || "http://localhost:8787/api";

type ArenaOverview = {
  generatedAt?: string;
  connectionsHealthy?: number;
  connectionsTotal?: number;
  akash?: { live?: boolean; workers?: unknown[] };
  emissionRouter?: { live?: boolean };
  treasury?: { live?: boolean };
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
          <div className="card__label">Chain / Balance</div>
          <div className="card__value">{chain?.name ?? "—"}</div>
          <div className="ysw-muted">{balance ? `${balance.formatted} ${balance.symbol}` : "—"}</div>
        </div>
        <div className="card">
          <div className="card__label">Wallet</div>
          <div className="ysw-mono ysw-muted">{wallet.address?.slice(0, 10)}…</div>
        </div>
      </div>

      <div className="panel">
        <h3>Emission router</h3>
        <p className="ysw-muted">
          Treasury split 50/30/15/5 — {overview?.emissionRouter?.live ? "connected" : "simulated"}
        </p>
      </div>
    </section>
  );
}
