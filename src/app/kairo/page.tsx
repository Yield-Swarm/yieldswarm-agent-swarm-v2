"use client";

import { useEffect, useState } from "react";

interface DriverSummary {
  driverId: string;
  evmAddress: string;
  iotexAddress: string;
  telemetryCount: number;
  totalDistanceM: number;
  totalRewardWeight: number;
  earnings: {
    appRevenue: string;
    depinCryptoRewards: string;
    potentialRewardsUsd: string;
  };
}

export default function KairoDashboardPage() {
  const [driverId, setDriverId] = useState("");
  const [summary, setSummary] = useState<DriverSummary | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function register() {
    setLoading(true);
    setError("");
    try {
      const res = await fetch("/api/kairo/drivers/register", { method: "POST" });
      const json = await res.json();
      if (!json.ok) throw new Error(json.error ?? "Registration failed");
      setDriverId(json.data.driver.driverId);
      setSummary(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Registration failed");
    } finally {
      setLoading(false);
    }
  }

  async function loadSummary(id: string) {
    setLoading(true);
    setError("");
    try {
      const res = await fetch(`/api/kairo/earnings/${id}`);
      const json = await res.json();
      if (!json.ok) throw new Error(json.error ?? "Load failed");
      setSummary(json.data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Load failed");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (driverId) loadSummary(driverId);
  }, [driverId]);

  return (
    <main className="mx-auto max-w-3xl p-8 text-slate-100">
      <h1 className="mb-2 text-3xl font-bold">Kairo Driver Node</h1>
      <p className="mb-8 text-slate-400">
        Cryptographic identity + signed telemetry → YieldSwarm Mandelbrot / Tree of Life
      </p>

      <div className="mb-6 flex gap-3">
        <button
          type="button"
          onClick={register}
          disabled={loading}
          className="rounded-lg bg-emerald-600 px-4 py-2 font-medium hover:bg-emerald-500 disabled:opacity-50"
        >
          Register new driver
        </button>
        <input
          className="flex-1 rounded-lg border border-slate-700 bg-slate-900 px-3 py-2"
          placeholder="Driver ID"
          value={driverId}
          onChange={(e) => setDriverId(e.target.value)}
        />
        <button
          type="button"
          onClick={() => driverId && loadSummary(driverId)}
          disabled={loading || !driverId}
          className="rounded-lg bg-slate-700 px-4 py-2 hover:bg-slate-600 disabled:opacity-50"
        >
          Refresh
        </button>
      </div>

      {error && <p className="mb-4 text-red-400">{error}</p>}

      {summary && (
        <section className="grid gap-4 rounded-xl border border-slate-800 bg-slate-900/60 p-6">
          <div>
            <h2 className="text-lg font-semibold">Identity</h2>
            <p className="font-mono text-sm text-slate-400">EVM: {summary.evmAddress}</p>
            <p className="font-mono text-sm text-slate-400">IoTeX: {summary.iotexAddress}</p>
          </div>
          <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
            <Stat label="Telemetry" value={String(summary.telemetryCount)} />
            <Stat label="Distance (m)" value={summary.totalDistanceM.toFixed(0)} />
            <Stat label="Reward weight" value={summary.totalRewardWeight.toFixed(4)} />
            <Stat label="Potential $" value={summary.earnings.potentialRewardsUsd} />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <Stat label="App revenue" value={`$${summary.earnings.appRevenue}`} />
            <Stat label="DePIN rewards" value={`$${summary.earnings.depinCryptoRewards}`} />
          </div>
        </section>
      )}
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg bg-slate-800/80 p-4">
      <p className="text-xs uppercase tracking-wide text-slate-500">{label}</p>
      <p className="text-xl font-semibold">{value}</p>
    </div>
  );
}
