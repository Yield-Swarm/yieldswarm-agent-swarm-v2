"use client";

import { useCallback, useEffect, useState } from "react";
import { api } from "@/lib/api";

interface ContributionData {
  driver: { id: string; evmAddress: string; iotexAddress: string };
  contribution: {
    telemetryCount: number;
    totalDistanceMiles: number;
    estimatedDepinRewards: string;
    appRevenueShare: string;
  };
  earnings: {
    total: string;
    tripPay: string;
    appRevenue: string;
    depinRewards: string;
    availableCashout: string;
    breakdown: { label: string; amount: string; source: string }[];
  };
}

export function KairoDashboard({ driverId }: { driverId: string }) {
  const [data, setData] = useState<ContributionData | null>(null);
  const [loading, setLoading] = useState(true);
  const [cashoutAmount, setCashoutAmount] = useState("");
  const [cashoutMsg, setCashoutMsg] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    const res = await api<ContributionData>(`/api/kairo/contributions?driverId=${driverId}`);
    if (res.ok && res.data) setData(res.data);
    setLoading(false);
  }, [driverId]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  async function handleCashout() {
    setCashoutMsg(null);
    const res = await api<{ cashout: { netAmount: string; status: string } }>(
      "/api/kairo/drivers/cashout",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ driverId, amount: cashoutAmount, rail: "wise", instant: true }),
      },
    );
    if (res.ok && res.data) {
      setCashoutMsg(`Cashout ${res.data.cashout.status}: $${res.data.cashout.netAmount} net`);
      refresh();
    } else {
      setCashoutMsg(res.error ?? "Cashout failed");
    }
  }

  if (loading || !data) {
    return <div className="panel p-8 text-center text-swarm-muted">Loading Kairo dashboard…</div>;
  }

  return (
    <div className="space-y-6">
      <div className="panel p-6">
        <h2 className="text-lg font-semibold text-white">Driver Identity</h2>
        <dl className="mt-3 grid gap-2 text-sm text-swarm-muted">
          <div>
            <dt className="text-xs uppercase tracking-wide">EVM</dt>
            <dd className="font-mono text-swarm-accent">{data.driver.evmAddress}</dd>
          </div>
          <div>
            <dt className="text-xs uppercase tracking-wide">IoTeX</dt>
            <dd className="font-mono text-swarm-accent">{data.driver.iotexAddress}</dd>
          </div>
        </dl>
      </div>

      <div className="grid gap-6 md:grid-cols-3">
        <div className="panel p-5">
          <p className="text-xs uppercase text-swarm-muted">Telemetry samples</p>
          <p className="mt-1 text-2xl font-semibold text-white">
            {data.contribution.telemetryCount}
          </p>
        </div>
        <div className="panel p-5">
          <p className="text-xs uppercase text-swarm-muted">Distance (mi)</p>
          <p className="mt-1 text-2xl font-semibold text-white">
            {Number(data.contribution.totalDistanceMiles).toFixed(1)}
          </p>
        </div>
        <div className="panel p-5">
          <p className="text-xs uppercase text-swarm-muted">Est. DePIN rewards</p>
          <p className="mt-1 text-2xl font-semibold text-emerald-400">
            {data.contribution.estimatedDepinRewards}
          </p>
        </div>
      </div>

      <div className="panel p-6">
        <h2 className="text-lg font-semibold text-white">Earnings breakdown</h2>
        <p className="mt-1 text-3xl font-bold text-white">${data.earnings.total}</p>
        <ul className="mt-4 space-y-2">
          {data.earnings.breakdown.map((row) => (
            <li
              key={row.label}
              className="flex items-center justify-between rounded-lg border border-white/5 px-3 py-2 text-sm"
            >
              <span className="text-swarm-muted">{row.label}</span>
              <span className="font-mono text-white">${row.amount}</span>
            </li>
          ))}
        </ul>
      </div>

      <div className="panel p-6">
        <h2 className="text-lg font-semibold text-white">Instant cashout</h2>
        <p className="mt-1 text-sm text-swarm-muted">
          Available: ${data.earnings.availableCashout} · 1.5% instant fee
        </p>
        <div className="mt-4 flex gap-3">
          <input
            type="text"
            inputMode="decimal"
            placeholder="Amount"
            value={cashoutAmount}
            onChange={(e) => setCashoutAmount(e.target.value)}
            className="flex-1 rounded-lg border border-white/10 bg-black/30 px-3 py-2 text-white"
          />
          <button
            type="button"
            onClick={handleCashout}
            className="rounded-lg bg-swarm-accent px-4 py-2 text-sm font-medium text-black"
          >
            Cash out via Wise
          </button>
        </div>
        {cashoutMsg && <p className="mt-2 text-sm text-swarm-muted">{cashoutMsg}</p>}
      </div>
    </div>
  );
}
