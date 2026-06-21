import { FC } from 'react';
import type { YieldRoute } from '@yieldswarm/cross-chain-sdk';

interface RoutingPanelProps {
  routes: YieldRoute[];
  bestRoute: YieldRoute | null;
  loading: boolean;
}

function formatApy(apyBps: number): string {
  return `${(apyBps / 100).toFixed(2)}%`;
}

export const RoutingPanel: FC<RoutingPanelProps> = ({ routes, bestRoute, loading }) => (
  <section className="panel routing-panel">
    <h2>Yield Routing Engine</h2>
    <p className="subtitle">Live rates across Kamino, Drift, and JitoSOL</p>
    {loading && <p className="loading">Scanning DeFi markets…</p>}
    {!loading && bestRoute && (
      <div className="best-route">
        <span className="badge">Optimal</span>
        <strong>{bestRoute.label}</strong>
        <span className="apy">{formatApy(bestRoute.apyBps)} APY</span>
      </div>
    )}
    <ul className="route-list">
      {routes.map((route) => (
        <li key={route.protocol} className={bestRoute?.protocol === route.protocol ? 'active' : ''}>
          <span className="protocol">{route.protocol.toUpperCase()}</span>
          <span className="label">{route.label}</span>
          <span className="apy">{formatApy(route.apyBps)}</span>
        </li>
      ))}
    </ul>
  </section>
);
