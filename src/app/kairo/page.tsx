"use client";

import { useEffect, useState } from "react";
import { KairoDashboard } from "@/components/kairo/KairoDashboard";
import { api } from "@/lib/api";

export default function KairoPage() {
  const [driverId, setDriverId] = useState<string | null>(null);
  const [registering, setRegistering] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    const stored = sessionStorage.getItem("kairo_driver_id");
    if (stored) setDriverId(stored);
    setHydrated(true);
  }, []);

  async function registerDriver() {
    setRegistering(true);
    setError(null);
    const res = await api<{ driver: { id: string }; privateKey: string }>(
      "/api/kairo/drivers/register",
      { method: "POST", headers: { "Content-Type": "application/json" }, body: "{}" },
    );
    setRegistering(false);
    if (res.ok && res.data) {
      setDriverId(res.data.driver.id);
      sessionStorage.setItem("kairo_driver_id", res.data.driver.id);
      sessionStorage.setItem("kairo_private_key", res.data.privateKey);
    } else {
      setError(res.error ?? "Registration failed");
    }
  }

  if (!hydrated) {
    return <div className="p-12 text-center text-swarm-muted">Loading…</div>;
  }

  if (!driverId) {
    return (
      <main className="mx-auto max-w-3xl px-4 py-12">
        <header className="mb-8">
          <span className="chip border-emerald-500/40 text-emerald-400">Kairo × YieldSwarm</span>
          <h1 className="mt-3 text-3xl font-semibold text-white">Driver Node</h1>
          <p className="mt-2 text-sm text-swarm-muted">
            Every Kairo driver is a YieldSwarm DePIN node with a persistent IoTeX + EVM identity.
            Signed telemetry feeds the Mandelbrot / Tree of Life data pipeline.
          </p>
        </header>
        <div className="panel p-8 text-center">
          <button
            type="button"
            disabled={registering}
            onClick={registerDriver}
            className="rounded-lg bg-emerald-500 px-6 py-3 font-medium text-black disabled:opacity-50"
          >
            {registering ? "Generating identity…" : "Register driver identity"}
          </button>
          {error && <p className="mt-3 text-sm text-red-400">{error}</p>}
        </div>
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-5xl px-4 py-8">
      <header className="mb-8">
        <span className="chip border-emerald-500/40 text-emerald-400">Kairo × YieldSwarm</span>
        <h1 className="mt-3 text-3xl font-semibold text-white">Data &amp; Rewards</h1>
        <p className="mt-2 text-sm text-swarm-muted">
          Customer trips: 1% flat fee · Driver pay: 2× base · Instant Wise cashout available
        </p>
      </header>
      <KairoDashboard driverId={driverId} />
    </main>
  );
}
