import { FC } from 'react';
import { formatLamports } from '@yieldswarm/cross-chain-sdk';
import { useTreasuryBalances } from '@yieldswarm/cross-chain-sdk';

export const TreasuryPanel: FC = () => {
  const treasury = useTreasuryBalances();

  return (
    <section className="panel treasury-panel">
      <h2>Multi-Chain Treasury</h2>
      <p className="subtitle">Nexus Treasury + Mining Roots (Solenoid 1)</p>
      {treasury.loading && <p className="loading">Loading treasury registry…</p>}
      {treasury.error && <p className="error">{treasury.error}</p>}
      {!treasury.loading && (
        <>
          <dl className="stats">
            <div>
              <dt>Nexus Treasury</dt>
              <dd className="mono">{treasury.nexusTreasury.slice(0, 12)}…</dd>
            </div>
            <div>
              <dt>Routed to Nexus</dt>
              <dd>{formatLamports(treasury.totalToNexus)} SOL</dd>
            </div>
            <div>
              <dt>Routed to Mining</dt>
              <dd>{formatLamports(treasury.totalToMining)} SOL</dd>
            </div>
            <div>
              <dt>Status</dt>
              <dd>
                {treasury.pausedSweeps || treasury.pausedInflows
                  ? `Paused (sweeps=${treasury.pausedSweeps}, inflows=${treasury.pausedInflows})`
                  : 'Active'}
              </dd>
            </div>
          </dl>
          <h3 className="subhead">Mining Roots</h3>
          <ul className="root-list">
            {treasury.miningRoots.map((root) => (
              <li key={root.rootKind}>
                <span className="protocol">#{root.rootKind}</span>
                <span className="label">{root.address.slice(0, 18)}…</span>
                <span className="apy">{formatLamports(root.totalRouted)}</span>
              </li>
            ))}
          </ul>
        </>
      )}
    </section>
  );
};
