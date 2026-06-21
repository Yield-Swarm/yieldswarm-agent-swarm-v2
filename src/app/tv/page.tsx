"use client";

import { useCallback, useEffect, useState } from "react";

interface TvData {
  generatedAt: string;
  agents: { active: number; target: number; cronsFiring: number; deitiesOnline: number; shards: number };
  vault: { netWorthUsd: number; targetUsd: number; progress: number; blendedApy: number; treasuryUsd: number; live: boolean };
  chains: {
    helix: { activated: boolean; phase: string; readiness: number };
    nexus: { treasury: string; solenoid: number };
    shadow: { status: string };
  };
  treasury: {
    solana: { balance: string; balanceUsd: number | null; live: boolean; address: string };
    evm: { balance: string; balanceUsd: number | null; live: boolean; address: string };
    iotex: { balance: string; balanceUsd: number | null; live: boolean; address: string; error?: string };
  };
  miningRoots: { chain: string; address: string }[];
  clouds: { id: string; label: string; live: boolean; detail: string; workers?: number }[];
  domains: { id: string; label: string; host: string; kind: string; resolved: boolean }[];
  revenueUsd: number;
}

function fmtUsd(n: number) {
  if (n >= 1_000_000) return `$${(n / 1_000_000).toFixed(2)}M`;
  if (n >= 1_000) return `$${(n / 1_000).toFixed(1)}K`;
  return `$${n.toFixed(0)}`;
}

function fmtPct(n: number) {
  return `${(n * 100).toFixed(1)}%`;
}

function shortAddr(a: string) {
  if (!a || a.length < 12) return a || "—";
  return `${a.slice(0, 6)}…${a.slice(-4)}`;
}

function LiveDot({ live }: { live: boolean }) {
  return <span className={`live-dot ${live ? "on" : "off"}`} aria-hidden />;
}

export default function TvDashboardPage() {
  const [data, setData] = useState<TvData | null>(null);
  const [clock, setClock] = useState("");
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      const res = await fetch("/api/tv/dashboard", { cache: "no-store" });
      const body = await res.json();
      if (!body.ok) throw new Error(body.error || "fetch failed");
      setData(body.data);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : "offline");
    }
  }, []);

  useEffect(() => {
    refresh();
    const id = setInterval(refresh, 15_000);
    return () => clearInterval(id);
  }, [refresh]);

  useEffect(() => {
    const tick = () =>
      setClock(
        new Date().toLocaleString("en-US", {
          weekday: "short",
          month: "short",
          day: "numeric",
          hour: "2-digit",
          minute: "2-digit",
          second: "2-digit",
        }),
      );
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, []);

  const totalTreasuryUsd =
    (data?.treasury.solana.balanceUsd ?? 0) +
    (data?.treasury.evm.balanceUsd ?? 0) +
    (data?.treasury.iotex.balanceUsd ?? 0);

  return (
    <div className="tv-root">
      <header className="tv-header">
        <div className="tv-brand">
          <h1>YieldSwarm</h1>
          <p className="tv-tagline">Command Center · Solenoid Tri-Layer</p>
        </div>
        <div className="tv-domains">
          {data?.domains.map((d) => (
            <span key={d.id} className={`domain-chip ${d.resolved ? "resolved" : ""}`}>
              <LiveDot live={d.resolved} />
              {d.host}
            </span>
          ))}
        </div>
        <div className="tv-clock">{clock}</div>
      </header>

      {error && <div className="tv-error">Reconnecting… {error}</div>}

      <section className="tv-hero">
        <div className="hero-card agents-card">
          <span className="card-label">Active Agents</span>
          <span className="hero-value accent">
            {(data?.agents.active ?? 10080).toLocaleString()}
          </span>
          <span className="hero-sub">
            / {(data?.agents.target ?? 10080).toLocaleString()} target
          </span>
          <div className="hero-meta">
            <span>{data?.agents.cronsFiring ?? 120} crons</span>
            <span>{data?.agents.deitiesOnline ?? 169} deities</span>
            <span>{data?.agents.shards ?? 120} shards</span>
          </div>
        </div>

        <div className="hero-card vault-card">
          <span className="card-label">Vault NAV</span>
          <span className="hero-value">{fmtUsd(data?.vault.netWorthUsd ?? 0)}</span>
          <span className="hero-sub">
            {fmtPct(data?.vault.progress ?? 0)} of {fmtUsd(data?.vault.targetUsd ?? 5_000_000)}
          </span>
          <div className="progress-bar">
            <div className="progress-fill" style={{ width: `${(data?.vault.progress ?? 0) * 100}%` }} />
          </div>
        </div>

        <div className="hero-card apy-card">
          <span className="card-label">Blended APY</span>
          <span className="hero-value green">{fmtPct(data?.vault.blendedApy ?? 0.37)}</span>
          <span className="hero-sub">Revenue {fmtUsd(data?.revenueUsd ?? 0)}</span>
        </div>
      </section>

      <section className="tv-grid">
        <div className="tv-panel">
          <h2>Multi-Cloud</h2>
          <ul className="cloud-list">
            {(data?.clouds ?? []).map((c) => (
              <li key={c.id}>
                <LiveDot live={c.live} />
                <span className="cloud-name">{c.label}</span>
                <span className="cloud-detail">{c.detail}</span>
              </li>
            ))}
          </ul>
        </div>

        <div className="tv-panel">
          <h2>Solenoid Chains</h2>
          <dl className="chain-dl">
            <div>
              <dt>Helix (S2)</dt>
              <dd>
                <LiveDot live={data?.chains.helix.activated ?? false} />
                {data?.chains.helix.phase ?? "—"} · {data?.chains.helix.readiness ?? 0}% ready
              </dd>
            </div>
            <div>
              <dt>Nexus (S1)</dt>
              <dd>
                <LiveDot live={true} />
                Treasury {shortAddr(data?.chains.nexus.treasury ?? "")}
              </dd>
            </div>
            <div>
              <dt>Shadow (S3)</dt>
              <dd>
                <LiveDot live={data?.chains.shadow.status === "active"} />
                {data?.chains.shadow.status ?? "standby"}
              </dd>
            </div>
          </dl>
        </div>

        <div className="tv-panel treasury-panel">
          <h2>Treasury Balances</h2>
          <p className="panel-sub">Live on-chain · est. {fmtUsd(totalTreasuryUsd)}</p>
          <ul className="balance-list">
            <li>
              <LiveDot live={data?.treasury.solana.live ?? false} />
              <span>Solana Nexus</span>
              <strong>{data?.treasury.solana.balance ?? "—"}</strong>
            </li>
            <li>
              <LiveDot live={data?.treasury.evm.live ?? false} />
              <span>EVM</span>
              <strong>{data?.treasury.evm.balance ?? "—"}</strong>
            </li>
            <li>
              <LiveDot live={data?.treasury.iotex.live ?? false} />
              <span>IoTeX</span>
              <strong>{data?.treasury.iotex.balance ?? "—"}</strong>
            </li>
          </ul>
        </div>
      </section>

      <section className="tv-panel mining-panel">
        <h2>Mining Roots</h2>
        <div className="mining-grid">
          {(data?.miningRoots ?? []).map((r) => (
            <div key={r.chain} className="mining-chip">
              <span className="mining-chain">{r.chain}</span>
              <span className="mining-addr">{shortAddr(r.address)}</span>
            </div>
          ))}
        </div>
      </section>

      <footer className="tv-footer">
        <span>yieldswarm.xyz</span>
        <span>Updated {data?.generatedAt ? new Date(data.generatedAt).toLocaleTimeString() : "—"}</span>
        <span className={data?.vault.live ? "live-tag" : ""}>
          {data?.vault.live ? "LIVE" : "SIM"}
        </span>
      </footer>
    </div>
  );
}
