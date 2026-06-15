"use client";

import type { Transaction } from "./types";

const STATUS_STYLES: Record<string, string> = {
  completed: "border-swarm-accent2/40 text-swarm-accent2",
  processing: "border-swarm-accent/40 text-swarm-accent",
  pending: "border-yellow-500/40 text-yellow-400",
  failed: "border-swarm-danger/40 text-swarm-danger",
  cancelled: "border-swarm-border text-swarm-muted",
};

export function TransactionsPanel({
  transactions,
  onRefresh,
}: {
  transactions: Transaction[];
  onRefresh: () => void;
}) {
  return (
    <section className="panel p-5">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-white">Activity</h2>
        <button className="btn-ghost !px-3 !py-1.5 text-xs" onClick={onRefresh}>
          Refresh
        </button>
      </div>
      {transactions.length === 0 ? (
        <p className="mt-4 text-sm text-swarm-muted">No transactions yet.</p>
      ) : (
        <div className="mt-4 overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="text-xs uppercase text-swarm-muted">
              <tr>
                <th className="py-2 pr-3">Type</th>
                <th className="py-2 pr-3">Rail</th>
                <th className="py-2 pr-3">Amount</th>
                <th className="py-2 pr-3">Status</th>
                <th className="py-2 pr-3">When</th>
              </tr>
            </thead>
            <tbody>
              {transactions.map((t) => (
                <tr key={t.id} className="border-t border-swarm-border/60">
                  <td className="py-2 pr-3 capitalize">{t.direction}</td>
                  <td className="py-2 pr-3">
                    <span className="chip uppercase">{t.rail}</span>
                    {t.chain && <span className="ml-1 text-[11px] text-swarm-muted">{t.chain}</span>}
                  </td>
                  <td className="py-2 pr-3 font-mono">
                    {t.direction === "withdrawal" ? "-" : "+"}
                    {t.amount} {t.currency}
                  </td>
                  <td className="py-2 pr-3">
                    <span className={`chip ${STATUS_STYLES[t.status] ?? "border-swarm-border"}`}>
                      {t.status}
                    </span>
                  </td>
                  <td className="py-2 pr-3 text-xs text-swarm-muted">
                    {new Date(t.createdAt).toLocaleString()}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
