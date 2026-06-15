"use client";

import { useEffect, useState } from "react";

interface Driver {
  id: string;
  displayName: string;
  evmAddress: string;
  iotexAddress: string;
  swarmShardId: number;
  status: string;
  lastActiveAt?: string;
}

interface Contribution {
  driverId: string;
  totalEvents: number;
  signedEvents: number;
  invalidSignatures: number;
  totalKm: number;
  mandelbrotShards: number[];
  estimatedRewardPoints: number;
  lastEventAt?: string;
}

export default function KairoDashboardPage() {
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [selectedDriver, setSelectedDriver] = useState<string>("");
  const [contribution, setContribution] = useState<Contribution | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch("/api/kairo/drivers/register")
      .then((r) => r.json())
      .then((d) => {
        setDrivers(d.drivers ?? []);
        if (d.drivers?.length) setSelectedDriver(d.drivers[0].id);
      })
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    if (!selectedDriver) return;
    fetch(`/api/kairo/telemetry?driverId=${selectedDriver}`)
      .then((r) => r.json())
      .then((d) => setContribution(d.contribution ?? null));
  }, [selectedDriver]);

  if (loading) {
    return (
      <main className="mx-auto max-w-5xl px-4 py-12 text-swarm-muted">
        Loading Kairo dashboard…
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-5xl px-4 py-8 md:py-12">
      <header className="mb-8">
        <div className="flex items-center gap-2 text-sm text-swarm-muted">
          <span className="chip border-emerald-500/40 text-emerald-400">Kairo</span>
          <span>DePIN Driver Dashboard</span>
        </div>
        <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white md:text-4xl">
          Data Contribution &amp; Rewards
        </h1>
        <p className="mt-2 max-w-2xl text-sm text-swarm-muted">
          Every Kairo driver is a YieldSwarm node. Signed telemetry routes into the
          Mandelbrot / Tree of Life mesh for DePIN reward attribution.
        </p>
      </header>

      {drivers.length === 0 ? (
        <div className="rounded-xl border border-swarm-border bg-swarm-surface p-6 text-sm text-swarm-muted">
          No drivers registered yet. POST to{" "}
          <code className="text-swarm-accent">/api/kairo/drivers/register</code> to
          create a cryptographic identity.
        </div>
      ) : (
        <>
          <div className="mb-6">
            <label className="text-sm text-swarm-muted">Select driver</label>
            <select
              className="mt-1 w-full rounded-lg border border-swarm-border bg-swarm-surface px-3 py-2 text-white"
              value={selectedDriver}
              onChange={(e) => setSelectedDriver(e.target.value)}
            >
              {drivers.map((d) => (
                <option key={d.id} value={d.id}>
                  {d.displayName} ({d.evmAddress.slice(0, 10)}…)
                </option>
              ))}
            </select>
          </div>

          {contribution && (
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
              <StatCard label="Signed Events" value={contribution.signedEvents} />
              <StatCard label="Total km" value={contribution.totalKm.toFixed(1)} />
              <StatCard label="Mandelbrot Shards" value={contribution.mandelbrotShards.length} />
              <StatCard
                label="Est. Reward Points"
                value={contribution.estimatedRewardPoints}
                accent
              />
            </div>
          )}

          {contribution && (
            <div className="mt-6 rounded-xl border border-swarm-border bg-swarm-surface p-6">
              <h2 className="text-lg font-medium text-white">Tree of Life Routing</h2>
              <p className="mt-2 text-sm text-swarm-muted">
                Telemetry from this driver has contributed to{" "}
                <strong className="text-white">{contribution.mandelbrotShards.length}</strong>{" "}
                of 10,080 mesh shards across 7 branches × 12 tribes × 120 cron shards.
              </p>
              {contribution.invalidSignatures > 0 && (
                <p className="mt-2 text-sm text-amber-400">
                  {contribution.invalidSignatures} events rejected (invalid signatures).
                </p>
              )}
            </div>
          )}
        </>
      )}
    </main>
  );
}

function StatCard({
  label,
  value,
  accent,
}: {
  label: string;
  value: string | number;
  accent?: boolean;
}) {
  return (
    <div className="rounded-xl border border-swarm-border bg-swarm-surface p-4">
      <p className="text-xs text-swarm-muted">{label}</p>
      <p className={`mt-1 text-2xl font-semibold ${accent ? "text-emerald-400" : "text-white"}`}>
        {value}
      </p>
    </div>
  );
}
