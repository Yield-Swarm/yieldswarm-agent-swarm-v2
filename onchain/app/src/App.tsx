import { useEffect, useMemo, useState } from 'react';
import { useConnection, useWallet } from '@solana/wallet-adapter-react';
import { WalletMultiButton } from '@solana/wallet-adapter-react-ui';
import { PROGRAM_IDS } from '@yieldswarm/onchain-sdk';
import { useYieldVault } from './hooks/useYieldVault';
import { useCrossChainBridge } from './hooks/useCrossChainBridge';
import { RoutingPanel } from './components/RoutingPanel';
import { VaultActions } from './components/VaultActions';

export default function App() {
  const { connection } = useConnection();
  const { publicKey } = useWallet();
  const vault = useYieldVault();
  const bridge = useCrossChainBridge();
  const [cluster, setCluster] = useState('devnet');

  useEffect(() => {
    void connection.getVersion().then((v) => setCluster(v['solana-core'] ?? 'devnet'));
  }, [connection]);

  const programs = useMemo(
    () => ({
      yieldVault: PROGRAM_IDS.yieldVault.toBase58().slice(0, 8) + '…',
      crossChain: PROGRAM_IDS.crossChain.toBase58().slice(0, 8) + '…',
      coordinator: PROGRAM_IDS.coordinator.toBase58().slice(0, 8) + '…',
    }),
    [],
  );

  return (
    <div className="app">
      <header className="header">
        <div>
          <h1>YieldSwarm</h1>
          <p className="subtitle">Cross-chain swarm vault dashboard · {cluster}</p>
        </div>
        <WalletMultiButton />
      </header>

      <main className="grid">
        <section className="card">
          <h2>Vault</h2>
          {publicKey ? (
            <>
              <p className="mono">Wallet: {publicKey.toBase58().slice(0, 12)}…</p>
              <dl className="stats">
                <div>
                  <dt>Total assets</dt>
                  <dd>{vault.totalAssets.toString()} lamports</dd>
                </div>
                <div>
                  <dt>Pending yield</dt>
                  <dd>{vault.pendingYield.toString()} lamports</dd>
                </div>
                <div>
                  <dt>Status</dt>
                  <dd>{vault.loading ? 'Loading…' : vault.initialized ? 'On-chain' : 'Not initialized'}</dd>
                </div>
              </dl>
              <VaultActions onDeposit={vault.deposit} onWithdraw={vault.withdraw} onClaim={vault.claim} />
            </>
          ) : (
            <p>Connect a Solana wallet to interact with the vault.</p>
          )}
        </section>

        <section className="card">
          <h2>Cross-chain bridge</h2>
          <dl className="stats">
            <div>
              <dt>Bridge total received</dt>
              <dd>{bridge.totalReceived.toString()} lamports</dd>
            </div>
            <div>
              <dt>Last harvest</dt>
              <dd>{bridge.lastHarvestTs ? new Date(bridge.lastHarvestTs * 1000).toLocaleString() : '—'}</dd>
            </div>
          </dl>
          {publicKey && (
            <button type="button" className="btn primary" onClick={() => void bridge.triggerHarvest()}>
              Trigger Helix harvest
            </button>
          )}
        </section>

        <RoutingPanel />
      </main>

      <footer className="footer">
        <span>Programs: {programs.yieldVault} · {programs.crossChain} · {programs.coordinator}</span>
      </footer>
    </div>
  );
}
