"use client";

import { useCallback, useEffect, useState } from "react";
import { api } from "@/lib/api";

interface EarningsData {
  driverId: string;
  earnings: {
    appRevenueUsd: string;
    depinRewardsUsd: string;
    cryptoRewardsUsd: string;
    grossTotalUsd: string;
    instantCashoutFeeUsd: string;
    netPayoutUsd: string;
  };
  feeModel: {
    customerPlatformFee: string;
    driverPayMultiplier: string;
    instantCashoutFee: string;
  };
}

export function KairoEarningsPanel({ driverId }: { driverId?: string }) {
  const [data, setData] = useState<EarningsData | null>(null);
  const [instant, setInstant] = useState(false);

  const refresh = useCallback(async () => {
    const id = driverId ?? "demo-driver";
    const q = new URLSearchParams({
      appRevenue: "125.50",
      depinRewards: "8.25",
      cryptoRewards: "3.10",
      instantCashout: instant ? "1" : "0",
    });
    const res = await api<EarningsData>(`/api/kairo/drivers/${id}/earnings?${q}`);
    if (res.ok && res.data) setData(res.data);
  }, [driverId, instant]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  if (!data) {
    return <div className="panel p-6 text-swarm-muted">Loading Kairo earnings…</div>;
  }

  const e = data.earnings;
  return (
    <div className="panel space-y-4 p-6">
      <div>
        <h3 className="text-lg font-semibold text-swarm-fg">Kairo Driver Earnings</h3>
        <p className="text-sm text-swarm-muted">
          {data.feeModel.driverPayMultiplier} pay · {data.feeModel.customerPlatformFee} customer fee
        </p>
      </div>
      <dl className="grid gap-2 text-sm">
        <div className="flex justify-between"><dt>App revenue</dt><dd>${e.appRevenueUsd}</dd></div>
        <div className="flex justify-between"><dt>DePIN rewards</dt><dd className="text-swarm-accent">${e.depinRewardsUsd}</dd></div>
        <div className="flex justify-between"><dt>Crypto rewards</dt><dd className="text-swarm-accent">${e.cryptoRewardsUsd}</dd></div>
        <div className="flex justify-between border-t border-swarm-border pt-2 font-semibold">
          <dt>Gross total</dt><dd>${e.grossTotalUsd}</dd>
        </div>
        {instant && (
          <div className="flex justify-between text-swarm-muted">
            <dt>Instant cashout fee</dt><dd>-${e.instantCashoutFeeUsd}</dd>
          </div>
        )}
        <div className="flex justify-between text-lg font-bold text-swarm-accent">
          <dt>Net payout</dt><dd>${e.netPayoutUsd}</dd>
        </div>
      </dl>
      <label className="flex items-center gap-2 text-sm">
        <input type="checkbox" checked={instant} onChange={(ev) => setInstant(ev.target.checked)} />
        Instant cashout (Wise/Square)
      </label>
    </div>
  );
}
