import { FC, useEffect, useState } from 'react';
import { useWallet } from '@solana/wallet-adapter-react';
import { useYieldVault } from '@yieldswarm/cross-chain-sdk';
import { VaultPanel } from './components/VaultPanel';
import { RoutingPanel } from './components/RoutingPanel';
import { TxPanel } from './components/TxPanel';
import { useYieldRoutes } from './hooks/useYieldRoutes';

export const App: FC = () => {
  const { publicKey } = useWallet();
  const vault = useYieldVault({ userPubkey: publicKey });
  const routes = useYieldRoutes();
  const [txLogs, setTxLogs] = useState<string[]>([]);

  const appendLog = (msg: string) => {
    setTxLogs((prev) => [`[${new Date().toLocaleTimeString()}] ${msg}`, ...prev].slice(0, 20));
  };

  useEffect(() => {
    fetch('/api/revenue/metrics')
      .then((r) => r.json())
      .then((data) => appendLog(`Revenue baseline: $${data?.totalUsd ?? '—'}`))
      .catch(() => appendLog('Revenue API offline (dev mode)'));
  }, []);

  return (
    <div className="dashboard">
      <header className="hero">
        <h1>YieldSwarm Dashboard</h1>
        <p>Cross-chain yield execution · 521-agent swarm · ValhallA analytics</p>
      </header>

      <main className="grid">
        <VaultPanel vault={vault} />
        <RoutingPanel
          routes={routes.routes}
          bestRoute={routes.bestRoute}
          loading={routes.loading}
        />
        <TxPanel pendingReferralRewards={vault.pendingReferralRewards} onLog={appendLog} />
      </main>

      <section className="panel tx-log-panel">
        <h2>Transaction Log</h2>
        <ul>
          {txLogs.length === 0 && <li className="muted">No transactions yet</li>}
          {txLogs.map((line) => (
            <li key={line}>{line}</li>
          ))}
        </ul>
      </section>
    </div>
  );
};
