"use client";

import { useCallback, useEffect, useState } from "react";
import { api } from "@/lib/api";
import type { BalanceResponse, PublicConfig } from "./types";
import { BalancePanel } from "./BalancePanel";
import { WalletConnectPanel } from "./WalletConnectPanel";
import { DepositPanel } from "./DepositPanel";
import { WithdrawPanel } from "./WithdrawPanel";
import { TransactionsPanel } from "./TransactionsPanel";
import { KairoEarningsPanel } from "./KairoEarningsPanel";

export function PaymentsApp() {
  const [config, setConfig] = useState<PublicConfig | null>(null);
  const [account, setAccount] = useState<BalanceResponse | null>(null);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    const res = await api<BalanceResponse>("/api/balance");
    if (res.ok && res.data) setAccount(res.data);
  }, []);

  useEffect(() => {
    let active = true;
    (async () => {
      const [cfg, bal] = await Promise.all([
        api<PublicConfig>("/api/config"),
        api<BalanceResponse>("/api/balance"),
      ]);
      if (!active) return;
      if (cfg.ok && cfg.data) setConfig(cfg.data);
      if (bal.ok && bal.data) setAccount(bal.data);
      setLoading(false);
    })();
    return () => {
      active = false;
    };
  }, []);

  if (loading || !config) {
    return (
      <div className="panel p-8 text-center text-swarm-muted">Loading payment rails…</div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="grid gap-6 md:grid-cols-2">
        <BalancePanel account={account} onRefresh={refresh} />
        <WalletConnectPanel
          config={config}
          wallets={account?.wallets ?? []}
          onLinked={refresh}
        />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <DepositPanel config={config} onChange={refresh} />
        <WithdrawPanel config={config} balances={account?.balances ?? {}} onChange={refresh} />
      </div>

      <TransactionsPanel transactions={account?.transactions ?? []} onRefresh={refresh} />

      <KairoEarningsPanel />
    </div>
  );
}
