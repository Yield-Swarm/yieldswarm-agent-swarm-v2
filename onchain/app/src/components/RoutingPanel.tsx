import { useEffect, useState } from 'react';
import { useConnection } from '@solana/wallet-adapter-react';
import { fetchYieldRoutes, bestYieldRoute, type YieldRoute } from '@yieldswarm/onchain-sdk';

export function RoutingPanel() {
  const { connection } = useConnection();
  const [routes, setRoutes] = useState<YieldRoute[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    void fetchYieldRoutes(connection).then((r) => {
      if (!cancelled) {
        setRoutes(r);
        setLoading(false);
      }
    });
    const id = setInterval(() => {
      void fetchYieldRoutes(connection).then((r) => {
        if (!cancelled) setRoutes(r);
      });
    }, 30_000);
    return () => {
      cancelled = true;
      clearInterval(id);
    };
  }, [connection]);

  const best = bestYieldRoute(routes);

  return (
    <section className="card wide">
      <h2>Yield routing</h2>
      <p className="subtitle">Kamino · Drift · JitoSOL (RPC scan)</p>
      {loading ? (
        <p>Scanning routes…</p>
      ) : (
        <table className="routes">
          <thead>
            <tr>
              <th>Protocol</th>
              <th>APY</th>
              <th>Mint</th>
            </tr>
          </thead>
          <tbody>
            {routes.map((r) => (
              <tr key={r.protocol} className={best?.protocol === r.protocol ? 'best' : ''}>
                <td>{r.protocol}</td>
                <td>{(r.apyBps / 100).toFixed(2)}%</td>
                <td className="mono">{r.mint.slice(0, 10)}…</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      {best && <p className="hint">Recommended: <strong>{best.protocol}</strong> @ {(best.apyBps / 100).toFixed(2)}% APY</p>}
    </section>
  );
}
