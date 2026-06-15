import { useBalance } from "../react/hooks";
import type { ChainNamespace } from "../types";

/** Compact native-balance display for an ecosystem, with live polling. */
export function BalanceLine({ namespace }: { namespace?: ChainNamespace }) {
  const { data, isLoading, error } = useBalance({ namespace });

  if (error) return <div className="ysw-muted">Balance unavailable</div>;
  if (isLoading && !data) return <div className="ysw-muted">Loading balance…</div>;
  if (!data) return null;

  return (
    <div className="ysw-muted">
      <strong style={{ color: "#f4f5f7" }}>{data.formatted}</strong> {data.symbol}
      {typeof data.usd === "number" && <span> · ${data.usd.toFixed(2)}</span>}
    </div>
  );
}
