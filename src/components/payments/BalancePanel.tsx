"use client";

import type { BalanceResponse } from "./types";

export function BalancePanel({
  account,
  onRefresh,
}: {
  account: BalanceResponse | null;
  onRefresh: () => void;
}) {
  const balances = account?.balances ?? {};
  const entries = Object.entries(balances).filter(([, v]) => Number(v) !== 0);

  return (
    <section className="panel p-5">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-white">Balances</h2>
        <button className="btn-ghost !px-3 !py-1.5 text-xs" onClick={onRefresh}>
          Refresh
        </button>
      </div>
      {entries.length === 0 ? (
        <p className="mt-4 text-sm text-swarm-muted">
          No funds yet. Make a deposit to get started.
        </p>
      ) : (
        <ul className="mt-4 space-y-2">
          {entries.map(([currency, amount]) => (
            <li
              key={currency}
              className="flex items-center justify-between rounded-xl border border-swarm-border bg-black/30 px-4 py-3"
            >
              <span className="font-medium text-slate-200">{currency}</span>
              <span className="font-mono text-lg text-swarm-accent2">{amount}</span>
            </li>
          ))}
        </ul>
      )}
      {account?.user && (
        <p className="mt-4 truncate text-xs text-swarm-muted">
          Account: <span className="font-mono">{account.user.id}</span>
        </p>
      )}
    </section>
  );
}
